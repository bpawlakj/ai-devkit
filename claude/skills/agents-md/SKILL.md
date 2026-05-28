---
name: agents-md
description: >
  Author AGENTS.md as the canonical single source of truth for project-specific
  agent rules, with a thin CLAUDE.md import shim and an optional
  .github/copilot-instructions.md shim — so Claude Code, Codex, Cursor, and
  Copilot all read the same file without duplication. Anchors every proposed
  rule in a real source (a docs/architecture/ decision, a docs/reference/
  lessons.md entry, an incident, or a product-spec constraint) and refuses to
  add generic best-practice content already covered by ai-devkit's auto-active
  rules in ~/.claude/rules/. Enforces the "test of inclusion" up front and
  respects the ~200-line size budget plus U-shaped attention layout (critical
  rules at the top, references at the bottom). For area-specific rules,
  proposes a granular file (e.g. src/api/AGENTS.md) instead of polluting root.
  Trigger phrases: "set up AGENTS.md", "init agents file", "onboard the agent
  to this project", "create CLAUDE.md", "agent rules for this repo".
argument-hint: "[scope-path — defaults to repo root]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - Skill
---

# /agents-md — Author Project Rules File With Anchored Content

`AGENTS.md` (a.k.a. `CLAUDE.md`, `.github/copilot-instructions.md`) is the project-specific layer between the agent's system prompt and your task prompt. It only earns its place in the context window if every rule passes one question: **could the agent know this without this file?** If yes, the rule is noise. If no, it belongs.

This skill writes `AGENTS.md` as the canonical file, with thin import shims for Claude Code (`CLAUDE.md` → `@AGENTS.md`) and optionally Copilot (`.github/copilot-instructions.md` → references `AGENTS.md`). Each proposed rule must be anchored in a real source from the project (`docs/`, lessons, incidents, product-spec constraints) — generic best-practice copy is rejected.

The skill is **anti-duplication**: it greps `~/.claude/rules/` for the rules ai-devkit already auto-activates by file type. Anything covered there does not enter `AGENTS.md`.

## When to use, when to skip

**Use when**:
- The project has no `AGENTS.md` / `CLAUDE.md` and the agent keeps drifting from local conventions.
- You're adding a meaningful new module / area and want a localized `<area>/AGENTS.md`.
- You inherited a project and want to capture the "embarrassing workarounds" the agent keeps re-breaking.

**Skip when**:
- The rule you want to add is a language convention (TypeScript `unknown` over `any`, Go error wrapping, Python typing) — ai-devkit's `~/.claude/rules/` already covers it. Adding it to `AGENTS.md` is redundant.
- The rule is a single one-off intent for the current task — put it in the prompt, not the file.
- The project has no `docs/` and no decisions worth anchoring rules in. Run `/discover` + `/product-spec` first, or just leave `AGENTS.md` minimal.
- You want to draft the file in raw form and audit later — use Claude Code's built-in `/init` and then `/rule-review` to clean up; this skill is for the test-of-inclusion-first path.

## Relationship to other skills

- `/rule-review` — downstream auditor. Audits the file this skill writes (or any existing one) across 7 dimensions. Run after any meaningful edit.
- `/kickoff` — workspace bootstrap. If `docs/` is missing, this skill delegates to `/kickoff` first.
- `/discover` + `/product-spec` — content source. The product-spec's user persona, business logic, and access-control sections become rule anchors. If `docs/product-spec.md` is missing, the skill warns but still proceeds (less anchored content available).
- `~/.claude/rules/*.md` — auto-active language layer. This skill **reads** these to know what NOT to propose. It never modifies them.
- Claude Code's built-in `/init` — alternative entry point. `/init` analyzes the codebase and proposes everything; this skill goes the opposite way (propose nothing unless anchored). They're complementary — `/init` first, this skill second with `/rule-review` audit.

## Output language

`AGENTS.md`, the `CLAUDE.md` shim, and the optional `.github/copilot-instructions.md` are written in **English**, regardless of the user's chat language. This matches the global policy in `~/.claude/CLAUDE.md` §13. The interactive dialogue during authoring may use the user's working language; the file content on disk is always English so the rules survive team handover and tool changes.

## What this skill writes

Three files (the second and third are opt-in):

