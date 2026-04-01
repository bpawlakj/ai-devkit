#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# AI DevKit — Update
# Checks for new version, shows what changed, pulls, and re-runs setup.
#
# Usage: ./update.sh                 # Update and install both (default)
#        ./update.sh --claude        # Update and install Claude Code only
#        ./update.sh --copilot       # Update and install Copilot CLI only
#        ./update.sh --check         # Only check for updates, don't install
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/VERSION"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}  [OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }

# ============================================================================
# Parse flags
# ============================================================================

SETUP_FLAG="--all"
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --claude)  SETUP_FLAG="--claude" ;;
        --copilot) SETUP_FLAG="--copilot" ;;
        --all)     SETUP_FLAG="--all" ;;
        --check)   CHECK_ONLY=true ;;
        -h|--help)
            echo "Usage: $0 [--claude | --copilot | --all | --check]"
            echo ""
            echo "  --claude   Update and install Claude Code config only"
            echo "  --copilot  Update and install Copilot CLI config only"
            echo "  --all      Update and install both (default)"
            echo "  --check    Only check for updates, don't install"
            exit 0 ;;
        *) echo "Unknown flag: $arg. Use --help for usage."; exit 1 ;;
    esac
done

# ============================================================================
# Verify we're in a git repo
# ============================================================================

if ! git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    err "Not a git repository. Did you install via git clone?"
    err "Re-install: git clone https://github.com/bpawlakj/ai-devkit.git ~/ai-devkit"
    exit 1
fi

cd "$SCRIPT_DIR"

# ============================================================================
# Read current version
# ============================================================================

LOCAL_VERSION="unknown"
if [ -f "$VERSION_FILE" ]; then
    LOCAL_VERSION="$(cat "$VERSION_FILE" | tr -d '[:space:]')"
fi

echo ""
echo -e "${BOLD}AI DevKit — Update${NC}"
echo -e "${DIM}Current version: ${LOCAL_VERSION}${NC}"
echo ""

# ============================================================================
# Fetch remote and compare
# ============================================================================

info "Checking for updates..."

REMOTE="origin"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if ! git fetch "$REMOTE" "$BRANCH" --quiet 2>/dev/null; then
    err "Cannot reach remote. Check your internet connection."
    exit 1
fi

LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse "$REMOTE/$BRANCH")"

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
    ok "Already up to date (v${LOCAL_VERSION})"
    echo ""
    exit 0
fi

# ============================================================================
# Show what's new
# ============================================================================

# Read remote VERSION to show target version
REMOTE_VERSION="$(git show "$REMOTE/$BRANCH:VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")"

echo -e "  ${BOLD}${GREEN}Update available: ${LOCAL_VERSION} → ${REMOTE_VERSION}${NC}"
echo ""

# Show changelog diff if CHANGELOG.md exists on both sides
LOCAL_CHANGELOG_EXISTS=$(git show HEAD:CHANGELOG.md &>/dev/null && echo "yes" || echo "no")
REMOTE_CHANGELOG_EXISTS=$(git show "$REMOTE/$BRANCH:CHANGELOG.md" &>/dev/null && echo "yes" || echo "no")

if [ "$REMOTE_CHANGELOG_EXISTS" = "yes" ]; then
    echo -e "${BOLD}What's new:${NC}"
    echo -e "${DIM}────────────────────────────────────────${NC}"

    if [ "$LOCAL_CHANGELOG_EXISTS" = "yes" ]; then
        # Show only the lines added to CHANGELOG.md
        diff <(git show HEAD:CHANGELOG.md) <(git show "$REMOTE/$BRANCH:CHANGELOG.md") \
            | grep '^> ' | sed 's/^> /  /' || true
    else
        # First time seeing changelog — show the whole thing (trimmed)
        git show "$REMOTE/$BRANCH:CHANGELOG.md" | head -40 | sed 's/^/  /'
    fi

    echo -e "${DIM}────────────────────────────────────────${NC}"
    echo ""
fi

# Summary of changed files
CHANGED_FILES=$(git diff --stat "$LOCAL_HEAD..$REMOTE_HEAD" -- \
    'claude/' 'copilot/' 'CLAUDE.md' 'setup.sh' 'uninstall.sh' 2>/dev/null || true)

if [ -n "$CHANGED_FILES" ]; then
    echo -e "${BOLD}Changed files:${NC}"
    echo "$CHANGED_FILES" | sed 's/^/  /'
    echo ""
fi

# ============================================================================
# Check-only mode exits here
# ============================================================================

if $CHECK_ONLY; then
    info "Run ./update.sh to apply the update."
    echo ""
    exit 0
fi

# ============================================================================
# Check for local modifications
# ============================================================================

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    warn "You have local modifications in this repo."
    warn "Files modified:"
    git diff --name-only 2>/dev/null | sed 's/^/    /'
    git diff --cached --name-only 2>/dev/null | sed 's/^/    /'
    echo ""
    read -p "  Stash changes and continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash push -m "ai-devkit-update-$(date +%Y%m%d-%H%M%S)"
        ok "Changes stashed (restore with: git stash pop)"
    else
        info "Update cancelled."
        exit 0
    fi
fi

# ============================================================================
# Pull and re-run setup
# ============================================================================

info "Pulling changes..."
if git pull --ff-only "$REMOTE" "$BRANCH" --quiet; then
    ok "Updated to v$(cat "$VERSION_FILE" | tr -d '[:space:]')"
else
    err "Fast-forward pull failed. You may have diverged from remote."
    err "Try: git pull --rebase origin main"
    exit 1
fi

echo ""
info "Re-running setup..."
echo ""

"$SCRIPT_DIR/setup.sh" "$SETUP_FLAG"
