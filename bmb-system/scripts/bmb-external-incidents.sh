#!/usr/bin/env bash
# BMB External Incidents — NDJSON spool, import, sanitize, rotate, classify
# Off-session dependency failures are recorded here, then imported by Lead into analytics.
# Single-writer invariant: shims write NDJSON only; Lead imports into SQLite.

set -euo pipefail

BMB_SPOOL_DIR="${BMB_SPOOL_DIR:-$HOME/.claude/bmb-system/runtime}"
BMB_SPOOL_FILE="${BMB_SPOOL_DIR}/external-incidents.ndjson"
BMB_SPOOL_ARCHIVE="${BMB_SPOOL_DIR}/archive"
BMB_RETENTION_DAYS="${BMB_RETENTION_DAYS:-7}"
BMB_MAX_SPOOL_MB="${BMB_MAX_SPOOL_MB:-50}"

# --- Ensure spool directory exists ---
_bmb_incidents_ensure_dir() {
  mkdir -p "$BMB_SPOOL_DIR" "$BMB_SPOOL_ARCHIVE"
}

# --- Sanitize: strip PII/tokens from a string ---
# Removes: Bearer tokens, API keys, email addresses, absolute home paths
_bmb_incidents_sanitize() {
  local input="${1:-}"
  printf '%s' "$input" \
    | sed -E \
      -e 's/Bearer [A-Za-z0-9_\.\-]+/Bearer [REDACTED]/g' \
      -e 's/[Aa]pi[_-]?[Kk]ey[=: ]*[A-Za-z0-9_\.\-]{8,}/api_key=[REDACTED]/g' \
      -e 's/[Ss]k-[A-Za-z0-9]{20,}/sk-[REDACTED]/g' \
      -e 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[EMAIL_REDACTED]/g' \
      -e "s|$HOME|~|g"
}

# --- Classify: pattern match -> severity ---
# Returns: info | warn | error | critical
_bmb_incidents_classify() {
  local event_key="${1:-}" exit_code="${2:-0}"
  case "$event_key" in
    *auth_401|*auth_fail)           echo "error" ;;
    *cli_missing)                   echo "error" ;;
    *exec_stalled|*review_timeout)  echo "warn" ;;
    *exec_nonzero)
      if [ "$exit_code" -gt 128 ]; then echo "error"; else echo "warn"; fi ;;
    *retest_timeout)                echo "warn" ;;
    *recovery_restart_failed)       echo "error" ;;
    *recovery_restart_attempted)    echo "info" ;;
    *preflight_failed)              echo "error" ;;
    *mcp_handshake_failed)          echo "warn" ;;
    *login_recovered)               echo "info" ;;
    *rate_limit)                    echo "warn" ;;
    *stall_detected)                echo "warn" ;;
    *crash)                         echo "critical" ;;
    *)                              echo "info" ;;
  esac
}

# --- Append incident to NDJSON spool ---
# Usage: bmb_incidents_record EVENT_KEY [DETAIL] [EXIT_CODE] [SOURCE]
bmb_incidents_record() {
  local event_key="${1:?bmb_incidents_record requires EVENT_KEY}"
  local detail="${2:-}"
  local exit_code="${3:-0}"
  local source="${4:-unknown}"

  _bmb_incidents_ensure_dir

  local severity
  severity=$(_bmb_incidents_classify "$event_key" "$exit_code")

  local sanitized_detail
  sanitized_detail=$(_bmb_incidents_sanitize "$detail")

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local ts_epoch
  ts_epoch=$(date +%s)

  # Build JSON line using python3 for safe encoding
  python3 -c "
import json, sys
obj = {
    'ts': '$ts',
    'ts_epoch': $ts_epoch,
    'event_key': '$event_key',
    'severity': '$severity',
    'exit_code': $exit_code,
    'source': '$source',
    'detail': sys.stdin.read().strip()
}
print(json.dumps(obj, ensure_ascii=False))
" <<< "$sanitized_detail" >> "$BMB_SPOOL_FILE"
}

