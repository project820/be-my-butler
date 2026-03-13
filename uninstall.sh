#!/bin/sh
# BMB Uninstaller — removes all BMB files from ~/.claude/
set -e

CLAUDE_DIR="$HOME/.claude"

# ── Colors ─────────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
fi

ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
info() { printf "  → %s\n" "$*"; }

# ── Parse arguments ────────────────────────────────────────────────────────────
AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        --yes|-y) AUTO_YES=true ;;
        --help|-h)
            printf "Usage: uninstall.sh [--yes]\n"
            printf "  --yes, -y  Skip confirmation prompt\n"
            exit 0
            ;;
        *) printf "Unknown option: %s\n" "$arg"; exit 1 ;;
    esac
done

# ── Collect targets ────────────────────────────────────────────────────────────
# Build list of paths that actually exist
TARGETS=""
ITEM_COUNT=0

add_target() {
    if [ -e "$1" ]; then
        TARGETS="$TARGETS
$1"
        ITEM_COUNT=$((ITEM_COUNT + 1))
    fi
}

# Skills
add_target "$CLAUDE_DIR/skills/bmb"
add_target "$CLAUDE_DIR/skills/bmb-brainstorm"
add_target "$CLAUDE_DIR/skills/bmb-refactoring"
add_target "$CLAUDE_DIR/skills/bmb-setup"

# Agents
for f in "$CLAUDE_DIR"/agents/bmb-*.md; do
    [ -f "$f" ] && add_target "$f"
done

# BMB system directory
add_target "$CLAUDE_DIR/bmb-system"

if [ "$ITEM_COUNT" -eq 0 ]; then
    printf "No BMB installation found. Nothing to remove.\n"
    exit 0
fi

# ── Show what will be removed ──────────────────────────────────────────────────
printf "\n${BOLD}The following BMB files will be removed:${RESET}\n\n"

echo "$TARGETS" | while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ -d "$path" ]; then
        info "$path/"
    else
        info "$path"
    fi
done

printf "\n"

# ── Confirmation ───────────────────────────────────────────────────────────────
if [ "$AUTO_YES" = false ]; then
    printf "Proceed with uninstall? [y/N] "
    read -r REPLY
    case "$REPLY" in
        [yY]|[yY][eE][sS]) ;;
        *)
            printf "Aborted.\n"
            exit 0
            ;;
    esac
fi

# ── Remove ─────────────────────────────────────────────────────────────────────
printf "\n${BOLD}Removing BMB...${RESET}\n"

REMOVED=""

echo "$TARGETS" | while IFS= read -r path; do
    [ -z "$path" ] && continue
    _label="${path#"$CLAUDE_DIR"/}"
    if [ -d "$path" ]; then
        rm -rf "$path"
        ok "Removed $_label/"
    elif [ -f "$path" ]; then
        rm -f "$path"
        ok "Removed $_label"
    fi
done

# Clean up empty parent directories (skills/, agents/) only if they're empty
for dir in "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"; do
    if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        rmdir "$dir" 2>/dev/null && ok "Removed empty directory: $(basename "$dir")/" || true
    fi
done

# ── Preserved items ───────────────────────────────────────────────────────────
printf "\n${BOLD}Preserved:${RESET}\n"
warn "Project-level .bmb/ directories are NOT removed."
warn "These live inside your project folders and contain per-project config."
warn "Remove them manually if needed: find ~/ -name .bmb -type d"

# ── Backup reminder ───────────────────────────────────────────────────────────
BACKUP_COUNT=0
for d in "$CLAUDE_DIR"/bmb-backup-*; do
    [ -d "$d" ] && BACKUP_COUNT=$((BACKUP_COUNT + 1))
done

if [ "$BACKUP_COUNT" -gt 0 ]; then
    printf "\n"
    warn "$BACKUP_COUNT backup(s) still exist in $CLAUDE_DIR/bmb-backup-*"
    warn "Remove them manually if no longer needed."
fi

printf "\n${GREEN}${BOLD}BMB uninstalled.${RESET}\n\n"
