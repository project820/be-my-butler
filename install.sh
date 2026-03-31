#!/bin/sh
# BMB (Be-my-butler) Installer
# Claude Code multi-agent orchestration pipeline
set -e

# ── Configuration ──────────────────────────────────────────────────────────────
REPO="project820/be-my-butler"
BRANCH="main"
CLAUDE_DIR="$HOME/.claude"

# ── Colors ─────────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
fi

ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
fail() { printf "  ${RED}✗${RESET} %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
info() { printf "  ${CYAN}→${RESET} %s\n" "$*"; }
header() { printf "\n${BOLD}%s${RESET}\n" "$*"; }

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<'USAGE'
BMB Installer

Usage:
  install.sh              Install BMB from local repo or GitHub
  install.sh --uninstall  Remove BMB installation
  install.sh --help       Show this help

Environment:
  BMB_REPO    Override default GitHub repo (default: project820/be-my-butler)
  BMB_BRANCH  Override default branch (default: main)
USAGE
    exit 0
}

# ── Parse arguments ────────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --uninstall)
            SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
            if [ -f "$SCRIPT_DIR/uninstall.sh" ]; then
                exec "$SCRIPT_DIR/uninstall.sh"
            elif [ -f "$CLAUDE_DIR/bmb-system/uninstall.sh" ]; then
                exec "$CLAUDE_DIR/bmb-system/uninstall.sh"
            else
                fail "uninstall.sh not found"; exit 1
            fi
            ;;
        --help|-h) usage ;;
        *) fail "Unknown option: $arg"; usage ;;
    esac
done

# Allow env override
REPO="${BMB_REPO:-$REPO}"
BRANCH="${BMB_BRANCH:-$BRANCH}"

# ── Detect source mode ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR=""
TEMP_DIR=""

if [ -d "$SCRIPT_DIR/skills/bmb" ] && [ -d "$SCRIPT_DIR/agents" ] && [ -d "$SCRIPT_DIR/bmb-system" ]; then
    REPO_DIR="$SCRIPT_DIR"
    info "Installing from local repository: $SCRIPT_DIR"
else
    header "Downloading BMB from GitHub..."
    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM
    ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
    info "Fetching $ARCHIVE_URL"
    if ! curl -fsSL "$ARCHIVE_URL" | tar xz -C "$TEMP_DIR" 2>/dev/null; then
        fail "Failed to download from GitHub. Check REPO ($REPO) and BRANCH ($BRANCH)."
        exit 1
    fi
    # tar extracts to {repo-name}-{branch}/
    EXTRACTED="$(find "$TEMP_DIR" -maxdepth 1 -type d ! -path "$TEMP_DIR" | head -1)"
    if [ -z "$EXTRACTED" ] || [ ! -d "$EXTRACTED/agents" ]; then
        fail "Downloaded archive does not contain expected agents/ directory."
        exit 1
    fi
    REPO_DIR="$EXTRACTED"
    ok "Downloaded successfully"
fi

# ── Prerequisites ──────────────────────────────────────────────────────────────
header "Checking prerequisites..."

REQUIRED_MISSING=""
OPTIONAL_MISSING=""

check_required() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1 found"
    else
        fail "$1 not found (required)"
        REQUIRED_MISSING="$REQUIRED_MISSING $1"
    fi
}

check_optional() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1 found"
    else
        warn "$1 not found (optional — $2)"
        OPTIONAL_MISSING="$OPTIONAL_MISSING $1"
    fi
}

check_required claude
check_required tmux
check_required python3
check_required sqlite3
check_required git
check_optional codex "cross-model Codex support"
check_required node "Node.js (required for Codex companion)"

if [ -n "$REQUIRED_MISSING" ]; then
    printf "\n"
    fail "Missing required tools:${REQUIRED_MISSING}"
    fail "Install them and re-run the installer."
    exit 1
fi

# ── Validate source files ─────────────────────────────────────────────────────
header "Validating source files..."

validate_exists() {
    if [ ! -e "$REPO_DIR/$1" ]; then
        fail "Missing source file: $1"
        return 1
    fi
}

