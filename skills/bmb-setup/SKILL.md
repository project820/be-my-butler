---
name: bmb-setup
description: "BMB setup — configure git, cross-model provider, timeouts, consultant style for a project."
---

# /BMB-setup

Configure BMB for the current project.

## Process

### Step 1: Check Existing Config
Read `.bmb/config.json` if it exists. Show current values to user. If no config exists, will create from defaults.

### Step 2: Interactive Configuration
Ask the user about each setting (show current/default value, accept Enter for no change):

1. **Git push policy**: yes / no / ask-each-time (default: ask)
2. **Git auto-commit**: true / false (default: true)
3. **Cross-model provider**: codex / gemini (default: codex)
4. **Cross-model timeout**: seconds (default: 3600)
5. **Claude agent timeout**: seconds (default: 1200)
6. **Writer timeout**: seconds (default: 600)
7. **Consultant style**: default / custom
   - If custom: ask for description (e.g., "explain like I'm a high schooler", "use construction analogies, keep it simple")
8. **Telegram notifications**: enabled / disabled (default: disabled)

### Step 3: Validate CLI
Verify the selected cross-model provider CLI exists:
```bash
command -v codex  # or gemini
```
If not found: warn user, note that pipeline will run Claude-only mode.

### Step 4: Save Config
Create `.bmb/` directory if needed and write `config.json`:
```bash
mkdir -p .bmb
```
Write config.json with the collected values. Use the schema from `~/.claude/bmb-system/config/defaults.json` as template.

### Step 5: Confirm
Show saved config summary. Tell user they can re-run `/BMB-setup` anytime to change settings.

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
    "telegram": { "enabled": false }
  }
}
```
