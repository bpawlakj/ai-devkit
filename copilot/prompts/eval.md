# Eval — Golden-task evaluation harness → regression-on-upgrade

Paste this prompt to Copilot CLI to run an evaluation harness over AI output and catch quality
regressions when the model or harness changes. Mirrors the Claude Code `/eval` skill.

---

You run a golden-task evaluation harness. Your job: score AI output against known expected outcomes,
compare to a recorded baseline, and report regressions — concretely, not by vibes.

The eval target is named per suite and may be a skill, a prompt file, an agent, or a product LLM
feature. Never grade output against the implementation's own echo — the oracle is the golden
expected outcome.

## Directory convention (`evals/` at project root)

```
evals/
├── README.md          # what this suite evaluates + how to run
├── thresholds.yml     # pass_rate, task_pass, allow_regressions
├── baseline.json      # last ACCEPTED run (git-tracked; its diff = the regression signal)
└── <suite>/
    └── G-001-<slug>.md  # golden task: frontmatter (id, suite, target, grader, weight) + ## Input + ## Expected
```

## Process

1. **No `evals/`?** Scaffold a starter (`README.md`, `thresholds.yml`, ONE example `G-001` with
   `## Input` + `## Expected`). Then stop — the user authors real golden tasks. Do not invent
   domain tasks.
2. **Discover** `G-*.md` in scope; skip any missing `## Expected` (no oracle = not runnable).
3. **Run** each task's `## Input` against its `target:` (skill / prompt / agent / feature),
   capturing output blind to `## Expected`.
4. **Score** against `## Expected`: `exact` (equality), `assert` (observable assertions),
   `rubric` (a SEPARATE judge agent scores 0..1 against the checklist — refute, don't rubber-stamp).
5. **Compare** to `baseline.json`; apply `thresholds.yml`. A run passes only if `pass_rate` clears
   AND (when `allow_regressions: false`) there are zero regressions — a drop fails the run even if
   the threshold is met.
6. **Report** per-task score, pass/FAIL, baseline value, regression delta, aggregate verdict;
   stamp the model + harness.
7. **Accept** (only if explicitly asked AND the run is acceptable): regenerate `baseline.json`
   stamping date + model + harness; show the diff before writing. Never auto-accept a failed run.

## Guardrails

- Oracle = `## Expected`, never observed output.
- A regression fails the run under `allow_regressions: false`, independent of the threshold.
- `baseline.json` is derived + git-tracked; written only on accept, never hand-edited.
- The rubric judge is a fresh agent (fresh-model verification).
- All persisted files are written in English.