VALIDATION_OK=true
for f in \
    skills/bmb/SKILL.md \
    skills/bmb/bmb.md \
    skills/bmb-brainstorm/SKILL.md \
    skills/bmb-refactoring/SKILL.md \
    skills/bmb-setup/SKILL.md \
    agents/bmb-architect.md \
    agents/bmb-consultant.md \
    agents/bmb-executor.md \
    agents/bmb-frontend.md \
    agents/bmb-simplifier.md \
    agents/bmb-tester.md \
    agents/bmb-verifier.md \
    agents/bmb-writer.md \
    agents/bmb-analyst.md \
    bmb-system/scripts/bmb-analytics.sh \
    bmb-system/scripts/bmb-learn.sh \
    bmb-system/scripts/knowledge-index.sh \
    bmb-system/scripts/knowledge-search.sh \
    bmb-system/scripts/conversation-logger.py \
    bmb-system/config/defaults.json \
    bmb-system/templates/session-prep.md \
    bmb-system/templates/handoff-frontmatter.md
do
    if ! validate_exists "$f"; then
        VALIDATION_OK=false
    fi
done

if [ "$VALIDATION_OK" = false ]; then
    fail "Source validation failed. Aborting."
    exit 1
fi
ok "All source files present"

# ── Backup existing installation ───────────────────────────────────────────────
NEEDS_BACKUP=false
for check_path in \
    "$CLAUDE_DIR/skills/bmb" \
    "$CLAUDE_DIR/skills/bmb-brainstorm" \
    "$CLAUDE_DIR/skills/bmb-refactoring" \
    "$CLAUDE_DIR/skills/bmb-setup" \
    "$CLAUDE_DIR/bmb-system"
do
    [ -d "$check_path" ] && NEEDS_BACKUP=true && break
done
# Also check agent files
for agent_file in "$CLAUDE_DIR"/agents/bmb-*.md; do
    [ -f "$agent_file" ] && NEEDS_BACKUP=true && break
done

