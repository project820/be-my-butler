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

_bmb_config_merge() {
  # Internal: 3-layer merge → stdout as JSON
  # If _BMB_KEY is set, prints the dot-path value; otherwise prints full merged JSON
  DEFAULTS_JSON="$HOME/.claude/bmb-system/config/defaults.json"
  _BMB_DF="$DEFAULTS_JSON" _BMB_GP="$GLOBAL_PROFILE" _BMB_LC="$LOCAL_CONFIG" python3 << 'PYEOF'
import json, sys, os

def shallow_merge(base, overlay):
    """Shallow merge: overlay top-level keys into base (dict keys merge, others replace)"""
    for k, v in overlay.items():
        if k.startswith('_'): continue
        if isinstance(v, dict) and k in base and isinstance(base[k], dict):
            base[k].update(v)
        else:
            base[k] = v

merged = {}
df = os.path.expanduser(os.environ['_BMB_DF'])
gp = os.path.expanduser(os.environ['_BMB_GP'])
lc = os.environ['_BMB_LC']

# Layer 1: Load hardcoded defaults from defaults.json
if os.path.isfile(df):
    d = json.load(open(df))
    for k, v in d.items():
        if k.startswith('_') or k == 'version': continue
        merged[k] = v

# Layer 2: Overlay global profile defaults section
if os.path.isfile(gp):
    g = json.load(open(gp))
    if 'defaults' in g:
        shallow_merge(merged, g['defaults'])
    if 'user' in g: merged['_user'] = g['user']
    if 'consultant_persona' in g: merged['_consultant_persona'] = g['consultant_persona']

# Layer 3: Overlay local config (highest priority)
if os.path.isfile(lc):
    local = json.load(open(lc))
    shallow_merge(merged, local)

key = os.environ.get('_BMB_KEY', '')
if key:
    d = merged
    for k in key.split('.'):
        d = d.get(k) if isinstance(d, dict) else None
    print(d if d is not None else '')
else:
    json.dump(merged, sys.stdout, ensure_ascii=False)
PYEOF
}

bmb_config_load() {
  # Merge defaults.json + global profile + local config → full JSON to stdout
  _BMB_KEY="" _bmb_config_merge
}

bmb_config_get() {
  # Usage: bmb_config_get "timeouts.claude_agent"
  _BMB_KEY="$1" _bmb_config_merge
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
