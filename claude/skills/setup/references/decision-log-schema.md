# Decision Log Schema (canonical reference)

Single source of truth for the shape of the numbered, living decision log under
`docs/architecture/decisions/`. `/setup` scaffolds the folder + README; `/research` appends a
record when it reaches a decision; `/implement` references the relevant `D-NNN` when it implements
one. This closes SL AiDLC's `ART-03` (a decision log as a *required living artifact*, each entry
numbered with date, rationale, and context).

It is the durable counterpart to `docs/analyzes/`: `analyzes/` holds the point-in-time *reasoning*
(never edited retroactively); `decisions/` holds the durable *verdict* (status updated in place).

## Directory layout

```
docs/architecture/decisions/
├── README.md              # the D-NNN convention (written by /setup)
├── D-001-<slug>.md        # one decision per file
├── D-002-<slug>.md
└── ...
```

Numbers are **sequential and never reused**. A new decision takes the next `D-NNN`; pick it by
scanning existing `D-*.md` for the highest N and incrementing (same pattern `/atomize` uses for
`T-NNN`).

## Record (`D-NNN-<slug>.md`)

### Frontmatter (load-bearing)

```yaml
---
id: D-001                          # zero-padded 3-digit, unique + sequential
title: Use Postgres over DynamoDB  # one-line decision title (<= 80 chars)
date: 2026-06-09                   # YYYY-MM-DD the decision was reached
status: accepted                   # proposed | accepted | superseded
supersedes: null                   # D-NNN this replaces, or null
superseded_by: null                # D-NNN that replaced this, or null (set in place when superseded)
analysis: ../../analyzes/<slug>.md # the research snapshot this came from, or null
---
```

### Body sections

```markdown
## Context

The forces at play — what made a decision necessary. Constraints, requirements, the problem.

## Decision

The choice that was made, stated plainly and in active voice ("We will …").

## Consequences

What becomes easier and what becomes harder as a result. Trade-offs accepted, follow-ups created,
risks taken on.
```

## Living-log rules (invariants)

1. **Never delete or renumber a record.** History is the point. A decision that no longer holds is
   marked `status: superseded` **in place** and gets `superseded_by: D-NNN`; the replacing record
   sets `supersedes: D-NNN`.
2. **Status is updated in place; reasoning is not.** Editing `status` / `superseded_by` on an
   existing record is expected. Rewriting its `## Context` / `## Decision` after the fact is not —
   that rewrites history. Capture new reasoning in the superseding record (and in `analyzes/`).
3. **Link to the reasoning.** When the decision came from a `/research` run, set `analysis:` to the
   `docs/analyzes/<slug>.md` snapshot so the verdict and its evidence stay connected (ART-06-style
   cross-reference).
4. **One decision per file.** If a discussion produced two decisions, write two records.
