#!/usr/bin/env bash
# BMB Analytics — file-backed analytics helpers for pipeline telemetry
# Single-writer model: Lead only. All state persisted under .bmb/analytics/
# Usage: source this file, then call bmb_analytics_* functions

BMB_ANALYTICS_DIR=".bmb/analytics"
BMB_ANALYTICS_DB="${BMB_ANALYTICS_DIR}/analytics.db"
BMB_ANALYTICS_STATE="${BMB_ANALYTICS_DIR}/state.env"
BMB_ANALYTICS_STEPS="${BMB_ANALYTICS_DIR}/steps"

# Severity ranking for severity_max comparisons
_bmb_severity_rank() {
  case "${1:-info}" in
    info)     echo 0 ;;
    warn)     echo 1 ;;
    error)    echo 2 ;;
    critical) echo 3 ;;
    *)        echo 0 ;;
  esac
}

# Escape single quotes for safe SQL string interpolation
# Usage: local escaped; escaped=$(_bmb_sql_escape "$value")
_bmb_sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# Safe sqlite3 wrapper — returns 1 if DB unavailable
_bmb_sql() {
  local db="${1:?}" ; shift
  if [ ! -f "$db" ]; then return 1; fi
  sqlite3 "$db" "$@" 2>/dev/null
}

# Initialize analytics for a session
# Usage: bmb_analytics_init SESSION_ID
bmb_analytics_init() {
  local session_id="${1:?bmb_analytics_init requires SESSION_ID}"
  local project_path
  project_path="$(pwd)"

  # Create directory structure
  mkdir -p "$BMB_ANALYTICS_STEPS"

  # Create schema
  sqlite3 "$BMB_ANALYTICS_DB" <<'SCHEMA'
CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  project_path TEXT NOT NULL,
  recipe TEXT,
  recipe_decided_at TEXT,
  started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now','localtime')),
  ended_at TEXT,
  status TEXT NOT NULL DEFAULT 'running',
  total_steps INTEGER NOT NULL DEFAULT 11,
  steps_completed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  step TEXT NOT NULL,
  step_seq INTEGER NOT NULL DEFAULT 1,
  agent TEXT,
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'info',
  event_key TEXT,
  detail TEXT,
  duration_sec INTEGER,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now','localtime')),
  FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

CREATE TABLE IF NOT EXISTS pattern_counts (
  event_key TEXT PRIMARY KEY,
  category TEXT,
  description TEXT,
  count INTEGER NOT NULL DEFAULT 1,
  first_seen TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now','localtime')),
  last_seen TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now','localtime')),
  last_session_id TEXT,
  severity_max TEXT NOT NULL DEFAULT 'info'
);

CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_step_seq ON events(session_id, step, step_seq);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_key ON events(event_key);
CREATE INDEX IF NOT EXISTS idx_pattern_counts ON pattern_counts(count DESC);
SCHEMA

  # Insert session row (recipe = NULL at this point)
  _bmb_sql "$BMB_ANALYTICS_DB" \
    "INSERT OR IGNORE INTO sessions (session_id, project_path) VALUES ('$(_bmb_sql_escape "$session_id")', '$(_bmb_sql_escape "$project_path")');"

  # Write state.env for cross-shell recovery
  cat > "$BMB_ANALYTICS_STATE" <<EOF
BMB_ANALYTICS_SESSION_ID="${session_id}"
BMB_ANALYTICS_DB="${BMB_ANALYTICS_DB}"
BMB_ANALYTICS_DIR="${BMB_ANALYTICS_DIR}"
BMB_ANALYTICS_STEPS="${BMB_ANALYTICS_STEPS}"
BMB_ANALYTICS_ACTIVE=true
EOF
}

# Source state.env — returns 0 if analytics active, 1 if unavailable
# Usage: bmb_analytics_use_state || return
bmb_analytics_use_state() {
  if [ -f "$BMB_ANALYTICS_STATE" ]; then
    # shellcheck disable=SC1090
    source "$BMB_ANALYTICS_STATE"
    return 0
  fi
  return 1
}

# Set recipe after user approval (idempotent UPDATE)
# Usage: bmb_analytics_set_recipe RECIPE
bmb_analytics_set_recipe() {
  local recipe="${1:?bmb_analytics_set_recipe requires RECIPE}"
  bmb_analytics_use_state || return 0
  _bmb_sql "$BMB_ANALYTICS_DB" \
    "UPDATE sessions SET recipe = '$(_bmb_sql_escape "$recipe")', recipe_decided_at = strftime('%Y-%m-%dT%H:%M:%S','now','localtime') WHERE session_id = '$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")' AND status = 'running';"
}

# Record step start — computes next step_seq, persists .current.env
# Usage: bmb_analytics_step_start STEP LABEL [AGENT]
bmb_analytics_step_start() {
  local step="${1:?}" label="${2:?}" agent="${3:-}"
  bmb_analytics_use_state || return 0

  # Compute next step_seq for this step in this session
  local seq
  seq=$(_bmb_sql "$BMB_ANALYTICS_DB" \
    "SELECT COALESCE(MAX(step_seq), 0) + 1 FROM events WHERE session_id = '$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")' AND step = '$(_bmb_sql_escape "$step")' AND event_type = 'step_start';")
  seq="${seq:-1}"

  # Persist current step state
  local step_file="${BMB_ANALYTICS_STEPS}/${step}.current.env"
  cat > "$step_file" <<EOF
STEP_START_TS="$(date +%s)"
STEP_SEQ="${seq}"
STEP_LABEL="${label}"
EOF

  # Insert step_start event
  _bmb_sql "$BMB_ANALYTICS_DB" \
    "INSERT INTO events (session_id, step, step_seq, agent, event_type, severity, detail) VALUES ('$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")', '$(_bmb_sql_escape "$step")', ${seq}, $([ -n "$agent" ] && echo "'$(_bmb_sql_escape "$agent")'" || echo "NULL"), 'step_start', 'info', '$(_bmb_sql_escape "$label")');"
}

