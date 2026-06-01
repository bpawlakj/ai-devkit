#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code & Copilot CLI — Unified Setup
#
# Single entry point for both first-time install and upgrades. If a newer
# version is available on origin/main, setup pulls it in (after offering to
# stash local modifications) and then re-runs the install. Use --check to
# inspect the update status without installing, or --no-pull to skip the
# remote check entirely and install from the working copy as-is.
#
# Usage: ./setup.sh                       # Install both (default)
#        ./setup.sh --claude              # Claude Code only
#        ./setup.sh --copilot             # Copilot CLI only
#        ./setup.sh --all                 # Both (same as no flag)
#        ./setup.sh --check               # Show update status, do not install
#        ./setup.sh --no-pull             # Skip the upstream fetch/pull step
#        ./setup.sh --permissions [DIR]   # Per-project permission policy in DIR (default cwd)
#                                         # Extra flags forwarded: --minimal --force --dry-run --yes
#        ./setup.sh --bitbucket-creds     # Configure /bitbucket-review credentials (prompts; writes ~/.claude/bitbucket-review.env)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
COPILOT_DIR="${COPILOT_HOME:-${XDG_CONFIG_HOME:-$HOME/.copilot}}"
BACKUP_SUFFIX="setup-$(date +%Y%m%d-%H%M%S)"
VERSION_FILE="$SCRIPT_DIR/VERSION"
LOCAL_VERSION="$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]' || echo "unknown")"

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
err()   { echo -e "${RED}[ERR]${NC} $1"; }
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
CHECK_ONLY=false
NO_PULL=false

# ----------------------------------------------------------------------------
# --permissions mode: forward to init-project-permissions.sh and exit.
# Handled before the main flag switch because it shortcircuits the install.
# ----------------------------------------------------------------------------
if [ "${1:-}" = "--permissions" ]; then
    shift
    PERMS_SCRIPT="$SCRIPT_DIR/claude/scripts/init-project-permissions.sh"
    if [ ! -x "$PERMS_SCRIPT" ]; then
        chmod +x "$PERMS_SCRIPT" 2>/dev/null || true
    fi
    if [ ! -f "$PERMS_SCRIPT" ]; then
        echo "Missing: $PERMS_SCRIPT" >&2
        exit 1
    fi
    exec bash "$PERMS_SCRIPT" "$@"
fi

# ----------------------------------------------------------------------------
# --bitbucket-creds mode: write ~/.claude/bitbucket-review.env and exit.
# Used by the /bitbucket-review skill. The token is entered at runtime and
# stored ONLY in this local file (chmod 600) — NEVER committed to the repo.
# Handled before the main flag switch because it shortcircuits the install.
# ----------------------------------------------------------------------------
if [ "${1:-}" = "--bitbucket-creds" ]; then
    CREDS_FILE="$CLAUDE_DIR/bitbucket-review.env"
    mkdir -p "$CLAUDE_DIR"
    header "Configure /bitbucket-review credentials"
    echo "  Token: Atlassian account > Settings > Security > API tokens"
    echo "         (scopes: read repository + read & write pull request)."
    echo "  App Passwords are deprecated (disabled 2026-06-09) — use an API token."
    echo ""
    DEFAULT_EMAIL=""
    if [ -f "$CREDS_FILE" ]; then
        DEFAULT_EMAIL="$(sed -n 's/^export BITBUCKET_EMAIL="\(.*\)"$/\1/p' "$CREDS_FILE" 2>/dev/null | head -1)"
    fi
    if [ -n "$DEFAULT_EMAIL" ]; then
        read -r -p "  Atlassian account email [$DEFAULT_EMAIL]: " BB_EMAIL
        BB_EMAIL="${BB_EMAIL:-$DEFAULT_EMAIL}"
    else
        read -r -p "  Atlassian account email: " BB_EMAIL
    fi
    read -r -s -p "  API token (input hidden): " BB_TOKEN
    echo ""
    if [ -z "${BB_EMAIL:-}" ] || [ -z "${BB_TOKEN:-}" ]; then
        err "Both email and token are required. Aborted."
        exit 1
    fi
    [ -f "$CREDS_FILE" ] && cp "$CREDS_FILE" "$CREDS_FILE.bak-$(date +%Y%m%d-%H%M%S)"
    ( umask 077; cat > "$CREDS_FILE" <<EOF
# /bitbucket-review credentials — sourced by the skill. DO NOT commit.
# Regenerate any time with: ./setup.sh --bitbucket-creds
export BITBUCKET_EMAIL="$BB_EMAIL"
export BITBUCKET_API_TOKEN="$BB_TOKEN"
EOF
    )
    chmod 600 "$CREDS_FILE"
    ok "Wrote $CREDS_FILE (chmod 600)"
    echo "  The /bitbucket-review skill loads it automatically (no shell-profile edit needed)."
    exit 0
