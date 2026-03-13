# Cross-Model Setup

Cross-model verification is BMB's key differentiator -- a second AI model reviews your code **blind**, without seeing the original model's reasoning. This guide covers installation and configuration of supported providers.

Cross-model is **optional**. BMB degrades gracefully to Claude-only if no provider is available.

---

## Supported Providers

| Provider | CLI | Install | Best For |
|----------|-----|---------|----------|
| Codex | `codex` | npm | Broad code understanding, large codebases |
| Gemini | `gemini` | npm | Fast iteration, lighter verification |

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

### 4. Configure BMB

In your project's `.bmb/config.json`:
```json
{
  "cross_model": {
    "provider": "codex",
    "codex_model": "LATEST"
  }
}
```

`"LATEST"` uses whatever model the Codex CLI defaults to. To pin a specific model:
```json
{
  "cross_model": {
    "codex_model": "o3-pro"
  }
}
```

---

## Gemini CLI Setup

### 1. Install

```bash
npm install -g @anthropic-ai/gemini-cli
```

### 2. Authenticate

```bash
gemini auth
```

Follow the browser-based authentication flow.

### 3. Test

```bash
gemini run 'echo hello'
```

### 4. Configure BMB

```json
{
  "cross_model": {
    "provider": "gemini",
    "gemini_model": "LATEST"
  }
}
```

---

## Profile Permissions

BMB's `cross-model-run.sh` enforces permission profiles to limit what the cross-model CLI can do at each pipeline step:

| Profile | Used In | Can Read | Can Write | Purpose |
|---------|---------|----------|-----------|---------|
| `council` | Step 4 (Architecture) | All source files | `.bmb/` only | Design review -- must not modify code |
| `verify` | Step 7 (Verification) | All source files | `.bmb/` only | Code review -- must not modify code |
| `test` | Step 6 (Testing) | All source files | Test files + `.bmb/` | Write and run tests only |
| `exec-assist` | Step 5 (Execution) | All source files | All files | Full write access (used rarely) |

Permissions are enforced via prompt injection -- the cross-model CLI receives an `IMPORTANT:` prefix that constrains its behavior. Example for `verify`:

```
IMPORTANT: You are in READ-ONLY mode. Do NOT modify any source files.
Only write to .bmb/ directory.
```

### How Profiles Are Applied

```bash
# Invoked by the Lead during Step 7:
~/.claude/bmb-system/scripts/cross-model-run.sh --profile verify \
  'Read .bmb/handoffs/briefing.md. Review all changed files. Write results to .bmb/handoffs/verify-result-cross.md.'
```

The script resolves the provider and model from config, prepends the permission prefix, and calls the appropriate CLI.

---

## Switching Providers

To switch from Codex to Gemini (or vice versa), update one field:

```json
{
  "cross_model": {
    "provider": "gemini"
  }
}
```

No other changes needed. The `cross-model-run.sh` wrapper handles provider-specific CLI differences.

You can also set the provider via environment variable as a fallback:
```bash
export BMB_CROSS_MODEL_PROVIDER="gemini"
```

Config file takes precedence over environment variable.

---

## Troubleshooting

### "codex: command not found" / "gemini: command not found"

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
# Re-authenticate
codex auth
# or
gemini auth
```

### Cross-Model Timeout

Default timeout is 3600s (1 hour). For complex codebases, increase it:

```json
{
  "timeouts": {
    "cross_model": 5400
  }
}
```

### Cross-Model Returns Empty Results

Check that the prompt references valid file paths. The cross-model CLI runs in the project root by default. Verify with:

```bash
~/.claude/bmb-system/scripts/cross-model-run.sh --profile verify \
  'List the files in the current directory and write results to .bmb/handoffs/test-cross-check.md'
```

### "DEGRADED: Cross-model unavailable" in Session Log

This is expected behavior. BMB detected that the configured CLI is not available and fell back to Claude-only mode. The pipeline continues normally with reduced verification coverage.

To fix: install the configured provider CLI and re-authenticate.

### Codex `--full-auto` Flag

BMB always invokes Codex with `--full-auto`. This is required for non-interactive pipeline execution. Do not use `--xhigh` or other interactive flags.

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

---

### Model Selection

Use `"LATEST"` unless you have a specific reason to pin a model. Pinning avoids surprises when the provider updates their default, but you miss out on improvements.

To check what model your provider currently defaults to:
```bash
codex --version   # Shows version, default model varies by version
gemini --version
```
