#!/bin/sh
# BMB Doctor — verifies prerequisites, installation, and runtime readiness
set -e

CLAUDE_DIR="$HOME/.claude"
BMB_SYS="$CLAUDE_DIR/bmb-system"

# ── Colors ─────────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    DIM=$(tput dim)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" DIM="" RESET=""
fi

# ── Table helpers ──────────────────────────────────────────────────────────────
COL_ITEM=30
COL_VER=20
COL_STATUS=8

print_row() {
    _item="$1"; _version="$2"; _status="$3"
    case "$_status" in
        OK)   _color="$GREEN" ;;
        WARN) _color="$YELLOW" ;;
        FAIL) _color="$RED" ;;
        *)    _color="$RESET" ;;
    esac
    printf "  %-${COL_ITEM}s %-${COL_VER}s %s%-${COL_STATUS}s%s\n" \
        "$_item" "$_version" "$_color" "$_status" "$RESET"
}

print_separator() {
    printf "  %s\n" "$(printf '%0.s─' $(seq 1 $((COL_ITEM + COL_VER + COL_STATUS + 2))))"
}

print_header() {
    printf "\n${BOLD}%s${RESET}\n" "$1"
    printf "  ${DIM}%-${COL_ITEM}s %-${COL_VER}s %-${COL_STATUS}s${RESET}\n" \
        "Component" "Version" "Status"
    print_separator
}

HAS_REQUIRED_FAIL=false

# ── Prerequisites ──────────────────────────────────────────────────────────────
print_header "Prerequisites"

check_tool() {
    _name="$1"; _required="$2"; _hint="$3"; _ver_cmd="$4"

    if command -v "$_name" >/dev/null 2>&1; then
        if [ -n "$_ver_cmd" ]; then
            _ver="$(eval "$_ver_cmd" 2>&1 | head -1)" || _ver="unknown"
        else
            _ver="installed"
        fi
        print_row "$_name" "$_ver" "OK"
    else
        if [ "$_required" = "required" ]; then
            print_row "$_name" "not found" "FAIL"
            HAS_REQUIRED_FAIL=true
        else
            print_row "$_name ($_hint)" "not found" "WARN"
        fi
    fi
}

check_tool claude   required "" "claude --version 2>/dev/null | head -1"
check_tool tmux     required "" "tmux -V 2>/dev/null"
check_tool python3  required "" "python3 --version 2>/dev/null"
check_tool sqlite3  required "" "sqlite3 --version 2>/dev/null | awk '{print \$1}'"
check_tool git      required "" "git --version 2>/dev/null"
check_tool codex    optional "cross-model" "codex --version 2>/dev/null | head -1"
check_tool gemini   optional "cross-model" "gemini --version 2>/dev/null | head -1"

# ── Installed Files ────────────────────────────────────────────────────────────
print_header "Installed Files"

check_file() {
    _path="$1"; _label="$2"
    if [ -e "$_path" ]; then
        print_row "$_label" "" "OK"
    else
        print_row "$_label" "missing" "FAIL"
        HAS_REQUIRED_FAIL=true
    fi
}

# Skills
check_file "$CLAUDE_DIR/skills/bmb/SKILL.md"            "skill: bmb/SKILL.md"
check_file "$CLAUDE_DIR/skills/bmb/bmb.md"               "skill: bmb/bmb.md"
check_file "$CLAUDE_DIR/skills/bmb-brainstorm/SKILL.md"  "skill: bmb-brainstorm/SKILL.md"
check_file "$CLAUDE_DIR/skills/bmb-refactoring/SKILL.md" "skill: bmb-refactoring/SKILL.md"
check_file "$CLAUDE_DIR/skills/bmb-setup/SKILL.md"       "skill: bmb-setup/SKILL.md"

# Agents
for agent in architect consultant executor frontend simplifier tester verifier writer; do
    check_file "$CLAUDE_DIR/agents/bmb-${agent}.md" "agent: bmb-${agent}.md"
done

# Agents (v0.2: analyst added)
check_file "$CLAUDE_DIR/agents/bmb-analyst.md"       "agent: bmb-analyst.md"

