#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# AI DevKit — Release (Maintainer only)
# Bumps version, generates changelog, tags, pushes, creates GitHub Release.
#
# Usage: ./release.sh patch    # 1.0.0 → 1.0.1  (bug fixes, minor tweaks)
#        ./release.sh minor    # 1.0.0 → 1.1.0  (new rules, agents, commands)
#        ./release.sh major    # 1.0.0 → 2.0.0  (breaking changes)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/VERSION"
CHANGELOG_FILE="$SCRIPT_DIR/CHANGELOG.md"

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
# Validate
# ============================================================================

BUMP_TYPE="${1:-}"
if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo "Usage: $0 <patch|minor|major>"
    echo ""
    echo "  patch  Bug fixes, doc updates         (1.0.0 → 1.0.1)"
    echo "  minor  New rules, agents, commands     (1.0.0 → 1.1.0)"
    echo "  major  Breaking changes to setup/API   (1.0.0 → 2.0.0)"
    exit 1
fi

cd "$SCRIPT_DIR"

# Pre-flight checks
if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is not clean. Commit or stash changes first."
    exit 1
fi

if ! command -v gh &>/dev/null; then
    err "GitHub CLI (gh) is required. Install: brew install gh"
    exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ]; then
    warn "You're on branch '$BRANCH', not 'main'."
    read -p "  Continue anyway? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 0
fi

# ============================================================================
# Bump version
# ============================================================================

CURRENT_VERSION="$(cat "$VERSION_FILE" | tr -d '[:space:]')"
IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
    major) V_MAJOR=$((V_MAJOR + 1)); V_MINOR=0; V_PATCH=0 ;;
    minor) V_MINOR=$((V_MINOR + 1)); V_PATCH=0 ;;
    patch) V_PATCH=$((V_PATCH + 1)) ;;
esac

NEW_VERSION="${V_MAJOR}.${V_MINOR}.${V_PATCH}"

echo ""
echo -e "${BOLD}AI DevKit — Release${NC}"
echo -e "  ${DIM}${CURRENT_VERSION}${NC} → ${BOLD}${GREEN}${NEW_VERSION}${NC} (${BUMP_TYPE})"
echo ""

# ============================================================================
# Generate changelog entry from commits since last tag
# ============================================================================

LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo "")"
if [ -n "$LAST_TAG" ]; then
    COMMIT_RANGE="${LAST_TAG}..HEAD"
else
    COMMIT_RANGE="HEAD"
fi

RELEASE_DATE="$(date +%Y-%m-%d)"

# Collect commits by type
FEATURES=""
FIXES=""
IMPROVEMENTS=""
BREAKING=""
OTHER=""

while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
        feat:*|feat\(*) FEATURES="${FEATURES}\n- ${line#*: }" ;;
        fix:*|fix\(*)   FIXES="${FIXES}\n- ${line#*: }" ;;
        perf:*|refactor:*|perf\(*|refactor\(*) IMPROVEMENTS="${IMPROVEMENTS}\n- ${line#*: }" ;;
        *BREAKING*|*breaking*) BREAKING="${BREAKING}\n- ${line}" ;;
        *)               OTHER="${OTHER}\n- ${line}" ;;
    esac
done < <(git log "$COMMIT_RANGE" --pretty=format:"%s" 2>/dev/null || true)

# Build changelog section
CHANGELOG_ENTRY="## [${NEW_VERSION}] - ${RELEASE_DATE}"

[ -n "$BREAKING" ]     && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Breaking Changes\n${BREAKING}"
[ -n "$FEATURES" ]     && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Added\n${FEATURES}"
[ -n "$FIXES" ]        && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Fixed\n${FIXES}"
[ -n "$IMPROVEMENTS" ] && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Improved\n${IMPROVEMENTS}"
[ -n "$OTHER" ]        && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Other\n${OTHER}"

# Show preview
echo -e "${BOLD}Changelog entry:${NC}"
echo -e "${DIM}────────────────────────────────────────${NC}"
echo -e "$CHANGELOG_ENTRY" | sed 's/^/  /'
echo -e "${DIM}────────────────────────────────────────${NC}"
echo ""

read -p "Proceed with release v${NEW_VERSION}? (y/N) " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { info "Release cancelled."; exit 0; }

# ============================================================================
# Write VERSION
# ============================================================================

echo "$NEW_VERSION" > "$VERSION_FILE"
ok "VERSION → ${NEW_VERSION}"

# ============================================================================
# Update CHANGELOG.md
# ============================================================================

if [ -f "$CHANGELOG_FILE" ]; then
    # Insert new entry after the header block (first ## or after front matter)
    TMPFILE="$(mktemp)"
    awk -v entry="$(echo -e "$CHANGELOG_ENTRY")" '
        /^## \[/ && !inserted {
            print entry
            print ""
            inserted=1
        }
        { print }
    ' "$CHANGELOG_FILE" > "$TMPFILE"
    mv "$TMPFILE" "$CHANGELOG_FILE"
else
    echo -e "# Changelog\n\n${CHANGELOG_ENTRY}" > "$CHANGELOG_FILE"
fi
ok "CHANGELOG.md updated"

# ============================================================================
# Commit, tag, push
# ============================================================================

git add VERSION CHANGELOG.md
git commit -m "release: v${NEW_VERSION}"
ok "Committed release"

git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
ok "Tagged v${NEW_VERSION}"

info "Pushing to remote..."
git push origin "$BRANCH" --follow-tags
ok "Pushed"

# ============================================================================
# Create GitHub Release
# ============================================================================

info "Creating GitHub Release..."

# Extract just this version's changelog for the release body
RELEASE_BODY="$(echo -e "$CHANGELOG_ENTRY" | tail -n +2)"

gh release create "v${NEW_VERSION}" \
    --title "v${NEW_VERSION}" \
    --notes "$RELEASE_BODY" \
    --latest

ok "GitHub Release created"

echo ""
echo -e "${BOLD}${GREEN}Released v${NEW_VERSION}${NC}"
echo ""
echo "  Users can update with: ./update.sh"
echo ""
