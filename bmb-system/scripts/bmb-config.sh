#!/usr/bin/env bash
# BMB Config — global/local merge + first-time gate

GLOBAL_PROFILE="$HOME/.claude/bmb-profile.json"
LOCAL_CONFIG=".bmb/config.json"

bmb_config_check_setup() {
  # Returns 0 if EITHER local .bmb/config.json OR global profile exists
  # This prevents blocking existing projects that already have local config
  # Finding 1 fix: existing projects with .bmb/config.json are NOT first-time
  [ -f "$LOCAL_CONFIG" ] && return 0
  [ -f "$GLOBAL_PROFILE" ] || return 1
  _BMB_GP="$GLOBAL_PROFILE" python3 << 'PYEOF'
import json, sys, os
p = json.load(open(os.environ['_BMB_GP']))
sys.exit(0 if p.get('setup_complete') else 1)
PYEOF
}

bmb_config_load() {
  # Merge global profile defaults + local config (local overrides global)
  # Exports merged JSON to stdout
  _BMB_GP="$GLOBAL_PROFILE" _BMB_LC="$LOCAL_CONFIG" python3 << 'PYEOF'
import json, sys, os
merged = {}
gp = os.path.expanduser(os.environ['_BMB_GP'])
lc = os.environ['_BMB_LC']
# Load global defaults section
if os.path.isfile(gp):
    g = json.load(open(gp))
    merged = g.get('defaults', {})
    # Also carry user + consultant_persona for agents to read
    if 'user' in g: merged['_user'] = g['user']
    if 'consultant_persona' in g: merged['_consultant_persona'] = g['consultant_persona']
# Overlay local config (shallow per top-level key)
if os.path.isfile(lc):
    local = json.load(open(lc))
    for k, v in local.items():
        if k.startswith('_'): continue
        if isinstance(v, dict) and k in merged and isinstance(merged[k], dict):
            merged[k].update(v)
        else:
            merged[k] = v
json.dump(merged, sys.stdout, ensure_ascii=False)
PYEOF
}

bmb_config_get() {
  # Usage: bmb_config_get "timeouts.claude_agent"
  local key="$1"
  _BMB_KEY="$key" _BMB_GP="$GLOBAL_PROFILE" _BMB_LC="$LOCAL_CONFIG" python3 << 'PYEOF'
import json, sys, os

merged = {}
gp = os.path.expanduser(os.environ['_BMB_GP'])
lc = os.environ['_BMB_LC']
if os.path.isfile(gp):
    g = json.load(open(gp))
    merged = g.get('defaults', {})
    if 'user' in g: merged['_user'] = g['user']
    if 'consultant_persona' in g: merged['_consultant_persona'] = g['consultant_persona']
if os.path.isfile(lc):
    local = json.load(open(lc))
    for k, v in local.items():
        if k.startswith('_'): continue
        if isinstance(v, dict) and k in merged and isinstance(merged[k], dict):
            merged[k].update(v)
        else:
            merged[k] = v

keys = os.environ['_BMB_KEY'].split('.')
d = merged
for k in keys:
    if isinstance(d, dict):
        d = d.get(k)
    else:
        d = None
print(d if d is not None else '')
PYEOF
}

bmb_config_first_time_gate() {
  # Call at top of every BMB skill. Prints message and returns 1 if setup needed.
  if ! bmb_config_check_setup; then
    echo ""
    echo "================================================"
    echo "  BMB를 처음 사용하시네요!"
    echo "  먼저 /BMB-setup 을 실행해주세요."
    echo "  사용자 맞춤 설정을 통해 더 나은 경험을 제공합니다."
    echo "================================================"
    echo ""
    return 1
  fi
  return 0
}
