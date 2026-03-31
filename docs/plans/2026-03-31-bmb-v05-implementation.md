# BMB v0.5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the BMB pipeline from tmux-based orchestration to Agent tool + Codex companion, implementing the Sandwich Pattern (Opus designs → Codex/Sonnet implements → Opus verifies).

**Architecture:** Replace 6 agents and cross-model-run.sh with direct Codex companion calls. Use Claude Code built-in infrastructure (/btw, /simplify, /last30days) instead of custom agents. Main session protection via Agent tool subagents.

**Tech Stack:** Markdown (agent definitions, pipeline skill), Bash (config, install, doctor), JSON (defaults.json), Codex companion (Node.js plugin)

**Spec:** `docs/plans/2026-03-31-bmb-v05-design.md`

---

## File Map

### Created
- (none — all work is modifications and deletions)

### Deleted (6 files)
- `agents/bmb-executor.md` (144 lines)
- `agents/bmb-frontend.md` (209 lines)
- `agents/bmb-consultant.md` (365 lines)
- `agents/bmb-monitor.md` (218 lines)
- `bmb-system/scripts/cross-model-run.sh` (375 lines)
- `bmb-system/bin/codex` (275 lines)

### Modified (11 files)
- `bmb-system/config/defaults.json` — add model_routing, companion config; remove Gemini
- `agents/bmb-architect.md` (167 lines) — remove council debate, add complexity rating
- `agents/bmb-verifier.md` (145 lines) — combined code+design review
- `agents/bmb-tester.md` (128 lines) — remove blind pattern
- `agents/bmb-writer.md` (104 lines) — change model to sonnet
- `agents/bmb-analyst.md` (215 lines) — update step numbers
- `skills/bmb/bmb.md` (1185 lines) — full rewrite
- `skills/bmb-brainstorm/SKILL.md` (568 lines) — replace cross-model-run.sh
- `skills/bmb-refactoring/SKILL.md` (101 lines) — replace cross-model-run.sh + tmux
- `install.sh` (330 lines) — remove codex shim, add node check
- `doctor.sh` (212 lines) — remove codex shim/gemini checks

---

## Phase 1: Foundation (Config + Deletions)

### Task 1: Update defaults.json

**Files:**
- Modify: `bmb-system/config/defaults.json`

- [ ] **Step 1: Read current defaults.json**

Read the full file to understand current structure.

- [ ] **Step 2: Remove Gemini and obsolete config**

Remove these keys from `cross_model`:
```json
"gemini_model": "LATEST",
"max_mcp_startup_sec": 15
```

- [ ] **Step 3: Add model_routing section**

Add after `cross_model`:
```json
"model_routing": {
  "coder_default": "gpt-5.4-mini",
  "coder_complex": "gpt-5.4",
  "coder_escalation": "sonnet",
  "researcher": "sonnet",
  "writer": "sonnet",
  "escalation_threshold": 2,
  "complex_file_threshold": 3,
  "_note": "Dynamic routing: mini for simple tasks, High for complex, Sonnet on 2+ rejections or 3+ files changed."
}
```

- [ ] **Step 4: Add companion section**

Add after `model_routing`:
```json
"companion": {
  "effort_default": "medium",
  "effort_complex": "high",
  "fallback_stages": ["retry", "resume", "escalate"],
  "_note": "Codex companion invocation config. 3-tier fallback: retry same, resume-last, escalate to Sonnet."
}
```

- [ ] **Step 5: Validate JSON syntax**

Run: `python3 -c "import json; json.load(open('bmb-system/config/defaults.json'))"`
Expected: No error output.

- [ ] **Step 6: Commit**

```bash
git add bmb-system/config/defaults.json
git commit -m "feat(v0.5): add model_routing and companion config, remove Gemini"
```

---

### Task 2: Delete obsolete files

**Files:**
- Delete: `agents/bmb-executor.md`
- Delete: `agents/bmb-frontend.md`
- Delete: `agents/bmb-consultant.md`
- Delete: `agents/bmb-monitor.md`
- Delete: `bmb-system/scripts/cross-model-run.sh`
- Delete: `bmb-system/bin/codex`

