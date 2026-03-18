---
name: bmb-brainstorm
description: "BMB brainstorming session — Lead + Consultant bidirectional consulting with conversation logging, idea lifecycle, and cross-model plan review."
---

# /BMB-brainstorm

Interactive brainstorming session with Lead + Consultant.

## YOUR ABSOLUTE RULES
1. **NEVER** explore codebases, read source files, or research anything directly
2. **NEVER** write or edit code — not a single line
3. **ONLY** read files in `.bmb/` directory and `CLAUDE.md`
4. Your job is ORCHESTRATION and RELAY only
5. **NEVER use the Agent tool** — Consultant spawns via tmux only
6. **NEVER call EnterPlanMode** — all plan documents are created as files directly
7. **PERMITTED operations:**
   - Source BMB scripts (`bmb-config.sh`, `bmb-ideas.sh`, `bmb-learn.sh`)
   - Write to `~/.claude/bmb-ideas/` (idea lifecycle)
   - Create project directories (Phase 4.1 only)
   - Write `CLAUDE.md` and `.gitignore` in new projects (Phase 4.1 only)

## Prerequisites
- Must be in tmux (`$TMUX` check)

## Phase 1: Setup
```bash
# tmux guard
if [ -z "$TMUX" ]; then echo "ERROR: BMB requires tmux." >&2; exit 1; fi

# Source config infrastructure
source "$HOME/.claude/bmb-system/scripts/bmb-config.sh"
if ! bmb_config_first_time_gate; then exit 0; fi

# Source idea management
source "$HOME/.claude/bmb-system/scripts/bmb-ideas.sh"

# Source auto-learning function
source "$HOME/.claude/bmb-system/scripts/bmb-learn.sh"
```

### Check for previous brainstorm to resume (Finding 2 fix — read BEFORE symlink update)
```bash
# Read previous session BEFORE creating new one
PREV_CF=""
RESUMING=false
if [ -L ".bmb/sessions/latest" ]; then
  PREV_SESSION=$(readlink .bmb/sessions/latest)
  PREV_CF=".bmb/sessions/${PREV_SESSION}/carry-forward.md"
  if [ -f "$PREV_CF" ] && grep -q "Context Overflow\|brainstorm" "$PREV_CF" 2>/dev/null; then
    RESUMING=true
  fi
fi
```