# Record step end — reads .current.env, computes elapsed, inserts with duration
# Usage: bmb_analytics_step_end STEP LABEL [AGENT] [STATUS]
bmb_analytics_step_end() {
  local step="${1:?}" label="${2:?}" agent="${3:-}" status="${4:-complete}"
  bmb_analytics_use_state || return 0

  local step_file="${BMB_ANALYTICS_STEPS}/${step}.current.env"
  local duration_sec=0
  local seq=1

  if [ -f "$step_file" ]; then
    # shellcheck disable=SC1090
    source "$step_file"
    local now_ts
    now_ts=$(date +%s)
    duration_sec=$(( now_ts - ${STEP_START_TS:-$now_ts} ))
    seq="${STEP_SEQ:-1}"
    rm -f "$step_file"
  fi

  _bmb_sql "$BMB_ANALYTICS_DB" \
    "INSERT INTO events (session_id, step, step_seq, agent, event_type, severity, detail, duration_sec) VALUES ('$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")', '$(_bmb_sql_escape "$step")', ${seq}, $([ -n "$agent" ] && echo "'$(_bmb_sql_escape "$agent")'" || echo "NULL"), 'step_end', 'info', '$(_bmb_sql_escape "$label")', ${duration_sec});"
}

# Record a point-in-time event
# Usage: bmb_analytics_event STEP AGENT EVENT_TYPE SEVERITY EVENT_KEY DETAIL
bmb_analytics_event() {
  local step="${1:?}" agent="${2:-}" event_type="${3:?}" severity="${4:-info}" event_key="${5:-}" detail="${6:-}"
  bmb_analytics_use_state || return 0

  # Compute step_seq
  local seq
  seq=$(_bmb_sql "$BMB_ANALYTICS_DB" \
    "SELECT COALESCE(MAX(step_seq), 0) FROM events WHERE session_id = '$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")' AND step = '$(_bmb_sql_escape "$step")';")
  seq="${seq:-1}"

  _bmb_sql "$BMB_ANALYTICS_DB" \
    "INSERT INTO events (session_id, step, step_seq, agent, event_type, severity, event_key, detail) VALUES ('$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")', '$(_bmb_sql_escape "$step")', ${seq}, $([ -n "$agent" ] && echo "'$(_bmb_sql_escape "$agent")'" || echo "NULL"), '$(_bmb_sql_escape "$event_type")', '$(_bmb_sql_escape "$severity")', $([ -n "$event_key" ] && echo "'$(_bmb_sql_escape "$event_key")'" || echo "NULL"), $([ -n "$detail" ] && echo "'$(_bmb_sql_escape "$detail")'" || echo "NULL"));"
}

# Upsert pattern_counts — increment counter for recurring patterns
# Usage: bmb_analytics_count_pattern EVENT_KEY [CATEGORY] [DESCRIPTION] [SEVERITY]
bmb_analytics_count_pattern() {
  local event_key="${1:?}" category="${2:-}" description="${3:-}" severity="${4:-info}"
  bmb_analytics_use_state || return 0

  local exists
  exists=$(_bmb_sql "$BMB_ANALYTICS_DB" \
    "SELECT count FROM pattern_counts WHERE event_key = '$(_bmb_sql_escape "$event_key")';")

  if [ -n "$exists" ]; then
    # Update existing: increment count, update last_seen, session, and severity_max
    local current_max
    current_max=$(_bmb_sql "$BMB_ANALYTICS_DB" \
      "SELECT severity_max FROM pattern_counts WHERE event_key = '$(_bmb_sql_escape "$event_key")';")
    local new_sev="$current_max"
    if [ "$(_bmb_severity_rank "$severity")" -gt "$(_bmb_severity_rank "$current_max")" ]; then
      new_sev="$severity"
    fi
    _bmb_sql "$BMB_ANALYTICS_DB" \
      "UPDATE pattern_counts SET count = count + 1, last_seen = strftime('%Y-%m-%dT%H:%M:%S','now','localtime'), last_session_id = '$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")', severity_max = '$(_bmb_sql_escape "$new_sev")' WHERE event_key = '$(_bmb_sql_escape "$event_key")';";
  else
    # Insert new pattern
    _bmb_sql "$BMB_ANALYTICS_DB" \
      "INSERT INTO pattern_counts (event_key, category, description, last_session_id, severity_max) VALUES ('$(_bmb_sql_escape "$event_key")', $([ -n "$category" ] && echo "'$(_bmb_sql_escape "$category")'" || echo "NULL"), $([ -n "$description" ] && echo "'$(_bmb_sql_escape "$description")'" || echo "NULL"), '$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")', '$(_bmb_sql_escape "$severity")');"
  fi
}

# End session — update session row
# Usage: bmb_analytics_end_session STATUS STEPS_COMPLETED
bmb_analytics_end_session() {
  local status="${1:-complete}" steps_completed="${2:-0}"
  bmb_analytics_use_state || return 0

  _bmb_sql "$BMB_ANALYTICS_DB" \
    "UPDATE sessions SET ended_at = strftime('%Y-%m-%dT%H:%M:%S','now','localtime'), status = '$(_bmb_sql_escape "$status")', steps_completed = ${steps_completed} WHERE session_id = '$(_bmb_sql_escape "$BMB_ANALYTICS_SESSION_ID")';";

  # Cleanup step files
  rm -f "${BMB_ANALYTICS_STEPS}"/*.current.env 2>/dev/null || true
}