fi

SCOPE_PICKED=false
for arg in "$@"; do
    case "$arg" in
        --claude)   DO_CLAUDE=true;  SCOPE_PICKED=true ;;
        --copilot)  DO_COPILOT=true; SCOPE_PICKED=true ;;
        --all)      DO_CLAUDE=true; DO_COPILOT=true; SCOPE_PICKED=true ;;
        --check)    CHECK_ONLY=true ;;
        --no-pull)  NO_PULL=true ;;
        -h|--help)
            echo "Usage: $0 [--claude | --copilot | --all] [--check | --no-pull] [--permissions [DIR]] [--bitbucket-creds]"
            echo ""
            echo "  --claude          Install Claude Code config only"
            echo "  --copilot         Install Copilot CLI config only"
            echo "  --all             Install both (default)"
            echo "  --check           Show update status (version / changelog diff) and exit"
            echo "  --no-pull         Skip the upstream fetch/pull step; install from working copy as-is"
            echo "  --permissions     Write per-project .claude/settings.json in DIR (default cwd)"
            echo "                    Forwards extra flags: --minimal --force --dry-run --yes"
            echo "  --bitbucket-creds Configure /bitbucket-review credentials (prompts; writes ~/.claude/bitbucket-review.env)"
            exit 0 ;;
        *) echo "Unknown flag: $arg. Use --help for usage."; exit 1 ;;
    esac
done

# Default scope when none picked: install both.
if ! $SCOPE_PICKED; then
    DO_CLAUDE=true
    DO_COPILOT=true
fi

echo ""
echo "========================================"
echo "  AI Coding Tools Setup  v${LOCAL_VERSION}"
echo "========================================"
echo ""

# ============================================================================
# Update check + optional pull
#
# When run inside a git repo (the normal install path), setup acts as both
# installer and updater: fetch origin, compare HEADs, optionally pull, then
# fall through to the install steps. --check exits after reporting status;
# --no-pull skips the network step and installs from the working copy.
# ============================================================================

IS_GIT_REPO=false
if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    IS_GIT_REPO=true
fi

if $CHECK_ONLY && ! $IS_GIT_REPO; then
    warn "Not a git repo — --check has nothing to compare against."
    exit 0
fi