1. **`AGENTS.md`** at the target scope (repo root by default; `<area>/AGENTS.md` if scoped). Canonical source of truth. Holds all the actual rules.
2. **`CLAUDE.md`** at the same scope, one line: `This file provides guidance to Claude Code when working with code in this repository: @AGENTS.md`. Only written if not already present.
3. **`.github/copilot-instructions.md`** (opt-in): brief shim that references `AGENTS.md`. Copilot lacks native `@` imports — the shim either re-links to AGENTS.md or copies its content (user picks at write time).

## Initial Response

When invoked:

1. **Path given** (`/agents-md src/api`): target scope is that directory. Jump to Step 1.
2. **No path**: target scope is repo root.

Print: `Target scope: <path>. Canonical file will be <path>/AGENTS.md.`

## Process

### Step 0: Verify workspace

```bash
test -d docs
```

If missing, ask whether to delegate to `/kickoff`. The skill will continue without `docs/`, but content anchoring becomes much weaker.

If `target/AGENTS.md` already exists, ask:
- "Append to existing file" (recommended for additions)
- "Audit existing file first" → delegate to `/rule-review`, then return.
- "Overwrite (after backup)" → save to `AGENTS.md.bak-YYYYMMDD-HHMMSS`.
- "Cancel".

### Step 1: Inventory ai-devkit's auto-active layer

Print what `~/.claude/rules/` already enforces by file type. This is the "free knowledge" you don't pay context for in `AGENTS.md`:

```bash
ls ~/.claude/rules/*.md 2>/dev/null
```

For each rule file, print one line: `~/.claude/rules/typescript.md → unknown over any, Zod validation, error narrowing, ...` (read the `## When this rule activates` and key bullet points). The user sees the "do not duplicate" list.

If `~/.claude/rules/` doesn't exist (user installed only the copilot side): print "ai-devkit's auto-active rules layer is not installed at `~/.claude/rules/`. Without it, you may need MORE rules in AGENTS.md than usual. Continue?"

### Step 2: Scan project for anchorable content

For the target scope, read in this order, capturing snippets / paths for later citation:

| Source | What to extract |
|---|---|
| `docs/product-spec.md` | `## User & Persona`, `## Access control`, `## Business logic`, `## Non-goals`. These constrain agent decisions (e.g. "only the trainer can mutate attendance"). |
| `docs/architecture/*.md` | Section headings + key decisions. Each decision is a candidate rule anchor. |
| `docs/reference/lessons.md` | If present, each `## <Rule>` block is a pre-made rule with a `Why:` already attached. |
| `docs/analyzes/*.md` | The `## Decision` line of each research doc. Constraints arising from research belong in AGENTS.md. |
| Existing root-level config files (`tsconfig.json`, `pyproject.toml`, `pom.xml`, `.eslintrc*`) | What's ALREADY enforced. Anything enforced here is candidate for "don't add to AGENTS.md". |
| `README.md` of the project | Commands (build, test, lint). If present, AGENTS.md should reference (not duplicate) these. |

Print a summary table:

```
Source                              Items found    Will use for anchors
docs/product-spec.md                4 sections     access-control, business-rule, non-goals
docs/architecture/auth.md           3 decisions    JWT-only, no-cookie-fallback
docs/reference/lessons.md           2 entries      no-lodash, utc-dates
docs/analyzes/db-choice.md          1 decision     postgres-not-mongo
.eslintrc.json                      enforces       (skip — already covered)
README.md                           build cmds     reference only, don't duplicate
```

### Step 3: Propose rules (test of inclusion applied)

For each anchorable item from Step 2, propose a rule using the **test of inclusion**:

> Could the agent know this **without** AGENTS.md, given `~/.claude/rules/` is active and the public docs in the codebase are readable?

If the answer is "yes", drop the rule. If the answer is "no" and the user can explain why, keep it.

Ask the user item by item — interactive AskUserQuestion per candidate, with the source citation visible:

```
Candidate rule #2:

> Mutating attendance requires trainer-of-record check (not any authenticated user).

Anchor: docs/product-spec.md § Access control.

Could the agent infer this from the codebase or public docs alone?
  - No, keep this rule (Recommended)
  - Yes, drop it — the auth middleware code already enforces it visibly
  - Reword it
  - Skip — I'm not sure yet
```

Items the user keeps go into the working draft. Items dropped do not appear later.

### Step 4: Draft AGENTS.md with U-shaped layout

Layout — top to bottom — leverages U-shaped attention (Liu et al., "Lost in the Middle"):