If `RESUMING=true`:
- Read the carry-forward.md from **previous** session (not latest, which hasn't been updated yet)
- Load the linked brainstorm-record.md for context
- Present: "이전 브레인스토밍을 이어갈까요?"
- If yes: start from remaining questions in carry-forward
- If no: start fresh (but preserve previous idea entry)

**THEN** proceed to create new SESSION_ID and update symlink:

```bash
# Generate session ID
SESSION_ID=$(date +%Y%m%d-%H%M%S)
mkdir -p .bmb/sessions/${SESSION_ID}/handoffs/.compressed
ln -sfn ${SESSION_ID} .bmb/sessions/latest

# Start conversation logger
python3 ~/.claude/bmb-system/scripts/conversation-logger.py .bmb/sessions/${SESSION_ID} &
LOGGER_PID=$!
echo $LOGGER_PID > .bmb/sessions/${SESSION_ID}/logger.pid
```

Load consultant style from config via `bmb_config_get`.

## Phase 2: Spawn Consultant
Initialize consultant feed (hybrid — Finding 3 fix):
```bash
cat > .bmb/consultant-feed.md << EOF
# Consultant Feed
Task: Brainstorming session
Session: .bmb/sessions/${SESSION_ID}/
Log: .bmb/sessions/${SESSION_ID}/conversation-log.md
Started: $(date)
Style: $(bmb_config_get "consultant.custom_style" || echo "default")
Persona: $(bmb_config_get "_consultant_persona.name" || echo "Consultant")

## Pipeline Events
### Step 1 ($(date +%H:%M)): Brainstorming session started
EOF
```

Spawn Consultant pane (vertical split — Axis 1):
```bash
CONSULTANT=$(tmux split-pane -h -p 35 -d -P -F '#{pane_id}' \
  "CLAUDECODE= claude --agent bmb-consultant --permission-mode dontAsk \
  '.bmb/consultant-feed.md를 읽고, 브레인스토밍 세션 시작을 알려주세요.'")
echo "$CONSULTANT" > .bmb/consultant-pane-id
```

## Phase 3: Bidirectional Brainstorming
Lead conducts interactive brainstorming directly with the user:

1. Ask opening questions about the task/problem
2. Log each exchange to the conversation logger pipe:
   ```bash
   echo "$(date +%H:%M)|Lead|QUESTION|{question}" > .bmb/sessions/${SESSION_ID}/log-pipe
   echo "$(date +%H:%M)|User|ANSWER|{answer}" > .bmb/sessions/${SESSION_ID}/log-pipe
   ```
3. Sync key points to consultant feed:
   ```bash
   echo "### 질문 ($(date +%H:%M)): {question summary}" >> .bmb/consultant-feed.md
   ```
4. SendMessage to Consultant for supplementary insights when needed:
   - `NEW_BUSINESS_RULE`: when user mentions a business rule
   - `CONTEXT_UPDATE`: when new requirements emerge
5. Handle `[NEW_IDEA]` from Consultant:
   When Consultant sends `[NEW_IDEA] title | description`:
   ```bash
   source "$HOME/.claude/bmb-system/scripts/bmb-ideas.sh"
   NEW_IDEA_ID=$(bmb_idea_create "{title}" "{description}" "$SESSION_ID")
   echo "$(date +%H:%M)|Lead|INSIGHT|Side idea captured: {title} (${NEW_IDEA_ID})" > .bmb/sessions/${SESSION_ID}/log-pipe
   ```
   SendMessage to Consultant: "아이디어 '{title}'이(가) 기록되었습니다 (${NEW_IDEA_ID})"
6. Continue until:
   - User says "enough" / "충분해" / "넘어가자"
   - All key questions are answered
   - **Context overflow detected** (see below)

## Context Overflow Protocol

If Lead detects context usage approaching limits (~75% of conversation length):

1. **Save state immediately:**
   ```bash
   # Save full conversation to brainstorm record
   cat .bmb/sessions/${SESSION_ID}/conversation-log.md > .bmb/sessions/${SESSION_ID}/brainstorm-record.md
   ```

2. **Create carry-forward (atomic write via temp+mv — council fix):**
   ```bash
   CARRY_TIMESTAMP=$(date '+%Y-%m-%d %H:%M KST')
   cat > .bmb/sessions/${SESSION_ID}/carry-forward.md.tmp << 'HEREDOC_EOF'
   # Carry Forward — Context Overflow
   HEREDOC_EOF
   cat >> .bmb/sessions/${SESSION_ID}/carry-forward.md.tmp << HEREDOC_EOF
   Session: ${SESSION_ID}
   Reason: Context limit approaching
   Generated: ${CARRY_TIMESTAMP}

   ## Brainstorm Progress
   - Questions answered: {count}
   - Key decisions so far: {list}
   - Remaining questions: {list}

   ## Resume Instructions
   Continue brainstorming from these remaining questions.
   All previous conversation is preserved in brainstorm-record.md.

   ## Suggested Resume Prompt
   "/BMB-brainstorm — 이전 세션 이어서"
   HEREDOC_EOF
   mv .bmb/sessions/${SESSION_ID}/carry-forward.md.tmp .bmb/sessions/${SESSION_ID}/carry-forward.md
   ```

3. **Create idea entry** (if not already created):
   ```bash
   source "$HOME/.claude/bmb-system/scripts/bmb-ideas.sh"
   IDEA_ID=$(bmb_idea_create "{topic}" "{summary so far}" "$SESSION_ID")
   cp .bmb/sessions/${SESSION_ID}/brainstorm-record.md "$HOME/.claude/bmb-ideas/${IDEA_ID}/brainstorm-log.md"
   ```

4. **Reassure user:**
   ```
   대화가 길어져서 새 세션으로 넘어가야 해요.

   걱정 마세요 — 모든 내용이 기록되어 있고,
   다음 세션에서 바로 이어갑니다.

   저장된 내용:
   - 대화 기록: .bmb/sessions/{SESSION_ID}/brainstorm-record.md
   - 이어갈 내용: .bmb/sessions/{SESSION_ID}/carry-forward.md
   - 아이디어 등록: ~/.claude/bmb-ideas/{IDEA_ID}/

   다음 세션에서 /BMB-brainstorm 을 실행하면 자동으로 이어갑니다.
   ```

5. Run Phase 5 (cleanup)

## Phase 4: Summary + Idea Lifecycle Gateway

**CRITICAL RULE: 절대 EnterPlanMode를 호출하지 않는다.**
브레인스토밍 세션 중 Plan 모드 진입은 스킬 흐름을 중단시킨다.
계획 문서는 Plan 모드 없이 직접 파일로 생성한다.

1. Summarize entire brainstorming session
2. Record learnings:
   - Corrections: `bmb_learn CORRECTION "brainstorm" "{what}" "{lesson}"`
   - Key decisions: `bmb_learn PRAISE "brainstorm" "{decision}" "{rationale}"`
3. Save conversation excerpt to `.bmb/sessions/${SESSION_ID}/brainstorm-record.md`

4. **Create idea entry:**
   ```bash
   IDEA_TITLE="{derived from brainstorm}"  # Ask user to confirm/edit
   IDEA_SUMMARY="{one-line from brainstorm}"
   IDEA_ID=$(bmb_idea_create "$IDEA_TITLE" "$IDEA_SUMMARY" "$SESSION_ID" "$(pwd)")
   ```

5. Copy brainstorm record to idea folder:
   ```bash
   cp .bmb/sessions/${SESSION_ID}/brainstorm-record.md "$HOME/.claude/bmb-ideas/${IDEA_ID}/brainstorm-log.md"
   ```

6. **Present choices to user:**
   ```
   브레인스토밍이 정리되었습니다. 이 아이디어를 어떻게 할까요?

   1. 🚀 프로젝트로 전환 — 바로 프로젝트를 만들고 작업 시작
   2. 🔍 더 탐구 — 아이디어를 더 구체화하고 싶어요
   3. 📦 보관 — 지금은 보관하고 나중에 다시 볼게요
   4. 💡 기록만 — 아이디어로 기록만 해두기
   ```

   Based on choice:
   - **프로젝트로 전환** → `bmb_idea_transition "$IDEA_ID" "project" "User chose project"`
     → Run **Phase 4.5: Cross-Model Plan Review** (see below)
     → Then run **Phase 4.1: Project Creation Subroutine** (see below)
   - **더 탐구** → `bmb_idea_transition "$IDEA_ID" "elaborate" "User wants deeper exploration"`
     → If plan generated, save to `~/.claude/bmb-ideas/${IDEA_ID}/plan.md`
     → Tell user: "다음 세션에서 /BMB-brainstorm으로 이어갈 수 있어요."
   - **보관** → `bmb_idea_archive "$IDEA_ID" "User archived for later"`
     → Tell user: "아이디어는 사라지지 않아요. /BMB-status에서 언제든 다시 꺼낼 수 있습니다."
   - **기록만** → status stays as `spark`
     → Tell user: "아이디어가 기록되었습니다."

**NOTE**: 절대 EnterPlanMode를 호출하지 않는다. 모든 계획 문서는 파일로 직접 생성한다.

## Phase 4.5: Cross-Model Plan Review

Only runs when user chooses "프로젝트로 전환" in Phase 4.
Runs AFTER brainstorm summary + idea creation, BEFORE project creation subroutine.

### Step 1: Generate Plan Draft
Lead generates a structured plan document from the brainstorm:
```bash
cat > .bmb/sessions/${SESSION_ID}/plan-draft.md << 'HEREDOC_EOF'
# {IDEA_TITLE} — Implementation Plan (Draft)

## Context
{extracted from brainstorm — problem statement, goals}

## Key Decisions
{from brainstorm — architecture choices, constraints}

## Proposed Approach
{Lead's recommended approach based on brainstorming}

## Scope
{what's in/out}

## Open Questions
{unresolved items from brainstorm}

## Risk Areas
{potential issues identified}
HEREDOC_EOF
```

**NOTE**: 절대 EnterPlanMode를 호출하지 않는다. 파일로 직접 생성한다.

### Step 2: Send to Cross-Model for Review (via cross-model-run.sh wrapper)
```bash
REVIEW_FILE=".bmb/sessions/${SESSION_ID}/plan-review.md"

# Adaptive timeout based on plan size (Review recommendation)
# v0.3.4: cross-model-run.sh now applies profile-based defaults internally,
# but brainstorm still sets adaptive timeout for the review profile.
PLAN_LINES=$(wc -l < ".bmb/sessions/${SESSION_ID}/plan-draft.md" 2>/dev/null || echo 0)
AUTO_TIMEOUT=600
[ "$PLAN_LINES" -ge 200 ] && AUTO_TIMEOUT=900
[ "$PLAN_LINES" -ge 500 ] && AUTO_TIMEOUT=1200
[ "$PLAN_LINES" -ge 900 ] && AUTO_TIMEOUT=1800

# Config override with clamp (min 300s, max 1800s)
CFG_TIMEOUT=$(bmb_config_get "timeouts.codex_review" || echo "")
[ -z "$CFG_TIMEOUT" ] && CFG_TIMEOUT=$AUTO_TIMEOUT
CODEX_TIMEOUT=$CFG_TIMEOUT
[ "$CODEX_TIMEOUT" -lt 300 ] && CODEX_TIMEOUT=300
[ "$CODEX_TIMEOUT" -gt 1800 ] && CODEX_TIMEOUT=1800

# Submit via cross-model-run.sh wrapper (--profile review, -o output, - for stdin)
{
  cat <<'PROMPT_EOF'
다음 계획 문서를 철저히 리뷰해주세요.
설계 결함, 누락된 고려사항, 실행 불가능한 부분, 보안 취약점, 현재 코드베이스/런타임 계약과의 충돌을 모두 지적해주세요.
결과는 findings-first 구조의 마크다운으로 작성해주세요.
PROMPT_EOF
  echo
  cat ".bmb/sessions/${SESSION_ID}/plan-draft.md"
} | ~/.claude/bmb-system/scripts/cross-model-run.sh \
    --profile review \
    -o "$REVIEW_FILE" \
    - &
REVIEW_PID=$!

echo "$(date +%H:%M)|Lead|CONTEXT|Cross-model plan review started (PID: $REVIEW_PID, timeout: ${CODEX_TIMEOUT}s)" > .bmb/sessions/${SESSION_ID}/log-pipe
echo "### $(date +%H:%M) Cross-model 계획 리뷰 시작" >> .bmb/consultant-feed.md
```

Tell user: "Codex에게 계획 리뷰를 요청했어요. 잠시 기다려주세요..."

### Step 3: Wait & Present Review
```bash
# Wait with adaptive timeout
REVIEW_DEADLINE=$((SECONDS + CODEX_TIMEOUT))
while kill -0 $REVIEW_PID 2>/dev/null; do
  [ $SECONDS -gt $REVIEW_DEADLINE ] && kill $REVIEW_PID 2>/dev/null && break
  sleep 5
done
wait $REVIEW_PID 2>/dev/null

# Early completion: proceed immediately without idle wait
```

Check exit code for v0.3.4 degradation handling:
```bash
REVIEW_EXIT=$?
if [ $REVIEW_EXIT -eq 2 ] || [ $REVIEW_EXIT -eq 3 ]; then
  # Cross-model timed out or was killed — recovery was attempted by cross-model-run.sh
  echo "$(date +%H:%M)|Lead|CONTEXT|Cross-model review degraded (exit=$REVIEW_EXIT)" > .bmb/sessions/${SESSION_ID}/log-pipe
  echo "### $(date +%H:%M) Cross-model 리뷰 타임아웃 — Claude-only로 계속" >> .bmb/consultant-feed.md
  # Inform user and proceed without cross-model review
  # Tell user: "Codex 리뷰가 시간 내에 완료되지 않았어요. 원안으로 진행할게요."
elif [ $REVIEW_EXIT -eq 1 ]; then
  echo "$(date +%H:%M)|Lead|CONTEXT|Cross-model CLI unavailable (exit=1)" > .bmb/sessions/${SESSION_ID}/log-pipe
  # Tell user: "Cross-model CLI를 사용할 수 없어서 리뷰를 건너뜁니다."
fi
```

Read `.bmb/sessions/${SESSION_ID}/plan-review.md` and present to user:
```
═══════════════════════════════════════
      Codex 리뷰 결과
═══════════════════════════════════════
{review content}
═══════════════════════════════════════
```

### Step 4: User Reviews Feedback
Ask user:
```
Codex 리뷰를 확인해주세요.

1. 리뷰 반영하여 계획 수정
2. 일부만 반영 (어떤 항목?)
3. 리뷰 무시하고 원안 유지
```

Based on choice:
- **수정**: Lead updates plan-draft.md with review feedback → save as plan-final.md
- **일부 반영**: User specifies which items → Lead applies selected fixes → plan-final.md
- **원안 유지**: Copy plan-draft.md to plan-final.md as-is

### Step 5: Finalize
```bash
# Save final plan to idea folder
cp .bmb/sessions/${SESSION_ID}/plan-final.md "$HOME/.claude/bmb-ideas/${IDEA_ID}/plan.md"

echo "$(date +%H:%M)|Lead|DECISION|Plan finalized after Codex review" > .bmb/sessions/${SESSION_ID}/log-pipe
echo "### $(date +%H:%M) 계획 확정 (Codex 리뷰 반영)" >> .bmb/consultant-feed.md
```

SendMessage to Consultant: `{"event":"plan_finalized","idea":"${IDEA_ID}","ts":"$(date +%H:%M)"}`

Tell user: "계획이 확정되었습니다. 프로젝트를 생성할게요."
→ Proceed to **Phase 4.1: Project Creation Subroutine**

## Phase 4.1: Project Creation Subroutine

Only runs when user chooses "프로젝트로 전환" in Phase 4.

1. **Ask project name:**
   Suggest slugified version of idea title. User can edit.
   ```
   프로젝트 이름을 정해주세요.
   제안: {slug from IDEA_TITLE}
   ```

2. **Ask location (Finding 4 fix — actually branch on user choice):**
   ```
   프로젝트 폴더 위치를 선택해주세요.
   1. ~/projects/{slug}/ (기본)
   2. 기존 폴더 사용 (경로 입력)
   3. 다른 경로 지정
   ```

3. **Create/validate project path based on ACTUAL user choice:**
   ```bash
   case $USER_CHOICE in
     1)  # Default path
         PROJECT_PATH="$HOME/projects/${slug}"
         mkdir -p "$PROJECT_PATH"
         cd "$PROJECT_PATH"
         git init
         ;;
     2)  # Existing folder — validate, do NOT overwrite
         # Ask user for path via AskUserQuestion
         PROJECT_PATH="{user-provided path}"
         if [ ! -d "$PROJECT_PATH" ]; then
           echo "ERROR: 폴더가 존재하지 않습니다: $PROJECT_PATH"
           # Re-ask or fallback to option 1
         fi
         cd "$PROJECT_PATH"
         # Do NOT run git init if .git already exists
         [ ! -d ".git" ] && git init
         # Do NOT overwrite existing CLAUDE.md — merge or append
         ;;
     3)  # Custom path
         # Ask user for path via AskUserQuestion
         PROJECT_PATH="{user-provided path}"
         mkdir -p "$PROJECT_PATH"
         cd "$PROJECT_PATH"
         git init
         ;;
   esac
   ```

4. **Generate CLAUDE.md with brainstorm context (Finding 4 fix — respect existing):**
   ```bash
   if [ -f "$PROJECT_PATH/CLAUDE.md" ]; then
     # Existing CLAUDE.md — APPEND brainstorm context, do NOT overwrite
     # Use quoted heredoc to prevent shell interpolation of user-derived content
     BMB_ADDED_DATE=$(date '+%Y-%m-%d')
     {
       echo ""
       echo "## BMB Brainstorm Origin"
       echo "- BMB Brainstorm Session: ${SESSION_ID}"
       echo "- BMB Idea: ${IDEA_ID}"
       echo "- Added: ${BMB_ADDED_DATE}"
       cat << 'HEREDOC_EOF'

   ## Brainstorm Goals
   {extracted from brainstorm summary}

   ## Brainstorm Key Decisions
   {extracted from brainstorm — decisions made}
   HEREDOC_EOF
     } >> "$PROJECT_PATH/CLAUDE.md"
   else
     # New project — create fresh CLAUDE.md
     # Use echo for safe shell vars, quoted heredoc for user-derived content
     BMB_CREATED_DATE=$(date '+%Y-%m-%d')
     {
       echo "# {Project Name}"
       echo ""
       echo "## Origin"
       echo "- BMB Brainstorm Session: ${SESSION_ID}"
       echo "- BMB Idea: ${IDEA_ID}"
       echo "- Created: ${BMB_CREATED_DATE}"
       cat << 'HEREDOC_EOF'

   ## Goals
   {extracted from brainstorm summary}

   ## Key Decisions
   {extracted from brainstorm — decisions made}

   ## Constraints
   {extracted from brainstorm — limitations agreed}

   ## Tech Stack
   {if discussed during brainstorm}
   HEREDOC_EOF
     } > "$PROJECT_PATH/CLAUDE.md"
   fi
   ```

5. **Init .bmb/ in new project (Review Issue 4 — config copy semantics):**
   ```bash
   mkdir -p "$PROJECT_PATH/.bmb/sessions" "$PROJECT_PATH/.bmb/handoffs/.compressed" "$PROJECT_PATH/.bmb/councils"
   # Copy defaults-only section from global profile (NOT merged effective config)
   # This avoids leaking _user/_consultant_persona and current project overrides
   _BMB_PROJECT_PATH="$PROJECT_PATH" python3 << 'PYEOF'
import json, os
gp = os.path.expanduser("~/.claude/bmb-profile.json")
defaults_path = os.path.expanduser("~/.claude/bmb-system/config/defaults.json")
target = os.path.join(os.environ.get("_BMB_PROJECT_PATH", "."), ".bmb/config.json")
# Priority: global profile defaults > hardcoded defaults
config = {}
if os.path.isfile(defaults_path):
    config = json.load(open(defaults_path))
if os.path.isfile(gp):
    g = json.load(open(gp))
    if "defaults" in g:
        for k, v in g["defaults"].items():
            if isinstance(v, dict) and k in config and isinstance(config[k], dict):
                config[k].update(v)
            else:
                config[k] = v
config["version"] = 2
with open(target, "w") as f:
    json.dump(config, f, ensure_ascii=False, indent=2)
PYEOF
   ```
   Note: `bmb_config_load()` merges _user and _consultant_persona which shouldn't go into project config. This uses defaults-only extraction instead.

6. **Update idea's project_path:**
   ```bash
   bmb_idea_set_project_path "$IDEA_ID" "$PROJECT_PATH"
   ```

7. **Add .bmb/ to .gitignore:**
   ```bash
   echo '.bmb/' >> "$PROJECT_PATH/.gitignore"
   ```

8. **Present to user:**
   ```
   프로젝트가 준비됐어요!

   📁 경로: {PROJECT_PATH}
   📄 CLAUDE.md 생성 완료 (브레인스토밍 맥락 포함)
   🔧 .bmb/ 초기화 완료

   바로 프로젝트를 열까요?
   1. 새 tmux 창에서 열기 (추천)
   2. 명령어 복사만
   ```

   If 1: `tmux new-window -c "$PROJECT_PATH" "claude"`
   If 2: show `cd {PROJECT_PATH} && claude`

## Phase 5: Cleanup
```bash
# Generate carry-forward (atomic: temp+mv — council fix)
# Use echo for safe shell vars, quoted heredoc for user-derived content
CF_TIMESTAMP=$(date '+%Y-%m-%d %H:%M KST')
CF_PROJECT=$(pwd)
{
  echo "# Carry Forward"
  echo "Session: ${SESSION_ID}"
  echo "Generated: ${CF_TIMESTAMP}"
  echo "Project: ${CF_PROJECT}"
  cat << 'HEREDOC_EOF'

## Brainstorm Summary
{key points from this session}

## Ideas Created
{list of ideas with IDs}

## Resume Context
{what to know for next session}
HEREDOC_EOF
} > .bmb/sessions/${SESSION_ID}/carry-forward.md.tmp
mv .bmb/sessions/${SESSION_ID}/carry-forward.md.tmp .bmb/sessions/${SESSION_ID}/carry-forward.md

# Send shutdown to logger
echo "$(date +%H:%M)|System|CONTEXT|SHUTDOWN" > .bmb/sessions/${SESSION_ID}/log-pipe
# Kill consultant
tmux kill-pane -t $(cat .bmb/consultant-pane-id) 2>/dev/null || true
rm -f .bmb/consultant-pane-id
```

Present output file paths to user.