if $IS_GIT_REPO && ! $NO_PULL; then
    BRANCH="$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD)"
    REMOTE="origin"

    if git -C "$SCRIPT_DIR" fetch "$REMOTE" "$BRANCH" --quiet 2>/dev/null; then
        LOCAL_HEAD="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
        REMOTE_HEAD="$(git -C "$SCRIPT_DIR" rev-parse "$REMOTE/$BRANCH" 2>/dev/null || echo "$LOCAL_HEAD")"
        REMOTE_VERSION="$(git -C "$SCRIPT_DIR" show "$REMOTE/$BRANCH:VERSION" 2>/dev/null | tr -d '[:space:]' || echo "")"

        if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
            if $CHECK_ONLY; then
                ok "Already up to date (v${LOCAL_VERSION})"
                echo ""
                exit 0
            fi
        else
            echo -e "  ${BOLD}${GREEN}Update available: ${LOCAL_VERSION} → ${REMOTE_VERSION:-unknown}${NC}"
            echo ""

            # Changelog diff (only the new lines added)
            if git -C "$SCRIPT_DIR" show "$REMOTE/$BRANCH:CHANGELOG.md" &>/dev/null; then
                echo -e "${BOLD}What's new:${NC}"
                echo "  ----------------------------------------"
                if git -C "$SCRIPT_DIR" show HEAD:CHANGELOG.md &>/dev/null; then
                    diff <(git -C "$SCRIPT_DIR" show HEAD:CHANGELOG.md) \
                         <(git -C "$SCRIPT_DIR" show "$REMOTE/$BRANCH:CHANGELOG.md") \
                        | grep '^> ' | sed 's/^> /  /' || true
                else
                    git -C "$SCRIPT_DIR" show "$REMOTE/$BRANCH:CHANGELOG.md" | head -40 | sed 's/^/  /'
                fi
                echo "  ----------------------------------------"
                echo ""
            fi

            if $CHECK_ONLY; then
                info "Run ./setup.sh to apply the update."
                echo ""
                exit 0
            fi

            # Stash local mods if any, then fast-forward.
            if ! git -C "$SCRIPT_DIR" diff --quiet 2>/dev/null \
                    || ! git -C "$SCRIPT_DIR" diff --cached --quiet 2>/dev/null; then
                warn "Local modifications detected:"
                git -C "$SCRIPT_DIR" diff --name-only        2>/dev/null | sed 's/^/    /'
                git -C "$SCRIPT_DIR" diff --cached --name-only 2>/dev/null | sed 's/^/    /'
                echo ""
                read -p "  Stash changes and pull? (y/N) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    git -C "$SCRIPT_DIR" stash push -m "ai-devkit-setup-$(date +%Y%m%d-%H%M%S)" >/dev/null
                    ok "Local changes stashed (restore with: git stash pop)"
                else
                    info "Skipping pull. Installing from current working copy."
                    NO_PULL=true
                fi
            fi

            if ! $NO_PULL; then
                info "Pulling ${REMOTE}/${BRANCH}..."
                if git -C "$SCRIPT_DIR" pull --ff-only "$REMOTE" "$BRANCH" --quiet; then
                    # Re-read VERSION after pull
                    LOCAL_VERSION="$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]' || echo "unknown")"
                    ok "Updated to v${LOCAL_VERSION}"
                    echo ""
                else
                    err "Fast-forward pull failed. Local branch has diverged from ${REMOTE}/${BRANCH}."
                    err "Resolve manually: git pull --rebase ${REMOTE} ${BRANCH}"
                    exit 1
                fi
            fi
        fi
    else
        warn "Cannot reach ${REMOTE} — skipping update check, installing from working copy."
        echo ""
    fi
elif $CHECK_ONLY; then
    info "Skipping check (--no-pull). Current version: v${LOCAL_VERSION}"
    exit 0
