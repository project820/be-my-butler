#!/usr/bin/env bash
# BMB Auto-Learning — shared function for all BMB skills
# Usage: bmb_learn TYPE STEP "what happened" "rule to remember"
# TYPE: MISTAKE | CORRECTION | PRAISE

bmb_learn() {
  local type="$1" step="$2" what="$3" rule="$4"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M')
  local entry
  entry=$(printf "[%s] %s (step %s): %s → %s" "$ts" "$type" "$step" "$what" "$rule")

  # Tier 1: Project-local learnings
  local file=".bmb/learnings.md"
  [ ! -f "$file" ] && printf "# BMB Learnings\n\n" > "$file"
  printf "%s\n" "$entry" >> "$file"

  # Tier 2: Global learnings (cross-project)
  local global="$HOME/.claude/bmb-system/learnings-global.md"
  local project
  project=$(basename "$(pwd)")
  [ ! -f "$global" ] && printf "# BMB Global Learnings\n\n" > "$global"
  printf "%s [%s]\n" "$entry" "$project" >> "$global"

  # Tier 3: Analytics mirror (structured, if analytics active)
  if [ "${BMB_ANALYTICS_ACTIVE:-}" = "true" ] && type bmb_analytics_event >/dev/null 2>&1; then
    local stable_key
    stable_key=$(echo "$rule" | cksum | awk '{print $1}')
    # Record individual learning event
    bmb_analytics_event "${step}" "" "learning" "info" "${stable_key}" "${type}: ${what} -> ${rule}"
    # Track frequency via pattern counting
    bmb_analytics_count_pattern "${stable_key}" "learning" "${rule}" "info"
  fi
}