# Scripts
check_file "$BMB_SYS/scripts/cross-model-run.sh"    "script: cross-model-run.sh"
check_file "$BMB_SYS/scripts/bmb-learn.sh"           "script: bmb-learn.sh"
check_file "$BMB_SYS/scripts/bmb-analytics.sh"       "script: bmb-analytics.sh"
check_file "$BMB_SYS/scripts/knowledge-index.sh"     "script: knowledge-index.sh"
check_file "$BMB_SYS/scripts/knowledge-search.sh"    "script: knowledge-search.sh"
check_file "$BMB_SYS/scripts/conversation-logger.py" "script: conversation-logger.py"

# Config & templates
check_file "$BMB_SYS/config/defaults.json"           "config: defaults.json"
check_file "$BMB_SYS/templates/session-prep.md"      "template: session-prep.md"
check_file "$BMB_SYS/templates/handoff-frontmatter.md" "template: handoff-frontmatter.md"

# ── File Permissions ───────────────────────────────────────────────────────────
print_header "File Permissions"

check_executable() {
    _path="$1"; _label="$2"
    if [ ! -f "$_path" ]; then
        print_row "$_label" "missing" "FAIL"
        HAS_REQUIRED_FAIL=true
    elif [ -x "$_path" ]; then
        print_row "$_label" "+x" "OK"
    else
        print_row "$_label" "not executable" "FAIL"
        HAS_REQUIRED_FAIL=true
    fi
}

check_executable "$BMB_SYS/scripts/cross-model-run.sh"  "cross-model-run.sh"
check_executable "$BMB_SYS/scripts/bmb-learn.sh"        "bmb-learn.sh"
check_executable "$BMB_SYS/scripts/bmb-analytics.sh"    "bmb-analytics.sh"
check_executable "$BMB_SYS/scripts/knowledge-index.sh"  "knowledge-index.sh"
check_executable "$BMB_SYS/scripts/knowledge-search.sh" "knowledge-search.sh"

# ── Runtime Checks ─────────────────────────────────────────────────────────────
print_header "Runtime"

# tmux session creation test
if command -v tmux >/dev/null 2>&1; then
    _test_session="bmb-doctor-test-$$"
    if tmux new-session -d -s "$_test_session" 2>/dev/null; then
        tmux kill-session -t "$_test_session" 2>/dev/null || true
        print_row "tmux session creation" "" "OK"
    else
        print_row "tmux session creation" "failed" "WARN"
    fi
else
    print_row "tmux session creation" "tmux missing" "FAIL"
    HAS_REQUIRED_FAIL=true
fi

# sqlite3 in-memory test
if command -v sqlite3 >/dev/null 2>&1; then
    _sql_result="$(echo "SELECT 1;" | sqlite3 2>/dev/null)" || _sql_result=""
    if [ "$_sql_result" = "1" ]; then
        print_row "sqlite3 query" "" "OK"
    else
        print_row "sqlite3 query" "failed" "WARN"
    fi
fi

# python3 import test
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json, sqlite3, os, sys" 2>/dev/null; then
        print_row "python3 stdlib imports" "" "OK"
    else
        print_row "python3 stdlib imports" "failed" "WARN"
    fi
fi

# Context7 MCP check (optional)
if [ -f "$HOME/.claude/mcp.json" ]; then
    if grep -q '"context7"' "$HOME/.claude/mcp.json" 2>/dev/null; then
        print_row "Context7 MCP" "configured" "OK"
    else
        print_row "Context7 MCP (live docs)" "not configured" "WARN"
    fi
else
    print_row "Context7 MCP (live docs)" "mcp.json missing" "WARN"
fi

# Analytics DB check (informational)
if [ -f ".bmb/analytics/analytics.db" ]; then
    _db_size="$(du -h .bmb/analytics/analytics.db 2>/dev/null | awk '{print $1}')"
    print_row "analytics.db" "$_db_size" "OK"
else
    print_row "analytics.db" "not yet created" "WARN"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
printf "\n"
if [ "$HAS_REQUIRED_FAIL" = true ]; then
    printf "  ${RED}${BOLD}FAIL${RESET} — One or more required checks failed.\n"
    printf "  Run ${BOLD}install.sh${RESET} to fix missing files, or install missing tools.\n"
    printf "\n"
    exit 1
else
    printf "  ${GREEN}${BOLD}ALL OK${RESET} — BMB is ready.\n"
    printf "\n"
    exit 0
fi