fi

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

    header "Claude Code: Skills"
    mkdir -p "$CLAUDE_DIR/skills"
    for d in "$SCRIPT_DIR"/claude/skills/*/; do
        [ -d "$d" ] || continue
        skill_name="$(basename "$d")"
        rm -rf "$CLAUDE_DIR/skills/$skill_name"
        cp -R "$d" "$CLAUDE_DIR/skills/$skill_name"
        ok "/$skill_name"
    done

    header "Claude Code: Settings (hooks, plugins, MCP)"
    backup_if_exists "$CLAUDE_DIR/settings.json" "$BACKUP_CLAUDE"

    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        if command -v jq &>/dev/null; then
            # Merge strategy: hooks always from template (arrays don't merge well),
            # everything else deep-merged with template winning conflicts
            jq -s '
              .[0] as $existing | .[1] as $template |
              ($existing | del(.hooks)) * ($template | del(.hooks))
              | .hooks = $template.hooks
            ' "$CLAUDE_DIR/settings.json" "$SCRIPT_DIR/claude/settings.template.json" \
                > "$CLAUDE_DIR/settings.json.tmp"
            mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
            ok "settings.json merged (hooks from template, existing user keys preserved)"
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

    header "Claude Code: Scripts (cloud wrappers)"
    mkdir -p "$CLAUDE_DIR/scripts"
    for f in "$SCRIPT_DIR"/claude/scripts/*.sh; do
        [ -f "$f" ] || continue
        cp "$f" "$CLAUDE_DIR/scripts/"
        chmod +x "$CLAUDE_DIR/scripts/$(basename "$f")"
        ok "$(basename "$f")"
    done
    if [ ! -f "$CLAUDE_DIR/cloud-config.json" ]; then
        info "  Run /cloud-setup in Claude Code to configure AWS/K8s access"
    else
        ok "cloud-config.json already exists"
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
check_tool "gofmt"               "install Go (go.dev/dl)"
check_tool "goimports"           "go install golang.org/x/tools/cmd/goimports@latest"
check_tool "php-cs-fixer"        "composer global require friendsofphp/php-cs-fixer"
check_tool "jq"                  "apt install jq / brew install jq"
check_tool "gh"                  "brew install gh (for /ship command)"
check_tool "aws"                 "brew install awscli (for /aws command)"
check_tool "kubectl"             "brew install kubectl (for /k8s command)"
check_tool "helm"                "brew install helm (for /k8s helm commands)"

# Playwright — the default runner for /scenario + /e2e-run. It is a PER-PROJECT
# dev dependency (and `npx playwright install` pulls ~hundreds of MB of browsers),
# so this is a check-and-hint only — never an auto-install. The --no-install flag
# stops npx from downloading anything just to probe the version.
PW_HINT="for /scenario + /e2e-run, in your project: npm i -D @playwright/test && npx playwright install"
if ! command -v npx &>/dev/null; then
    warn "playwright not checkable — Node.js/npx not found (install Node, then $PW_HINT)"
elif npx --no-install playwright --version &>/dev/null; then
    ok "playwright ($(npx --no-install playwright --version 2>/dev/null | head -1))"
else
    warn "playwright not found — $PW_HINT"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo "  Setup Complete  v${LOCAL_VERSION}"
echo "========================================"
echo ""

if $DO_CLAUDE; then
    echo "  Claude Code (~/.claude/):"
    echo "    Rules:    $(ls "$CLAUDE_DIR/rules/"*.md 2>/dev/null | wc -l) files"
    echo "    Commands: $(ls "$CLAUDE_DIR/commands/"*.md 2>/dev/null | wc -l) files"
    echo "    Agents:   $(ls "$CLAUDE_DIR/agents/"*.md 2>/dev/null | wc -l) files"
    echo "    Skills:   $(find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ') (setup, discover, product-spec, research, save-plan, atomize, implement, agents-md, rule-review, open-web, scenario, e2e-run, bitbucket-review, ci-setup, repo-map, eval)"
    echo "    Scripts:  $(ls "$CLAUDE_DIR/scripts/"*.sh 2>/dev/null | wc -l) files (cloud wrappers)"
    echo "    Hooks:    7 (ruff, java-format, swiftformat, prettier, goimports, php-cs-fixer, safety guard)"
    echo "    Plugin:   Maister (SkillPanel/maister)"
    echo ""
fi

if $DO_COPILOT; then
    echo "  Copilot CLI (~/.copilot/):"
    echo "    Agents:   $(ls "$COPILOT_DIR/agents/"*.md 2>/dev/null | wc -l) files"
    echo "    MCP:      configured"
    echo "    Per-repo: 11 instructions + hooks (use install-to-repo.sh)"
    echo "    Prompts:  18 templates (ship, retro, changelog, threat-model, init-permissions [shell-script docs], setup, discover, product-spec, research, save-plan, atomize, implement, agents-md, rule-review, bitbucket-review, scenario, e2e-run, eval)"
    echo ""
fi

BACKUP_DIR=""
[ -d "${BACKUP_CLAUDE:-}" ] && BACKUP_DIR="$BACKUP_CLAUDE"
[ -d "${BACKUP_COPILOT:-}" ] && BACKUP_DIR="${BACKUP_DIR:+$BACKUP_DIR, }$BACKUP_COPILOT"
[ -n "$BACKUP_DIR" ] && echo "  Backups: $BACKUP_DIR" && echo ""

echo "  Restart your tool for changes to take effect."
echo ""