- [ ] **Step 1: Verify files exist before deletion**

Run: `ls -la agents/bmb-executor.md agents/bmb-frontend.md agents/bmb-consultant.md agents/bmb-monitor.md bmb-system/scripts/cross-model-run.sh bmb-system/bin/codex`

- [ ] **Step 2: Delete agent files**

```bash
git rm agents/bmb-executor.md agents/bmb-frontend.md agents/bmb-consultant.md agents/bmb-monitor.md
```

- [ ] **Step 3: Delete cross-model infrastructure**

```bash
git rm bmb-system/scripts/cross-model-run.sh bmb-system/bin/codex
```

- [ ] **Step 4: Verify no broken symlinks**

Run: `find ~/.claude/bmb-system/ -type l ! -exec test -e {} \; -print 2>/dev/null`
Expected: No output (no broken symlinks).

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(v0.5): remove executor, frontend, consultant, monitor agents + cross-model-run.sh + codex shim"
```

---

## Phase 2: Agent Modifications (5 agents)

### Task 3: Update bmb-architect.md

**Files:**
- Modify: `agents/bmb-architect.md`

- [ ] **Step 1: Read current file**

Read `agents/bmb-architect.md` in full.

- [ ] **Step 2: Remove council debate sections**

Remove the entire "### 4. Invoke Cross-Model" section (tmux pane spawn, polling, timeout logic) and "### 5. Iterate Rounds" section. Remove the "### 5.5 Council Consolidation" section.

- [ ] **Step 3: Add complexity rating to handoff output**

In the "### 7. Derive Handoff" section (plan-to-exec.md template), add a required field:

```markdown
## Complexity Rating
complexity: low | high

