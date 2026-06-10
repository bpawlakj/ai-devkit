---
name: eval
description: >
  Run an evaluation harness over AI output to catch quality regressions when the
  model or harness changes. Reads golden tasks (input + a known expected outcome)
  from an evals/ directory, runs each against its named target (a skill, prompt,
  agent, or product LLM feature), scores the output against the expected oracle
  with a rubric/assert/exact grader, compares to a git-tracked baseline, and
  reports pass/fail per task plus a regression diff. A run fails on any drop vs
  baseline, not just on missing a threshold. Concrete, not aspirational: golden
  tasks, a baseline, acceptance thresholds, and a model/harness-stamped
  regression check. Does NOT grade against the implementation's own output (the
  oracle is the golden expected outcome). Trigger phrases: "run the evals",
  "eval the prompt", "did the model upgrade regress anything", "score against
  golden tasks", "set up an eval harness".
argument-hint: "[evals/ | suite-name | G-NNN] [--accept] [--grep <tag>] [--target <skill:|prompt:|agent:|feature:>] [--out <file>]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - Agent
  - Skill
---

# /eval — Golden-task evaluation harness with regression-on-upgrade

This skill is ai-devkit's answer to "is the AI output still good after a model or harness change?".
It turns subjective "looks fine" into a concrete, repeatable verdict: **golden tasks** (input + a
known expected outcome), a recorded **baseline**, **acceptance thresholds**, and a **regression
check stamped with the model + harness** so a drop is attributable to an upgrade.

The contract for the `evals/` directory — golden task, baseline, and threshold shapes — lives at
`references/eval-schema.md` (relative to this SKILL.md). Read it before producing any artifact and
re-check at every write.

## When to use, when to skip

**Use when**:
- You changed the model, the harness/tooling, or a prompt/skill, and want to know what regressed.
- You want to lock in a quality bar for an AI feature before it ships, then guard it over time.
- You're standing up the harness for the first time (no `evals/` yet) — the skill scaffolds it.

**Skip when**:
- You want to verify one code change behaves correctly — that's `/implement`'s test gate or
  `/scenario` + `/e2e-run` (deterministic E2E), not output-quality scoring.
- You want a one-off subjective read of a single answer — just ask; an eval harness is for
  *repeatable* regression-catching, not one-shot review.

## Relationship to other skills

- `/implement` — orthogonal but shares the **oracle rule**: the expected value comes from the spec
  / acceptance / golden outcome, never the implementation's own output. `/implement` guards code
  correctness; `/eval` guards AI *output quality* over model/harness changes.
- `/ci-setup` — downstream. An `/eval` run is a natural CI gate; `/ci-setup` can emit an `evals`
  job that runs this harness on PRs and on model/harness bumps (see "CI hook" below). Building that
  recipe is a follow-up, not part of standing up the harness.
- `/research` — upstream. A decision to adopt or change a model is exactly when you re-run `/eval`
  against the baseline to quantify the trade-off.
- `~/.claude/rules/*.md` — not re-enforced here; `/eval` scores output, it does not lint code.

## Output language

All persisted artifacts — golden tasks, `thresholds.yml`, `baseline.json`, `evals/README.md` — are
written in **English**, regardless of chat language (global policy, `~/.claude/CLAUDE.md` §13).

## Initial Response

When invoked:

1. **Argument given** (`evals/`, a suite name, or `G-NNN`): resolve the scope; jump to Step 1.
2. **No argument**: check for `evals/` at the project root.
   - Present → propose running the full set; list discovered suites.
   - Absent → offer to **scaffold** a starter `evals/` (Step 0b), then STOP for the user to author
     golden tasks.

## Process

### Step 0: Resolve scope and mode

```bash
test -d evals
```

- **No `evals/`** → SCAFFOLD mode (Step 0b).
- **`evals/` exists** → RUN mode. Resolve scope: whole dir, one `<suite>/`, a `--grep <tag>`
  selection, or a single `G-NNN`. Print the resolved scope + the targets it will exercise.

### Step 0b: Scaffold (first-time only)

Create the layout from `references/eval-schema.md`:
- `evals/README.md` — what this suite evaluates, how to run, how to accept a baseline.
- `evals/thresholds.yml` — defaults (`pass_rate: 0.80`, `task_pass: 0.70`, `allow_regressions: false`).
- `evals/<suite>/G-001-<slug>.md` — ONE example golden task with `## Input` + `## Expected`, so the
  shape is concrete.
- No `baseline.json` yet — it is written on the first `--accept`.

