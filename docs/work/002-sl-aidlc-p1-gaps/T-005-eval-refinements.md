---
id: T-005
title: /eval refinements — pattern taxonomy, assertion checklists, triggers fixture
status: pending
plan: ../plan.md
created: 2026-06-10
completed: null
commit: null
depends_on: []
blocks: [T-007]
plan_anchor: P1-5
---

## Scope

- `claude/skills/eval/references/eval-schema.md` — `pattern:` dimension +
  `expectations[]` checklist shape for golden tasks
- `claude/skills/eval/SKILL.md` — grading flow honors checklists (judge checks
  assertions one-by-one)
- New `triggers.json` discrimination fixture convention + a runnable check
  (bats or eval-target)
- `tests/eval.bats` — extend for the new shapes

## Approach

Three refinements from BMAD prior art (borrow scan Tier 1.3), keeping
`baseline.json` + thresholds untouched (already ahead of the prior art):
(1) `pattern:` on golden tasks — `A` artifact-correctness, `B`
process-discipline (inspects side-artifacts like the decision log), `C`
config-compliance — greppable dimension for filtering; (2) granular NL
`expectations[]` checklists preferred over one holistic rubric — the fresh judge
scores each assertion separately, which grades more deterministically; (3) a
`{query, should_trigger}` corpus with adversarial negatives testing skill
routing/dispatch separately from output quality — ai-devkit has many overlapping
trigger phrases and no test that they fire correctly.

## Acceptance

- A golden task can declare `pattern: A|B|C` and an `expectations[]` list; the
  schema documents both; the rubric grader scores expectations one-by-one.
- A `triggers.json` fixture exists with at least one adversarial negative per
  covered skill, and a documented way to run the discrimination check.
- If a query in the fixture is marked `should_trigger: false` and the skill
  would fire on it, then the check fails (over-triggering is a failure, not a
  warning).
- Existing eval flow (baseline diff, thresholds, --accept) unchanged;
  `tests/eval.bats` passes including new cases.
