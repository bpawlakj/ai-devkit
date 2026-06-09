---
name: ci-setup
description: >
  Generate a CI/CD pipeline for a project: a GitHub Actions workflow that lints,
  tests, and enforces a coverage gate (default 80%), publishes coverage to an
  external dashboard (Codecov), and optionally adds an AI code-review step on PRs
  (kukuvaia on a self-hosted runner, or the official Claude Code Action). Detects
  the stack (Python/uv, Node/npm) to emit the right commands and reuses
  /implement's runner-detection. Writes nothing until you confirm the file plan.
  Idempotent. Trigger phrases: "set up CI", "add a CI/CD pipeline", "add GitHub
  Actions", "add a coverage gate", "add AI code review to CI", "/ci-setup".
argument-hint: "[--coverage <pct>] [--reviewer kukuvaia|claude|none] [--coverage-tool codecov|none] [--provider github]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - Skill
---

# /ci-setup — Generate a CI/CD pipeline (coverage gate + external dashboard + AI review)

This skill scaffolds a project's continuous-integration pipeline from a small set
of decisions, matching the project's actual stack. It produces **three things**,
the last two optional:

1. **A CI workflow** (`.github/workflows/ci.yml`) — lint + test + a **coverage
   gate** (default 80%), per detected stack.
2. **External coverage visualization** — uploads coverage to **Codecov** (badge +
   PR diff-coverage comment + dashboard).
3. **AI code review on PRs** — either **kukuvaia** on a self-hosted runner
   (reuse-internal-infrastructure) or the official **Claude Code Action**
   (Anthropic-hosted). The user picks per project.

It is a **generator with a human-review gate**: it detects, proposes a concrete
file plan, and writes only what the user confirms. It never runs `setup.sh`,
commits, pushes, or stores secrets — those are the user's explicit steps.

Read the three `references/` files before writing any artifact; they hold the
locked recipes and are the source of truth for what gets generated:
`references/ci-recipes.md` (per-stack commands + workflow skeleton),
`references/coverage-codecov.md` (Codecov wiring), `references/ai-reviewers.md`
(the two reviewer recipes + security model).

## When to use, when to skip

**Use when**:
- A project has tests but no CI, or has CI but no coverage gate / AI review.
- You want a coverage badge + external dashboard at a target threshold.
- You want automated code review on PRs via kukuvaia or Claude.

**Skip when**:
- The project already has a CI workflow you're happy with — edit it by hand, or
  use this skill's `--reviewer`/coverage additions surgically (Step 4 can target a
  single concern).
- There are no tests yet — write them first (`/implement`, `/scenario`). A
  coverage gate over an empty suite is theatre.
- You need CD / deployment — out of scope (this skill is CI + review only; see
  Notes for why).

## Relationship to other skills & rules

- **`/implement`** — upstream and the source of stack detection. This skill reuses
  the runner-detection heuristics documented in `/implement`'s
  `references/runner-detection.md` (package-manager + test-runner per stack).
- **`/setup`** — sibling. `/setup` scaffolds `docs/`; `/ci-setup` scaffolds CI.
  Neither depends on the other, but a CI architecture doc (Step 4, optional) lands
  under `docs/architecture/` if that tree exists.
- **`/e2e-run` + `/scenario`** — if the project has `tests/e2e/`, this skill can
  add an (opt-in, self-hosted) e2e job that calls them. It does not author e2e
  tests.
- **`/agents-md`** — orthogonal. AGENTS.md may carry a project rule like "LLM
  calls go through <internal gateway>"; this skill respects it when choosing the
  reviewer (prefers the internal-infra reviewer where such a rule exists).
- **`~/.claude/rules/`** (read-only) — language rules (`python.md`, `node.md`,
  `typescript.md`, `react.md`) already state **"80%+ coverage"**; this skill's
  default gate encodes that. `security.md` governs **no hardcoded secrets** — all
  tokens come from GitHub Secrets/Variables, never literals. Do not duplicate or
  modify these rules; reference them.

## Output language

All persisted artifacts — workflows, scripts, config, the architecture doc,
comments — are written in **English** (global policy, `~/.claude/CLAUDE.md` §13).
User-facing prompts may follow the user's working language.

## Initial Response

When invoked:

1. **Args/flags given** (`/ci-setup --coverage 80 --reviewer kukuvaia`): capture
   them as defaults; jump to Step 0.
2. **No args**: proceed to Step 0 — the skill detects and asks interactively.

## Process

