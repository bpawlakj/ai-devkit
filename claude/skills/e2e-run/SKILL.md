---
name: e2e-run
description: >
  Discover and run the end-to-end tests authored by /scenario, with the right
  tool per artifact type and scoped to what you ask for. Default runner is
  Playwright (web .spec.ts via the browser, API .api.spec.ts via the request
  fixture); dedicated API tools — Hurl, Schemathesis — are opt-in extensions for
  plain-text or OpenAPI-derived specs. Resolves scope from a scenario plan, an
  initiative folder, a T-NNN task (via depends_on), a path-type tag
  (@optimistic / @pessimistic), or a layer. Reports pass/fail per layer and per
  path type with trace artifacts. Strictly reports failures — never regenerates
  or auto-heals tests. Optionally appends a one-line result note to the linked
  T-NNN task. Trigger phrases: "run e2e", "run the scenarios", "e2e-run T-NNN",
  "run pessimistic paths", "execute the e2e tests".
argument-hint: "[scenario.md | initiative-folder | T-NNN | tests/e2e | all] [--grep @optimistic|@pessimistic] [--layer web|api] [--headed] [--dir tests/e2e]"
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - Agent
  - Skill
---

# /e2e-run — Run E2E Scenarios with the Right Tool

This skill is the execution half of the e2e pair: `/scenario` authors committed
tests, `/e2e-run` runs them. It discovers what exists under `tests/e2e/`, detects
the right tool per artifact, resolves the scope you asked for, runs, and reports.

It is **report-only on failure**: it never regenerates, edits, or "heals" tests
to make them pass. Fixing a failing test is a deliberate, human-driven step
(re-run `/scenario`, or hand-edit) — never a side effect of running.

Tool mapping and scoping rules live in `references/runner-detection.md`; read it
once per session before the first run.

## When to use, when to skip

**Use when**:
- You have scenarios under `tests/e2e/` (from `/scenario`) and want them run.
- You want to run a subset — one initiative, one task's scenarios, or only the
  pessimistic paths.
- You want a structured pass/fail report with trace artifacts.

**Skip when**:
- No committed scenarios exist yet — author them with `/scenario` first.
- You want a one-shot live check of a change — use built-in `/verify` or `/open-web`.
- You want the project's unit suite — that's `/implement`'s runner, not this.

## Relationship to other skills

- `/scenario` — the authoring half. `/e2e-run` reads the scenario plan's
  `generated:` list and `depends_on` / `initiative` frontmatter to resolve scope.
  On failure it points back to `/scenario` for human-driven revision — it does not
  revise itself.
- `/implement` — `/e2e-run` reuses its runner-detection and package-manager
  conventions (Step 2.4) and its `extensions/` mechanism. Natural flow:
  `/implement` → `/scenario` → `/e2e-run`.
- `extensions/` (next to this SKILL.md) — opt-in API runners (Hurl, Schemathesis)
  for `.hurl` / OpenAPI specs. Discovered via `*.opt-in.md`; enabled per project,
  recorded in `tests/e2e/extensions.md`. Authoring contract: `extensions/README.md`.
- `/setup` — delegated to only if `docs/` is needed for `T-NNN` / initiative
  scope resolution and is absent.

## Output language

Any persisted output — the optional task `## Notes` result line, `tests/e2e/extensions.md`
— is **English** (global policy §13). User-facing prompts may follow chat language.

## Initial Response

When invoked:

1. **Scope given** (`/e2e-run tests/e2e/scenarios/checkout.md`, `/e2e-run T-012`,
   `/e2e-run docs/work/004-checkout/`, `/e2e-run all`): jump to Step 0.
2. **No scope**: glob `tests/e2e/scenarios/*.md`. If none, print "No scenarios
   found under tests/e2e/. Author some with /scenario first." and STOP. If some
   exist, list them and ask which scope to run (all / pick one / by initiative).

## Process

### Step 0: Discover tests + detect runner

Resolve `--dir` (default `tests/e2e/`). Glob the tree:

```bash
DIR="${ARG_DIR:-tests/e2e}"
find "$DIR" -type f \( -name '*.spec.ts' -o -name '*.hurl' \) 2>/dev/null | sort
ls "$DIR"/scenarios/*.md 2>/dev/null
```

Detect tools per `references/runner-detection.md`:
- `.spec.ts` → Playwright. Confirm `@playwright/test` resolves; if absent, STOP
  and offer the install command (`npm/pnpm/yarn i -D @playwright/test && npx
  playwright install`) — do not auto-install. Note if browsers aren't installed.
- `.hurl` / OpenAPI present → an extension is needed (Step 2).

### Step 1: Resolve scope

Map the argument to a concrete file set (print it before running):

| Argument | Resolution |
|---|---|
| scenario `.md` | read its `generated:` list — run exactly those files |
| initiative folder | every scenario whose `initiative:` matches → union of their `generated:` |
| `T-NNN` | every scenario whose `depends_on` contains that id |
| `tests/e2e` / `all` / none-picked | the whole tree |

Apply `--layer web|api` (restrict subdir) and remember `--grep` for Step 3.
Print:

```
Resolved scope: <N> test files
  web:  <files>
  api:  <files>
  filter: --grep <tag>   (if any)
```

