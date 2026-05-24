#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Init Project Permissions
#
# Writes a per-project Claude Code permission policy to <target>/.claude/settings.json
# based on the M1L3 lesson of 10xDevs 3.0:
#   - allow routine local operations (package managers, runtimes, local git, file primitives)
#   - ask before network egress, git push, docker, ssh, cloud CLIs, database CLIs
#   - deny recursive force-delete unconditionally
#
# Usage:
#   bash init-project-permissions.sh                   # cwd, full policy, interactive on conflicts
#   bash init-project-permissions.sh /path/to/project  # explicit target
#   bash init-project-permissions.sh --minimal         # base only (no docker/ssh/cloud/db in ask)
#   bash init-project-permissions.sh --force           # overwrite without prompting
#   bash init-project-permissions.sh --dry-run         # print, do not write
#   bash init-project-permissions.sh --yes             # answer yes to all prompts
#   bash init-project-permissions.sh --help            # this message
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}▸${NC} $1"; }
ok()      { echo -e "${GREEN}✔${NC} $1"; }
warn()    { echo -e "${YELLOW}△${NC} $1"; }
err()     { echo -e "${RED}✖${NC} $1" >&2; }
header()  { echo -e "\n${BOLD}$1${NC}"; }

# ----------------------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------------------
TARGET="$PWD"
MINIMAL=false
FORCE=false
DRY_RUN=false
ASSUME_YES=false

print_help() {
    sed -n '4,21p' "$0" | sed 's/^# \{0,1\}//'
}

# ----------------------------------------------------------------------------
# Parse args
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal)   MINIMAL=true; shift ;;
        --force)     FORCE=true; shift ;;
        --dry-run)   DRY_RUN=true; shift ;;
        --yes|-y)    ASSUME_YES=true; shift ;;
        -h|--help)   print_help; exit 0 ;;
        --target)    TARGET="$2"; shift 2 ;;
        --*)         err "Unknown flag: $1"; exit 1 ;;
        *)
            if [[ -d "$1" ]]; then
                TARGET="$1"
            else
                err "Target dir does not exist: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

TARGET="$(cd "$TARGET" && pwd)"  # canonical absolute path

# ----------------------------------------------------------------------------
# Project root sanity check
# ----------------------------------------------------------------------------
looks_like_project() {
    local dir="$1"
    [[ -d "$dir/.git" ]] && return 0
    for marker in package.json pyproject.toml go.mod pom.xml build.gradle build.gradle.kts Cargo.toml composer.json Package.swift mix.exs Gemfile; do
        [[ -f "$dir/$marker" ]] && return 0
    done
    # any *.csproj or *.sln
    compgen -G "$dir/*.csproj" >/dev/null 2>&1 && return 0
    compgen -G "$dir/*.sln" >/dev/null 2>&1 && return 0
    return 1
}

confirm() {
    local prompt="$1" default="${2:-N}"
    if $ASSUME_YES; then return 0; fi
    local hint
    if [[ "$default" == "Y" ]]; then hint="(Y/n)"; else hint="(y/N)"; fi
    read -r -p "$prompt $hint " ans
    if [[ -z "$ans" ]]; then ans="$default"; fi
    [[ "$ans" =~ ^[Yy]$ ]]
}

header "Init Project Permissions"
info "Target: $TARGET"

if ! looks_like_project "$TARGET"; then
    warn "$TARGET does not look like a project root (no .git, no package.json / pyproject.toml / go.mod / etc.)"
    if ! confirm "Continue anyway?"; then
        info "Aborted."
        exit 0
    fi
fi

SETTINGS_DIR="$TARGET/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

# ----------------------------------------------------------------------------
# Build the policy
# ----------------------------------------------------------------------------
# allow: routine local ops (polyglot)
ALLOW=(
    "Bash(pnpm *)"
    "Bash(npm *)"
    "Bash(npx *)"
    "Bash(yarn *)"
    "Bash(node *)"
    "Bash(python *)"
    "Bash(python3 *)"
    "Bash(pip *)"
    "Bash(pip3 *)"
    "Bash(uv *)"
    "Bash(poetry *)"
    "Bash(pipx *)"
    "Bash(go *)"
    "Bash(mvn *)"
    "Bash(./gradlew *)"
    "Bash(gradle *)"
    "Bash(cargo *)"
    "Bash(rustc *)"
    "Bash(composer *)"
    "Bash(php *)"
    "Bash(./vendor/bin/* *)"
    "Bash(swift *)"
    "Bash(mix *)"
    "Bash(iex *)"
    "Bash(bundle *)"
    "Bash(rake *)"
    "Bash(rails *)"
    "Bash(dotnet *)"
    "Bash(git add *)"
    "Bash(git commit *)"
    "Bash(git diff *)"
    "Bash(git log *)"
    "Bash(git status *)"
    "Bash(git branch *)"
    "Bash(git checkout *)"
    "Bash(git stash *)"
    "Read"
    "Edit"
    "Write"
)

