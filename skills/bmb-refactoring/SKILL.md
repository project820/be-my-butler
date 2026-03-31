---
name: bmb-refactoring
description: "BMB refactoring session — parallel analysis, cross-model review, and merge."
---

# /BMB-refactoring

Refactoring session with parallel planning, cross-model execution, and review.

## YOUR ABSOLUTE RULES
1. **NEVER** explore codebases, read source files, or research anything directly
2. **NEVER** write or edit code — not a single line
3. **NEVER** create files except inside `.bmb/` directory
4. **ONLY** read files in `.bmb/` directory and `CLAUDE.md`
5. Your job is DECISIONS, ORCHESTRATION, and RELAY only

## Prerequisites
- `.bmb/config.json` should exist

## Codex Companion Invocation
```bash
COMPANION="${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs"
if [ -z "$COMPANION" ] || [ ! -f "$COMPANION" ]; then
  COMPANION=$(find ~/.claude/plugins/cache/openai-codex -name codex-companion.mjs 2>/dev/null | head -1)
fi
node "$COMPANION" task [--write] [--effort EFFORT] 'prompt'
```

## Phase 0: Parallel Analysis
1. Read config for cross-model provider and timeouts
2. Source auto-learning: `source "$HOME/.claude/bmb-system/scripts/bmb-learn.sh"`
3. Create worktrees:
   ```bash
   mkdir -p .bmb/worktrees
   git worktree add .bmb/worktrees/refactor-exec refactor-exec-$(date +%s) 2>/dev/null || true
   ```

4. **Track A — Claude analysis** (in-process): Lead reads the codebase scope from user's description, spawns bmb-architect to analyze:
   ```bash
   CLAUDECODE= claude --agent bmb-architect --permission-mode dontAsk \
     'Analyze the codebase for refactoring opportunities. Focus on: {user scope}. \
      Write refactoring PLAN (markdown only, no code) to .bmb/handoffs/refactor-plan-claude.md'
   ```

5. **Track B — Codex Companion analysis** (independent):
   ```bash
   node "$COMPANION" task --effort medium \
     "Analyze the codebase for refactoring opportunities. Focus on: {user scope}. \
      Write refactoring PLAN to .bmb/handoffs/refactor-plan-cross.md"
   ```

6. Run both tracks; collect results sequentially or in subshells.

## Phase 0.5: Synthesis
1. Read both plans
2. Auto-confirm agreement points
3. Present conflicts to user
4. Write final `refactor-plan.md`

## Phase 1: Execution
Run Codex Companion executor in worktree:
```bash
node "$COMPANION" task --write --effort high \
  "Read .bmb/handoffs/refactor-plan.md. Execute the refactoring. \
   Write results to .bmb/handoffs/refactor-exec-result.md"
```

## Phase 2: Cross-Review
Spawn bmb-verifier (Claude) to review the diff:
```bash
CLAUDECODE= claude --agent bmb-verifier --permission-mode dontAsk \
  'Review the refactoring diff in .bmb/worktrees/refactor-exec/. \
   Check architecture, security, intent fidelity. \
   Write review to .bmb/handoffs/refactor-review.md'
```
If review finds issues: `bmb_learn MISTAKE "refactor-review" "{issue description}" "{preventive rule}"`

## Phase 3: Fix + Simplify
1. If review has issues: spawn executor to fix in worktree
2. Optional: spawn bmb-simplifier for cleanup
3. Re-verify after fixes
4. If fix attempt fails: `bmb_learn MISTAKE "refactor-fix" "{what failed}" "{lesson}"`

## Phase 4: Merge + Commit + Push
1. Read git config from `.bmb/config.json`
2. Merge worktree changes:
   ```bash
   cd .bmb/worktrees/refactor-exec && git add -A && git commit -m "refactor: {description}"
   cd {project_root}
   git merge refactor-exec-{timestamp}
   git worktree remove .bmb/worktrees/refactor-exec
   ```
3. Git push based on config (yes/no/ask)
4. Present summary