### Step 0: Preconditions

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
git remote get-url origin 2>/dev/null     # host → provider sanity (GitHub assumed)
ls .github/workflows/ 2>/dev/null
```

- Not a git repo → print that CI needs a repo + remote, STOP.
- Remote is not GitHub and `--provider` is unset → tell the user GitHub Actions is
  the only provider in v1; ask whether to generate GitHub workflows anyway or
  STOP. (Other providers are a documented extension, not v1.)
- `.github/workflows/` already has a `ci.*` → not fatal; Step 4 collision-handles.

### Step 1: Detect the stack(s)

Per `references/ci-recipes.md` (which mirrors `/implement`'s runner-detection):

| Marker | Stack | Default commands |
|---|---|---|
| `pyproject.toml` / `uv.lock` | Python (uv) | lint `ruff check`, test `pytest --cov` |
| `package.json` | Node | `npm ci`, lint/`test` scripts; detect vitest vs jest |

Detect coverage tooling already present (`pytest-cov`, `@vitest/coverage-v8`,
jest `--coverage`) and the test framework. A monorepo may match both (e.g. a
Python backend + a `frontend/` Node app) → plan one job per surface. Print the
detected matrix:

```
Detected: Python (uv, pytest) at ./ · Node (vitest) at ./frontend
Coverage tooling: pytest-cov MISSING · @vitest/coverage-v8 MISSING
```

If a stack isn't covered by v1 recipes, say so explicitly and emit a
`# TODO: add <stack> recipe` placeholder rather than guessing commands.

### Step 2: Resolve options

Honor flags; otherwise ask (one AskUserQuestion with the open decisions). Defaults
in parentheses:

- **Coverage threshold** (`80`). Before locking a *hard* gate, optionally measure
  current coverage (offer to run the stack's coverage command). If a surface is
  **below** the threshold, default that surface to a **non-blocking warning**
  (`continue-on-error`) and say so — a hard gate that's red on commit #1 helps
  no one. Record the gap so it's visible (see `references/ci-recipes.md`
  § "Hard gate vs warning").
- **Coverage tool** (`codecov`). `codecov` or `none` (CI-only summary + badge).
- **AI reviewer** (`ask`). `kukuvaia` · `claude` · `none`. See
  `references/ai-reviewers.md` for the trade-offs to surface — notably: a
  self-hosted kukuvaia runner reaches an internal LLM gateway and honors a
  "reuse-internal-infra" AGENTS.md rule, while the Claude Code Action is
  zero-infra but needs `ANTHROPIC_API_KEY` and calls Anthropic directly.

### Step 3: Human-review gate (mandatory)

Present the **exact file plan** before writing anything: each file, each job,
which gates are hard vs warning, and the **manual follow-ups** (secrets/vars the
user must add). Then:

AskUserQuestion:
- question: "Generate this CI/CD setup?"
  header: "Confirm CI"
  options:
  - label: "Generate these (Recommended)"
    description: "Write the confirmed workflows / config / scripts."
  - label: "Revise first"
    description: "Adjust threshold / reviewer / coverage tool / scope before writing."
  - label: "Plan only — no files yet"
    description: "Print the plan, write nothing."
  multiSelect: false

No file is written on "Revise" (loop Step 2) or "Plan only" (STOP after printing).

### Step 4: Generate files

Per the references, for the confirmed choices:

- **`.github/workflows/ci.yml`** — one job per detected surface; each runs deps →
  lint → test-with-coverage. Backend coverage gate via the stack's native flag
  (e.g. `pytest --cov-fail-under=<pct>`); frontend via the runner's thresholds.
  Cache heavy assets (language toolchain; model/data caches when relevant).
- **Codecov** (if chosen) — add the `codecov/codecov-action@v4` upload step
  (token from `secrets.CODECOV_TOKEN`), coverage output in a machine-readable
  format (`coverage xml` / `lcov`), and a README badge. See
  `references/coverage-codecov.md`.
- **AI review** (if chosen) — generate `.github/workflows/pr-review.yml` plus, for
  `kukuvaia`, `scripts/ai_review.py` (stdlib-only, SSE) and the self-hosted job
  gated by a repo variable + same-repo guard; for `claude`, the
  `anthropics/claude-code-action` job keyed on `ANTHROPIC_API_KEY`. Exact recipes
  in `references/ai-reviewers.md`.
- **Coverage config** — add the coverage dependency + thresholds to the project's
  config (`pyproject.toml` dev group, `vite.config.ts`/jest config). Update
  lockfiles only with the user's go-ahead (they may prefer to run install
  themselves).
