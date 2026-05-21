---
name: save-plan
description: >
  Save the most recent plan (from Claude Code's /plan mode or pasted/file
  content) into a new initiative folder docs/work/NNN-<slug>/plan.md, then
  optionally chain into /atomize to decompose it into atomic task files.
  Bridges Claude Code's built-in /plan mode (which only displays the plan)
  to the docs/work/ convention (where plans need to live as files to be
  consumed by /atomize). Auto-detects plan source: inline file arg → recent
  conversation context → ask user to paste.
  Trigger phrases: "save the plan", "save plan", "stash this plan",
  "create initiative folder", "atomize this plan", "the plan I just approved".
argument-hint: "[slug] [optional-source-file]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - AskUserQuestion
  - Skill
---

# /save-plan — Bridge /plan Mode → docs/work/

Claude Code's built-in `/plan` mode displays a plan but doesn't persist it. This skill bridges that gap: it takes the most recent plan (from conversation context, an inline file, or pasted input) and lands it as `docs/work/NNN-<slug>/plan.md`, ready for `/atomize` to decompose into tasks.

The skill is intentionally lightweight — it captures + writes + optionally chains. It does NOT modify the plan content, re-plan, or alter its structure. The plan content goes to disk verbatim.

## When to use, when to skip

**Use when**:
- You just exited `/plan` mode with an approved plan and want it tracked under `docs/work/`
- You have a plan written down somewhere (chat scrollback, scratch file, paste buffer) and want to formalize it as an initiative
- You want to skip the manual `mkdir docs/work/...` + `vim plan.md` dance

