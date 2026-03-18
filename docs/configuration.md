# BMB Configuration

BMB is configured via `.bmb/config.json` in your project root. If the file does not exist, BMB uses built-in defaults.

Run `/BMB-setup` to generate a config file interactively.

---

## Full Schema Reference

```jsonc
{
  "version": 1,

  "git": {
    "auto_push": "ask",       // "yes" | "no" | "ask"
    "auto_commit": true        // true | false
  },

  "cross_model": {
    "provider": "codex",       // "codex" | "gemini"
    "codex_model": "LATEST",   // "LATEST" or specific model name
    "gemini_model": "LATEST",  // "LATEST" or specific model name
    "timeout_seconds": 3600    // Cross-model operation timeout
  },

  "timeouts": {
    "claude_agent": 1200,      // Executor, Tester, Verifier, Simplifier
    "cross_model": 3600,       // Cross-model CLI operations
    "writer": 600,             // Writer agent
    "analyst": 300             // Analyst agent (Step 10.5)
  },

  "analytics": {
    "enabled": true,           // true | false — record pipeline telemetry
    "db_path": ".bmb/analytics/analytics.db"  // SQLite database location
  },

  "consultant": {
    "style": "default",        // "default" | "concise" | "socratic" | "custom"
    "custom_style": null       // Free-text style description (used when style="custom")
  },

  "notifications": {
    "telegram": {
      "enabled": false         // true | false (requires env vars)
    }
  }
}
```

### Field Details

#### `git`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `auto_push` | string | `"ask"` | After final commit: `"yes"` pushes automatically, `"no"` skips, `"ask"` prompts the user |
| `auto_commit` | boolean | `true` | Whether Step 11 auto-commits all changes |

#### `cross_model`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `provider` | string | `"codex"` | Which CLI to use for cross-model verification. `"codex"` or `"gemini"` |
| `codex_model` | string | `"LATEST"` | Model override for Codex CLI. `"LATEST"` uses the CLI default |
| `gemini_model` | string | `"LATEST"` | Model override for Gemini CLI. `"LATEST"` uses the CLI default |
| `timeout_seconds` | integer | `3600` | Legacy field (prefer `timeouts.cross_model`) |

#### `timeouts`

| Field | Type | Default | Applies To |
|-------|------|---------|------------|
| `claude_agent` | integer | `1200` | Executor, Tester, Verifier, Simplifier agents |
| `cross_model` | integer | `3600` | All `cross-model-run.sh` invocations |
| `writer` | integer | `600` | Writer agent (documentation updates) |
| `analyst` | integer | `300` | Analyst agent (Step 10.5 retrospective) |

All values are in **seconds**.

#### `consultant`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `style` | string | `"default"` | Consultant personality preset |
| `custom_style` | string | `null` | Free-text style when `style` is `"custom"` |

Available styles:
- `"default"` -- balanced, professional Korean consultant
- `"concise"` -- minimal responses, bullet points only
- `"socratic"` -- asks probing questions, challenges assumptions
- `"custom"` -- uses the `custom_style` field verbatim as the personality prompt

#### `analytics`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Whether to record pipeline telemetry to `analytics.db` |
| `db_path` | string | `".bmb/analytics/analytics.db"` | SQLite database path for analytics data |

When enabled, `bmb-analytics.sh` records session start/end, step durations, agent events, and pattern counts. The Analyst agent (Step 10.5) queries this database to classify events by Bird's Law severity and identify promotion candidates.

To disable analytics (e.g., for CI or ephemeral environments):
```json
{
  "analytics": {
    "enabled": false
  }
}
```

#### `notifications.telegram`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Send Telegram notifications at pipeline milestones |

---

## Environment Variables

Set these in `~/.zshenv` (not `.zshrc` -- MCP and daemon processes do not read `.zshrc`).

| Variable | Required | Description |
|----------|----------|-------------|
| `BMB_TG_TOKEN` | No | Telegram bot token for notifications |
| `BMB_TG_CHAT` | No | Telegram chat ID for notifications |
| `BMB_CROSS_MODEL_PROVIDER` | No | Fallback provider if `config.json` is missing. `"codex"` or `"gemini"` |
| `BMB_DIR` | No | Override `.bmb/` directory path (rarely needed) |
| `BMB_WORKDIR` | No | Override working directory for cross-model CLI |
| `BMB_COMPRESS_OUTPUT` | No | Set to `"1"` to enable L2 write-time compression |

### Telegram Setup

1. Create a bot via [@BotFather](https://t.me/botfather) on Telegram
2. Get your chat ID by messaging [@userinfobot](https://t.me/userinfobot)
3. Add to `~/.zshenv`:
   ```bash
   export BMB_TG_TOKEN="123456:ABC-DEF..."
   export BMB_TG_CHAT="-100123456789"
   ```

BMB sends notifications at three points: pipeline start, user approval needed, pipeline complete.

---

## Timeout Tuning Guide

### When to Increase Timeouts

| Symptom | Adjust | Recommended |
|---------|--------|-------------|
| Executor times out on large codebases | `claude_agent` | 1800-2400s |
| Cross-model never completes | `cross_model` | 5400-7200s |
| Writer times out on many docs | `writer` | 900-1200s |
| Analyst times out on large analytics.db | `analyst` | 600s |
| All agents timing out | All | Multiply by 2x |

### When to Decrease Timeouts

| Scenario | Adjust | Recommended |
|----------|--------|-------------|
| Small bugfixes | `claude_agent` | 600s |
| Fast cross-model (Gemini) | `cross_model` | 1800s |
| Simple doc updates | `writer` | 300s |
| Small projects with few patterns | `analyst` | 120s |

### Per-Track Timeout Behavior

During Steps 6-7 (cross-model blind testing/verification), Claude and cross-model tracks have **independent timeouts**:

- Claude track uses `claude_agent` timeout (default: 1200s)
- Cross-model track uses `cross_model` timeout (default: 3600s)

If the Claude track times out first, it is logged and the pipeline waits only for the cross-model track. The pipeline never waits longer than `max(claude_agent, cross_model)`.

---

## Consultant Language

The Consultant agent supports multiple languages for user interaction:

| Language | Code | Notes |
|----------|------|-------|
| English | `en` | Default for non-Korean environments |
| Korean | `ko` | Default when user locale is Korean |
| Japanese | `ja` | Full support |
| Traditional Chinese | `zh-TW` | Full support |

Language is auto-detected from the user's first message. To force a language, include it in the initial prompt: "Respond in English" or "日本語で回答してください".

---

## Consultant Style Customization

### Preset Styles

**default:**
> Balanced professional tone. Asks clarifying questions when ambiguous. Suggests alternatives. Uses structured responses.

**concise:**
> Bullet points only. No pleasantries. Maximum information density.

**socratic:**
> Responds primarily with questions. Challenges every assumption. Forces the user to articulate their reasoning before validating.

### Custom Style Example

```json
{
  "consultant": {
    "style": "custom",
    "custom_style": "You are a senior staff engineer at a FAANG company. Be direct, opinionated, and cite specific design patterns by name. Push back on over-engineering."
  }
}
```

The `custom_style` text is injected directly into the Consultant agent's system prompt.
