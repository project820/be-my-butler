# Troubleshooting

Common issues and solutions when running BMB pipelines.

---

## tmux Errors

### "ERROR: BMB requires tmux."

BMB pipelines must run inside a tmux session. Claude Code itself must be started from within tmux.

**Fix:**
```bash
# Start tmux first
tmux new -s work

# Then start Claude Code inside tmux
claude
```

If you already have tmux running but see this error, you may have started Claude Code outside of tmux and then attached. Restart Claude Code from within a tmux pane.

### Agent Panes Not Closing

If a pipeline is interrupted (Ctrl+C, crash, timeout), agent panes may remain open.

**Fix -- kill all BMB-related panes:**
```bash
# List all panes
tmux list-panes -a -F '#{pane_id} #{pane_current_command}'

# Kill specific pane
tmux kill-pane -t %42

# Nuclear option -- kill all panes except your current one
tmux kill-pane -a
```

### "can't find pane" Errors

The consultant pane ID file (`.bmb/consultant-pane-id`) references a pane that no longer exists.

**Fix:**
```bash
rm -f .bmb/consultant-pane-id
```

The next pipeline run will create a fresh consultant pane.

---

## Timeout Issues

### Agent Times Out But Work Was Almost Done

Increase the relevant timeout in `.bmb/config.json`:

```json
{
  "timeouts": {
    "claude_agent": 1800,
    "cross_model": 5400,
    "writer": 900
  }
}
```

See [configuration.md](configuration.md) for timeout tuning guidance.

### Claude Track Blocks on Cross-Model Timeout

This was a known bug in early versions. BMB now tracks per-track timeouts independently. If you still see this behavior, verify your BMB installation is current:

```bash
bmb doctor
```

### Pipeline Hangs Indefinitely

Check if an agent pane is waiting for user input (it should not, but can happen with misconfigured permissions):

```bash
# Look at all tmux panes
tmux list-panes -a -F '#{pane_id} #{pane_current_command}'
```

Kill the stuck pane and the pipeline will detect the timeout.

---

## Worktree Conflicts

### "fatal: '.bmb/worktrees/executor' is already checked out"

A previous pipeline did not clean up its worktrees.

**Fix:**
```bash
# Remove all BMB worktrees
git worktree list | grep '.bmb/worktrees' | awk '{print $1}' | \
  xargs -I{} git worktree remove --force {} 2>/dev/null

# Also clean up stale branches
git branch | grep 'bmb-' | xargs git branch -D 2>/dev/null
```

### Merge Conflicts at Step 5.5

When executor and frontend worktrees modify the same files, merge conflicts occur. BMB escalates these to the user.

**Fix:** Resolve conflicts manually in the project root, then tell the Lead to continue:
```
충돌 해결했습니다. 계속 진행해주세요.
```

**Prevention:** During brainstorming, clearly separate file ownership between executor and frontend agents.

### "fatal: not a git repository"

BMB requires the project to be a git repository (worktrees depend on git).

**Fix:**
```bash
git init
git add -A
git commit -m "Initial commit"
```

---

## Cross-Model Issues

### Cross-Model Unavailable (Graceful Degradation)

If the session log shows `DEGRADED: Cross-model unavailable`, BMB is running in Claude-only mode. This is safe but loses blind verification benefits.

**Fix:** Install and authenticate the cross-model CLI. See [cross-model-setup.md](cross-model-setup.md).

### Cross-Model Produces Garbled Output

The cross-model CLI may return malformed output if the prompt is too long or contains special characters.

**Fix:**
1. Check `.bmb/handoffs/briefing.md` for unusual characters
2. Reduce the briefing scope
3. Try switching providers (`codex` vs `gemini`)

---

## Analytics Issues

### analytics.db Not Found

The Analyst agent (Step 10.5) expects `analytics.db` at `.bmb/analytics/analytics.db`. If this file does not exist, the first pipeline run creates it automatically via `bmb-analytics.sh`.

**Fix -- manually initialize:**
```bash
mkdir -p .bmb/analytics
~/.claude/bmb-system/scripts/bmb-analytics.sh init
```

### Analyst Agent Timeout

The Analyst has a short default timeout (300s) since it only queries the database. If your `analytics.db` has grown large (many pipeline runs), increase the timeout:

```json
{
  "timeouts": {
    "analyst": 600
  }
}
```

