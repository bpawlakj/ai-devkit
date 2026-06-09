---
id: T-001
title: EVAL harness — /eval skill + evals/ convention
status: pending
plan: ../plan.md
created: 2026-06-09
completed: null
commit: null
depends_on: []
blocks: []
plan_anchor: p0-1-eval-harness-eval-skill-evals-convention
---

## Scope

- New skill `claude/skills/eval/SKILL.md` (`/eval`) + `references/eval-schema.md` (locked shape).
- New `evals/` directory convention: golden tasks (input + expected outcome), a recorded
  `baseline.md`/`baseline.json`, acceptance thresholds.
- A regression command: run golden tasks against the current model/harness, diff results against
  the baseline, report pass/fail per task + an aggregate verdict.
- Optional CI hook: an `evals` job recipe that `/ci-setup` can emit, reusing the same CI surface
  and AI-reviewer recipe (`references/ci-recipes.md` / `references/ai-reviewers.md`).
- Copilot mirror: `copilot/prompts/eval.md`.
- README skill count + workflow framing updated; `CHANGELOG.md` `[Unreleased]` entry.

## Approach

- Follow the existing skill authoring pattern (SKILL.md frontmatter with `allowed-tools` + a locked
  `references/` schema), as `/scenario` and `/e2e-run` do.
- Prior art for the directory shape: BMAD ships an `evals/` directory — adopt the convention, not a
  dependency.
- Hook into CI via the existing `/ci-setup` extension mechanism (it is already self-hosted-runner
  aware and recipe-driven), rather than building a separate runner.
- Eval oracle = acceptance criteria / golden expected output, never the implementation's own echo
  (same oracle rule as `/implement` Step 4 and `rules/typescript.md` § Testing).

## Acceptance

- `/eval` runs a set of golden tasks and prints pass/fail per task + an aggregate verdict against
  the baseline.
- Re-running after a (simulated) model/harness change reports a regression diff vs the baseline.
- `references/eval-schema.md` defines the golden-task + baseline + threshold shape and is followed
  by the skill body.
- A bats test (`tests/eval.bats`) covers the skill's discovery + a dry-run path.
- Closes EVAL-05 / EVAL-07: a concrete v1 harness exists (golden tasks, baseline, thresholds,
  upgrade regression check) — not just the principle.

## Notes

Effort: L. The CI hook is the optional second half — if it grows, split it into a follow-up task
(`depends_on: [T-001]`) rather than expanding this one.
