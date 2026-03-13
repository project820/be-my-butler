#!/bin/bash
# BMB-System Knowledge Search
# Searches FTS5 knowledge base for past decisions and handoffs.
# Usage: knowledge-search.sh "search query" [.bmb/ directory path]
#
# Returns: matching decisions and handoffs ranked by relevance.
# Output is structured for easy parsing by agents.

set -euo pipefail

QUERY="${1:?Usage: knowledge-search.sh 'query' [bmb_dir]}"
BMB_DIR="${2:-.bmb}"
DB_PATH="${BMB_DIR}/knowledge.db"

if [ ! -f "$DB_PATH" ]; then
  echo "No knowledge base found at ${DB_PATH}. Run knowledge-index.sh first."
  exit 0
fi

# Sanitize: escape single quotes for FTS5 MATCH
SAFE_QUERY="${QUERY//\'/\'\'}"

ERR_FILE=$(mktemp)
trap "rm -f '$ERR_FILE'" EXIT

echo "## Past Decisions"
if ! sqlite3 -header -column "$DB_PATH" \
  "SELECT topic, consensus, session_date FROM decisions WHERE decisions MATCH '${SAFE_QUERY}' ORDER BY rank LIMIT 5;" 2>"$ERR_FILE"; then
  echo "(query error: $(cat "$ERR_FILE"))"
fi

echo ""
echo "## Related Handoffs"
if ! sqlite3 -header -column "$DB_PATH" \
  "SELECT agent, substr(content, 1, 200) as summary, phase FROM handoffs WHERE handoffs MATCH '${SAFE_QUERY}' ORDER BY rank LIMIT 5;" 2>"$ERR_FILE"; then
  echo "(query error: $(cat "$ERR_FILE"))"
fi
