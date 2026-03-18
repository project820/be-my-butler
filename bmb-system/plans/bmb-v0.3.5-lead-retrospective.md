# BMB v0.3.5 — Lead Retrospective Enforcement + Cross-Model Reliability

## Problem Statement

Lead가 Step 11 Cleanup에서 commit/push/pane 정리에만 집중하고, 핵심 회고 단계를 건너뛰고 있음:

1. **`bmb_learn` 미호출** — bash 함수를 source하지 않아 learnings.md가 영구적으로 비어있음
2. **analyst 보고서 미전달** — summary만 보고 유저에게 핵심 발견사항을 전달하지 않음
3. **promotion check 미실행** — learnings.md가 비었으니 2회 이상 반복 규칙 탐지도 불가
4. **auto-memory 저장 미실행** — 세션에서 발견된 유저 성향/교훈이 영구 저장 안 됨

결과: BMB의 학습 루프가 사실상 끊겨있음. 파이프라인을 반복해도 같은 실수가 반복됨.

## Root Cause

bmb.md Step 11에서 회고가 cleanup의 **부속 항목**으로 나열됨 (항목 10/14).
Lead 입장에서 commit/push가 "마무리"처럼 느껴져서 회고 전에 완료를 선언함.

## Design: Step 11을 분리

### 현재 (v0.3.4)
```
Step 10.5: Analyst → report 파일 생성
Step 11: Cleanup (commit + push + carry-forward + promotion check + ...)
```

### 제안 (v0.3.5)
```
Step 10.5: Analyst → report 파일 생성
Step 11: Lead Retrospective (NEW — 회고 전용)
Step 12: Cleanup (commit + push + carry-forward)
```

## Step 11: Lead Retrospective (신규)

### 11.1 — bmb_learn 호출 (필수)
```bash
# Lead가 직접 bash로 실행
source "$HOME/.claude/bmb-system/scripts/bmb-learn.sh"

# 파이프라인 중 발생한 사건 기록
# 예: verification 실패, cross-model timeout, executor 재시도 등
bmb_learn MISTAKE "7" "cross-model verifier timeout" "cross_model_verify timeout을 900초로 줄여야 함"
bmb_learn PRAISE "5" "executor 10파일 한번에 완료" "infra 레시피에서 단일 executor 전략이 효과적"
```

**규칙**: 세션당 최소 1개의 `bmb_learn` 호출 필수.
실수가 없었으면 PRAISE라도 기록. 빈 learnings.md는 허용하지 않음.

### 11.2 — Analyst 보고서 유저 전달 (필수)
```
Lead가 .bmb/handoffs/analyst-report.md를 읽고:
1. 핵심 발견사항 3줄 이내로 유저에게 직접 전달
2. 권고사항이 있으면 유저에게 "이 설정 바꿀까요?" 확인
3. 반복 패턴이 있으면 명시
```

**규칙**: analyst 보고서가 존재하면 반드시 유저에게 요약 전달.
"analyst complete" 로그만 남기고 넘어가는 것은 금지.

### 11.3 — Promotion Check (필수)
```bash
# learnings.md 스캔
if [ -f ".bmb/learnings.md" ]; then
  # 동일/유사 rule 텍스트가 2회 이상 등장하는지 체크
  # 발견 시 유저에게 제안
fi
```

**규칙**: learnings.md가 존재하면 반드시 스캔.
승격 후보 발견 시 유저에게 제안 (auto-edit 금지).

### 11.4 — Auto-memory 저장 (선택)
```
세션 중 발견된 항목 중 영구 저장 가치가 있는 것:
- 유저 성향/선호 (feedback 타입)
- 프로젝트 상태 변경 (project 타입)
- 외부 참조 발견 (reference 타입)
→ auto-memory에 저장
```

### 11.5 — Context Check
```
Lead가 context 여유를 확인:
- 여유 있음 → 11.1~11.4 전부 실행
- 빡빡함 → 11.1 (bmb_learn) + 11.3 (promotion) 최소 실행 후 carry-forward에 "회고 미완" 기록
```

**규칙**: context가 아무리 부족해도 11.1은 반드시 실행.
bmb_learn 1회 호출은 토큰 100개 미만이므로 항상 가능.

## Step 12: Cleanup (기존 Step 11에서 회고 제거)

기존 Step 11의 나머지:
- Consultant pane 종료
- Conversation logger shutdown
- Git commit + push
- Carry-forward + session-prep 작성
- Worktree 정리
- Telegram 알림
- "계속할까요?" 질문

## 수정 대상 파일

| 파일 | 변경 |
|------|------|
| `skills/bmb/bmb.md` | Step 11 → Step 11 (Retrospective) + Step 12 (Cleanup) 분리 |
| `agents/bmb-analyst.md` | analyst 보고서에 "Lead 전달용 요약" 섹션 추가 |
| `bmb-system/scripts/bmb-analytics.sh` | `bmb_analytics_end_session`에서 steps_completed 12로 변경 |
| `config/defaults.json` | `retrospective.min_learnings_per_session: 1` 추가 |
| `RECIPE REFERENCE 테이블` | 모든 레시피에 retrospective 단계 명시 |

## Part 2: Cross-Model Reliability (Codex 실패율 0% 목표)

### Problem Statement

cross-model-run.sh를 통한 Codex 호출이 반복적으로 실패:
- verifier-cross 50% 실패율 (3세션 중 2회 호출, 1회 timeout/crash)
- tester-cross도 이전 세션에서 timeout 강등
- Lead는 "graceful degradation"으로 매번 넘어감 → 원인 분석 없음

