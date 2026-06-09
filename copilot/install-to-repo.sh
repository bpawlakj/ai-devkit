#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Install Copilot instructions and hooks into a specific repository
# Usage: ./install-to-repo.sh /path/to/your/project
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project-path> [--languages java,python,typescript,react,angular,node,swift,go,php]"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/project                          # Install all"
    echo "  $0 /path/to/project --languages java,python   # Only Java + Python + security"
    echo ""
    exit 1
fi

PROJECT_DIR="$1"
LANGUAGES=""

# Parse --languages flag
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --languages)
            if [ $# -lt 2 ] || [[ "$2" == --* ]]; then
                echo "Error: --languages requires a comma-separated list (e.g., java,python,typescript)"
                exit 1
            fi
            LANGUAGES="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: $PROJECT_DIR is not a directory"
    exit 1
fi

echo ""
echo "Installing Copilot config to: $PROJECT_DIR"
echo ""

# Create directories
mkdir -p "$PROJECT_DIR/.github/instructions"
mkdir -p "$PROJECT_DIR/.github/hooks"

# Install security (always)
cp "$SCRIPT_DIR/instructions/security.instructions.md" "$PROJECT_DIR/.github/instructions/"
ok "security.instructions.md"

# Install accessibility (always — cross-cutting, applies to all UI work)
cp "$SCRIPT_DIR/instructions/accessibility.instructions.md" "$PROJECT_DIR/.github/instructions/"
ok "accessibility.instructions.md"

# Install language-specific instructions
install_instruction() {
    local name="$1"
    local src="$SCRIPT_DIR/instructions/${name}.instructions.md"
    if [ -f "$src" ]; then
        cp "$src" "$PROJECT_DIR/.github/instructions/"
        ok "${name}.instructions.md"
    fi
}

if [ -z "$LANGUAGES" ]; then
    # Install all
    for f in "$SCRIPT_DIR"/instructions/*.instructions.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        [[ "$name" == "security.instructions.md" ]] && continue  # already installed
        [[ "$name" == "accessibility.instructions.md" ]] && continue  # already installed
        cp "$f" "$PROJECT_DIR/.github/instructions/"
        ok "$name"
    done
else
    # Install selected
    IFS=',' read -ra LANGS <<< "$LANGUAGES"
    VALID_LANGS="java spring spring-boot python typescript react angular node swift-ios go php security"
    for lang in "${LANGS[@]}"; do
        lang=$(echo "$lang" | tr -d ' ')
        # Validate against allowlist to prevent path traversal
        if ! echo "$VALID_LANGS" | grep -qw "$lang"; then
            warn "Unknown language: $lang (valid: $VALID_LANGS)"
            continue
        fi
        case "$lang" in
            java)
                install_instruction "java"
                install_instruction "spring-boot"
                ;;
            spring|spring-boot)
                install_instruction "spring-boot"
                ;;
            *)
                install_instruction "$lang"
                ;;
        esac
    done
fi

# Install hooks
cp "$SCRIPT_DIR/hooks/hooks.json" "$PROJECT_DIR/.github/hooks/"
ok "hooks.json"

echo ""
info "Done. Add to .gitignore if you don't want to commit:"
echo "  .github/instructions/"
echo "  .github/hooks/"
echo ""
info "Or commit them to share with team."
echo ""
