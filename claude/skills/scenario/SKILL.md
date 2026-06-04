---
name: scenario
description: >
  Author end-to-end test scenarios (optimistic + pessimistic paths) from a task,
  initiative, product-spec, or freeform description, and generate committed
  Playwright test files into tests/e2e/. Each scenario is a two-part artifact: a
  human-reviewable plan (tests/e2e/scenarios/<slug>.md, carrying depends_on links
  to docs/work/<NNN>-<slug>/ initiatives and T-NNN tasks) plus generated
  .spec.ts files — web via the browser, backend via Playwright's request fixture
  — tagged @optimistic / @pessimistic so /e2e-run can scope by path type. The
  plan is a mandatory human-review gate: no test code is written until the user
  confirms the paths. Optionally grounds web selectors against a live app via the
  Playwright MCP for honest role/test-id locators. Does NOT run the tests (that's
  /e2e-run) and never auto-heals. Trigger phrases: "write e2e scenarios",
  "create test scenarios", "scenario for T-NNN", "test the happy and edge paths",
  "author e2e tests".
argument-hint: "<T-NNN | initiative-folder | spec.md | freeform> [--layers web,api] [--paths optimistic,pessimistic] [--dir tests/e2e] [--url <base-url>]"
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
  - mcp__plugin_maister_playwright__browser_navigate
  - mcp__plugin_maister_playwright__browser_snapshot
  - mcp__plugin_maister_playwright__browser_wait_for
  - mcp__plugin_maister_playwright__browser_console_messages
  - mcp__plugin_maister_playwright__browser_close
---

# /scenario — Author E2E Scenarios → committed Playwright tests

This skill turns a unit of intent (a `T-NNN` task, an initiative plan, a
product-spec, or a freeform description) into **durable, re-runnable** end-to-end
test scenarios. It is the authoring half of a two-skill pair: `/scenario` writes,
`/e2e-run` executes.

Every scenario is two coupled artifacts (see `references/scenario-schema.md`):

1. **A scenario plan** — `tests/e2e/scenarios/<slug>.md`, human-reviewable,
   carrying the `depends_on` / `initiative` back-links and the
   **optimistic + pessimistic** path enumeration.
2. **Generated test files** — committed `.spec.ts` under `tests/e2e/web/` and/or
   `tests/e2e/api/`, tagged `@optimistic` / `@pessimistic`, with a banner linking
   back to the plan and the work it traces to.

The plan is a **mandatory human-review gate**: this skill never writes test code
before the user confirms the paths. It is a facilitator on *what to test* and a
generator only of *test scaffolding the user approved* — it never invents
requirements the source did not state.

Read `references/scenario-schema.md` before writing any artifact; re-check
against it at every write.

## When to use, when to skip

**Use when**:
- A task / initiative / spec describes behavior worth pinning with re-runnable e2e tests.
- You want both the happy flow and the edge/failure flows captured deliberately.
- You want the tests linked to the work that motivated them (`depends_on: [T-NNN]`).

**Skip when**:
- You just want to *verify a change works once* live — use Claude Code's built-in `/verify`, or `/open-web` to eyeball a page. `/scenario` produces committed tests, not a one-shot check.
- The behavior is pure-internal logic with no e2e surface — that belongs in unit tests via `/implement`, not here.
- You only want to *run* existing scenarios — use `/e2e-run`.

## Relationship to other skills

- `/e2e-run` — the execution half. It reads the scenario plan's `generated:` list
  and `depends_on` to resolve what to run, with the right tool. `/scenario` hands
  off to it but never runs tests itself.
- `/implement` — upstream. A `T-NNN` task's `## Acceptance` block is the richest
  scenario source. Natural flow: `/implement` a task → `/scenario` for its e2e
  coverage → `/e2e-run`. Shares the assertion-oracle rule (assert against
  acceptance criteria, never observed output) and the modify-in-place discipline.
- `/atomize` — defines the `T-NNN` / initiative layout this skill links to
  (`references/task-schema.md` in that skill).
- `/open-web` — the reference for driving the maister Playwright MCP and the
  `$OUT` capture-file discipline reused in Step 3.
- `/kickoff` — delegated to if `docs/` is needed and absent.

## Output language

All persisted artifacts — scenario plans, generated test code, comments — are
written in **English**, regardless of chat language (global policy, `~/.claude/CLAUDE.md` §13).
User-facing prompts may follow the user's working language.

## Initial Response

When invoked:

