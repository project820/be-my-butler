# BMB v0.3.5 — Haiku Monitor Agent

## 목적

`config/defaults.json`에는 Monitor 설정이 이미 존재하지만, 실제 Monitor 에이전트 정의와 Lead 파이프라인 spawn 연결이 없어 기능이 비활성 상태다.

이 변경의 목표는 아래 세 가지다.

- Lead가 직접 폴링하며 컨텍스트를 낭비하지 않도록 한다.
- 54분 hang 같은 조용한 실패를 더 빨리 감지한다.
- Consultant가 lifecycle-safe 범위 안에서 에이전트 진행 상태를 실시간에 가깝게 받도록 한다.

## 검토 결과 요약

기존 초안은 방향은 맞지만 v0.3.5 기준으로는 아래 보완이 필요하다.

- Monitor의 `tmux split-pane` 예외 규칙이 명시적으로 적혀 있어야 한다.
- Watch item에 `blind_phase`가 포함되어야 하며, Step 6~7 진입/해제 알림도 별도 계약으로 정의되어야 한다.
- Monitor는 관찰자여야 하므로 recovery 방안을 추천하거나 결정하는 문구는 제거해야 한다.
- 입력 범위는 메타데이터 중심으로 더 좁혀야 하며, handoff 본문/요약 헤더 읽기에 기대면 blind phase 누출 위험이 생긴다.
- Monitor 실패는 파이프라인을 절대 막지 않는 optional dependency로 명시해야 한다.

## 설계 결정

### 1. tmux split-pane 규칙의 유일한 예외

기존 규칙:

> NEVER use the Agent tool — ALL agents MUST be spawned via tmux split-pane.

v0.3.5 예외:

> Monitor 에이전트는 이 규칙의 유일한 예외다.
> Lead가 Agent tool로 직접 실행한다.
> pane를 배정하지 않는다.
> 다른 모든 에이전트는 여전히 tmux split-pane 필수다.

이 예외의 이유는 Monitor가 작업 수행자가 아니라 Lead 직속의 경량 관찰자이기 때문이다. 독립 pane보다 Lead 컨텍스트 안에서 작동하는 메타데이터 루프가 설계 의도에 맞다.

### 2. 모델

- Monitor 모델은 `claude-haiku`를 사용한다.
- Haiku-class 이상 모델로 올리지 않는다.
- Monitor는 메타데이터 감시 전용이므로 비용과 응답성을 우선한다.

### 3. 기존 설정과의 정렬

현재 `config/defaults.json`에는 아래 Monitor 기본값이 이미 있다.

- `enabled: true`
- `interval: 30`
- `model: "haiku"`
- `idle_stall_sec: 180`
- `consultant_reporting: "filtered"`

구현은 이 설정을 그대로 소비하되, 실제 spawn 시점의 모델 지정은 `claude-haiku`로 명확히 맞춘다.

## Monitor 책임

### Monitor가 하는 것

- handoff 결과 파일 존재 여부 감지
- 파일 `mtime` / `size` 변화 정지 감지
- timeout 90% 도달 시 `timeout_imminent` 경고
- timeout 100% 도달 시 `timeout_exceeded` 경고
- 상태 변화가 있을 때만 Lead에게 짧은 메시지 보고
- lifecycle-safe 이벤트만 Consultant에게 전달

### Monitor가 하지 않는 것

- 소스 파일 읽기
- 결과 내용 해석
- recovery 결정
- blind phase 중 verdict/실패 세부내용/coverage 전달
- 사용자에게 직접 발화
- heartbeat성 주기 메시지 전송

## 관찰 계약

### Watch Item

Lead가 각 에이전트 spawn 직후 Monitor에 아래 구조를 전달한다.

```json
{
  "agent": "executor",
  "step": "5",
  "result_path": ".bmb/handoffs/exec-result.md",
  "pid_file": ".bmb/sessions/{SESSION_ID}/executor.pid",
  "timeout_sec": 1200,
  "started_at_epoch": 1773372600,
  "blind_phase": false,
  "consultant_reporting": "filtered"
}
```

필드 의미:

- `agent`: 감시 대상 에이전트 이름
- `step`: 파이프라인 step 식별자
- `result_path`: 완료 산출물 경로
- `pid_file`: 대상 프로세스 PID 파일
- `timeout_sec`: 대상 timeout
- `started_at_epoch`: 시작 시각
- `blind_phase`: 현재 blind phase 여부
- `consultant_reporting`: Consultant 전달 정책

### Lead 보고 형식

상태 변화가 있을 때만 아래 형식으로 보낸다.

```text
[MONITOR] agent=executor step=5 state=result_ready file=.bmb/handoffs/exec-result.md ts=14:09
[MONITOR] agent=tester step=6 state=stalled idle_sec=240 cpu_pct=0.1 ts=14:22
[MONITOR] agent=verifier step=7 state=timeout_imminent elapsed=1080/1200s ts=14:35
```

원칙:

- noisy heartbeat 금지
- 상태 변화가 없으면 아무 메시지도 보내지 않음
- 판단이 아니라 관찰 결과만 보고

### Consultant 이벤트 형식

