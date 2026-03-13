# BMB v0.3.4 — Codex Timeout Management + Repo Consolidation

**Date:** 2026-03-13
**Status:** READY
**Previous:** v0.3.2 Human-Centered Brainstorming Redesign

## Background

v0.3.2 파이프라인 실행 중 Codex가 re-test 단계에서 54분+ hang → 사용자가 지적할 때까지 감지 못함.
추가로 `~/.claude`와 `~/Projects/bmb` 이중 repo 문제 발견, symlink 구조로 정리 완료.

## v0.3.4 Scope

### Axis 1: Codex Timeout 단축 (cross-model-run.sh)
- **현재:** 모든 프로필 기본 3600s, config override만 가능
- **변경:** 프로필별 기본 timeout 차등 적용
  - `council`: 600s (read-only, 빠름)
  - `verify`: 600s
  - `review`: 600s (plan critique)
  - `test`: 1200s (테스트 실행 필요)
  - `exec-assist`: 3600s (유지)
- **Config override:** `timeouts.{profile}` 키로 개별 오버라이드 가능

### Axis 2: 조기 진행 확인 (Early Progress Check)
- cross-model-run.sh에 background monitor 추가
- 5분 시점: Codex 프로세스 CPU 사용률 확인
- CPU idle (< 5%) + 출력 없음 → stderr 경고 + SIGTERM
- 구현: `timeout` 명령 + trap 기반

### Axis 3: Graceful Degradation 자동 감지
- **현재:** exit 1 → 호출 측에서 수동 판단
- **변경:** exit code 체계화
  - `exit 0`: 성공
  - `exit 1`: CLI not found (DEGRADED)
  - `exit 2`: timeout (DEGRADED)
  - `exit 3`: process hung (killed, DEGRADED)
- 호출 측(bmb.md, brainstorm SKILL.md)에서 exit code 기반 자동 분기

### Axis 4: install.sh에 symlink 배포 로직 추가
- `~/Projects/bmb` → `~/.claude/` symlink 자동 생성
- 대상: skills/bmb*, agents/, commands/, bmb-system/
- 기존 실물 폴더 감지 → 백업 후 symlink 교체

## Files to Modify

| File | Change |
|------|--------|
| `bmb-system/scripts/cross-model-run.sh` | Profile-based timeout, early check, exit codes |
| `bmb-system/config/defaults.json` | `timeouts` 섹션에 프로필별 기본값 |
| `skills/bmb/bmb.md` | Exit code 기반 degradation 분기 |
| `skills/bmb-brainstorm/SKILL.md` | Exit code 기반 review 단계 분기 |
| `install.sh` | Symlink 배포 로직 |

## Test Plan
1. `bash -n` 전체 스크립트
2. `cross-model-run.sh --profile council 'test'` → 600s timeout 확인
3. timeout 시 exit code 2 확인
4. install.sh 실행 → symlink 생성 확인
5. 기존 실물 폴더 있을 때 → 백업 + symlink 교체 확인

## Recipe
`bugfix` — timeout 관리는 operational fix, install.sh는 infra fix