Print the file plan and confirm (AskUserQuestion) before writing. Then STOP — the user authors real
golden tasks before the first run. Do not invent domain golden tasks the user did not describe.

### Step 1: Discover golden tasks

Glob the resolved scope for `G-*.md`. For each, read frontmatter (`id`, `suite`, `target`,
`grader`, `weight`) and the `## Input` / `## Expected` body. Skip and warn on any task missing
`## Expected` (no oracle = not runnable). Print the run plan: N tasks across M suites, grouped by
`target`.

### Step 2: Run each golden task against its target

For each golden task, produce the target's output for the task `## Input`:

| `target:` | How `/eval` runs it |
|---|---|
| `skill:<name>` | Invoke the skill (via `Skill`) on the input, capture the produced artifact/output. |
| `prompt:<path>` | Send the prompt file + input to a fresh `Agent`, capture the response. |
| `agent:<name>` | Delegate to that subagent via `Agent`, capture its final output. |
| `feature:<id>` | Run the project's own command/endpoint for that feature (from `evals/README.md`); capture output. |

Run independent tasks concurrently where the harness allows. Never let the target see `## Expected`
— the run produces output blind to the oracle.

### Step 3: Score against the oracle

Grade each output **against `## Expected`, never against the target's own echo**:

- `grader: exact` — string/JSON equality → score 1.0 or 0.0.
- `grader: assert` — evaluate the declared observable assertions (must-contain / must-not-contain /
  structural) → fraction satisfied.
- `grader: rubric` — delegate to a **fresh `Agent` as judge** with the `## Expected` checklist as
  the rubric; the judge returns a 0..1 score + a one-line justification per criterion. Use a
  separate agent from any that produced the output (fresh-model verification per the shared
  contract `references/fresh-verification.md` — refute, don't rubber-stamp). Model tier: the
  judge is judgment work — never run it on a weaker model than the one that produced the output
  (ai-devkit `docs/model-per-skill.md`, rule 2).

Record per-task score; aggregate per suite by `weight`.

### Step 4: Compare to baseline + apply thresholds

Read `evals/baseline.json` if present.
- For each task: `delta = score - baseline_score`. A negative delta is a **regression**.
- Apply `thresholds.yml`: a run **passes** only if `pass_rate` clears AND (if
  `allow_regressions: false`) there are **zero regressions** — a drop fails the run even when the
  threshold is still met. Catching the drop is the point.
- If no baseline exists, the run is informational ("no baseline — accept to set one").

### Step 5: Report

Print the run report from the schema: per-task score, pass/FAIL, baseline value, and the regression
delta; then the aggregate verdict with the reason (which tasks regressed / fell below `task_pass`).
Stamp `model` + `harness`. With `--out <file>`, also write the report there.

### Step 6: Accept (only with `--accept`)

If and only if the user passed `--accept` AND the run is acceptable, regenerate
`evals/baseline.json` from this run (stamping `accepted` date, `model`, `harness`, per-suite +
per-task scores). Show the `baseline.json` diff and confirm before writing — its diff is the
regression signal future runs and PR reviewers rely on. Never auto-accept a run that failed.

## CI hook (documented; recipe is a follow-up)

An `/eval` run is a natural CI gate: run the harness on PRs and whenever the model or harness pins
change; fail the job on a regression. `/ci-setup` owns CI recipe generation and is already
self-hosted-runner aware — emitting an `evals` job belongs there as a recipe, not here. This skill
deliberately stops at producing the local verdict + the git-tracked `baseline.json`; wiring it into
CI is a separate, opt-in task.

## Critical guardrails

1. **The oracle is `## Expected`, never observed output.** A grader that reads the target's own
   output as truth only cements current behavior, bugs included.
2. **A regression fails the run** under `allow_regressions: false`, independent of the threshold.
3. **`baseline.json` is derived + git-tracked.** Written only on `--accept`, never hand-edited; its
   PR diff is how regressions are reviewed.
4. **Never auto-accept a failed run**, and never accept without showing the baseline diff.
5. **The judge is a fresh agent.** Rubric grading uses a separate agent from the one that produced
   the output — refute, don't rubber-stamp (fresh-model verification).
6. **Don't invent golden tasks.** Scaffolding writes ONE example task to show the shape; real domain
   golden tasks come from the user, not the skill's guesses.

## Notes

- Project-agnostic by design: the eval *target* is named per suite (`skill:` / `prompt:` / `agent:`
  / `feature:`), so the same harness evals an ai-devkit skill, a product prompt, or an LLM feature.
- The model/harness stamp on the baseline is what makes "did the upgrade regress anything?"
  answerable — the EVAL-07 requirement this skill closes.
