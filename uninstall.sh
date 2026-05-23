#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code & Copilot CLI — Unified Uninstall
# Usage: ./uninstall.sh                # Both (default)
#        ./uninstall.sh --claude       # Claude Code only
#        ./uninstall.sh --copilot      # Copilot CLI only
#        ./uninstall.sh --all          # Both (same as no flag)
# ============================================================================

CLAUDE_DIR="$HOME/.claude"
COPILOT_DIR="${COPILOT_HOME:-${XDG_CONFIG_HOME:-$HOME/.copilot}}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()   { echo -e "\033[0;34m[INFO]\033[0m $1"; }
ok()     { echo -e "${GREEN}  [OK]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${BOLD}$1${NC}"; }

remove_files() {
    local dir="$1" ext="$2"
    shift 2
    for name in "$@"; do
        local f="$dir/${name}.${ext}"
        [ -f "$f" ] && rm "$f" && ok "Removed ${name}.${ext}"
    done
}

DO_CLAUDE=false
DO_COPILOT=false

case "${1:---all}" in
    --claude)  DO_CLAUDE=true ;;
    --copilot) DO_COPILOT=true ;;
    --all)     DO_CLAUDE=true; DO_COPILOT=true ;;
    -h|--help)
        echo "Usage: $0 [--claude | --copilot | --all]"
        exit 0 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
esac

echo ""
echo "========================================"
echo "  Uninstall"
echo "========================================"

if $DO_CLAUDE; then
    header "Claude Code"

    info "Removing rules..."
    remove_files "$CLAUDE_DIR/rules" md security java spring-boot python typescript react angular node swift-ios

    info "Removing commands..."
    remove_files "$CLAUDE_DIR/commands" md ship retro changelog threat-model init-permissions

    info "Removing agents..."
    remove_files "$CLAUDE_DIR/agents" md security-reviewer build-resolver performance-analyzer

    info "Removing skills..."
    for skill in kickoff discover product-spec atomize research save-plan implement agents-md rule-review; do
        if [ -d "$CLAUDE_DIR/skills/$skill" ]; then
            rm -rf "$CLAUDE_DIR/skills/$skill" && ok "Removed /$skill"
        fi
    done

    echo ""
    warn "NOT removed (may contain manual edits):"
    warn "  ~/.claude/CLAUDE.md"
    warn "  ~/.claude/settings.json"
    warn "  Maister plugin"
    info "Restore from backup: ~/.claude/backups/"
fi

if $DO_COPILOT; then
    header "Copilot CLI"

    info "Removing agents..."
    remove_files "$COPILOT_DIR/agents" md security-reviewer build-resolver performance-analyzer

    echo ""
    warn "NOT removed (may contain manual edits):"
    warn "  $COPILOT_DIR/mcp-config.json"
    warn "  ~/.claude/CLAUDE.md"
    warn "Per-repo files (.github/instructions/, .github/hooks/) must be removed manually."
fi

echo ""
