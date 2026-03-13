#!/usr/bin/env bash
# BMB Idea Lifecycle — CRUD for persistent idea storage
# States: spark → validate → elaborate → decide → project | archive

BMB_IDEAS_DIR="$HOME/.claude/bmb-ideas"
BMB_IDEAS_INDEX="$BMB_IDEAS_DIR/index.json"

bmb_idea_init() {
  mkdir -p "$BMB_IDEAS_DIR"
  if [ ! -f "$BMB_IDEAS_INDEX" ]; then
    echo '{"version":1,"ideas":[]}' > "$BMB_IDEAS_INDEX"
  fi
}

bmb_idea_create() {
  # Usage: bmb_idea_create "TITLE" "SUMMARY" [SOURCE_SESSION] [SOURCE_PROJECT]
  local title="$1" summary="$2"
  local source_session="${3:-}"
  local source_project="${4:-$(pwd)}"

  bmb_idea_init

  local ts=$(date +%Y%m%dT%H%M%S)
  local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | cut -c1-40)
  local id="${ts}-${slug}"
  local idea_dir="$BMB_IDEAS_DIR/$id"

  mkdir -p "$idea_dir"

  # idea.md — use env vars for safety (Finding 5)
  _BMB_TITLE="$title" \
  _BMB_SUMMARY="$summary" \
  _BMB_SESSION="${source_session:-N/A}" \
  _BMB_PROJECT="${source_project}" \
  _BMB_IDEA_MD="$idea_dir/idea.md" \
  python3 << 'PYEOF'
import os
t = os.environ['_BMB_TITLE']
s = os.environ['_BMB_SUMMARY']
sess = os.environ['_BMB_SESSION']
proj = os.environ['_BMB_PROJECT']
out = os.environ['_BMB_IDEA_MD']
from datetime import datetime
now = datetime.now().strftime('%Y-%m-%d %H:%M')
with open(out, 'w') as f:
    f.write(f"# {t}\n\n## Summary\n{s}\n\n## Origin\n- Created: {now}\n- Source session: {sess}\n- Source project: {proj}\n")
PYEOF

  # v0.3.1 review fix: merged two Python blocks into one to avoid env injection mismatch
  # All user strings passed via env vars (Finding 5 + Review Issue 1)
  _BMB_IDEA_DIR="$idea_dir" \
  _BMB_ID="$id" \
  _BMB_TITLE="$title" \
  _BMB_SUMMARY="$summary" \
  _BMB_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  _BMB_SRC_SESSION="${source_session:-}" \
  _BMB_SRC_PROJECT="${source_project}" \
  _BMB_INDEX="$BMB_IDEAS_INDEX" \
  python3 << 'PYEOF'
import json, os

idea_dir = os.environ['_BMB_IDEA_DIR']
idx_path = os.environ['_BMB_INDEX']
ts = os.environ['_BMB_TS']
idea_id = os.environ['_BMB_ID']

# 1. Write status.json
status = {
    "current": "spark",
    "history": [{
        "from": None,
        "to": "spark",
        "at": ts,
        "reason": "Captured during brainstorm"
    }]
}
with open(os.path.join(idea_dir, 'status.json'), 'w') as f:
    json.dump(status, f, ensure_ascii=False, indent=2)

# 2. Update index
with open(idx_path) as f:
    idx = json.load(f)
idx['ideas'].append({
    'id': idea_id,
    'title': os.environ['_BMB_TITLE'],
    'status': 'spark',
    'created_at': ts,
    'updated_at': ts,
    'source_session': os.environ['_BMB_SRC_SESSION'],
    'source_project': os.environ['_BMB_SRC_PROJECT'],
    'project_path': None,
    'tags': [],
    'summary': os.environ['_BMB_SUMMARY']
})
with open(idx_path, 'w') as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)
PYEOF
  echo "$id"
}

bmb_idea_validate_id() {
  # Reject IDs containing path traversal characters
  local id="$1"
  if [[ "$id" == *"/"* ]] || [[ "$id" == *".."* ]]; then
    echo "ERROR: Invalid idea ID '$id' — must not contain '/' or '..'" >&2
    return 1
  fi
  return 0
}

bmb_idea_transition() {
  # Usage: bmb_idea_transition "IDEA_ID" "NEW_STATUS" "REASON"
  local id="$1" new_status="$2" reason="$3"

  bmb_idea_validate_id "$id" || return 1

  local idea_dir="$BMB_IDEAS_DIR/$id"

  [ ! -d "$idea_dir" ] && echo "ERROR: Idea $id not found" >&2 && return 1

  # Finding 5 fix — pass all strings via env vars
  _BMB_IDEA_DIR="$idea_dir" \
  _BMB_ID="$id" \
  _BMB_NEW_STATUS="$new_status" \
  _BMB_REASON="$reason" \
  _BMB_INDEX="$BMB_IDEAS_INDEX" \
  python3 << 'PYEOF'
import json, os
from datetime import datetime

idea_dir = os.environ['_BMB_IDEA_DIR']
new_status = os.environ['_BMB_NEW_STATUS']
reason = os.environ['_BMB_REASON']
idx_path = os.environ['_BMB_INDEX']
idea_id = os.environ['_BMB_ID']
ts = datetime.utcnow().isoformat() + 'Z'

# Update status.json
status_path = os.path.join(idea_dir, 'status.json')
with open(status_path) as f:
    status = json.load(f)
old = status['current']
status['current'] = new_status
status['history'].append({'from': old, 'to': new_status, 'at': ts, 'reason': reason})
with open(status_path, 'w') as f:
    json.dump(status, f, ensure_ascii=False, indent=2)

# Update index
with open(idx_path) as f:
    idx = json.load(f)
for idea in idx['ideas']:
    if idea['id'] == idea_id:
        idea['status'] = new_status
        idea['updated_at'] = ts
        break
with open(idx_path, 'w') as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)
PYEOF
}

bmb_idea_set_project_path() {
  # Usage: bmb_idea_set_project_path "IDEA_ID" "/path/to/project"
  local id="$1" project_path="$2"

  bmb_idea_validate_id "$id" || return 1
  # Finding 5 fix — env vars
  _BMB_ID="$id" _BMB_PATH="$project_path" _BMB_INDEX="$BMB_IDEAS_INDEX" \
  python3 << 'PYEOF'
import json, os
idx_path = os.environ['_BMB_INDEX']
with open(idx_path) as f:
    idx = json.load(f)
for idea in idx['ideas']:
    if idea['id'] == os.environ['_BMB_ID']:
        idea['project_path'] = os.environ['_BMB_PATH']
        break
with open(idx_path, 'w') as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)
PYEOF
}

bmb_idea_list() {
  # Usage: bmb_idea_list [STATUS_FILTER]
  # Outputs: id | title | status | updated_at
  # CRITICAL FIX: uses env vars instead of shell interpolation (council decision)
  local filter="${1:-}"
  bmb_idea_init
  _BMB_INDEX="$BMB_IDEAS_INDEX" _BMB_FILTER="$filter" \
  python3 << 'PYEOF'
import json, os
idx = json.load(open(os.environ['_BMB_INDEX']))
filt = os.environ.get('_BMB_FILTER', '')
for idea in idx['ideas']:
    if filt and idea['status'] != filt: continue
    print(f"{idea['id']} | {idea['title']} | {idea['status']} | {idea.get('updated_at','')}")
PYEOF
}

bmb_idea_archive() {
  bmb_idea_transition "$1" "archive" "${2:-Archived by user}"
}

bmb_idea_promote() {
  bmb_idea_transition "$1" "${2:-spark}" "${3:-Promoted from archive}"
}