**Skip when**:
- The plan is already at `docs/work/<NNN>-<slug>/plan.md` — just run `/atomize <folder>` directly
- You want to plan first (use Claude Code's `/plan` mode upstream, then this skill)
- The work is too small for a tracked initiative (just edit + commit; not everything needs an initiative folder)

## Relationship to other skills

- **Claude Code's built-in `/plan` mode** — upstream. User runs `/plan`, approves, then invokes `/save-plan` to persist. This skill is the manual replacement for an `ExitPlanMode` hook (which is deferred work).
- **`/atomize`** — downstream. `/save-plan` writes `plan.md`; `/atomize` reads it and writes `T-*.md` task files. Step 6 below offers to auto-chain.
- **`/kickoff`** — prerequisite. `docs/work/` must exist. If absent, this skill delegates to `/kickoff` via the `Skill` tool.
- **`docs/reference/`** — NOT scanned by this skill. If the plan came from `/discover` or `/research`, those skills already wove reference citations into the plan content (as `> Ref: docs/reference/<file>` blockquotes); `/save-plan` preserves them verbatim, and `/atomize` reads them downstream from `plan.md` directly.

## Process

### Step 0: Verify workspace

```bash
test -d docs/work
```

If missing, ask:

AskUserQuestion:
- question: "docs/work/ is missing. Run /kickoff to scaffold the docs/ structure?"
  header: "Init?"
  options:
  - label: "Yes — run /kickoff (Recommended)"
    description: "Scaffolds docs/ + subdirs, then continues."
  - label: "Create docs/work/ only"
    description: "Quick mkdir without full /kickoff."
  - label: "Cancel"
    description: "Exit without changes."
  multiSelect: false

On "Yes": delegate to `kickoff` via the `Skill` tool. Continue when it returns.
On "Create only": `mkdir -p docs/work` and continue.
On "Cancel": STOP.

### Step 1: Resolve plan source

Plan content can come from three sources, in priority order:

1. **Inline file argument** — if the second argument is a file path that exists, read it FULLY and use its content. Example: `/save-plan observability-otel ~/scratch/plan.md`.

2. **Conversation context** — if no file arg was provided, look at the **most recent assistant message that contains a plan structure**. Heuristics: it has at least one `# ` heading, multiple `## ` sub-headings, prose paragraphs (not a tool result block). Typically this is the content shown right before the user approved `ExitPlanMode`. If found, capture verbatim as the plan source. Print:

   ```
   Found a recent plan in conversation context (heading: "<top heading>", ~N lines).
   Using it as the source. Pass --paste to override.
   ```

3. **Ask user to paste** — if neither source resolved, or if user passed `--paste` as a flag, prompt:

   ```
   No plan source detected. Paste the plan content below (end with an empty line):
   ```

   Read input until empty line. Treat that as the plan source.

If after all three the source is still empty: print "No plan content provided. STOP." and exit.

### Step 2: Derive slug

If the first argument was passed and is a valid slug (kebab-case: lowercase alphanumeric + hyphens, 3-60 chars), use it verbatim.

Otherwise, derive from the plan content:

- Extract the first `# ` heading (top-level title) from the plan source
- Take the first 5 meaningful words (skip stopwords: "the", "a", "an", "to", "for", "of", "in", "on", "with", "and", "or")
- Lowercase, replace whitespace with hyphens, strip non-alphanumeric (except hyphens), collapse repeated hyphens
- Truncate to 60 chars max

Examples:
- "# Implement OpenTelemetry observability with traces and metrics" → `implement-opentelemetry-observability-traces-metrics`
- "# Add data masking for PII" → `add-data-masking-pii`
- "# Refactor auth flow" → `refactor-auth-flow`

Print the derived slug and ask confirmation:

AskUserQuestion:
- question: "Derived slug: '<slug>'. Use as is, or override?"
  header: "Slug"
  options:
  - label: "Use as derived (Recommended)"
    description: "Continue with slug: '<derived>'"
  - label: "Override"
    description: "I'll re-prompt for a custom slug."
  - label: "Cancel"
    description: "Exit without writes."
  multiSelect: false

On "Override": ask "Enter slug (kebab-case, 3-60 chars):" and validate. Retry on invalid.

### Step 3: Compute initiative folder name

Scan `docs/work/` for the highest existing `NNN`:

```bash
ls -d docs/work/[0-9][0-9][0-9]-*/ 2>/dev/null | sed -E 's|^docs/work/([0-9]+)-.*|\1|' | sort -n | tail -1
```

- No matches → start at `001`
- Found `NNN` → next is `NNN+1` (zero-padded to 3 digits)

Compose the folder path: `docs/work/<NNN>-<slug>/`.

Print:

```
Proposed initiative folder: docs/work/004-implement-opentelemetry-observability-traces-metrics/
```

### Step 4: Collision check

```bash
test -d docs/work/<NNN>-<slug>
```

If absent: proceed to Step 5.

If exists, check for `plan.md`:

```bash
test -f docs/work/<NNN>-<slug>/plan.md
```

- **Folder exists, no plan.md** (unusual): warn, then ask whether to write `plan.md` into existing folder or pick a different slug. Default: write into existing folder.
- **Folder + plan.md exist** (collision): ask:

AskUserQuestion:
- question: "docs/work/<NNN>-<slug>/plan.md already exists. How to proceed?"
  header: "Collision"
  options:
  - label: "Pick a different slug (Recommended)"
    description: "Re-prompt for slug; compute next NNN with new slug."
  - label: "Overwrite existing plan.md"
    description: "Replace existing plan. Lost unless committed. T-*.md files in folder are preserved (run /atomize reconciliation after to align them)."
  - label: "Save as plan-v2.md sibling"
    description: "Preserves history. Existing plan.md is unchanged; new plan lands at plan-v2.md (or v3, v4...)."
  - label: "Cancel"
    description: "Exit without writes."
  multiSelect: false

Handle accordingly. Versioned save scans for `plan-v*.md` to pick next slot.

### Step 5: Write plan.md

```bash
mkdir -p docs/work/<NNN>-<slug>/
```

Write the plan source content verbatim to `docs/work/<NNN>-<slug>/plan.md`. Do NOT add frontmatter, reformat, or "improve" the content — the plan goes to disk exactly as approved.

If the plan content doesn't start with a `# ` heading, **prepend one**: derive a title from the slug (Title Case, hyphens→spaces) and add `# <Title>\n\n` at the top. This keeps `plan.md` self-contained as a readable document.

Print:

```
Plan saved to docs/work/<NNN>-<slug>/plan.md (<line-count> lines)
```

### Step 6: Offer to atomize

Ask:

AskUserQuestion:
- question: "Decompose this plan into atomic task files now?"
  header: "Atomize?"
  options:
  - label: "Yes — run /atomize (Recommended)"
    description: "Invokes /atomize on the new folder. Reads plan.md, proposes T-001 ... T-NNN, you confirm per task."
  - label: "No — leave plan as-is"
    description: "Exit here. Run /atomize docs/work/<NNN>-<slug>/ manually when ready."
  multiSelect: false

On "Yes": invoke `atomize` via the **Skill** tool, passing the folder path as argument. The /atomize skill takes over from there; do NOT duplicate its logic.

On "No": print the hand-off summary (Step 7) and STOP.

### Step 7: Hand off

If `/atomize` was invoked, it produces its own summary. This skill's Step 7 is only reached when user picked "No" in Step 6:

```
═══════════════════════════════════════════════════════════
  PLAN SAVED
═══════════════════════════════════════════════════════════

  Slug:             <slug>
  Initiative:       <NNN>-<slug>
  Plan path:        docs/work/<NNN>-<slug>/plan.md
  Lines:            <count>

  Next: run  /atomize docs/work/<NNN>-<slug>/  to decompose into tasks.
═══════════════════════════════════════════════════════════
```

STOP.

## Critical guardrails

1. **Plan content is sacred.** Whatever the user approved in `/plan` mode (or pasted, or pointed to via file path) lands on disk verbatim. The skill does not "polish", reformat, or restructure the plan. The only exception is prepending a `# <Title>` heading if the plan starts headingless — and that title is derived mechanically from the slug, not invented.

2. **Slug stability.** Once `docs/work/<NNN>-<slug>/` is created, the slug is part of the path other docs may cite. Don't change it after creation. To rename, the user must do it manually (mv + update cross-references).

3. **NNN is a counter, not a priority.** Higher number doesn't mean higher priority — it means "created later". Initiatives are sorted by status (via `index.md` inside each folder), not by `NNN`.

4. **Never overwrite without explicit user choice.** Step 4 always asks before overwriting; versioned save (`plan-v2.md`) is the recommended path.

5. **Source priority is fixed.** File arg > conversation context > paste. The "most recent plan in context" detection is best-effort — if the user's last assistant message wasn't a plan, the skill must NOT silently pick something else as the source. Fall through to paste.

6. **No re-planning.** This is a save+chain skill, not a planning skill. If the user wants to plan, they use Claude Code's `/plan` mode. If they want to re-plan, they re-run `/plan` and overwrite plan.md via Step 4's "Overwrite" path.

7. **Delegation to /atomize is opt-in.** Default-recommended (Yes), but user can decline. Some users prefer to review the plan on disk before committing to task decomposition.

8. **No reference scanning.** This skill does NOT scan `docs/reference/`. If reference citations belong in the plan, they were inserted upstream by `/discover` or `/research` (as `> Ref: docs/reference/<file>` blockquotes) and are preserved verbatim in `plan.md`. `/atomize` reads the plan and picks up those citations directly.

## Notes

- This skill exists because Claude Code's `/plan` mode is built-in and not extensible — there's no hook to trigger on `ExitPlanMode` that we'd want to install just for this. `/save-plan` is the manual bridge that captures the same UX in a slash command.
- Future work (Phase 2): if/when an `ExitPlanMode` hook proves reliable across Claude Code versions, this skill's logic could be invoked automatically by the hook — `/save-plan` would still exist as the manual fallback.
- Slug derivation is best-effort. Real-world plan headings are sometimes terrible (`"# Plan"`, `"# Implementation"`). In those cases, Step 2's confirmation prompt is the user's chance to override with something better.
- The conversation-context detection is the load-bearing convenience feature. If it doesn't find a plan reliably (e.g. because the user's chat scrolled), fall through to paste — don't hallucinate content.
