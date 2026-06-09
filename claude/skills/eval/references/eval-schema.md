# Eval Schema (canonical reference)

Single source of truth for the shape of the `evals/` directory that `/eval` reads and writes:
**golden tasks**, the **baseline**, and **thresholds**. `/eval` conforms to this format; re-check
it at every write.

The design goal is EVAL-07-grade *concreteness*: golden tasks with expected outcomes, a recorded
baseline, acceptance thresholds, and a regression check on every model/harness upgrade — not just
the principle. It is deliberately thin and project-agnostic: the eval *target* (a skill, a prompt,
an agent, or an LLM feature in the product) is named per suite, not assumed.

## Directory layout

```
evals/
├── README.md                  # what this suite evaluates + how to run it (human-authored)
├── thresholds.yml             # pass criteria (one file per project)
├── baseline.json              # last ACCEPTED run scores (regenerated on accept; git-tracked)
└── <suite>/                   # one folder per evaluation suite (e.g. summarize/, classify/)
    ├── G-001-<slug>.md        # golden task
    ├── G-002-<slug>.md
    └── ...
```

`evals/` lives at the project root next to `docs/` and `tests/`. `baseline.json` is **git-tracked**
— it is the recorded prior-known-good, and its diff in a PR is the regression signal.

## Golden task (`G-NNN-<slug>.md`)

One golden task = one input with a known expected outcome. The **oracle is the expected outcome
declared here**, never the target's observed output (an eval whose oracle is the implementation
only cements current behavior — the same oracle rule as `/implement` Step 4).

### Frontmatter (load-bearing)

```yaml
---
id: G-001                          # zero-padded 3-digit, unique within the suite
suite: summarize                   # parent suite folder name
target: skill:product-spec         # what is being evaluated: skill:<name> | prompt:<path> | agent:<name> | feature:<id>
grader: rubric                     # rubric (LLM-as-judge against ## Expected) | assert (deterministic) | exact
weight: 1                          # relative weight in the suite aggregate (default 1)
tags: []                           # optional: for --grep scoping
---
```

### Body sections

```markdown
## Input

The exact input handed to the target — prompt, task description, or fixture. Reproducible: anyone
re-running gets the same input.

## Expected

The oracle. For grader=rubric: the criteria a correct output must satisfy (checklist the judge
scores against). For grader=assert: the observable assertions (values, structure, must-contain /
must-not-contain). For grader=exact: the exact expected string/JSON.

## Notes

(Optional) Why this task is in the suite, edge case it guards, provenance.
```

## thresholds.yml

```yaml
# Acceptance criteria evaluated after a run. A run PASSES only if all hold.
pass_rate: 0.80          # min fraction of golden tasks scoring >= task_pass
task_pass: 0.70          # min per-task score (0..1) for a task to count as passing
allow_regressions: false # if false, ANY task that dropped vs baseline fails the run
per_suite:               # optional overrides keyed by suite name
  classify:
    pass_rate: 0.90
```

## baseline.json (derived — regenerated on accept)

Records the last **accepted** run so the next run can diff against it. Written only when the user
accepts a run (`/eval --accept`); never hand-edited.

```json
{
  "accepted": "2026-06-09",
  "model": "claude-opus-4-8",
  "harness": "ai-devkit@1.11.0",
  "suites": {
    "summarize": {
      "pass_rate": 0.86,
      "tasks": { "G-001": 0.9, "G-002": 0.8 }
    }
  }
}
```

`model` + `harness` are stamped so a regression diff can attribute a drop to a model or harness
upgrade — the EVAL-07 "regression check on every model/harness upgrade" requirement.

## Run report (printed, not persisted unless `--out`)

```
EVAL — suite: summarize · target: skill:product-spec · model: claude-opus-4-8
  G-001  0.90  pass   (baseline 0.90  →  no change)
  G-002  0.60  FAIL   (baseline 0.80  →  REGRESSION -0.20)
  ─────────────────────────────────────────────
  pass_rate 0.50 < 0.80  →  RUN FAILED (1 regression, 1 below task_pass)
```

## Invariants

1. **Oracle = `## Expected`, never observed output.** A grader reads the golden expected outcome,
   not the target's own echo.
2. **baseline.json is derived + git-tracked.** Regenerated only on `--accept`; its PR diff is the
   regression signal. Never hand-edit.
3. **A regression fails the run** when `allow_regressions: false` — even if `pass_rate` still clears
   the threshold. Catching the *drop* is the point.
4. **Golden tasks are append-only in spirit.** Changing a task's `## Expected` changes the oracle —
   prefer adding `G-NNN` over silently editing an accepted task's expectation.
5. **Model + harness are stamped** on every baseline so a drop is attributable to an upgrade.
