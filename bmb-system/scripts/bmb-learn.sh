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
}
