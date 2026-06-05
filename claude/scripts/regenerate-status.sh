#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# regenerate-status.sh — Rebuild docs/work/STATUS.md from current state
#
# Scans docs/work/<NNN>-<slug>/ folders, reads plan.md frontmatter (if any)
# and T-*.md task statuses, and emits a categorised overview at
# docs/work/STATUS.md.
#
# This is the *bottom-up* derived view: "where are we now" — what's in
# flight, what's backlog, what shipped, what's obsoleted. Distinct from
# docs/roadmap.md (top-down planning artifact, hand-edited) — see
# claude/skills/save-plan/references/roadmap-shape.md for the two-file
# rationale.
#
# Designed to be called from /save-plan, /atomize, /implement, /setup
# after they mutate docs/work/. Pure bash (POSIX-ish + GNU find/sort/awk
# on macOS and Linux), no Python or yq dependency.
#
# Usage:
#   bash regenerate-status.sh           # operate on $PWD
#   bash regenerate-status.sh /path     # operate on /path
# ============================================================================

ROOT="${1:-$PWD}"
WORK="$ROOT/docs/work"
STATUS_FILE="$WORK/STATUS.md"
TODAY="$(date +%Y-%m-%d)"

if [ ! -d "$WORK" ]; then
    echo "regenerate-status.sh: $WORK does not exist. Run /setup first." >&2
    exit 1
fi

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

# yaml_get FILE KEY  — extract scalar value of KEY from --- frontmatter ---
# Returns empty string if absent. Only handles single-line scalars.
yaml_get() {
    local file="$1" key="$2"
    awk -v k="$key" '
        BEGIN { in_fm=0 }
        /^---[[:space:]]*$/ {
            if (in_fm) exit
            in_fm=1; next
        }
        in_fm && $0 ~ "^"k":" {
            sub("^"k":[[:space:]]*", "", $0)
            gsub(/^[\"\x27]|[\"\x27]$/, "", $0)
            print $0
            exit
        }
    ' "$file" 2>/dev/null
}

# OS-portable stat / date wrappers (macOS BSD vs Linux GNU).
_is_darwin() { [ "$(uname)" = "Darwin" ]; }

_mtime_epoch() {
    local f="$1"
    [ -e "$f" ] || return 0
    if _is_darwin; then
        stat -f "%m" "$f" 2>/dev/null
    else
        stat -c "%Y" "$f" 2>/dev/null
    fi
}

_epoch_to_date() {
    local e="$1"
    [ -n "$e" ] || return 0
    if _is_darwin; then
        date -r "$e" +%Y-%m-%d 2>/dev/null
    else
        date -d "@$e" +%Y-%m-%d 2>/dev/null
    fi
}

# folder_updated DIR  — mtime of most recently modified file inside DIR (YYYY-MM-DD).
folder_updated() {
    local dir="$1" newest=""
    while IFS= read -r -d '' f; do
        local m
        m="$(_mtime_epoch "$f")"
        if [ -n "$m" ] && { [ -z "$newest" ] || [ "$m" -gt "$newest" ]; }; then
            newest="$m"
        fi
    done < <(find "$dir" -type f -not -name "STATUS.md" -print0 2>/dev/null)
    _epoch_to_date "$newest"
}

# file_mtime FILE  — YYYY-MM-DD of file's mtime (or empty).
file_mtime() {
    local f="$1"
    [ -f "$f" ] || return 0
    _epoch_to_date "$(_mtime_epoch "$f")"
}

# Categorise a single initiative folder. Echos: "<category>\t<id>\t<slug>\t<done>\t<total>\t<created>\t<updated>"
# Categories: active | backlog | done | obsolete
classify_folder() {
    local dir="$1"
    local name id slug plan status_field done_count total_count created updated
    name="$(basename "$dir")"
    id="${name%%-*}"
    slug="${name#*-}"
    plan="$dir/plan.md"

    created="$(file_mtime "$plan")"
    updated="$(folder_updated "$dir")"

    status_field=""
    if [ -f "$plan" ]; then
        status_field="$(yaml_get "$plan" status)"
    fi

    # Count T-*.md files by status frontmatter
    done_count=0
    total_count=0
    local in_progress_count=0
    local obsolete_count=0
    local pending_count=0
    shopt -s nullglob
    for tf in "$dir"/T-*.md; do
        total_count=$((total_count + 1))
        local s
        s="$(yaml_get "$tf" status)"
        case "$s" in
            done)        done_count=$((done_count + 1)) ;;
            in-progress|in_progress) in_progress_count=$((in_progress_count + 1)) ;;
            obsolete)    obsolete_count=$((obsolete_count + 1)) ;;
            *)           pending_count=$((pending_count + 1)) ;;
        esac
    done
    shopt -u nullglob

    # Decide category
    local category="backlog"
    if [ "$status_field" = "obsolete" ] \
        || { [ "$total_count" -gt 0 ] && [ "$obsolete_count" -eq "$total_count" ]; }; then
        category="obsolete"
    elif [ "$status_field" = "done" ] \
        || { [ "$total_count" -gt 0 ] && [ "$((done_count + obsolete_count))" -eq "$total_count" ] && [ "$done_count" -gt 0 ]; }; then
        category="done"
    elif [ "$in_progress_count" -gt 0 ] || { [ "$done_count" -gt 0 ] && [ "$pending_count" -gt 0 ]; }; then
        category="active"
    else
        category="backlog"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$category" "$id" "$slug" "$done_count" "$total_count" "${created:-—}" "${updated:-—}"
}