Criteria:
- `low`: Single file, straightforward logic, boilerplate, simple bug fix
- `high`: Multi-file changes (3+), architecture changes, complex business logic, new subsystem
```

- [ ] **Step 4: Update description to reflect solo design**

In frontmatter, update description to mention solo design (no council). Remove any references to "cross-model council debate" or "divergent framing" from the body.

- [ ] **Step 5: Remove cross-model-run.sh references**

Search and remove all references to `cross-model-run.sh`, `tmux split-pane`, `CROSS_PANE`, council round files.

- [ ] **Step 6: Validate no broken references**

Run: `grep -n 'cross-model-run\|tmux\|CROSS_PANE\|council.*cross\|round-.*-cross' agents/bmb-architect.md`
Expected: No output.

- [ ] **Step 7: Commit**

```bash
git add agents/bmb-architect.md
git commit -m "feat(v0.5): architect solo design, add complexity rating, remove council"
```

---

### Task 4: Update bmb-verifier.md

**Files:**
- Modify: `agents/bmb-verifier.md`

- [ ] **Step 1: Read current file**

Read `agents/bmb-verifier.md` in full.

- [ ] **Step 2: Update role description**

Change frontmatter description to reflect combined code quality + design fitness review. The verifier now reviews Codex-produced code (cross-model verification is structural).

- [ ] **Step 3: Add design review checklist**

Add to the verification checklist:
```markdown
## Design Fitness Review
- [ ] Implementation matches plan-to-exec.md architecture
- [ ] No unnecessary complexity beyond what the plan specified
- [ ] File structure follows the plan's module boundaries
- [ ] API contracts match the plan's interface definitions
```

- [ ] **Step 4: Remove blind verification references**

Remove all references to: blind phase, divergent framing, `*-cross.md` files, `*-claude.md` files, "Do NOT read any *-cross.md files", cross-model track.

- [ ] **Step 5: Update output path**

Change output from `verify-result-claude.md` to `review-result.md`.

- [ ] **Step 6: Validate**

Run: `grep -n 'blind\|divergent\|cross.*md\|claude.*md' agents/bmb-verifier.md`
Expected: No output.

- [ ] **Step 7: Commit**

```bash
git add agents/bmb-verifier.md
git commit -m "feat(v0.5): verifier combined code+design review, remove blind pattern"
```

---

### Task 5: Update bmb-tester.md

**Files:**
- Modify: `agents/bmb-tester.md`

- [ ] **Step 1: Read current file**

Read `agents/bmb-tester.md` in full.

- [ ] **Step 2: Remove blind phase references**

Remove: blind phase context, divergent framing notes, references to `briefing.md` vs `plan-to-exec.md` split, "Do NOT read any *-cross.md files".

- [ ] **Step 3: Simplify to single comprehensive test pass**

The tester reads `plan-to-exec.md` and the code diff, writes and runs tests. Single output: `.bmb/handoffs/test-result.md` (not `test-result-claude.md`).

- [ ] **Step 4: Add structural independence note**

Add:
```markdown
## Independence Rule
You are structurally independent from the coder. The code was written by Codex (GPT-5.4).
Your tests verify the implementation from a fresh perspective — different model family, different context.
Do NOT assume the implementation is correct. Test edge cases and failure modes.
```

- [ ] **Step 5: Validate**

Run: `grep -n 'blind\|divergent\|cross\|briefing.*vs\|claude.*md' agents/bmb-tester.md`
Expected: No output.

- [ ] **Step 6: Commit**

```bash
git add agents/bmb-tester.md
git commit -m "feat(v0.5): tester independent single-pass, remove blind pattern"
```

---

### Task 6: Update bmb-writer.md and bmb-analyst.md

**Files:**
- Modify: `agents/bmb-writer.md`
- Modify: `agents/bmb-analyst.md`

- [ ] **Step 1: Read both files**

Read `agents/bmb-writer.md` and `agents/bmb-analyst.md`.

- [ ] **Step 2: Change writer model to sonnet**

In `bmb-writer.md` frontmatter, change:
```yaml
model: sonnet
```

- [ ] **Step 3: Update analyst step references**

In `bmb-analyst.md`, update any hardcoded step numbers to match v0.5 pipeline:
- "Step 10.5" → "Step 10"
- References to Consultant feed → remove
- References to Monitor data → remove

- [ ] **Step 4: Remove Consultant/Monitor references from analyst**

The analyst should not reference consultant-feed.md or monitor events that no longer exist.

- [ ] **Step 5: Validate**

Run: `grep -n 'consultant\|monitor\|Step 10\.5' agents/bmb-analyst.md`
Expected: No output (no stale references).

Run: `head -5 agents/bmb-writer.md` to verify model: sonnet.

- [ ] **Step 6: Commit**

```bash
git add agents/bmb-writer.md agents/bmb-analyst.md
git commit -m "feat(v0.5): writer model to sonnet, analyst updated for new pipeline"
```

---

## Phase 3: Pipeline Rewrite

### Task 7: Rewrite skills/bmb/bmb.md

This is the largest single task. The pipeline goes from 1185 lines of tmux-based orchestration to a streamlined Agent-tool-based flow.

**Files:**
- Modify: `skills/bmb/bmb.md` (full rewrite)

- [ ] **Step 1: Read current bmb.md in full**

Read the entire file to understand the current structure, especially:
- Frontmatter and skill metadata
- Preamble sections (config loading, helper functions)
- Each of the 12 steps
- Graceful degradation section
- Worktree lifecycle section
- Compression section

- [ ] **Step 2: Preserve and update frontmatter**

Keep the existing frontmatter structure but update the description:
```yaml
---
name: bmb
description: "BMB full A-to-Z pipeline — 12 steps with Codex companion coding, structural cross-model verification, dynamic difficulty routing, and mandatory retrospective."
---
```

- [ ] **Step 3: Rewrite preamble sections**

Replace the current preamble (cross-model invocation standard, config loading, bmb_analytics helpers) with:

1. **Config Loading** — keep `bmb_config_get` pattern, add model_routing reads
2. **Companion Path Resolution** — new section:
```bash
COMPANION="${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs"
if [ -z "$COMPANION" ] || [ ! -f "$COMPANION" ]; then
  COMPANION=$(find ~/.claude/plugins/cache/openai-codex -name codex-companion.mjs 2>/dev/null | head -1)
