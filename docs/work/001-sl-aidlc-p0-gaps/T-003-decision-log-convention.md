---
id: T-003
title: Living numbered decision-log convention
status: pending
plan: ../plan.md
created: 2026-06-09
completed: null
commit: null
depends_on: []
blocks: []
plan_anchor: p0-3-living-numbered-decision-log-convention
---

## Scope

- A numbered ADR log convention under `docs/architecture/decisions/` — one file per decision,
  `D-NNN-<slug>.md`, with date / context / rationale / status / consequences.
- `/setup` scaffolds `docs/architecture/decisions/` + a `README.md` documenting the D-NNN
  convention (idempotent, create-if-absent — consistent with existing `/setup` scaffolding).
- `/research` appends a `D-NNN` entry when a decision is reached (its snapshot already records a
  `decision:` — wire it to also emit/append the numbered log entry).
- `/implement` references the relevant `D-NNN` when an increment implements a decision.
- A locked `references/decision-log-schema.md` (in the `/research` or `/setup` skill) defining the
  D-NNN file shape. `CHANGELOG.md` `[Unreleased]` entry.

## Approach

- Prior art: OpenSpec's lightweight decision log + `changes/` split; keep it a thin convention +
  tiny scaffold, NOT a heavyweight new skill.
- Reuse the existing `docs/architecture/` directory and the `/research` snapshot shape
  (`docs/analyzes/<slug>.md` already carries a `decision:` frontmatter key — the log entry can
  cross-link the analysis).
- Numbering: scan existing `D-*.md` for the highest N, increment (same pattern `/atomize` uses for
  `T-NNN`).

## Acceptance

- `/setup` creates `docs/architecture/decisions/` with a convention README on a fresh project.
- Reaching a decision via `/research` produces/append a numbered `D-NNN-<slug>.md` with
  date/context/rationale/status.
- The log is referenceable from tasks/specs (ART-06-style cross-reference).
- Closes ART-03: a numbered, living decision log exists as a required artifact, not ad-hoc ADRs.

## Notes

Effort: S–M.