1. **Source given** (`/scenario T-012`, `/scenario docs/work/004-checkout/`,
   `/scenario docs/product-spec.md`, or freeform text): capture it; jump to Step 0.
2. **No source**: ask what to base scenarios on:

```
What should I write scenarios for? Options:
  - A task:        /scenario docs/work/004-checkout/T-012-checkout.md
  - An initiative: /scenario docs/work/004-checkout/
  - A spec:        /scenario docs/product-spec.md
  - Freeform:      /scenario "user logs in, adds item to cart, checks out"
```

Then STOP.

## Process

### Step 0: Preconditions

Resolve the output dir (`--dir`, default `tests/e2e/`). Ensure its subdirs exist
(create on confirm):

```bash
DIR="${ARG_DIR:-tests/e2e}"
ls -d "$DIR"/scenarios "$DIR"/web "$DIR"/api 2>/dev/null
```

If the source is a `T-NNN` / initiative path, verify `docs/work/` exists. If a
spec path, verify it exists. If `docs/` is entirely absent and the source needs
it, offer to delegate to `/kickoff` via the `Skill` tool; STOP if declined.
A freeform source needs no `docs/`.

### Step 1: Resolve source + extract acceptance criteria

| Source | Where the criteria live |
|---|---|
| `T-NNN-*.md` | `## Acceptance` (richest); fall back to `## Scope` + title |
| initiative folder | each pending/done task's `## Acceptance`; or `plan.md` sections |
| `docs/product-spec.md` | `## Functional Requirements` + `## User Stories` (Given/When/Then) |
| freeform | the text the user gave — ask for the success condition if absent |

Read the source FULLY. Capture, for the frontmatter: `initiative` (folder path or
null), `depends_on` (the `T-NNN` ids this scenario will exercise). **Quote the
acceptance criteria verbatim** into the plan's `## Source` — they are the
assertion oracle.

If the source names no observable success condition, ask: "What observable
outcome proves the optimistic path worked?" before continuing.

### Step 2: Draft the scenario plan (human-review gate)

Enumerate paths. This is the core of the skill — be concrete and domain-specific,
never generic.

- **Optimistic paths** — the expected-success flows. Usually 1–3: the primary
  happy path plus meaningful successful variants (e.g. valid-with-coupon).
- **Pessimistic paths** — the failure/edge flows the system must handle
  gracefully. Walk the standard families and include those that apply, naming why
  any is N/A: invalid input · auth/permission failure · empty/boundary state ·
  duplicate/conflict · upstream/server error · timeout/slow response · concurrent
  modification. Honor `--paths` if the user scoped it (e.g. `--paths optimistic`).

Write each path as a numbered, observable sequence ending in an **Assert** drawn
from the source. Decide the layers (`--layers`, default both where applicable):
`web` for browser-visible flows, `api` for backend/contract assertions.

Present the full plan (paths + which layers each maps to) and get explicit
confirmation via AskUserQuestion:

- question: "Here are the optimistic + pessimistic paths I'll turn into tests. Generate them?"
  header: "Confirm paths"
  options:
  - label: "Generate these (Recommended)"
    description: "Write the scenario plan + the tagged .spec.ts files for the confirmed paths."
  - label: "Revise paths first"
    description: "Add / remove / reword paths before any code is written."
  - label: "Plan only — no test code yet"
    description: "Write tests/e2e/scenarios/<slug>.md but skip code generation. You'll generate later."
  multiSelect: false

Do NOT write test code on "Revise" (loop) or "Plan only" (write the `.md`, then
jump to Step 6).

### Step 3: Live-ground selectors (web layer; optional, recommended)

Only if generating a `web` layer AND a base URL is available (`--url`, or
`base_url_hint` from the source, or ask once). Drive the maister Playwright MCP
to read the real accessibility tree so generated locators are honest:

