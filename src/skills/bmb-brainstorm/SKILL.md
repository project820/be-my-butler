---
name: bmb-brainstorm
description: "BMB brainstorming session — Lead + Consultant bidirectional consulting with conversation logging."
---

# /BMB-brainstorm

Interactive brainstorming session with Lead + Consultant.

## YOUR ABSOLUTE RULES
1. **NEVER** explore codebases, read source files, or research anything directly
2. **NEVER** write or edit code — not a single line
3. **ONLY** read files in `.bmb/` directory and `CLAUDE.md`
4. Your job is ORCHESTRATION and RELAY only
5. **NEVER use the Agent tool** — Consultant spawns via tmux only

## Prerequisites
- Must be in tmux (`$TMUX` check)
- `.bmb/config.json` should exist (run `/BMB-setup` first if not)

## Phase 1: Setup
```bash
# tmux guard
if [ -z "$TMUX" ]; then echo "ERROR: BMB requires tmux." >&2; exit 1; fi

# Generate session ID
SESSION_ID=$(date +%Y%m%d-%H%M%S)
mkdir -p .bmb/sessions/${SESSION_ID}/handoffs/.compressed
ln -sfn ${SESSION_ID} .bmb/sessions/latest

# Source auto-learning function
source "$HOME/.claude/bmb-system/scripts/bmb-learn.sh"

# Start conversation logger
python3 ~/.claude/bmb-system/scripts/conversation-logger.py .bmb/sessions/${SESSION_ID} &
LOGGER_PID=$!
echo $LOGGER_PID > .bmb/sessions/${SESSION_ID}/logger.pid
```

Load consultant style from `.bmb/config.json`.

## Phase 2: Spawn Consultant
Initialize consultant feed:
```bash
cat > .bmb/consultant-feed.md << EOF
# Consultant Feed
Task: Brainstorming session
Started: $(date)
Style: {loaded from config or "default"}

## Pipeline Events
### Step 1 ($(date +%H:%M)): Brainstorming session started
EOF
```

Spawn Consultant pane:
```bash
CONSULTANT=$(tmux split-pane -v -p 30 -d -P -F '#{pane_id}' \
  "CLAUDECODE= claude --agent bmb-consultant --permission-mode bypassPermissions \
  'Read .bmb/consultant-feed.md first, then announce the brainstorming session start to the user in their configured language.'")
echo "$CONSULTANT" > .bmb/consultant-pane-id
```

## Phase 3: Bidirectional Brainstorming
Lead conducts interactive brainstorming directly with the user (in configured language):

1. Ask opening questions about the task/problem
2. Log each exchange to the conversation logger pipe:
   ```bash
   echo "$(date +%H:%M)|Lead|QUESTION|{question}" > .bmb/sessions/${SESSION_ID}/log-pipe
   echo "$(date +%H:%M)|User|ANSWER|{answer}" > .bmb/sessions/${SESSION_ID}/log-pipe
   ```
3. Sync key points to consultant feed:
   ```bash
   echo "### Q ($(date +%H:%M)): {question summary}" >> .bmb/consultant-feed.md
   ```
4. SendMessage to Consultant for supplementary insights when needed:
   - `NEW_BUSINESS_RULE`: when user mentions a business rule
   - `CONTEXT_UPDATE`: when new requirements emerge
5. Continue until:
   - Lead context reaches ~70%
   - User says "enough" / "충분해" / "넘어가자" / "十分です"
   - All key questions are answered

## Phase 4: Summary + Plan Decision
1. Summarize entire brainstorming session
2. Record any user corrections/decisions made during brainstorming:
   - If user corrected an assumption: `bmb_learn CORRECTION "brainstorm" "{what was corrected}" "{lesson}"`
   - If user made a key decision: `bmb_learn PRAISE "brainstorm" "{decision}" "{rationale}"`
3. Save to `.bmb/sessions/${SESSION_ID}/brainstorm-record.md`
4. Ask user: "Enter plan mode?" (YES/NO)

If YES:
- Ask about project folder: existing / new / custom path
- Generate structured plan document
- Save to `.bmb/sessions/${SESSION_ID}/plan.md`
- This plan can be referenced by `/BMB` full session later

## Phase 5: Cleanup
```bash
# Send shutdown to logger
echo "$(date +%H:%M)|System|CONTEXT|SHUTDOWN" > .bmb/sessions/${SESSION_ID}/log-pipe
# Kill consultant
tmux kill-pane -t $(cat .bmb/consultant-pane-id) 2>/dev/null || true
rm -f .bmb/consultant-pane-id
```

Present output file paths to user.