lifecycle-safe 이벤트만 전달한다.

```json
{"event":"agent_complete","step":"5","agent":"executor","result":".bmb/handoffs/exec-result.md","ts":"14:09","source":"monitor"}
{"event":"monitor_stall","step":"6","agent":"tester","idle_sec":240,"cpu_pct":0.1,"ts":"14:22","source":"monitor"}
{"event":"monitor_timeout_imminent","step":"7","agent":"verifier","elapsed_sec":1080,"timeout_sec":1200,"ts":"14:35","source":"monitor"}
```

blind phase 중 아래 정보는 절대 전달하지 않는다.

- 테스트 verdict
- 검증 verdict
- 실패 세부내용
- coverage 수치
- root-cause 해석

## Stall 판정 규칙

metadata-first 원칙을 사용한다.

stall 의심 보고 조건:

1. 프로세스가 살아 있다. `pid_file` 기반 확인
2. `result_path`가 아직 없다.
3. 파일 `mtime` / `size` 변화가 `idle_stall_sec` 이상 없다.

CPU%는 보조 증거로만 사용한다.

- CPU가 낮아도 단독으로 stall 판정 금지
- CPU 수치는 Lead 보고 메시지의 부가 정보로만 포함 가능

즉, stall은 `alive + no_result + no_metadata_progress` 조합으로 의심 보고하고, 최종 판단과 recovery 시도 여부는 Lead가 결정한다.

## Blind Phase 프로토콜

Step 6~7은 blind phase로 취급한다.

Lead는 아래 두 종류의 제어 메시지를 Monitor에 추가로 보낸다.

1. blind phase 진입 시:
   `blind_phase=true`로 해당 watch item을 갱신
2. blind phase 해제 시:
   `blind_phase=false`로 복구

Monitor 동작:

- Lead에게는 기존대로 상태 변화 보고 가능
- Consultant에게는 lifecycle-safe 이벤트만 전달
- verdict, failure detail, coverage, result body 기반 정보는 전달 금지

## 컨텍스트 효율 규칙

Monitor는 아래 명령만으로 충분한 관찰을 우선한다.

- `test -f`
- `stat`
- `wc -c`
- `ls -l`
- `ps`

추가 원칙:

- 대용량 파일 내용 로드 금지
- 메타데이터로 충분하면 본문을 읽지 않음
- 내부 상태는 최소만 유지

유지 상태:

- `last_size`
- `last_mtime`
- `last_state`
- timeout 체크포인트 보고 여부

## 구현 범위

### 1. `agents/bmb-monitor.md` 신규 생성

포함 내용:

- Lead-owned Haiku Monitor 역할 정의
- 허용 입력과 금지 입력
- watch item 등록/갱신 계약
- blind phase 필터링 규칙
- Lead/Consultant 보고 형식
- optional dependency 원칙

### 2. `skills/bmb/bmb.md` 업데이트

Step 1에 아래를 추가한다.

- Monitor를 Agent tool로 직접 spawn
- tmux 예외 규칙을 코드와 문서 양쪽에 명시
- spawn 실패 시 경고만 남기고 파이프라인 계속 진행

각 작업 에이전트 spawn 지점에 아래를 추가한다.

- watch item 생성
- Monitor에 등록 메시지 전달
- blind phase 진입/해제 시 watch item 갱신

## Optional Dependency 규칙

Monitor는 보조 도구다.

- Monitor spawn 실패 시 파이프라인은 계속 진행
- Monitor가 중간에 종료되어도 파이프라인은 계속 진행
- Lead는 Monitor 부재 시에만 기존 폴링 방식으로 fallback
- Monitor 상태 자체가 block condition이 되면 안 된다

## 검증 기준

- `agents/bmb-monitor.md`가 생성된다
- `skills/bmb/bmb.md` Step 1에서 Monitor가 Agent tool로 실행된다
- executor spawn 시 Monitor에 watch item이 전달된다
- stall 감지 시 Lead에게 `[MONITOR]` 메시지가 전달된다
- blind phase 중 Consultant에 verdict 정보가 유출되지 않는다
- Monitor가 죽어도 파이프라인은 계속 진행된다

## 구현 전 확인 메모

2026-03-13 기준 현재 워크스페이스에서 확인된 파일은 아래 두 개다.

- `plans/bmb-monitor-draft.md`
- `config/defaults.json`

반면 아래 구현 대상 파일은 아직 현재 경로에서 보이지 않았다.

- `agents/bmb-monitor.md`
- `skills/bmb/bmb.md`

따라서 구현 시작 전에는 실제 canonical 경로를 한 번 더 확인해야 한다. 경로가 이동된 상태라면 동일 책임을 가진 실제 pipeline 정의 파일에 반영하면 된다.

## Lead 전달용 한 줄 요약

v0.3.5에서는 Monitor를 `claude-haiku` 기반의 Lead-owned optional observer로 추가한다. Agent tool direct spawn만 허용되는 유일한 예외이며, 메타데이터만 감시하고, 상태 변화만 Lead에 보고하고, blind phase에서는 Consultant에 lifecycle-safe 이벤트만 전달한다.
