#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code & Copilot CLI — Unified Setup
# Usage: ./setup.sh                # Install both (default)
#        ./setup.sh --claude       # Claude Code only
#        ./setup.sh --copilot      # Copilot CLI only
#        ./setup.sh --all          # Both (same as no flag)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
COPILOT_DIR="${COPILOT_HOME:-${XDG_CONFIG_HOME:-$HOME/.copilot}}"
BACKUP_SUFFIX="setup-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}  [OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
header(){ echo -e "\n${BOLD}$1${NC}"; }

backup_if_exists() {
    local file="$1" backup_dir="$2"
    if [ -f "$file" ]; then
        mkdir -p "$backup_dir"
        cp "$file" "$backup_dir/$(basename "$file")"
    fi
}

# ============================================================================
# Parse flags
# ============================================================================

DO_CLAUDE=false
DO_COPILOT=false

case "${1:---all}" in
    --claude)  DO_CLAUDE=true ;;
    --copilot) DO_COPILOT=true ;;
    --all)     DO_CLAUDE=true; DO_COPILOT=true ;;
    -h|--help)
        echo "Usage: $0 [--claude | --copilot | --all]"
        echo "  --claude   Install Claude Code config only"
        echo "  --copilot  Install Copilot CLI config only"
        echo "  --all      Install both (default)"
        exit 0 ;;
    *) echo "Unknown flag: $1. Use --help for usage."; exit 1 ;;
esac

echo ""
echo "========================================"
echo "  AI Coding Tools Setup"
echo "========================================"
echo ""

# ============================================================================
# Shared: CLAUDE.md (both tools read it)
# ============================================================================

header "Shared: CLAUDE.md"
BACKUP_CLAUDE="$CLAUDE_DIR/backups/$BACKUP_SUFFIX"

if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    backup_if_exists "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_CLAUDE"
    read -p "  CLAUDE.md already exists. Overwrite? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$CLAUDE_DIR"
        cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
        ok "CLAUDE.md installed (backup saved)"
    else
        info "  Skipped CLAUDE.md"
    fi
else
    mkdir -p "$CLAUDE_DIR"
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    ok "CLAUDE.md installed"
fi

# ============================================================================
# Claude Code
# ============================================================================