# ----------------------------------------------------------------------------
# Collect initiatives
# ----------------------------------------------------------------------------

ROWS=""
shopt -s nullglob
for d in "$WORK"/[0-9][0-9][0-9]-*/; do
    [ -d "$d" ] || continue
    ROWS+="$(classify_folder "${d%/}")"$'\n'
done
shopt -u nullglob

# ----------------------------------------------------------------------------
# Render section
# ----------------------------------------------------------------------------

# render_section CATEGORY HEADER COLUMNS
# CATEGORY: filter rows by first column
# HEADER:   section heading text
# COLUMNS:  "active" | "backlog" | "done" | "obsolete"  — picks the column layout
render_section() {
    local category="$1" header="$2" layout="$3"
    local filtered
    filtered="$(printf '%s' "$ROWS" | awk -F'\t' -v c="$category" '$1==c')"

    printf '## %s\n\n' "$header"

    if [ -z "$filtered" ]; then
        printf '_None._\n\n'
        return
    fi

    case "$layout" in
        active)
            printf '| ID | Initiative | Tasks (done/total) | Updated |\n'
            printf '|----|------------|---------------------|---------|\n'
            printf '%s' "$filtered" | sort -k2,2 | awk -F'\t' '{
                printf "| %s | [%s](%s-%s/) | %s/%s | %s |\n", $2, $3, $2, $3, $4, $5, $7
            }'
            ;;
        backlog)
            printf '| ID | Initiative | Tasks | Created |\n'
            printf '|----|------------|-------|---------|\n'
            printf '%s' "$filtered" | sort -k2,2 | awk -F'\t' '{
                tasks = ($5 == 0) ? "0/0 (not atomized)" : ($4"/"$5)
                printf "| %s | [%s](%s-%s/) | %s | %s |\n", $2, $3, $2, $3, tasks, $6
            }'
            ;;
        done)
            printf '| ID | Initiative | Tasks | Closed |\n'
            printf '|----|------------|-------|--------|\n'
            printf '%s' "$filtered" | sort -k2,2 | awk -F'\t' '{
                printf "| %s | [%s](%s-%s/) | %s/%s | %s |\n", $2, $3, $2, $3, $4, $5, $7
            }'
            ;;
        obsolete)
            printf '| ID | Initiative | Tasks | Closed |\n'
            printf '|----|------------|-------|--------|\n'
            printf '%s' "$filtered" | sort -k2,2 | awk -F'\t' '{
                printf "| %s | [%s](%s-%s/) | %s/%s | %s |\n", $2, $3, $2, $3, $4, $5, $7
            }'
            ;;
    esac

    printf '\n'
}

# ----------------------------------------------------------------------------
# Write STATUS.md
# ----------------------------------------------------------------------------

{
    printf '# Initiative status\n\n'
    printf '> Auto-generated from `docs/work/*/`. Last updated: %s.\n' "$TODAY"
    printf '> Maintained by `/save-plan`, `/atomize`, `/implement`. Manual edits are overwritten on the next run — to influence the table, change `plan.md` `status:` or task `T-*.md` `status:` frontmatter.\n'
    printf '> Top-down product sequencing (foundations + slices) lives at `docs/roadmap.md`, hand-edited.\n\n'

    if [ -z "$(printf '%s' "$ROWS" | tr -d '[:space:]')" ]; then
        printf '_No initiatives yet. Run `/save-plan` to add the first one._\n'
    else
        render_section active   "Active"    active
        render_section backlog  "Backlog"   backlog
        render_section done     "Done"      done
        render_section obsolete "Obsoleted" obsolete

        # Legend
        printf '%s\n\n' '---'
        printf '## How initiatives are classified\n\n'
        printf '%s\n' '- **Active** — has tasks in flight (any `T-*.md` with `status: in-progress`, or a mix of done + pending).'
        printf '%s\n' '- **Backlog** — no `T-*.md` yet (not atomized), or all tasks `pending`.'
        printf '%s\n' '- **Done** — every `T-*.md` is `done` or `obsolete`, with at least one `done`. Also when `plan.md` frontmatter has `status: done`.'
        printf '%s\n' '- **Obsoleted** — `plan.md` frontmatter has `status: obsolete`, or every `T-*.md` is `obsolete`.'
    fi
} > "$STATUS_FILE"

echo "regenerate-status.sh: wrote $STATUS_FILE"
