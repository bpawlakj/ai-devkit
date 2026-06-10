# Decision log (D-NNN)

The numbered, **living decision log** — the durable counterpart to `docs/analyzes/`:
`analyzes/` holds the point-in-time *reasoning* (never edited retroactively);
this directory holds the durable *verdicts* (status updated in place).

Canonical shape: `claude/skills/setup/references/decision-log-schema.md`.

## Convention

- One decision per file: `D-NNN-<slug>.md`, numbers sequential, zero-padded,
  **never reused or renumbered**.
- Frontmatter: `id`, `title`, `date`, `status` (proposed | accepted | superseded),
  `supersedes`, `superseded_by`, `analysis:` (link back to the
  `docs/analyzes/<slug>.md` snapshot the decision came from, or null).
- Body: `## Context` (the forces), `## Decision` ("We will …"), `## Consequences`
  (trade-offs, follow-ups).

## Living-log rules

1. Never delete or renumber a record — history is the point.
2. Status is updated in place; reasoning is not. A decision that no longer holds
   gets `status: superseded` + `superseded_by: D-NNN`; the replacement sets
   `supersedes: D-NNN` and carries the new reasoning.
3. `/research` appends a record when it reaches a decision; `/implement`
   references the relevant `D-NNN` in commit `Refs:` when a task implements one.
