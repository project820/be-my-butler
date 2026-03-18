---
name: bmb-status
description: "BMB project/idea status dashboard — on-demand overview of all ideas, projects, and pending work."
---

# /BMB-status

On-demand dashboard for BMB ecosystem state. Works from ANY directory.

## Process

1. Source scripts:
   ```bash
   source "$HOME/.claude/bmb-system/scripts/bmb-ideas.sh"
   bmb_idea_init  # Ensures index.json exists (Residual R1 fix)
   ```

2. Read `~/.claude/bmb-ideas/index.json` — if empty (no ideas), show welcome message:
   ```
   아직 등록된 아이디어가 없어요.
   /BMB-brainstorm 으로 첫 브레인스토밍을 시작해보세요!
   ```

3. For each idea with `status=project` and `project_path` set:
   - Check if `{project_path}/.bmb/sessions/latest/carry-forward.md` exists
   - Check if `{project_path}/.bmb/sessions/latest/session-prep.md` exists
   - Count pending items

4. Present dashboard in Korean:

   ```
   ═══════════════════════════════════════
         BMB 프로젝트 & 아이디어 현황
   ═══════════════════════════════════════

   🚀 진행 중인 프로젝트
   ┌──────────┬──────────────────┬────────────┬──────────┐
   │ 프로젝트  │ 경로             │ 마지막 세션 │ 대기 항목 │
   ├──────────┼──────────────────┼────────────┼──────────┤
   │ {title}  │ ~/projects/...   │ 3일 전     │ 2건      │
   └──────────┴──────────────────┴────────────┴──────────┘

   🔍 탐구 중인 아이디어
   ┌──────────┬──────────┬────────────┐
   │ 아이디어  │ 상태     │ 마지막 업데이트 │
   ├──────────┼──────────┼────────────┤
   │ {title}  │ elaborate│ 2일 전     │
   └──────────┴──────────┴────────────┘

   💡 새로운 스파크
   - {title} (n일 전)

   📦 보관함 ({count}개)
   - {title} — {summary}

   ═══════════════════════════════════════
   ```

5. **Nudge logic** (Axis 7):
   - Ideas in `spark` for >7 days: "💡 이 아이디어 기억하시나요? — {title}"
   - Ideas in `validate`/`elaborate` for >14 days: "🔍 {title} 진행 상황이 궁금해요"
   - Projects with carry-forward: "📋 {project}에 미완성 작업이 있어요"
   - Archived ideas with keywords matching current project CLAUDE.md: "📦 보관된 '{title}'이(가) 지금 작업과 관련있을 수 있어요"

6. Offer actions:
   - "보관함에서 꺼낼 아이디어가 있나요?"
   - "프로젝트로 이동할까요?"
   - "새 브레인스토밍을 시작할까요?"
