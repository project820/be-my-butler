#!/bin/bash
# BMB-System Knowledge Indexer
# Indexes council decisions and handoff files into FTS5 knowledge base.
# Usage: knowledge-index.sh [.bmb/ directory path]
#
# Indexes:
#   - Council CONSENSUS.md files → decisions table
#   - Handoff files → handoffs table
#
# DB location: {bmb_dir}/knowledge.db

set -uo pipefail  # no -e: we handle errors per-insert

BMB_DIR="${1:-.bmb}"
DB_PATH="${BMB_DIR}/knowledge.db"

if ! command -v sqlite3 &>/dev/null; then
  echo "ERROR: sqlite3 not found" >&2
  exit 1
fi

# Initialize DB and FTS5 tables
sqlite3 "$DB_PATH" <<'SQL'
CREATE VIRTUAL TABLE IF NOT EXISTS decisions USING fts5(
  topic,
  consensus,
  evidence,
  session_date UNINDEXED,
  tokenize='porter unicode61'
);

CREATE VIRTUAL TABLE IF NOT EXISTS handoffs USING fts5(
  agent,
  content,
  phase UNINDEXED,
  source_file UNINDEXED,
  tokenize='porter unicode61'
);
SQL

INDEXED=0
FAILED=0

# Safe SQL insert via temp file (avoids shell interpolation issues with content)
sql_insert() {
  local table="$1"; shift
  local tmpfile
  tmpfile=$(mktemp)
  # Build SQL: all values are single-quote escaped via sed
  {
    printf "INSERT INTO %s VALUES (" "$table"
    local first=true
    for val in "$@"; do
      $first || printf ", "
      first=false
      printf "'"
      printf '%s' "$val" | sed "s/'/''/g"
      printf "'"
    done
    printf ");\n"
  } > "$tmpfile"

  if sqlite3 "$DB_PATH" < "$tmpfile" 2>/dev/null; then
    rm -f "$tmpfile"
    return 0
  else
    rm -f "$tmpfile"
    return 1
  fi
}

# Check if record exists
sql_exists() {
  local table="$1" where="$2"
  local count
  count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM ${table} WHERE ${where};" 2>/dev/null || echo "0")
  [ "$count" -gt 0 ]
}

# Index council CONSENSUS.md files → decisions table
for consensus_file in "${BMB_DIR}"/councils/*/CONSENSUS.md; do
  [ -f "$consensus_file" ] || continue
  topic=$(basename "$(dirname "$consensus_file")")
  session_date=$(grep -m1 'Created:' "$consensus_file" | sed 's/.*Created: *//' || echo "unknown")

  # Skip if already indexed
  safe_topic=$(printf '%s' "$topic" | sed "s/'/''/g")
  safe_date=$(printf '%s' "$session_date" | sed "s/'/''/g")
  if sql_exists "decisions" "topic='${safe_topic}' AND session_date='${safe_date}'"; then
    continue
  fi

  # Extract sections with awk (BSD/GNU portable)
  consensus_text=$(awk '/^## Consensus/{f=1;next} /^## /{f=0} f' "$consensus_file" | head -n 30)
  evidence_text=$(awk '/^## Evidence/{f=1;next} /^## /{f=0} f' "$consensus_file" | head -n 20)
  [ -z "$consensus_text" ] && consensus_text=$(head -n 50 "$consensus_file")

  if sql_insert "decisions" "$topic" "$consensus_text" "$evidence_text" "$session_date"; then
    INDEXED=$((INDEXED + 1))
  else
    echo "WARN: Failed to index council/$topic" >&2
    FAILED=$((FAILED + 1))
  fi
done

# Index handoff files → handoffs table (skip .compressed/)
for handoff_file in "${BMB_DIR}"/handoffs/*.md; do
  [ -f "$handoff_file" ] || continue
  filename=$(basename "$handoff_file")

  # Derive agent and phase from filename
  agent="unknown"; phase="execution"
  case "$filename" in
    briefing*)      agent="brainstormer"; phase="brainstorming" ;;
    plan-to-exec*)  agent="architect";    phase="architecture" ;;
    test-result*)   agent="tester";       phase="testing" ;;
    verify-result*) agent="verifier";     phase="verification" ;;
    review-result*) agent="reviewer";     phase="review" ;;
    docs-update*|docs-result*) agent="writer"; phase="documentation" ;;
    exec-result*)   agent="executor";     phase="execution" ;;
    *)              agent=$(echo "$filename" | sed 's/\.md$//; s/-result//') ;;
  esac

  # Skip if already indexed (agent + phase + source_file)
  safe_agent=$(printf '%s' "$agent" | sed "s/'/''/g")
  safe_phase=$(printf '%s' "$phase" | sed "s/'/''/g")
  safe_fn=$(printf '%s' "$filename" | sed "s/'/''/g")
  if sql_exists "handoffs" "agent='${safe_agent}' AND phase='${safe_phase}' AND source_file='${safe_fn}'"; then
    continue
  fi

  content=$(head -n 80 "$handoff_file")

  if sql_insert "handoffs" "$agent" "$content" "$phase" "$filename"; then
    INDEXED=$((INDEXED + 1))
  else
    echo "WARN: Failed to index handoff/$filename" >&2
    FAILED=$((FAILED + 1))
  fi
done

echo "Indexed ${INDEXED} items into ${DB_PATH}${FAILED:+ (${FAILED} failed)}"