1. Check `mcp__plugin_maister_playwright__browser_navigate` is available. If not,
   skip grounding (don't fail) — generate with `// TODO: verify selector` markers.
2. Set the capture dir like `/open-web`: `OUT="${TMPDIR:-/tmp}/scenario"; mkdir -p "$OUT"`.
   **Always pass absolute `$OUT/<slug>.md` filenames** to MCP calls — a bare
   filename pollutes the working tree.
3. `browser_navigate` to the URL, `browser_wait_for` body, `browser_snapshot`
   to `$OUT/<slug>.md`. If the page is an auth wall, STOP grounding and tell the
   user to log in in the opened browser, then re-run (mirror `/open-web` Step 2);
   generate with TODO markers in the meantime.
4. Harvest `getByRole` / `getByLabel` / `data-testid` locators from the snapshot
   for the elements the optimistic/pessimistic steps touch. Do NOT click through
   flows — this is read-only grounding, not execution.

Grounding never runs the test; it only makes the *generated selectors* real.

### Step 4: Generate committed tests

For each confirmed layer, write per `references/scenario-schema.md`:

- `tests/e2e/web/<slug>.spec.ts` — browser steps; role-based locators first;
  `baseURL` from config/env, never hardcoded; each test tagged `@optimistic` or
  `@pessimistic`.
- `tests/e2e/api/<slug>.api.spec.ts` — Playwright `request` fixture; stateful
  flow seed/login → act → assert backend state → reset; tokens from env/fixtures.

Every test file opens with the back-link banner (scenario path, initiative,
tasks, generation date, "do NOT auto-heal" note). **Assertions come from the
acceptance criteria captured in Step 1 — never from what the app happens to
return.** If a `tests/e2e/playwright.config.ts` is absent, offer to create a
minimal one (testDir, baseURL from env, trace on-first-retry); do not force it.

### Step 5: Write the scenario plan `.md`

Write `tests/e2e/scenarios/<slug>.md` with the full frontmatter (slug, title,
initiative, depends_on, layers, tags, base_url_hint, generated, created) and the
`## Source` / `## Optimistic paths` / `## Pessimistic paths` body. List EVERY
generated file under `generated:` — it is the scenario's full footprint.

Slug: kebab-case from the title/source, ≤ 5 meaningful words. Collision check
`tests/e2e/scenarios/<slug>.md`; if it exists, ask overwrite / suffix `-2` / cancel.

### Step 6: Hand off

Print the summary and STOP. Do NOT run tests. Do NOT commit (the user commits, or
runs `/e2e-run` first).

```
═══════════════════════════════════════════════════════════
  SCENARIO AUTHORED
═══════════════════════════════════════════════════════════

  Slug:            <slug>
  Source:          <T-NNN | initiative | spec | freeform>
  Links:           initiative <path|none> · depends_on [<T-NNN...>]
  Optimistic:      <N> paths
  Pessimistic:     <M> paths
  Layers:          <web, api>
  Grounded:        <live via MCP | skipped — TODO selectors | n/a (api only)>
  Generated:
    - tests/e2e/scenarios/<slug>.md
    - tests/e2e/web/<slug>.spec.ts
    - tests/e2e/api/<slug>.api.spec.ts

  ► Next:  /e2e-run tests/e2e/scenarios/<slug>.md
═══════════════════════════════════════════════════════════
```

## Critical guardrails

1. **Plan before code — always.** The Step 2 confirmation is a hard gate. No
   `.spec.ts` is written until the user approves the paths. "Plan only" is a valid
   terminal state.
2. **Facilitator on requirements.** Optimistic and pessimistic paths are derived
   from the source's acceptance criteria, not invented. If a path needs a fact the
   source doesn't state, ask — don't fabricate behavior.
3. **Assertion oracle = spec, never the implementation.** Generated assertions
   encode what *should* happen (acceptance criteria), not what the running app
   currently returns. Asserting observed output cements bugs.
4. **No hardcoded secrets or hosts.** Base URLs and tokens come from env / config.
   This mirrors `/implement`'s security-baseline SEC-01.
5. **Never auto-heal, never run here.** This skill authors and grounds; it does
   not execute tests and does not "fix tests until green". Execution and any
   revision are explicit, human-driven, separate steps (`/e2e-run`, or re-running
   `/scenario`).
6. **Capture files stay out of the tree.** MCP snapshots go to `$OUT`
   (`${TMPDIR:-/tmp}/scenario`) as absolute paths, exactly like `/open-web`.

## Notes

- The two-tier split (live-ground → committed file) follows the 2026 Playwright
  consensus recorded in `docs/analyzes/e2e-scenario-skill-web-backend-decision.md`:
  MCP for honest selectors, a committed `.spec.ts` for CI. MCP is the grounding
  tool, not the runner.
- Backend scenarios use Playwright's `request` fixture by default (one runner,
  shared auth/state). Dedicated API tools (Hurl, Schemathesis) are an opt-in
  concern of `/e2e-run`, not this skill.
- Wrapping Playwright's official Test Agents (Planner/Generator/Healer) is a
  possible future swap inside Step 4 — out of scope until their Claude-Code-CLI
  usability is confirmed (open question in the research doc).