if $DO_CLAUDE; then
    header "Claude Code: Rules"
    mkdir -p "$CLAUDE_DIR/rules"
    for f in "$SCRIPT_DIR"/claude/rules/*.md; do
        [ -f "$f" ] || continue
        cp "$f" "$CLAUDE_DIR/rules/"
        ok "$(basename "$f")"
    done

    header "Claude Code: Commands"
    mkdir -p "$CLAUDE_DIR/commands"
    for f in "$SCRIPT_DIR"/claude/commands/*.md; do
        [ -f "$f" ] || continue
        cp "$f" "$CLAUDE_DIR/commands/"
        ok "/$(basename "$f" .md)"
    done

    header "Claude Code: Agents"
    mkdir -p "$CLAUDE_DIR/agents"
    for f in "$SCRIPT_DIR"/claude/agents/*.md; do
        [ -f "$f" ] || continue
        cp "$f" "$CLAUDE_DIR/agents/"
        ok "$(basename "$f")"
    done

    header "Claude Code: Settings (hooks, plugins, MCP)"
    backup_if_exists "$CLAUDE_DIR/settings.json" "$BACKUP_CLAUDE"

    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        if command -v jq &>/dev/null; then
            jq -s '.[0] * .[1]' "$CLAUDE_DIR/settings.json" "$SCRIPT_DIR/claude/settings.template.json" \
                > "$CLAUDE_DIR/settings.json.tmp"
            mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
            ok "settings.json merged (template wins for conflicts, existing keys preserved)"
        else
            warn "jq not installed — cannot merge settings"
            read -p "  Overwrite settings.json? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$SCRIPT_DIR/claude/settings.template.json" "$CLAUDE_DIR/settings.json"
                ok "settings.json installed (backup saved)"
            else
                info "  Skipped settings.json"
            fi
        fi
    else
        cp "$SCRIPT_DIR/claude/settings.template.json" "$CLAUDE_DIR/settings.json"
        ok "settings.json installed"
    fi

    header "Claude Code: Maister Plugin"
    if [ -d "$CLAUDE_DIR/plugins/marketplaces/maister-plugins" ]; then
        ok "Maister marketplace already registered"
    else
        warn "Maister will auto-install on next Claude Code session"
        warn "Or run: claude /plugins to manage plugins"
    fi
fi

# ============================================================================
# Copilot CLI
# ============================================================================

if $DO_COPILOT; then
    BACKUP_COPILOT="$COPILOT_DIR/backups/$BACKUP_SUFFIX"

    header "Copilot CLI: Agents"
    mkdir -p "$COPILOT_DIR/agents"
    for f in "$SCRIPT_DIR"/copilot/agents/*.md; do
        [ -f "$f" ] || continue
        cp "$f" "$COPILOT_DIR/agents/"
        ok "$(basename "$f")"
    done

    header "Copilot CLI: MCP Config"
    MCP_FILE="$COPILOT_DIR/mcp-config.json"
    backup_if_exists "$MCP_FILE" "$BACKUP_COPILOT"
    if [ -f "$MCP_FILE" ] && command -v jq &>/dev/null; then
        jq -s '.[0] * .[1]' "$MCP_FILE" "$SCRIPT_DIR/copilot/mcp-config.json" > "${MCP_FILE}.tmp"
        mv "${MCP_FILE}.tmp" "$MCP_FILE"
        ok "mcp-config.json merged"
    else
        cp "$SCRIPT_DIR/copilot/mcp-config.json" "$MCP_FILE"
        ok "mcp-config.json installed"
    fi

    header "Copilot CLI: Per-Repo Files"
    info "Instructions and hooks are per-repo. Install with:"
    echo ""
    echo "    # All languages"
    echo "    ./copilot/install-to-repo.sh /path/to/project"
    echo ""
    echo "    # Specific languages"
    echo "    ./copilot/install-to-repo.sh /path/to/project --languages java,python"
    echo ""

    header "Copilot CLI: Prompts"
    info "Copilot CLI doesn't support custom slash commands."
    info "Use prompts in copilot/prompts/ as copy-paste templates:"
    for f in "$SCRIPT_DIR"/copilot/prompts/*.md; do
        [ -f "$f" ] || continue
        echo "    copilot/prompts/$(basename "$f")"
    done
fi

# ============================================================================
# Tool check
# ============================================================================

header "Optional Formatters"
check_tool() {
    if command -v "$1" &>/dev/null; then
        ok "$1 installed"
    else
        warn "$1 not found — $2"
    fi
}
check_tool "ruff"                "pip install ruff"
check_tool "google-java-format"  "brew install google-java-format"
check_tool "swiftformat"         "brew install swiftformat"
check_tool "prettier"            "npm install -g prettier"
check_tool "jq"                  "apt install jq / brew install jq"
check_tool "gh"                  "brew install gh (for /ship command)"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo "  Setup Complete"
echo "========================================"
echo ""

if $DO_CLAUDE; then
    echo "  Claude Code (~/.claude/):"
    echo "    Rules:    $(ls "$CLAUDE_DIR/rules/"*.md 2>/dev/null | wc -l) files"
    echo "    Commands: $(ls "$CLAUDE_DIR/commands/"*.md 2>/dev/null | wc -l) files"
    echo "    Agents:   $(ls "$CLAUDE_DIR/agents/"*.md 2>/dev/null | wc -l) files"
    echo "    Hooks:    5 (ruff, java-format, swiftformat, prettier, safety guard)"
    echo "    Plugin:   Maister (SkillPanel/maister)"
    echo ""
fi

if $DO_COPILOT; then
    echo "  Copilot CLI (~/.copilot/):"
    echo "    Agents:   $(ls "$COPILOT_DIR/agents/"*.md 2>/dev/null | wc -l) files"
    echo "    MCP:      configured"
    echo "    Per-repo: 9 instructions + hooks (use install-to-repo.sh)"
    echo "    Prompts:  4 templates (ship, retro, changelog, threat-model)"
    echo ""
fi

BACKUP_DIR=""
[ -d "${BACKUP_CLAUDE:-}" ] && BACKUP_DIR="$BACKUP_CLAUDE"
[ -d "${BACKUP_COPILOT:-}" ] && BACKUP_DIR="${BACKUP_DIR:+$BACKUP_DIR, }$BACKUP_COPILOT"
[ -n "$BACKUP_DIR" ] && echo "  Backups: $BACKUP_DIR" && echo ""

echo "  Restart your tool for changes to take effect."
echo ""
