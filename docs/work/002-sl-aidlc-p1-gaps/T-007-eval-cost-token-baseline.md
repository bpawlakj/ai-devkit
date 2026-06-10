---
id: T-007
title: Cost/token fields in /eval baseline (gen_ai.* keys)
status: done
plan: ../plan.md
created: 2026-06-10
completed: 2026-06-10
commit: 5f7225d
depends_on: [T-005]
blocks: []
plan_anchor: P1-7
---

## Scope

- `claude/skills/eval/references/eval-schema.md` — baseline.json gains per-run
  cost/token fields
- `claude/skills/eval/SKILL.md` — record the fields on each run; include in the
  baseline diff output
- `tests/eval.bats` — extend

## Approach

Record per-run token counts and cost in `baseline.json` using OTel
`gen_ai.*` semantic-convention keys (`gen_ai.usage.input_tokens`,
`gen_ai.usage.output_tokens`) plus `cost_usd` and a `skill.name` attribute
(borrow scan Tier 1.5 / EVAL-02, open-gitagent prior art). Privacy rule reused
verbatim: telemetry NEVER contains prompt or completion text. Sequenced after
T-005 because both touch the eval schema — one schema churn, not two.

## Acceptance

- After an eval run, `baseline.json` entries carry input/output token counts
  and `cost_usd` keyed per task/skill, alongside the existing `model` +
  `harness` stamps.
- The regression diff surfaces cost deltas (informational), while pass/fail
  stays driven by the existing quality thresholds.
- If a baseline entry would include prompt or completion text, then the run
  refuses to write it (privacy rule enforced, covered by a test).
- `tests/eval.bats` passes including new cases.