```markdown
# <Project name> — Agent Rules

<2–3 line summary: what this project is and what it expects from an agent.>

## Critical (highest priority)

<3–5 rules. The non-negotiables. Access control, data integrity,
destructive-operation gates, anything where a wrong decision is hard to
recover from.>

## Conventions (project-specific)

<Rules that aren't critical but enforce local idioms the agent wouldn't
otherwise infer. File naming, import paths, error formats, etc. Group by
topic.>

## Workflow

<How work flows through this repo: branch naming, commit conventions,
PR template, where lessons go (docs/reference/lessons.md), what / 10x / or
ai-devkit skills are in use.>

## References

<Pointers to the canonical sources, NOT duplicated content. e.g.
"Build/test commands: see README.md", "Architecture decisions: see
docs/architecture/", "Lessons learned: see docs/reference/lessons.md".>

## Out of scope for this file

<One-liner: "Language conventions live in ~/.claude/rules/*.md (auto-active
on file edit). Do not re-state them here.">
```

Each rule is one to three sentences, imperative voice. Cite anchors inline as `> Source: docs/architecture/auth.md § JWT`. Group related rules — never write a 30-rule wall of one-liners.

### Step 5: Size budget check

After drafting, count lines:

```bash
wc -l <draft>
```

| Lines | Action |
|---|---|
| ≤ 150 | Healthy. Proceed. |
| 151 – 200 | At the edge. Print: "AGENTS.md is at <N> lines. Recommended ceiling is ~200 to keep the high-attention top of context budgeted." Proceed. |
| 201 – 250 | Over. Print which sections are largest. Offer to **split** an area-specific section out into `<area>/AGENTS.md` (granular file, loaded only when the agent works in that area). |
| > 250 | Strong push to split. Default action: split, not save. User can override. |

When splitting, write the area-specific file and replace the section in root `AGENTS.md` with a one-liner: `> Rules for src/api/: see src/api/AGENTS.md` (Claude Code follows this organically via its directory walk; Codex too).

### Step 6: Write the shim files

After `AGENTS.md` is approved:

1. **`CLAUDE.md`** (if not present):
   ```markdown
   This file provides guidance to Claude Code when working with code in this repository: @AGENTS.md
   ```
   Or as symlink: `ln -s AGENTS.md CLAUDE.md` — offer the user the choice. Default: the one-line file (works on Windows, survives `rm` of either side).

2. **`.github/copilot-instructions.md`** (opt-in):
   ```
   AskUserQuestion:
   - question: "Also write .github/copilot-instructions.md for Copilot users?"
     header: "Copilot shim?"
     options:
     - label: "Yes — link-only shim"
       description: "One-line file pointing to AGENTS.md. Copilot users open AGENTS.md manually."
     - label: "Yes — copy content"
       description: "Copies AGENTS.md content (will drift over time)."
     - label: "No"
       description: "Skip Copilot. Add later if needed."
     multiSelect: false
   ```

3. **`.gitattributes` (optional)** — if a symlinked `CLAUDE.md` was chosen and the repo is shared across OSes, suggest adding `CLAUDE.md text` to avoid CRLF issues.

### Step 7: Lesson hook

Print:

```
Authored: <path>/AGENTS.md (<N> lines), CLAUDE.md shim, [copilot shim?].

This file is a living artifact. When the agent makes the same mistake twice
in a row, append a new entry to docs/reference/lessons.md and bring the
new rule into AGENTS.md the next time you /rule-review it.

Next step: /rule-review <path>/AGENTS.md
```

STOP.

## Edge cases

- **Empty project (no docs/, no code)**: skill prints "Nothing to anchor rules in yet. Either run /discover → /product-spec first, or start with a minimal `AGENTS.md` containing only the workflow section." User picks.
- **Multi-language repo with conflicting conventions**: prefer granular files (`backend/AGENTS.md`, `frontend/AGENTS.md`). Root file holds only the cross-cutting concerns.
- **Monorepo**: the skill targets the cwd's package, not the workspace root, unless the user passes the root path explicitly.
- **Existing AGENTS.md is huge and unanchored**: do not attempt to migrate inline. Recommend running `/rule-review` first to identify what's actually load-bearing, then re-running this skill to rebuild from anchors.
- **No `~/.claude/rules/` installed**: the anti-duplication step is skipped; the skill prints a warning so the user knows AGENTS.md may end up longer than usual. The user can later install ai-devkit's rules layer and prune.
- **Conflicting CLAUDE.md ↔ AGENTS.md content** (both pre-existing): the skill refuses to silently overwrite. Asks: "audit existing files with `/rule-review` to identify drift, then re-run."