fi
```
3. **Analytics Helpers** — keep `bmb_analytics_event`, `bmb_analytics_step_start/end`, `bmb_learn`
4. **Escalation State** — new:
```bash
REJECTION_COUNT=0
CODER_MODEL=$(bmb_config_get "model_routing.coder_default")
```

Remove: cross-model invocation standard, tmux pane helpers, Consultant pane management, Monitor spawning, worktree lifecycle for blind phase, MCP disable references.

- [ ] **Step 4: Rewrite Steps 1-3 (Setup, Brainstorm, Approval)**

**Step 1 Setup**: Remove Consultant spawn, Monitor spawn, tmux setup. Keep: session init, config load, incident spool import, carry-forward check.

**Step 2 Brainstorm**: Remove Consultant pane references. Lead talks directly with user. Note that user can /btw anytime. Output: briefing.md.

**Step 3 User Approval**: Simplified — present briefing, get go/no-go. No Consultant summary.

- [ ] **Step 5: Rewrite Step 4 (Architecture)**

Replace council debate pattern with simple Agent dispatch:
```markdown
### Step 4: Architecture
Agent(subagent_type="bmb-architect")
  prompt: "Read .bmb/handoffs/briefing.md. Design the architecture.
           Include complexity: low|high rating.
           Write plan to .bmb/handoffs/plan-to-exec.md"
```

No tmux pane, no council rounds, no cross-model debate. Architect works solo.

Read plan-to-exec.md after agent returns. Extract complexity rating:
```bash
COMPLEXITY=$(grep -oP 'complexity:\s*\K\w+' .bmb/handoffs/plan-to-exec.md || echo "low")
```

- [ ] **Step 6: Write Step 5 (Pre-Research) — NEW**

This step is entirely new:
```markdown
### Step 5: Pre-Research
Agent(model="sonnet")
  prompt: "Read .bmb/handoffs/plan-to-exec.md.
           Use /last30days skill to research the latest solutions, libraries,
           and best practices relevant to this implementation.
           Write findings to .bmb/handoffs/research-results.md"
```

- [ ] **Step 7: Write Step 6 (Implementation — Codex companion)**

This replaces the Executor agent + tmux pane with companion direct call:
```markdown
### Step 6: Implementation

Set model based on complexity:
  if COMPLEXITY == "high":
    MODEL = config.model_routing.coder_complex  # gpt-5.4
    EFFORT = config.companion.effort_complex     # high
  else:
    MODEL = config.model_routing.coder_default   # gpt-5.4-mini
    EFFORT = config.companion.effort_default      # medium

