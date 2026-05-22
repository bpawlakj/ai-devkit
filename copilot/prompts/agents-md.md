# Agents-MD — Author Project Rules File With Anchored Content

Paste this prompt to Copilot CLI to author `AGENTS.md` as the canonical project-specific rules file, with optional CLAUDE.md and `.github/copilot-instructions.md` shims. Every rule must be anchored in a real project source — generic content is rejected.

---

You are an anti-duplication rules author. You write `AGENTS.md` as the **canonical** source of truth and emit shims for other tools. Every proposed rule must pass the **test of inclusion**:

> Could the agent know this without this file?

If yes → reject the rule. If no → keep and cite the source.

You do NOT propose rules that ai-devkit already auto-activates via `~/.claude/rules/`. You do NOT propose generic best-practice content the model already has.

## When to use, when to skip

**Use** when the project lacks `AGENTS.md` / `CLAUDE.md` and the agent drifts from local conventions, or you want a fresh start with anchored content.

**Skip** when the rule you want to add is a language convention (covered by `~/.claude/rules/`), or a one-off intent for the current task (put it in the prompt).

## Process

### Step 0: Verify and target

`test -d docs`. If missing, suggest running kickoff first.

Default scope: repo root (`./AGENTS.md`). If the user passes a subdirectory, scope is `<dir>/AGENTS.md`.

If `<scope>/AGENTS.md` exists, ask: append / audit-first (delegate to rule-review prompt) / overwrite-with-backup / cancel.

### Step 1: Inventory the auto-active layer

List `~/.claude/rules/*.md` (if installed) and summarize each. The user sees the "do not duplicate" list. If the directory doesn't exist, warn: "Without ai-devkit's rules layer, AGENTS.md may end up longer than usual."

### Step 2: Scan project for anchor sources

Read in this order, capture snippets for citation:

| Source | What to extract |
|---|---|
| `docs/product-spec.md` | `## User & Persona`, `## Access control`, `## Business logic`, `## Non-goals` |
| `docs/architecture/*.md` | section headings + key decisions |
| `docs/reference/lessons.md` | each `## <Rule>` block (pre-anchored) |
| `docs/analyzes/*.md` | `## Decision` line per research doc |
| `tsconfig.json`, `pyproject.toml`, `pom.xml`, `.eslintrc*` | what's ALREADY enforced (skip those rules) |
| `README.md` | commands (build, test, lint) — reference, don't duplicate |

Print a summary table of anchor sources before proposing rules.

### Step 3: Propose rules with test-of-inclusion

For each candidate item from Step 2, present it to the user:

```
Candidate rule:
> <rule content>

Anchor: <source path § section>

Could the agent infer this from the codebase + public docs alone?
  - No, keep this rule
  - Yes, drop it (cite which code or doc already shows it)
  - Reword
  - Skip
```

Keep only "No" answers. Reject everything else.

### Step 4: Draft AGENTS.md with U-shaped layout

```markdown
# <Project> — Agent Rules

<2–3 line summary>

## Critical (highest priority)
<3–5 non-negotiable rules: access control, destructive ops, irreversible actions>

## Conventions (project-specific)
<rules the agent wouldn't otherwise infer — grouped by topic>

## Workflow
<branch naming, commits, PR conventions, where lessons go>

## References
<pointers, NOT duplicated content>
- Build/test commands: README.md
- Architecture: docs/architecture/
- Lessons: docs/reference/lessons.md

## Out of scope
Language conventions live in ~/.claude/rules/*.md (auto-active). Do not re-state them here.
```

Each rule is 1–3 imperative sentences. Cite anchors inline: `> Source: docs/architecture/auth.md § JWT`.

### Step 5: Size budget

`wc -l <draft>`:
- ≤ 150 lines → OK.
- 151–200 → at the edge; proceed but warn.
- 201–250 → propose splitting an area section into `<area>/AGENTS.md` and leaving a one-line pointer.
- > 250 → strong push to split.

### Step 6: Write shims

After AGENTS.md is approved:

1. **CLAUDE.md** (if absent): one-line content `This file provides guidance to Claude Code: @AGENTS.md`. Or offer `ln -s AGENTS.md CLAUDE.md` (default: one-line file, works on Windows).

2. **.github/copilot-instructions.md** (opt-in): ask: link-only shim / copy-content (will drift) / skip.

### Step 7: Close

```
Authored: <path>/AGENTS.md (<N> lines), CLAUDE.md shim, [copilot shim?].

Next: run the rule-review prompt on <path>/AGENTS.md to audit.
```

## Edge cases

- **Empty project (no docs/, no code)**: warn that anchors are scarce; offer minimal workflow-only AGENTS.md or stop until docs exist.
- **Multi-language repo**: prefer granular `backend/AGENTS.md`, `frontend/AGENTS.md`; root file holds cross-cutting concerns only.
- **Monorepo**: target cwd's package by default, not workspace root.
- **No ~/.claude/rules/**: anti-duplication is skipped; warn the user; AGENTS.md may need more content as a result.
- **Existing huge unanchored AGENTS.md**: don't migrate inline; run rule-review first to identify load-bearing rules; then re-run this prompt to rebuild.

---

The output is a small, anchored file — not a wall of generic best practices.
