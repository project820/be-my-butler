---
name: bmb-setup
description: "BMB setup — configure git, cross-model provider, timeouts, consultant style for a project."
---

# /BMB-setup

One-stop setup for BMB in the current project. Handles prerequisites, config, and gitignore in a single pass.

## Process

### Step 0: Prerequisites Check
Run all checks first, report results as a table:

```bash
# 1. Claude Code CLI
command -v claude && claude --version

# 2. Cross-model CLIs (optional)
command -v codex && echo "codex: OK" || echo "codex: not found"
command -v gemini && echo "gemini: OK" || echo "gemini: not found"

# 3. Required env vars for optional features
[ -n "${BMB_TG_TOKEN:-}" ] && echo "BMB_TG_TOKEN: set" || echo "BMB_TG_TOKEN: not set"
[ -n "${BMB_TG_CHAT:-}" ] && echo "BMB_TG_CHAT: set" || echo "BMB_TG_CHAT: not set"

# 4. BMB system files
[ -d ~/.claude/bmb-system ] && echo "bmb-system: OK" || echo "bmb-system: MISSING"
[ -d ~/.claude/agents ] && ls ~/.claude/agents/bmb-*.md 2>/dev/null | wc -l | xargs -I{} echo "bmb agents: {} found"
```

Display results as:
| Component | Status | Required |
|-----------|--------|----------|
| Claude Code | vX.X.X | Yes |
| codex CLI | OK / missing | No (cross-model) |
| gemini CLI | OK / missing | No (cross-model) |
| BMB_TG_TOKEN | set / not set | No (notifications) |
| BMB_TG_CHAT | set / not set | No (notifications) |
| bmb-system/ | OK / MISSING | Yes |
| bmb agents | N found | Yes |

If required components are missing, stop and guide user to install them.

### Step 1: Check Existing Config
Read `.bmb/config.json` if it exists. Show current values to user. If no config exists, will create from defaults.

### Step 2: Interactive Configuration
Ask the user about each setting (show current/default value, accept Enter for no change):

1. **Git push policy**: yes / no / ask-each-time (default: ask)
2. **Git auto-commit**: true / false (default: true)
3. **Cross-model provider**: codex / gemini / none (default: codex)
   - If the selected provider CLI was not found in Step 0, warn and suggest `none`
4. **Cross-model timeout**: seconds (default: 3600)
5. **Claude agent timeout**: seconds (default: 1200)
6. **Writer timeout**: seconds (default: 600)
7. **Consultant style**: default / custom
   - If custom: ask for description (e.g., "explain like I'm a high schooler", "use construction analogies")
8. **Telegram notifications**: enabled / disabled (default: disabled)
   - If enabled but env vars missing from Step 0: warn that `BMB_TG_TOKEN` and `BMB_TG_CHAT` must be set in `~/.zshenv`
   - NEVER store tokens or chat IDs in config.json

### Step 3: Save Config
Create `.bmb/` directory and write `config.json`:
```bash
mkdir -p .bmb/handoffs/.compressed .bmb/councils .bmb/sessions .bmb/worktrees
```
Write config.json with collected values using the schema below.

### Step 4: Gitignore Protection
**Auto-add sensitive patterns to project `.gitignore`.** This is NON-OPTIONAL — always runs.

Check if `.gitignore` exists. If not, create it. Then ensure ALL of these patterns are present (append only missing ones):

```gitignore
# BMB runtime data (secrets, logs, sessions)
.bmb/

# Environment and secrets
.env
.env.*
!.env.example

# Credentials and tokens
*.pem
*.key
*.p12
*.pfx
*.jks
credentials.json
token.json
service-account*.json
*-credentials.json

# OS artifacts
.DS_Store
Thumbs.db
```

Implementation:
```bash
# For each pattern, check if already in .gitignore before appending
grep -qxF '.bmb/' .gitignore 2>/dev/null || echo '.bmb/' >> .gitignore
# ... repeat for each pattern
```

Do NOT duplicate existing entries. Only append missing ones.

### Step 5: Confirm
Show saved config summary + gitignore changes. Tell user:
- Re-run `/BMB-setup` anytime to change settings
- Telegram tokens go in `~/.zshenv`, NEVER in config files
- `.bmb/` is gitignored — safe for session logs and handoffs

## Config Schema
```json
{
  "version": 1,
  "git": {
    "auto_push": "ask",
    "auto_commit": true
  },
  "cross_model": {
    "provider": "codex",
    "codex_model": "LATEST",
    "gemini_model": "LATEST",
    "timeout_seconds": 3600
  },
  "timeouts": {
    "claude_agent": 1200,
    "cross_model": 3600,
    "writer": 600
  },
  "consultant": {
    "style": "default",
    "custom_style": null
  },
  "notifications": {
    "telegram": {
      "enabled": false
    }
  }
}
```

## Security Notes
- **Secrets belong in `~/.zshenv` only**: `BMB_TG_TOKEN`, `BMB_TG_CHAT`, API keys
- **config.json stores flags, never values**: `telegram.enabled: true/false`, never the actual token
- **`.bmb/` is always gitignored**: contains session logs, handoffs, conversation history
- If user has existing `.env` with relevant vars, suggest migrating to `~/.zshenv` for cross-project consistency