# --- Import spool into analytics SQLite ---
# Usage: bmb_incidents_import SESSION_ID DB_PATH [LOOKBACK_SEC]
# Only imports incidents not yet imported (uses ts_epoch > last import)
bmb_incidents_import() {
  local session_id="${1:?}" db_path="${2:?}" lookback_sec="${3:-86400}"

  if [ ! -f "$BMB_SPOOL_FILE" ]; then
    return 0
  fi
  if [ ! -f "$db_path" ]; then
    return 1
  fi

  local cutoff_epoch
  cutoff_epoch=$(( $(date +%s) - lookback_sec ))

  # Create external_incidents table if missing
  sqlite3 "$db_path" <<'SQL'
CREATE TABLE IF NOT EXISTS external_incidents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  ts TEXT NOT NULL,
  ts_epoch INTEGER NOT NULL,
  event_key TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'info',
  exit_code INTEGER DEFAULT 0,
  source TEXT,
  detail TEXT,
  imported_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now','localtime')),
  UNIQUE(ts_epoch, event_key)
);
CREATE INDEX IF NOT EXISTS idx_ext_incidents_session ON external_incidents(session_id);
CREATE INDEX IF NOT EXISTS idx_ext_incidents_key ON external_incidents(event_key);
SQL

  # Parse spool and insert, deduplicating on (ts_epoch, event_key)
  local count=0
  while IFS= read -r line; do
    # Extract fields via python3
    local fields
    fields=$(python3 -c "
import json, sys
try:
    obj = json.loads(sys.stdin.read())
    epoch = obj.get('ts_epoch', 0)
    if epoch < $cutoff_epoch:
        sys.exit(1)
    # Tab-separated: ts, ts_epoch, event_key, severity, exit_code, source, detail
    print('\t'.join([
        str(obj.get('ts', '')),
        str(obj.get('ts_epoch', 0)),
        str(obj.get('event_key', '')),
        str(obj.get('severity', 'info')),
        str(obj.get('exit_code', 0)),
        str(obj.get('source', '')),
        str(obj.get('detail', ''))
    ]))
except:
    sys.exit(1)
" <<< "$line" 2>/dev/null) || continue

    local ts ts_ep ek sev ec src det
    IFS=$'\t' read -r ts ts_ep ek sev ec src det <<< "$fields"

    # Escape single quotes for SQL
    det=$(printf '%s' "$det" | sed "s/'/''/g")
    src=$(printf '%s' "$src" | sed "s/'/''/g")
    ek=$(printf '%s' "$ek" | sed "s/'/''/g")
    ts=$(printf '%s' "$ts" | sed "s/'/''/g")
    ts_ep=$(printf '%s' "$ts_ep" | sed "s/'/''/g")
    ec=$(printf '%s' "$ec" | sed "s/'/''/g")

    sqlite3 "$db_path" \
      "INSERT OR IGNORE INTO external_incidents (session_id, ts, ts_epoch, event_key, severity, exit_code, source, detail)
       VALUES ('$session_id', '$ts', '$ts_ep', '$ek', '$sev', '$ec', '$src', '$det');" 2>/dev/null || true
    count=$((count + 1))
  done < "$BMB_SPOOL_FILE"

  echo "$count"
}

# --- Rotate spool: keep recent, archive older ---
# Usage: bmb_incidents_rotate [RETENTION_DAYS]
bmb_incidents_rotate() {
  local retention="${1:-$BMB_RETENTION_DAYS}"

  if [ ! -f "$BMB_SPOOL_FILE" ]; then
    return 0
  fi

  _bmb_incidents_ensure_dir

  local cutoff_epoch
  cutoff_epoch=$(( $(date +%s) - (retention * 86400) ))

  # Split: recent lines stay, old lines go to archive
  local archive_file
  archive_file="${BMB_SPOOL_ARCHIVE}/incidents-$(date +%Y%m%d-%H%M%S).ndjson"
  local tmp_recent
  tmp_recent="${BMB_SPOOL_FILE}.tmp"

  : > "$tmp_recent"
  : > "$archive_file"

  while IFS= read -r line; do
    local epoch
    epoch=$(python3 -c "
import json, sys
try:
    print(json.loads(sys.stdin.read()).get('ts_epoch', 0))
except:
    print(0)
" <<< "$line" 2>/dev/null) || epoch=0

    if [ "$epoch" -ge "$cutoff_epoch" ]; then
      echo "$line" >> "$tmp_recent"
    else
      echo "$line" >> "$archive_file"
    fi
  done < "$BMB_SPOOL_FILE"

  mv "$tmp_recent" "$BMB_SPOOL_FILE"

  # Remove empty archive
  [ ! -s "$archive_file" ] && rm -f "$archive_file"

  # Enforce max spool size
  local spool_size_kb
  spool_size_kb=$(du -k "$BMB_SPOOL_FILE" 2>/dev/null | cut -f1)
  local max_kb=$(( BMB_MAX_SPOOL_MB * 1024 ))
  if [ "${spool_size_kb:-0}" -gt "$max_kb" ]; then
    # Truncate oldest half
    local total_lines
    total_lines=$(wc -l < "$BMB_SPOOL_FILE")
    local keep=$(( total_lines / 2 ))
    tail -n "$keep" "$BMB_SPOOL_FILE" > "${BMB_SPOOL_FILE}.tmp"
    mv "${BMB_SPOOL_FILE}.tmp" "$BMB_SPOOL_FILE"
  fi
}

# --- List recent incidents (for CLI/debugging) ---
# Usage: bmb_incidents_list [COUNT]
bmb_incidents_list() {
  local count="${1:-20}"
  if [ ! -f "$BMB_SPOOL_FILE" ]; then
    echo "No incidents recorded."
    return 0
  fi
  tail -n "$count" "$BMB_SPOOL_FILE" | python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        print(f\"[{obj.get('severity','?'):>8}] {obj.get('ts','?')} {obj.get('event_key','?')}: {obj.get('detail','')[:80]}\")
    except:
        pass
"
}

# --- CLI mode ---
if [ "${1:-}" = "--record" ]; then
  shift
  bmb_incidents_record "$@"
elif [ "${1:-}" = "--import" ]; then
  shift
  bmb_incidents_import "$@"
elif [ "${1:-}" = "--rotate" ]; then
  shift
  bmb_incidents_rotate "$@"
elif [ "${1:-}" = "--list" ]; then
  shift
  bmb_incidents_list "$@"
fi