### Step 2: Extension opt-in (only if non-Playwright artifacts exist)

If `.hurl` files or an OpenAPI spec are in scope, the matching extension must be
enabled. Read `tests/e2e/extensions.md` if present (enablement is locked). Else
glob `extensions/*.opt-in.md`, read each lightweight descriptor, and ask:

- question: "<title> tests are present. Enable the <name> runner for this project?"
  header: "<name>"
  options:
  - label: "Enable (Recommended)"
    description: "Run these specs with <tool>. Requires <tool> installed."
  - label: "Skip — Playwright only"
    description: "Ignore the non-Playwright artifacts this run."
  multiSelect: false

Record choices in `tests/e2e/extensions.md`:

```yaml
---
extensions:
  api-hurl: enabled        # enabled | off
  api-schemathesis: off
recorded: <YYYY-MM-DD>
---
```

Playwright never needs opt-in. If an enabled tool isn't installed, STOP and print
its install command (from the extension's rules file) — never auto-install.

### Step 3: Run

Execute the right command(s), scoped, per `references/runner-detection.md`:

- Playwright: `npx playwright test <resolved files> [--grep <tag>] [--headed]`.
- Hurl (if enabled): `hurl --test <resolved .hurl files>`.
- Schemathesis (if enabled): per `extensions/api-schemathesis.md`.

Run each tool once over its slice. Collect exit codes and output. Do not retry a
failing test or modify any test file.

### Step 4: Report

Print a structured result. Break down by layer and by path type (read the
`@optimistic` / `@pessimistic` tags from results where the runner exposes them):

```
═══════════════════════════════════════════════════════════
  E2E RUN COMPLETE
═══════════════════════════════════════════════════════════

  Scope:        <scenario | initiative | T-NNN | all>  (<N> files)
  Tool(s):      Playwright [+ Hurl / Schemathesis]
  Result:       <PASS | FAIL>

  Web:          <passed>/<total>   (optimistic <a>/<b>, pessimistic <c>/<d>)
  API:          <passed>/<total>

  Failures:
    - <test name>  (<file>:<line>)
        <first failure-message line>
    ...

  Artifacts:    playwright-report/  ·  test-results/<...>/trace.zip
═══════════════════════════════════════════════════════════
```

On failure, **report only**. Offer next steps as choices, all human-driven:
open the trace (`npx playwright show-trace <path>`), re-author with `/scenario`
(if the test itself is wrong), or fix the app. NEVER regenerate the test to make
it pass.

### Step 5: Optional task write-back

If the run mapped to one or more `T-NNN` (via scenario `depends_on`), offer once:

- question: "Append a one-line e2e result note to the linked task(s)' ## Notes?"
  header: "Write-back?"
  options:
  - label: "Yes — append result note"
    description: "Adds a dated one-line PASS/FAIL summary under ## Notes. Never changes task status."
  - label: "No"
    description: "Leave task files untouched."
  multiSelect: false

On yes: append a `### E2E note` line under the task's `## Notes` (create the line
only if `## Notes` exists; never invent the section), English, e.g.
`E2E (2026-06-04): PASS — 6/6 web, 3/3 api (scenario checkout-happy-and-edge).`
**Never flip task `status`** — that is `/implement`'s job, gated on a commit.

## Edge cases

- **No `tests/e2e/`**: nothing to run — point to `/scenario`. STOP.
- **Playwright dep/browsers missing**: STOP with the exact install command; don't
  install silently.
- **Scenario `generated:` lists a file that's gone**: warn (the scenario drifted
  from disk) and run the files that exist; suggest re-running `/scenario`.
- **`T-NNN` matches no scenario**: print "no scenarios depend on T-NNN" and list
  available scopes.
- **Mixed Playwright + extension scope**: run each tool over its own slice; report
  combined; a tool with no enabled extension is skipped with a one-line note (no
  silent drop).

## Critical guardrails

1. **Report-only on failure — never auto-heal.** No regeneration, no test edits,
   no retry-until-green. This is the central discipline (the research pre-mortem:
   self-healing optimizes for *pass*, not *correctness*).
2. **Never auto-install.** Missing Playwright, browsers, Hurl, or Schemathesis →
   surface the command, let the user run it.
3. **Print scope before running.** The user sees exactly which files will run
   before anything executes — no surprise broad runs.
4. **Don't touch task status.** Write-back is an opt-in `## Notes` line only;
   `status` flips belong to `/implement` at a commit boundary.
5. **Extensions are opt-in and recorded.** Non-Playwright tools run only after an
   explicit enable, persisted in `tests/e2e/extensions.md`.

## Notes

- Playwright covers web + API (request fixture) in one runner — the default,
  minimal-sprawl path per `docs/analyzes/e2e-scenario-skill-web-backend-decision.md`.
  Hurl (plain-text API specs) and Schemathesis (OpenAPI fuzz / stateful) are added
  only on a real gap, via the opt-in extension mechanism.
- This skill never drives a live browser via MCP — it runs the real test runner.
  The MCP browser is `/scenario`'s grounding tool, not a runner.
- Trace artifacts (`playwright-report/`, `test-results/`) belong in `.gitignore`.