Invoke Codex companion:
  Bash("node $COMPANION task --write --model $MODEL --effort $EFFORT \
    'Read .bmb/handoffs/plan-to-exec.md and .bmb/handoffs/research-results.md.
     Implement the design. Write summary to .bmb/handoffs/impl-result.md'")

3-tier fallback on failure:
  Attempt 1: retry same command
  Attempt 2: add --resume-last
  Attempt 3: Agent(model="sonnet") takes over coding

On success: log analytics event, proceed to Step 7
On all-fail: log DEGRADED, escalate to Sonnet immediately
```

- [ ] **Step 8: Write Step 7 (Review) with escalation controller**

```markdown
### Step 7: Review

Agent(subagent_type="bmb-verifier")
  prompt: "Read .bmb/handoffs/plan-to-exec.md and the git diff.
           Review code quality AND design fitness.
           Write results to .bmb/handoffs/review-result.md"

Read review-result.md:
  if PASS → proceed to Step 8
  if REJECT:
    REJECTION_COUNT++
    bmb_learn MISTAKE "7" "{rejection reason}" "{lesson}"
    CHANGED_FILES=$(git diff --name-only | wc -l)
    if REJECTION_COUNT >= escalation_threshold OR CHANGED_FILES >= complex_file_threshold:
      CODER_MODEL = "sonnet"
      log "ESCALATION: coder upgraded to Sonnet 4.6"
    → loop to Step 6
```

- [ ] **Step 9: Write Step 8 (Testing)**

```markdown
### Step 8: Testing

Agent(subagent_type="bmb-tester")
  prompt: "Read .bmb/handoffs/plan-to-exec.md and the code changes.
           Write and run comprehensive tests.
           Write results to .bmb/handoffs/test-result.md"

Read test-result.md:
  if PASS → proceed to Step 9
  if FAIL:
    REJECTION_COUNT++  # test failures count toward escalation
    → loop to Step 6
```

- [ ] **Step 10: Write Steps 9-12 (Simplify, Retrospective, Cleanup)**

**Step 9**: Lead invokes /simplify skill. Then `Agent(subagent_type="bmb-writer", model="sonnet")` for docs.

**Step 10**: `Agent(subagent_type="bmb-analyst")` for Bird's Law analysis. Output: analyst-report.md.

**Step 11**: Lead reads analyst report. Integrates learnings via `bmb_learn`. Writes session-prep.md. **RULE: MUST execute. Pipeline cannot end without this step.**

**Step 12**: Git commit and push. Session archive.

- [ ] **Step 11: Remove obsolete sections**

Remove from bmb.md:
- GRACEFUL DEGRADATION section (exit code 0-6 table) — replaced by companion fallback
- WORKTREE LIFECYCLE section (blind phase worktrees) — no longer needed
- Consultant isolation rules
- Monitor spawning patterns
- Blind phase entry/exit SendMessage patterns
- tmux pane management (kill-pane, split-pane patterns)

- [ ] **Step 12: Add new sections**

Add:
- **ESCALATION RULES** section (document the 3-tier fallback + rejection escalation)
- **MODEL ROUTING** section (document the complexity-based model selection)
- **COMPANION INVOCATION** section (document the Codex companion call pattern)

- [ ] **Step 13: Validate bmb.md**

Run these checks:
```bash
# No tmux references
grep -c 'tmux' skills/bmb/bmb.md
# Expected: 0

# No cross-model-run.sh references
grep -c 'cross-model-run' skills/bmb/bmb.md
# Expected: 0

# No Consultant references
grep -c -i 'consultant' skills/bmb/bmb.md
# Expected: 0

# No Monitor references
grep -c -i 'monitor' skills/bmb/bmb.md
# Expected: 0

# No blind phase references
grep -c 'blind' skills/bmb/bmb.md
# Expected: 0

# Companion reference exists
grep -c 'companion' skills/bmb/bmb.md
# Expected: > 0

# All 12 steps present
grep -c '### Step' skills/bmb/bmb.md
# Expected: 12
```

- [ ] **Step 14: Commit**

```bash
git add skills/bmb/bmb.md
git commit -m "feat(v0.5): rewrite pipeline — companion coding, agent dispatch, no tmux"
```

---

## Phase 4: Skills + Infrastructure

### Task 8: Update bmb-brainstorm skill

**Files:**
- Modify: `skills/bmb-brainstorm/SKILL.md`

- [ ] **Step 1: Read current file**

Read `skills/bmb-brainstorm/SKILL.md` in full. Focus on the cross-model review section (Step 2 of the brainstorm skill, around lines 274-340).

- [ ] **Step 2: Replace cross-model review with companion call**

Replace the `cross-model-run.sh --profile review` pattern (lines ~294-306) with:
```bash
COMPANION="${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs"
if [ -z "$COMPANION" ] || [ ! -f "$COMPANION" ]; then
  COMPANION=$(find ~/.claude/plugins/cache/openai-codex -name codex-companion.mjs 2>/dev/null | head -1)
fi

REVIEW_FILE=".bmb/sessions/${SESSION_ID}/plan-review.md"

{
  cat <<'PROMPT_EOF'
Review this plan document thoroughly.
Point out design flaws, missing considerations, infeasible parts,
security vulnerabilities, and runtime contract conflicts.
Output findings-first markdown.
PROMPT_EOF
  echo
  cat ".bmb/sessions/${SESSION_ID}/plan-draft.md"
} | node "$COMPANION" task --effort xhigh \
    "$(cat /dev/stdin)" > "$REVIEW_FILE" 2>"${REVIEW_FILE}.stderr" &
REVIEW_PID=$!
```

- [ ] **Step 3: Update exit code handling**

Replace the cross-model-run.sh exit code checks (codes 1, 2, 3) with companion-appropriate checks:
```bash
REVIEW_EXIT=$?
if [ $REVIEW_EXIT -ne 0 ]; then
  echo "$(date +%H:%M)|Lead|CONTEXT|Cross-model review failed (exit=$REVIEW_EXIT)" > .bmb/sessions/${SESSION_ID}/log-pipe
  # Proceed without review — companion failure is non-blocking
fi
```

- [ ] **Step 4: Remove Consultant pane references**

Remove any references to spawning Consultant, SendMessage to Consultant, consultant-feed.md in the brainstorm skill.

- [ ] **Step 5: Validate**

Run: `grep -n 'cross-model-run\|tmux\|consultant' skills/bmb-brainstorm/SKILL.md`
Expected: No output.

- [ ] **Step 6: Commit**

```bash
git add skills/bmb-brainstorm/SKILL.md
git commit -m "feat(v0.5): brainstorm skill uses companion for plan review"
```

---

### Task 9: Update bmb-refactoring skill

**Files:**
- Modify: `skills/bmb-refactoring/SKILL.md`

- [ ] **Step 1: Read current file**

Read `skills/bmb-refactoring/SKILL.md` in full.

- [ ] **Step 2: Replace Phase 0 cross-model analysis**

Replace `cross-model-run.sh --profile council` tmux pane pattern with:
```markdown
Track B — Cross-model analysis:
  Bash: node "$COMPANION" task --effort medium \
    "Analyze the codebase for refactoring opportunities. Focus on: {user scope}.
     Write refactoring PLAN to .bmb/handoffs/refactor-plan-cross.md"
```

- [ ] **Step 3: Replace Phase 1 execution**

Replace `cross-model-run.sh --profile exec-assist` with:
```markdown
Phase 1 — Execution:
  Bash: node "$COMPANION" task --write --effort high \
    "Read .bmb/handoffs/refactor-plan.md. Execute the refactoring.
     Write results to .bmb/handoffs/refactor-exec-result.md"
```

- [ ] **Step 4: Update cross-model invocation standard**

Replace the `cross-model-run.sh` reference at the top with:
```markdown
## Codex Companion Invocation
COMPANION="${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs"
if [ -z "$COMPANION" ] || [ ! -f "$COMPANION" ]; then
  COMPANION=$(find ~/.claude/plugins/cache/openai-codex -name codex-companion.mjs 2>/dev/null | head -1)
fi
```

- [ ] **Step 5: Remove tmux references**

Remove all `tmux split-pane`, pane polling, `tmux kill-pane` patterns.

- [ ] **Step 6: Validate**

Run: `grep -n 'cross-model-run\|tmux' skills/bmb-refactoring/SKILL.md`
Expected: No output.

- [ ] **Step 7: Commit**

```bash
git add skills/bmb-refactoring/SKILL.md
git commit -m "feat(v0.5): refactoring skill uses companion, no tmux"
```

---

### Task 10: Update install.sh and doctor.sh

**Files:**
- Modify: `install.sh`
- Modify: `doctor.sh`

- [ ] **Step 1: Read both files**

Read `install.sh` and `doctor.sh` in full.

- [ ] **Step 2: Update install.sh — remove codex shim**

Remove the installation of `bmb-system/bin/codex` from the file copy list and the `chmod +x` section. Remove `cross-model-run.sh` from the install list.

- [ ] **Step 3: Update install.sh — remove gemini checks**

Remove any `check_optional gemini` or gemini-related prerequisite checks.

- [ ] **Step 4: Update install.sh — add node check**

Add to prerequisite checks:
```bash
check_required "node" "Node.js (required for Codex companion)"
```

- [ ] **Step 5: Update doctor.sh — remove obsolete checks**

Remove:
```bash
check_file "$BMB_SYS/scripts/cross-model-run.sh"
check_executable "$BMB_SYS/scripts/cross-model-run.sh"
check_file "$BMB_SYS/bin/codex"
```

Remove any gemini-related checks.

- [ ] **Step 6: Update doctor.sh — add companion check**

Add:
```bash
# Codex companion
COMPANION=$(find ~/.claude/plugins/cache/openai-codex -name codex-companion.mjs 2>/dev/null | head -1)
if [ -n "$COMPANION" ]; then
  check_pass "Codex companion: $COMPANION"
else
  check_warn "Codex companion not found (install Codex plugin)"
fi

check_required_cmd "node" "Node.js"
```

- [ ] **Step 7: Test both scripts**

```bash
bash -n install.sh && echo "install.sh syntax OK"
bash -n doctor.sh && echo "doctor.sh syntax OK"
```
Expected: Both report "syntax OK".

- [ ] **Step 8: Commit**

```bash
git add install.sh doctor.sh
git commit -m "feat(v0.5): update install/doctor for companion, remove codex shim + gemini"
```

---

## Phase 5: Final Validation

### Task 11: End-to-end validation

- [ ] **Step 1: Verify no stale cross-model references in repo**

```bash
grep -r 'cross-model-run\.sh' --include='*.md' --include='*.sh' . | grep -v docs/plans | grep -v CHANGELOG | grep -v WHATS-NEW | grep -v bmb-system/plans
```
Expected: No output from active source files (docs/plans and WHATS-NEW are historical, OK to keep).

- [ ] **Step 2: Verify no stale tmux references in active files**

```bash
grep -rn 'tmux split-pane\|tmux kill-pane' agents/ skills/bmb/ skills/bmb-brainstorm/ skills/bmb-refactoring/
```
Expected: No output.

- [ ] **Step 3: Verify no stale Consultant/Monitor references in active files**

```bash
grep -rn 'SendMessage to Consultant\|SendMessage to Monitor\|bmb-consultant\|bmb-monitor' agents/ skills/bmb/ skills/bmb-brainstorm/ skills/bmb-refactoring/
```
Expected: No output.

- [ ] **Step 4: Verify all 5 retained agents exist and have valid frontmatter**

```bash
for agent in architect verifier tester writer analyst; do
  echo "--- bmb-$agent ---"
  head -6 "agents/bmb-$agent.md"
done
```
Expected: All 5 files exist with valid YAML frontmatter.

- [ ] **Step 5: Verify deleted agents are gone**

```bash
ls agents/bmb-executor.md agents/bmb-frontend.md agents/bmb-consultant.md agents/bmb-monitor.md 2>&1
```
Expected: "No such file or directory" for all 4.

- [ ] **Step 6: Verify companion is accessible**

```bash
COMPANION=$(find ~/.claude/plugins/cache/openai-codex -name codex-companion.mjs 2>/dev/null | head -1)
[ -f "$COMPANION" ] && echo "Companion found: $COMPANION" || echo "FAIL: companion not found"
```
Expected: "Companion found: ..."

- [ ] **Step 7: Smoke test companion**

```bash
node "$COMPANION" setup --json | python3 -c "import sys,json; d=json.load(sys.stdin); print('ready' if d['ready'] else 'NOT READY')"
```
Expected: "ready"

- [ ] **Step 8: Final commit with version bump**

Update VERSION file if it exists, then:
```bash
git add -A
git status  # review all changes
git commit -m "feat(v0.5): BMB pipeline redesign — Codex companion, sandwich pattern, structural cross-model"
git push
```

---

## Summary

| Phase | Tasks | Est. Files | Key Risk |
|-------|-------|-----------|----------|
| 1. Foundation | 1-2 | 8 deleted, 1 modified | Broken symlinks after deletion |
| 2. Agents | 3-6 | 5 modified | Inconsistent references |
| 3. Pipeline | 7 | 1 rewritten (1185→~600 lines) | Largest single change |
| 4. Skills+Infra | 8-10 | 4 modified | Companion path in brainstorm |
| 5. Validation | 11 | 0 | Stale references missed |

**Total: 11 tasks, ~50 steps, 17 files affected.**