### 진단 결과 (2026-03-13 실측)

| # | 문제 | 근본 원인 | 영향 |
|---|------|----------|------|
| 1 | **`timeout` 명령어 없음** | macOS에 GNU coreutils 미설치. `timeout`이 없으므로 `set -euo pipefail`에 의해 스크립트 즉사 (exit 127) | **Critical — pane이 결과 없이 죽는 주 원인** |
| 2 | **MCP 서버 8개 startup** | codex가 기동 시 playwright, filesystem, omx_*, context7, supermemory 등 MCP 서버 8개를 로딩. supermemory는 매번 실패 (HTTP 404) | Medium — 시작 지연 + 에러 노이즈 |
| 3 | **stdout 배너 오염** | `codex exec` 출력에 버전 정보, MCP 로그, token count가 실제 응답과 혼합 | Low — 파일 기반 결과 전달로 우회 가능 |

### 수정 설계

#### Fix 1: `timeout` portable fallback (Critical)

```bash
# cross-model-run.sh 상단에 추가
if ! command -v timeout &>/dev/null; then
  # macOS: perl 기반 portable timeout
  timeout() {
    local duration="$1"; shift
    perl -e '
      $SIG{ALRM} = sub { kill 9, $pid; exit 124 };
      alarm(shift);
      $pid = fork // die;
      if ($pid == 0) { exec @ARGV; die "exec: $!" }
      waitpid($pid, 0);
      exit ($? >> 8);
    ' "$duration" "$@"
  }
fi
```

검증 방법:
```bash
# macOS에서 테스트
timeout 5 sleep 2 && echo "OK"       # 정상 종료
timeout 2 sleep 5; echo "RC=$?"      # RC=124 (timeout)
```

#### Fix 2: Codex invocation 안정화

```bash
# codex exec 호출 시 노이즈 필터링 + 결과 분리
# stdout → 파일 (결과 전달용)
# stderr → 로그 (디버깅용)
timeout "$TIMEOUT" codex exec $MODEL_ARGS --full-auto \
  -C "$WORKDIR" "$FULL_PROMPT" \
  > "$output_tmp" 2> "${output_tmp}.stderr"

# stderr에서 실패 패턴 감지
if grep -qi 'error\|failed\|401\|unauthorized' "${output_tmp}.stderr" 2>/dev/null; then
  _bmb_record_incident "codex_stderr_error" "..." $rc "cross-model-run"
fi
```

#### Fix 3: 호출 전 pre-flight check

```bash
# codex 호출 전 빠른 헬스체크 (5초 제한)
_codex_preflight() {
  local test_output
  test_output=$(timeout 10 codex exec --full-auto "echo PREFLIGHT_OK" 2>/dev/null | grep -c "PREFLIGHT_OK")
  [ "$test_output" -ge 1 ] && return 0 || return 1
}

# 호출 전
if ! _codex_preflight; then
  _bmb_record_incident "codex_preflight_fail" "profile=$PROFILE" 1 "cross-model-run"
  echo "DEGRADED: codex preflight failed" >&2
  exit 1
fi
```

#### Fix 4: 실패 시 원인 분류 강화

현재: timeout이면 무조건 exit 2, 나머지는 exit 1
제안:
```
exit 0 — 성공
exit 1 — CLI 없음 / 일반 실패
exit 2 — timeout (DEGRADED)
exit 3 — signal killed
exit 4 — auth 실패 (NEW)
exit 5 — preflight 실패 (NEW)
exit 6 — stall detected (NEW)
```

각 exit code를 incident에 기록하여 analyst가 실패 유형별 통계를 낼 수 있도록.

### 수정 대상 파일 (추가)

| 파일 | 변경 |
|------|------|
| `bmb-system/scripts/cross-model-run.sh` | timeout fallback, stderr 분리, preflight check, exit code 세분화 |
| `bmb-system/bin/codex` | supermemory MCP 에러 무시 처리 (shim 레벨) |
| `bmb-system/scripts/bmb-external-incidents.sh` | 새 exit code 분류 추가 |
| `config/defaults.json` | `cross_model.preflight_timeout: 10`, `cross_model.max_mcp_startup_sec: 15` |
| `agents/bmb-analyst.md` | exit code별 실패 유형 통계 쿼리 추가 |

### 검증 기준

- [ ] `timeout 5 sleep 2` 성공 (macOS bash)
- [ ] `timeout 2 sleep 5` → exit 124 (macOS bash)
- [ ] `cross-model-run.sh --profile verify 'echo test'` → exit 0 + 결과 파일 생성
- [ ] preflight 실패 시 → exit 5 + incident 기록
- [ ] 3회 연속 `cross-model-run.sh` 호출 → 0회 실패

## 핵심 제약 (통합)

### Part 1: Retrospective
- Lead가 회고 없이 cleanup으로 넘어가는 것을 **구조적으로 차단**
- bmb_learn 최소 1회 호출은 context 상태와 무관하게 필수
- analyst 보고서 → 유저 전달은 생략 불가
- auto-edit/auto-promote 금지 — 항상 유저 확인
- 12단계로 늘어나도 실제 시간 추가는 1~2분 이내 (Lead가 직접 수행)

### Part 2: Cross-Model Reliability
- `timeout` fallback은 외부 의존성 없이 순수 perl (macOS 기본 내장)
- preflight check 실패 → 즉시 degradation (무한 대기 금지)
- stderr를 반드시 분리 캡처 → 실패 원인 파악 가능하게
- "graceful degradation"은 **비상 경로** — 기본 경로로 사용 금지
- 3회 연속 성공 검증 통과 후 배포
