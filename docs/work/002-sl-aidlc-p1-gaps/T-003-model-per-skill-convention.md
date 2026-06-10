---
id: T-003
title: Model-per-skill convention + reference table
status: done
plan: ../plan.md
created: 2026-06-10
completed: 2026-06-10
commit: ba329bc
depends_on: []
blocks: []
plan_anchor: P1-3
---

## Scope

- One reference page documenting the per-skill `model:` hint convention and a
  recommended model-per-task table (landing spot: `claude/skills/` shared
  reference or `docs/` page — decide during implementation; link from README)

## Approach

Guidance + defaults only — the skill/`Agent` model-override mechanism already
exists; build no machinery. Table maps skill archetypes to model tiers: cheap
model for mechanical/extraction work (plumbing, file generation, status rollups),
capable model for design/review/judgment work (`/research`, `/discover`, `/eval`
rubric judge, code review). State the default rule: omit the override and inherit
the session model unless confident a different tier fits. Closes SKILL-04/05
(token economy).

## Acceptance

- The reference page exists, names the convention, and contains the
  archetype→tier table with rationale.
- README links to it.
- At least the skills with an obvious tier (e.g. `/eval` judge = capable) carry
  the documented hint or a pointer to the table.
- No new runtime machinery added (doc-only change, verifiable by diff).