# base ask: network egress and remote-state-changing operations
ASK=(
    "Bash(curl *)"
    "Bash(wget *)"
    "Bash(git push *)"
    "Bash(git push)"
)

# extras unless --minimal
if ! $MINIMAL; then
    ASK+=(
        "Bash(docker *)"
        "Bash(docker compose *)"
        "Bash(docker-compose *)"
        "Bash(ssh *)"
        "Bash(scp *)"
        "Bash(rsync *)"
        "Bash(aws *)"
        "Bash(gcloud *)"
        "Bash(az *)"
        "Bash(kubectl *)"
        "Bash(helm *)"
        "Bash(terraform *)"
        "Bash(psql *)"
        "Bash(mysql *)"
        "Bash(redis-cli *)"
        "Bash(mongosh *)"
    )
fi

# deny: hard rules
DENY=(
    "Bash(rm -rf *)"
)

# ----------------------------------------------------------------------------
# Emit JSON
# ----------------------------------------------------------------------------
emit_array() {
    # Pass array elements as args; emits JSON-array lines with proper commas.
    local n=$# i=1
    for elem in "$@"; do
        local sep=,
        [[ $i -eq $n ]] && sep=""
        printf '      "%s"%s\n' "$elem" "$sep"
        i=$((i + 1))
    done
}

build_json() {
    cat <<'HEAD'
{
  "permissions": {
    "allow": [
HEAD
    emit_array "${ALLOW[@]}"
    cat <<'MID1'
    ],
    "ask": [
MID1
    emit_array "${ASK[@]}"
    cat <<'MID2'
    ],
    "deny": [
MID2
    emit_array "${DENY[@]}"
    cat <<'TAIL'
    ]
  }
}
TAIL
}

# ----------------------------------------------------------------------------
# Dry run
# ----------------------------------------------------------------------------
if $DRY_RUN; then
    header "Dry run (no files written)"
    info "Would write: $SETTINGS_FILE"
    echo "---"
    build_json
    echo "---"
    if [[ -f "$TARGET/.gitignore" ]] && ! grep -q '\.claude/settings\.local\.json' "$TARGET/.gitignore"; then
        info "Would suggest appending '.claude/settings.local.json' to .gitignore"
    fi
    exit 0
fi

# ----------------------------------------------------------------------------
# Existing file handling
# ----------------------------------------------------------------------------
mkdir -p "$SETTINGS_DIR"

if [[ -f "$SETTINGS_FILE" ]]; then
    if ! $FORCE && ! $ASSUME_YES; then
        warn "$SETTINGS_FILE already exists."
        if ! confirm "Backup and overwrite?"; then
            info "Aborted. Existing file untouched."
            exit 0
        fi
    fi
    BACKUP="$SETTINGS_FILE.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$SETTINGS_FILE" "$BACKUP"
    ok "Backed up to $BACKUP"
fi

# ----------------------------------------------------------------------------
# Write
# ----------------------------------------------------------------------------
build_json > "$SETTINGS_FILE"
ok "Wrote $SETTINGS_FILE (${#ALLOW[@]} allow, ${#ASK[@]} ask, ${#DENY[@]} deny)"

# ----------------------------------------------------------------------------
# Gitignore suggestion
# ----------------------------------------------------------------------------
GITIGNORE="$TARGET/.gitignore"
LOCAL_PATTERN=".claude/settings.local.json"

if [[ -f "$GITIGNORE" ]]; then
    if grep -q "$LOCAL_PATTERN" "$GITIGNORE"; then
        ok ".gitignore already excludes .claude/settings.local.json"
    else
        if confirm "Add '.claude/settings.local.json' to .gitignore?" "Y"; then
            printf '\n# Claude (per-machine override)\n%s\n' "$LOCAL_PATTERN" >> "$GITIGNORE"
            ok "Appended to .gitignore"
        else
            warn "Skipped. Remember: settings.json is team policy; settings.local.json is per-machine."
        fi
    fi
else
    info "No .gitignore at $TARGET — when you create one, remember to exclude .claude/settings.local.json"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
header "Done"
cat <<SUMMARY
  Order of evaluation: deny -> ask -> allow (first match wins).
  Restart Claude Code in this directory for the policy to take effect.

  Tune later by editing $SETTINGS_FILE:
    - Add patterns to "allow" if you keep approving the same Bash repeatedly.
    - Move patterns to "deny" when you see something you never want.
    - Keep "ask" as the safety net for anything new.

  Reference: M1L3 of 10xDevs 3.0 ("AI-Powered Bootstrap").
SUMMARY
