# Cross-Model Setup

BMB v0.5 uses the **Codex companion plugin** as its cross-model engine. The companion runs Codex tasks directly from the pipeline, with automatic 3-tier fallback and model escalation. This guide covers installation and configuration.

Cross-model is **optional**. BMB degrades gracefully to Claude-only if the Codex companion is unavailable.

---

## Prerequisites

- **Node.js** v18+ (required to run the companion plugin)
- **Codex CLI** installed and authenticated
- **Codex companion plugin** available at `CLAUDE_PLUGIN_ROOT`

---

## Codex CLI Setup

### 1. Install

```bash
npm install -g @anthropic-ai/codex
```

### 2. Authenticate

```bash
codex auth
```

Follow the OAuth flow in your browser. Credentials are stored locally.

### 3. Test

```bash
codex exec 'echo hello'
```

Expected output: the CLI executes the command and returns `hello`. If this works, Codex is ready.

---

## Companion Plugin Setup

The companion plugin is a Node.js script that wraps Codex invocations with retry logic, model routing, and result normalization.

### Companion Path Resolution

BMB resolves the companion using the following priority order:

1. `$CLAUDE_PLUGIN_ROOT/codex-companion/companion.js`
2. Fallback: `find ~/.claude -name "companion.js" -path "*/codex-companion/*"` (first match)

Set `CLAUDE_PLUGIN_ROOT` in `~/.zshenv` to make resolution explicit:

```bash
export CLAUDE_PLUGIN_ROOT="$HOME/.claude/plugins"
```

### Companion Invocation

The pipeline invokes the companion directly:

```bash
node "$COMPANION" task [--write] [--effort EFFORT] 'prompt'
```

| Flag | Description |
|------|-------------|
| _(none)_ | Read-only task — Codex may not modify files |
| `--write` | Write-enabled — Codex may create and modify files |
| `--effort EFFORT` | Override effort level: `low`, `medium`, `high` (default: `medium`) |

Examples:

```bash
# Read-only verification
node "$COMPANION" task 'Read .bmb/handoffs/briefing.md. Review all changed files. Write results to .bmb/handoffs/verify-result-cross.md.'

# Write-enabled execution
node "$COMPANION" task --write --effort high 'Implement the feature described in .bmb/handoffs/briefing.md.'
```

---

## Model Routing

The companion routes tasks to different Codex models based on task complexity. Configure routing in `.bmb/config.json` under `model_routing`:

| Key | Default | Description |
|-----|---------|-------------|
| `coder_default` | `gpt-5.4-mini` | Used for verification, review, and simple tasks |
| `coder_complex` | `gpt-5.4` | Used when task exceeds `complex_file_threshold` or requires deep reasoning |
| `coder_escalation` | `sonnet` | Fallback when Codex rejects the task twice (`escalation_threshold`) |
| `escalation_threshold` | `2` | Number of Codex rejections before escalating to Claude |
| `complex_file_threshold` | `3` | File count that triggers `coder_complex` instead of `coder_default` |

The companion automatically selects the appropriate model. You do not need to specify a model per-invocation.

---

## 3-Tier Fallback

When a Codex task fails, the companion applies a 3-tier recovery sequence before giving up:

1. **Retry** — Re-submits the same prompt to Codex. Handles transient API errors and rate limits.
2. **Resume** — Appends a continuation prompt to the partial result and re-submits. Handles incomplete outputs from context-length limits.
3. **Escalate** — Hands the task off to Claude (configured via `coder_escalation`). Triggered after `escalation_threshold` Codex rejections, or when retry and resume both fail.

If escalation also fails, the pipeline logs `DEGRADED: Cross-model unavailable` and continues in Claude-only mode.

---

## Configure BMB

In your project's `.bmb/config.json`:

```json
{
  "cross_model": {
    "provider": "codex",
    "timeout_seconds": 600
  },
  "model_routing": {
    "coder_default": "gpt-5.4-mini",
    "coder_complex": "gpt-5.4",
    "coder_escalation": "sonnet",
    "escalation_threshold": 2,
    "complex_file_threshold": 3
  },
  "companion": {
    "effort_default": "medium",
    "effort_complex": "high",
    "fallback_stages": ["retry", "resume", "escalate"]
  }
}
```

---

## Troubleshooting

### "codex: command not found"

The CLI is not installed globally or not in your PATH.

```bash
# Check if installed
npm list -g @anthropic-ai/codex

# Reinstall
npm install -g @anthropic-ai/codex
```

If installed but not found, ensure your npm global bin directory is in PATH (add to `~/.zshenv`):

```bash
export PATH="$(npm config get prefix)/bin:$PATH"
```

### Authentication Expired

```bash
codex auth
```

### Companion Not Found

If BMB cannot locate the companion plugin, it logs `DEGRADED: companion not found` and falls back to Claude-only mode.

Verify the companion path:

```bash
ls "$CLAUDE_PLUGIN_ROOT/codex-companion/companion.js"
# or check the fallback
find ~/.claude -name "companion.js" -path "*/codex-companion/*"
```

### Cross-Model Timeout

Default companion timeout is 600s. For large codebases, increase it:

```json
{
  "timeouts": {
    "cross_model": 1200
  }
}
```

### "DEGRADED: Cross-model unavailable" in Session Log

This is expected behavior when the companion or Codex CLI is unavailable. The pipeline continues in Claude-only mode with reduced verification coverage.

To fix: ensure Codex CLI is installed, authenticated, and the companion plugin is present at the resolved path.

---

## Context7 MCP Setup

BMB's Architect, Executor, and Frontend agents query live library documentation via **Context7 MCP** before writing code. This ensures agents write against current SDK APIs rather than stale training data.

### 1. Add Context7 to Claude Code MCP settings

In `~/.claude/mcp.json` (or your project's `.mcp.json`):

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

### 2. Test

Restart Claude Code and verify Context7 is listed as an available MCP server. The agents will automatically use `mcp__context7__resolve-library-id` and `mcp__context7__query-docs` when encountering unfamiliar libraries.

### 3. When Context7 is unavailable

If Context7 MCP is not configured, agents fall back to their training data. This is safe but may produce outdated API usage for recently updated libraries. No pipeline step is skipped.