### analytics.db Corruption

Similar to `knowledge.db`, a hard crash during write can corrupt the SQLite database.

**Fix -- delete and let the next pipeline re-create it:**
```bash
rm -f .bmb/analytics/analytics.db
```

Historical telemetry will be lost, but the pipeline continues normally. New data is recorded from the next run.

### Analytics Disabled But Analyst Still Runs

If `analytics.enabled` is `false` in config, the Analyst step is skipped automatically. If it still appears to run, verify your config is valid JSON:

```bash
python3 -c "import json; json.load(open('.bmb/config.json'))"
```

---

## Context7 Issues

### Context7 MCP Not Connecting

The Architect, Executor, and Frontend agents query Context7 for live library docs. If Context7 is not available, agents fall back to training data.

**Fix:**
1. Verify Context7 is configured in `~/.claude/mcp.json`:
   ```json
   {
     "mcpServers": {
       "context7": {
         "command": "npx",
         "args": ["-y", "@context7/mcp@latest"]
       }
     }
   }
   ```
2. Restart Claude Code after adding the MCP config
3. Test by asking Claude Code to resolve a library via Context7

### Context7 Returns Stale Docs

Context7 serves documentation from its CDN. If you see outdated content, try:

```bash
# Force re-fetch by clearing npx cache
npx clear-npx-cache
```

---

## Knowledge Database

### knowledge.db Corruption

SQLite database corruption can occur after a hard crash during indexing.

**Fix -- delete and re-index:**
```bash
rm -f .bmb/knowledge.db
~/.claude/bmb-system/scripts/knowledge-index.sh .bmb/
```

This rebuilds the FTS5 tables from existing council and handoff files. No data is lost -- the source markdown files are the ground truth.

### "sqlite3: command not found"

**Fix:**
```bash
# macOS (usually pre-installed)
which sqlite3

# If missing on macOS
brew install sqlite3

# Linux
sudo apt install sqlite3
```

---

## Installation Issues

### "bmb doctor" Reports Missing Dependencies

Run `bmb doctor` to see what is missing:

```bash
bmb doctor
```

Common missing dependencies:

| Dependency | Install Command |
|------------|----------------|
| tmux | `brew install tmux` (macOS) / `apt install tmux` (Linux) |
| python3 | `brew install python3` (macOS) / `apt install python3` (Linux) |
| sqlite3 | `brew install sqlite3` (macOS) / `apt install sqlite3` (Linux) |
| Claude Code | `npm install -g @anthropic-ai/claude-code` |

### Permission Denied on Scripts

```bash
chmod +x ~/.claude/bmb-system/scripts/*.sh
```

### Skills Not Appearing in Claude Code

BMB skills must be in `~/.claude/skills/bmb/SKILL.md`. Only one skill file per folder is recognized by Claude Code.

**Verify:**
```bash
ls -la ~/.claude/skills/bmb/SKILL.md
```

If the file exists but the `/BMB` command is not recognized, restart Claude Code.

### Stale Config After Upgrade

After upgrading BMB, old config files may conflict with new defaults.

**Fix:**
```bash
# Back up current config
cp .bmb/config.json .bmb/config.json.bak

# Re-run setup
/BMB-setup
```

---

## Session Continuity

### "이전 세션을 이어갈까요?" Not Appearing

The session prep file is missing or the symlink is broken.

**Check:**
```bash
ls -la .bmb/sessions/latest
cat .bmb/sessions/latest/session-prep.md
```

**Fix:** If the symlink is broken, remove it:
```bash
rm -f .bmb/sessions/latest
```

The next session will start fresh.

### Session Log is Empty

Each agent appends to `.bmb/session-log.md`. If it is empty, agents may have failed before producing output.

Check individual handoff files in `.bmb/handoffs/` to see how far the pipeline progressed.

---

## General Tips

1. **Always check `session-log.md` first.** It contains timestamped events from every agent.
2. **Use `bmb doctor`** after any installation change.
3. **Read `.bmb/learnings.md`** -- BMB logs its own mistakes and may have already identified the issue.
4. **Start simple.** If a full `feature` recipe fails, try `research` first to verify brainstorming works, then escalate.
5. **Check tmux panes.** Most "hanging" issues are agents waiting in a pane that you cannot see. Use `tmux list-panes -a` to find them.
