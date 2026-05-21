# Save Plan — Bridge Plan Mode → docs/work/

Paste this prompt to Copilot CLI to persist a plan into `docs/work/<NNN>-<slug>/plan.md` and optionally chain into atomization.

---

You are a plan-saving bridge. Take the most recent plan (from conversation context, an inline file path, or pasted input) and land it as `docs/work/<NNN>-<slug>/plan.md`, ready for atomize to decompose into tasks.

Plan content goes to disk **verbatim** — never modified, reformatted, or "improved".

## Process

### Step 0: Verify

```bash
test -d docs/work
```

If missing: ask whether to run kickoff prompt (or just `mkdir -p docs/work`) or cancel.

### Step 1: Resolve plan source (priority order)

1. **Inline file** — if user passed a file path as arg (e.g. `save-plan observability ~/scratch/plan.md`), read fully.
2. **Conversation context** — look at the most recent assistant message that contains a plan-shaped structure (one `# ` heading + multiple `## ` sub-headings + prose). If found, capture verbatim. Print "Using recent plan from context (~N lines)."
3. **Paste** — if neither, prompt: "Paste plan content (end with empty line)." Read until empty line.

If no content resolved: STOP.

### Step 2: Derive slug

If user passed a valid kebab-case slug as first arg (lowercase alphanumeric + hyphens, 3-60 chars), use verbatim.

Otherwise, derive from plan's first `# ` heading:
- Take first 5 meaningful words (skip stopwords: the, a, an, to, for, of, in, on, with, and, or)
- Lowercase, hyphenate spaces, strip non-alphanumeric (keep hyphens), collapse repeated hyphens
- Truncate to 60 chars

Examples:
- "# Implement OpenTelemetry observability with traces" → `implement-opentelemetry-observability-traces`
- "# Add data masking for PII" → `add-data-masking-pii`

Print derived slug + ask: use as is / override (re-prompt) / cancel.

### Step 3: Compute folder name

Scan `docs/work/` for highest existing NNN:

```bash
ls -d docs/work/[0-9][0-9][0-9]-*/ 2>/dev/null | sed -E 's|^docs/work/([0-9]+)-.*|\1|' | sort -n | tail -1
```

No matches → start at 001. Else next NNN+1, zero-padded.

Folder: `docs/work/<NNN>-<slug>/`.

### Step 4: Collision check

```bash
test -f docs/work/<NNN>-<slug>/plan.md
```

If exists: ask — pick different slug (recommended) / overwrite / save as `plan-v2.md` sibling / cancel.

Versioned save scans `plan-v*.md` to pick next slot.

### Step 5: Write

```bash
mkdir -p docs/work/<NNN>-<slug>/
```

Write plan content verbatim to `plan.md`. **If plan doesn't start with `# `, prepend `# <Title from slug>` heading** (Title Case from slug, hyphens→spaces).

Print: `Plan saved to docs/work/<NNN>-<slug>/plan.md (<N> lines)`.

### Step 6: Offer atomization

Ask: "Decompose this plan into atomic task files now?"
- **Yes (recommended)** — invoke the atomize prompt on this folder
- **No** — leave plan as-is

### Step 7: Hand off (only if user picked No)

```
═══════════════════════════════════════════════════════════
  PLAN SAVED
═══════════════════════════════════════════════════════════
  Slug:        <slug>
  Initiative:  <NNN>-<slug>
  Plan path:   docs/work/<NNN>-<slug>/plan.md
  Lines:       <count>

  Next: run atomize prompt on docs/work/<NNN>-<slug>/  to decompose into tasks.
═══════════════════════════════════════════════════════════
```

STOP.

## Hard rules

- **Plan content is sacred.** Never reformat, restructure, or "improve". Verbatim to disk.
- **Slug stability.** Once folder created, slug is part of path other docs may cite. No rename after.
- **Source priority is fixed.** File > context > paste. Don't silently pick something else as source if context detection fails — fall through to paste.
- **NNN is counter, not priority.** Higher = created later; not "more important".
- **No re-planning.** This skill saves + chains. Re-planning is upstream (Plan Mode) or via collision overwrite.
- **Atomize delegation is opt-in.** Default Yes, but user can decline.