- **Architecture doc** (optional, only if `docs/architecture/` exists) —
  `docs/architecture/ci-cd.md` describing the tiers + how to enable the reviewer.

Every generated workflow opens with a one-line banner: which skill authored it,
the date, and "do NOT store secrets here". Selectors/commands trace to the
detected stack, not to guesses.

### Step 5: Write + collision handling

Write the confirmed files. For each existing target, never clobber silently:

AskUserQuestion (per real collision):
- question: "<path> already exists. How to proceed?"
  header: "Collision"
  options:
  - label: "Overwrite"
    description: "Replace it. Lost unless committed."
  - label: "Write as <name>-v2"
    description: "Preserve the existing file; new content lands at a sibling."
  - label: "Skip this file"
    description: "Leave the existing file; continue with the rest."
  multiSelect: false

Config edits (pyproject/vite.config) are surgical `Edit`s, never full rewrites.

### Step 6: Hand off

Print the summary + the manual TODO list (this is load-bearing — half of CI is
secrets/vars the skill must NOT set):

```
═══════════════════════════════════════════════════════════
  CI/CD SCAFFOLDED
═══════════════════════════════════════════════════════════
  Surfaces:    <python ./, node ./frontend>
  Coverage:    gate <pct>%  (backend hard · frontend warning)
  Dashboard:   Codecov  (badge added to README)
  AI review:   <kukuvaia self-hosted | claude action | none>
  Generated:
    - .github/workflows/ci.yml
    - .github/workflows/pr-review.yml          (if reviewer)
    - scripts/ai_review.py                      (if kukuvaia)
    - docs/architecture/ci-cd.md                (if docs/ exists)

  ► YOUR manual steps (the skill cannot do these):
    - Add repo secret CODECOV_TOKEN            (Settings → Secrets → Actions)
    - <reviewer-specific: ANTHROPIC_API_KEY  OR  register self-hosted runner
       + set repo var SELF_HOSTED_CI=true>
    - Verify locally: <stack coverage command>, then commit + push.
═══════════════════════════════════════════════════════════
```

STOP. Do not run `setup.sh`, install deps, commit, or push.

## Critical guardrails

1. **Human-review gate before any write.** Step 3 is a hard stop. "Plan only" is a
   valid terminal state.
2. **Never store secrets.** Tokens (`CODECOV_TOKEN`, `ANTHROPIC_API_KEY`) and hosts
   come from GitHub Secrets/Variables, referenced as `${{ secrets.* }}` /
   `${{ vars.* }}` — never literals in a workflow or script (`security.md`).
3. **Honest coverage gates.** Measure before locking a hard threshold; a surface
   below target is a `continue-on-error` warning with the gap logged, not a
   silent pass and not a red-on-day-one block.
4. **Self-hosted = same-repo only.** Any `runs-on: self-hosted` job carries a guard
   so it never executes fork-PR code on the user's machine, and stays *skipped*
   (not pending) until an explicit opt-in variable is set.
5. **Respect the project's LLM-routing rule.** If AGENTS.md mandates an internal
   gateway (e.g. kukuvaia), recommend the kukuvaia reviewer and flag the tension
   if the user picks the direct-Anthropic action anyway. The choice is theirs;
   the surfacing is mandatory.
6. **Detect, don't guess.** Commands come from the detected stack via
   `references/ci-recipes.md`. An unknown stack gets a `# TODO` placeholder, never
   a fabricated command.
7. **No auto-install / commit / push / setup.sh.** This skill writes files and
   hands off. Every state-changing follow-up is the user's explicit step.

## Notes

- **Reference implementation.** The recipes are distilled from a real setup
  (Python/uv + React/Vite + kukuvaia review + Codecov-style coverage). The
  `references/` files are the portable form of that.
- **Why CI-only (no CD).** Deployment shape is project-specific (provider, region,
  rollout). Generating a deploy pipeline blind is worse than none. A future
  `--deploy` extension could add it once the target is known.
- **Extensibility.** v1 detects Python + Node. Adding a stack = adding a recipe
  block to `references/ci-recipes.md` (commands + coverage flag + format) — the
  Process needs no change. Other CI providers (GitLab, etc.) are a similar
  recipe-level extension.
- **Copilot.** Skills are Claude Code-only. A copy-paste `copilot/prompts/`
  template mirroring this skill is possible future work, not part of v1.
