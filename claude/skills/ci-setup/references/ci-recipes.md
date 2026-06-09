# CI recipes (canonical reference for /ci-setup)

Per-stack commands and the GitHub Actions skeleton `/ci-setup` emits. v1 covers
**Python (uv)** and **Node (npm)**. Mirrors `/implement`'s `runner-detection.md`
for marker → tool mapping; coverage is the addition.

## Stack detection → commands

### Python (uv)

- **Markers**: `pyproject.toml`, `uv.lock`. Source dir: the top-level package (e.g.
  `app/`, `src/`); test dir `tests/`.
- **Coverage dep**: `pytest-cov` (add to `[dependency-groups] dev`).
- **Commands**:
  - install: `uv sync --frozen`
  - lint: `uv run ruff check <pkg> tests` (only if ruff is configured)
  - test + gate: `uv run pytest --cov=<pkg> --cov-report=term-missing --cov-report=xml --cov-fail-under=<PCT>`
  - `--cov-report=xml` → `coverage.xml` for Codecov.
- **Python setup**: `astral-sh/setup-uv@v6` with `python-version` from
  `requires-python`; `enable-cache: true`.

### Node (npm)

- **Markers**: `package.json` (+ `package-lock.json` → `npm ci`). A `frontend/`
  (or similar) subdir with its own `package.json` is its own surface.
- **Test runner**: detect `vitest` vs `jest` in devDependencies / scripts.
- **Coverage dep**: vitest → `@vitest/coverage-v8`; jest → built-in (`--coverage`).
- **Commands**:
  - install: `npm ci`
  - lint: `npm run lint` (if a `lint` script exists)
  - test: `npm run test` (blocking — unit tests must pass)
  - coverage: vitest `npx vitest run --coverage` (thresholds in `vite.config.ts`
    `test.coverage.thresholds`); jest `npx jest --coverage --coverageThreshold ...`
    (or `coverageThreshold` in jest config). Coverage reporter must include
    `lcov` (→ `coverage/lcov.info`) for Codecov.
- **Node setup**: `actions/setup-node@v4`, `node-version` (LTS, e.g. `22`),
  `cache: npm`, `cache-dependency-path: <dir>/package-lock.json`.

> Unknown stack → emit `# TODO: add <stack> recipe (lint/test/coverage command + report format)` and do not fabricate commands.

## Hard gate vs warning

The coverage gate must reflect reality on day one:

- **At/above target** → **hard gate** (the run fails below the threshold):
  - Python: `--cov-fail-under=<PCT>` (built-in fail).
  - Node: thresholds in the runner config → non-zero exit; keep the step blocking.
- **Below target** → **warning**: keep the threshold in config (so the gap is
  visible and `coverage` fails locally), but mark the CI coverage step
  `continue-on-error: true` and name it `Coverage (warning until <PCT>%)`. Print
  the current number in the plan so the user sees the gap. Removing
  `continue-on-error` later is the one edit that promotes it to a hard gate.
- Keep **unit tests themselves blocking** regardless: run `npm run test` as a
  separate, always-blocking step, and the coverage run as its own step. (A single
  `--coverage` invocation with `continue-on-error` would let unit failures pass.)

## Workflow skeleton

```yaml
name: CI

on:
  push:
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # ── one job per detected surface ──
  backend:                       # Python example
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v6
        with: { enable-cache: true, python-version: "<from requires-python>" }
      # (optional) cache big model/data dirs the test suite downloads:
      # - uses: actions/cache@v4
      #   with: { path: ~/.cache/<...>, key: <stable-key> }
      - run: uv sync --frozen
      - run: uv run ruff check <pkg> tests        # if ruff configured
      - run: uv run pytest --cov=<pkg> --cov-report=term-missing --cov-report=xml --cov-fail-under=<PCT>
      # + Codecov upload step → see coverage-codecov.md

  frontend:                      # Node example
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: <dir> } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "22", cache: npm, cache-dependency-path: <dir>/package-lock.json }
      - run: npm ci
      - run: npm run lint
      - run: npm run test                          # blocking unit tests
      - name: Coverage (warning until <PCT>%)      # if below target
        continue-on-error: true
        run: npm run coverage                       # vitest run --coverage / jest --coverage
      # + Codecov upload step → see coverage-codecov.md
```

`concurrency` cancels superseded runs on the same ref. `push:` (no branch filter)
+ `pull_request: [main]` is the default trigger; `pull_request` may double-run on
PR branches — acceptable, and concurrency de-dupes within a ref.
