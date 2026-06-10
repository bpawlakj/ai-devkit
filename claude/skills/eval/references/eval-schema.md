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
pattern: A                         # A artifact-correctness | B process-discipline | C config-compliance
weight: 1                          # relative weight in the suite aggregate (default 1)
tags: []                           # optional: for --grep scoping
---
```

**`pattern:` taxonomy** (greppable dimension for filtering — `grep -r "pattern: B" evals/`):

- **A — artifact-correctness**: grades the produced artifact itself (a spec, a summary, generated code).
- **B — process-discipline**: grades side-artifacts the run should have produced or respected (a
  decision-log entry written, frontmatter writeback, a gate honored) — the output may be fine while
  the process was violated.
- **C — config-compliance**: grades conformance to configuration (rules files honored, thresholds
  applied, schema fields present).

### Body sections

```markdown
## Input

The exact input handed to the target — prompt, task description, or fixture. Reproducible: anyone
re-running gets the same input.

## Expected

The oracle. For grader=rubric: a numbered checklist of plain-English **expectations** — granular,
independently checkable assertions, one per line. The judge scores each expectation met / not met
and the task score is the fraction met. Prefer many small assertions over one holistic description:
per-assertion grading is markedly more deterministic than a holistic 0..1 impression. For
grader=assert: the observable assertions (values, structure, must-contain / must-not-contain). For
grader=exact: the exact expected string/JSON.

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
      "tasks": { "G-001": 0.9, "G-002": 0.8 },
      "usage": {
        "G-001": { "gen_ai.usage.input_tokens": 1240, "gen_ai.usage.output_tokens": 890, "cost_usd": 0.0121 },
        "G-002": { "gen_ai.usage.input_tokens": 980, "gen_ai.usage.output_tokens": 1410, "cost_usd": 0.0158 }
      }
    }
  }
}
```

`model` + `harness` are stamped so a regression diff can attribute a drop to a model or harness
upgrade — the EVAL-07 "regression check on every model/harness upgrade" requirement.

**`usage` (per-task cost/token telemetry, EVAL-02):** keys follow the OTel GenAI semantic
conventions (`gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`) plus `cost_usd`, keyed per
task; the suite's `target:` (e.g. `skill:product-spec`) is the `skill.name` attribution. Best-effort
— when the harness can't report usage for a run, omit the task's entry rather than estimating.
Cost deltas in the regression diff are **informational**: pass/fail stays driven by the quality
thresholds. **Privacy rule (hard):** `usage` entries carry numbers only — never prompt text,
completion text, or any artifact content (open-gitagent's no-prompt-text rule, reused verbatim).

## triggers.json (routing discrimination fixture — optional)

Tests skill **routing/dispatch** separately from output quality: does each skill fire on the
queries it should, and — the half that usually goes untested — stay silent on the queries it
should NOT? Every covered skill carries at least one **adversarial negative**: a query that
plausibly resembles the skill's trigger phrases but belongs to a sibling skill.

```json
{
  "skills": {
    "research": {
      "cases": [
        { "query": "should we adopt pgvector or Pinecone?", "should_trigger": true },
        { "query": "I have an idea for an app, help me shape it",
          "should_trigger": false, "note": "product-level discovery -> /discover" }
      ]
    }
  }
}
```

Run: for each case, a **fresh `Agent`** receives ONLY the query + the skill's frontmatter
`description` (never the full SKILL.md body, never the other cases) and answers whether it would
route the query to that skill. Compare to `should_trigger`. **Firing on a `should_trigger: false`
case is a failure, not a warning** — over-triggering is the documented collision failure mode of
overlapping workflow skills. Report alongside suite results.

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
6. **Telemetry never contains prompt or completion text.** `usage` is numbers only
   (`gen_ai.usage.*` token counts + `cost_usd`); a baseline entry that would embed content is
   refused. Cost deltas inform — quality thresholds decide.