if [ "$NEEDS_BACKUP" = true ]; then
    BACKUP_DIR="$CLAUDE_DIR/bmb-backup-$(date +%Y%m%d-%H%M%S)"
    header "Backing up existing BMB files to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"

    for d in skills/bmb skills/bmb-brainstorm skills/bmb-refactoring skills/bmb-setup bmb-system; do
        if [ -d "$CLAUDE_DIR/$d" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$d")"
            cp -R "$CLAUDE_DIR/$d" "$BACKUP_DIR/$d"
            ok "Backed up $d/"
        fi
    done
    if [ -d "$CLAUDE_DIR/agents" ]; then
        mkdir -p "$BACKUP_DIR/agents"
        for f in "$CLAUDE_DIR"/agents/bmb-*.md; do
            [ -f "$f" ] || continue
            cp "$f" "$BACKUP_DIR/agents/"
            ok "Backed up agents/$(basename "$f")"
        done
    fi
    ok "Backup complete: $BACKUP_DIR"
fi

# ── Install ────────────────────────────────────────────────────────────────────
header "Installing BMB..."

# Skills
for skill_dir in bmb bmb-brainstorm bmb-refactoring bmb-setup; do
    target="$CLAUDE_DIR/skills/$skill_dir"
    mkdir -p "$target"
    cp "$REPO_DIR/skills/$skill_dir/"* "$target/"
    ok "Installed skill: $skill_dir/"
done

# Agents
mkdir -p "$CLAUDE_DIR/agents"
for agent_file in "$REPO_DIR"/agents/bmb-*.md; do
    cp "$agent_file" "$CLAUDE_DIR/agents/"
    ok "Installed agent: $(basename "$agent_file")"
done

# BMB system (scripts, config, templates)
BMB_SYS="$CLAUDE_DIR/bmb-system"
mkdir -p "$BMB_SYS/scripts" "$BMB_SYS/config" "$BMB_SYS/templates"

for script in bmb-learn.sh bmb-analytics.sh knowledge-index.sh knowledge-search.sh conversation-logger.py; do
    cp "$REPO_DIR/bmb-system/scripts/$script" "$BMB_SYS/scripts/"
done
ok "Installed scripts"

cp "$REPO_DIR/bmb-system/config/defaults.json" "$BMB_SYS/config/"
ok "Installed config"

cp "$REPO_DIR/bmb-system/templates/"*.md "$BMB_SYS/templates/"
ok "Installed templates"

# Copy installer scripts into bmb-system for future use
for installer in install.sh doctor.sh uninstall.sh; do
    if [ -f "$REPO_DIR/$installer" ]; then
        cp "$REPO_DIR/$installer" "$BMB_SYS/"
    fi
done

# ── Set permissions ────────────────────────────────────────────────────────────
header "Setting permissions..."
find "$BMB_SYS/scripts" -name "*.sh" -exec chmod +x {} \;
for installer in "$BMB_SYS/install.sh" "$BMB_SYS/doctor.sh" "$BMB_SYS/uninstall.sh"; do
    [ -f "$installer" ] && chmod +x "$installer"
done
ok "All .sh files are executable"

# ── Doctor check ───────────────────────────────────────────────────────────────
header "Running doctor check..."
printf "\n"

DOCTOR_PASS=true

# Check installed files exist
check_installed() {
    if [ -e "$1" ]; then
        ok "$2"
    else
        fail "$2 — missing: $1"
        DOCTOR_PASS=false
    fi
}

check_installed "$CLAUDE_DIR/skills/bmb/SKILL.md"                  "Skill: bmb"
check_installed "$CLAUDE_DIR/skills/bmb-brainstorm/SKILL.md"       "Skill: bmb-brainstorm"
check_installed "$CLAUDE_DIR/skills/bmb-refactoring/SKILL.md"      "Skill: bmb-refactoring"
check_installed "$CLAUDE_DIR/skills/bmb-setup/SKILL.md"            "Skill: bmb-setup"
check_installed "$CLAUDE_DIR/agents/bmb-architect.md"              "Agent: architect"
check_installed "$CLAUDE_DIR/agents/bmb-consultant.md"             "Agent: consultant"
check_installed "$CLAUDE_DIR/agents/bmb-executor.md"               "Agent: executor"
check_installed "$CLAUDE_DIR/agents/bmb-verifier.md"               "Agent: verifier"
check_installed "$BMB_SYS/scripts/bmb-learn.sh"                    "Script: bmb-learn"
check_installed "$BMB_SYS/config/defaults.json"                    "Config: defaults"
check_installed "$BMB_SYS/templates/session-prep.md"               "Template: session-prep"

# Check executability
for sh_file in "$BMB_SYS"/scripts/*.sh; do
    [ -f "$sh_file" ] || continue
    if [ -x "$sh_file" ]; then
        ok "Executable: $(basename "$sh_file")"
    else
        fail "Not executable: $(basename "$sh_file")"
        DOCTOR_PASS=false
    fi
done

if [ "$DOCTOR_PASS" = false ]; then
    printf "\n"
    fail "Doctor check found issues. Run doctor.sh for full diagnostics."
    exit 1
fi

# ── Done ───────────────────────────────────────────────────────────────────────
printf "\n"
printf "${GREEN}${BOLD}BMB installed successfully!${RESET}\n"
printf "\n"
printf "  Installed to:\n"
printf "    Skills:    %s/skills/bmb*/\n" "$CLAUDE_DIR"
printf "    Agents:    %s/agents/bmb-*.md\n" "$CLAUDE_DIR"
printf "    System:    %s/bmb-system/\n" "$CLAUDE_DIR"
printf "\n"
if [ -n "$OPTIONAL_MISSING" ]; then
    printf "  ${YELLOW}Optional tools not found:${RESET}%s\n" "$OPTIONAL_MISSING"
    printf "  Install them to enable cross-model orchestration.\n"
    printf "\n"
fi
printf "  ${BOLD}Run /BMB-setup in your project to configure.${RESET}\n"
printf "\n"
