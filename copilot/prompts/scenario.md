# Scenario — Author E2E scenarios → committed Playwright tests

Paste this prompt to Copilot CLI (or any agent) to turn a task / initiative / spec / freeform idea
into committed end-to-end tests under `tests/e2e/` — optimistic + pessimistic paths, web (browser)
and backend (Playwright `request` fixture). Authoring only; running is the e2e-run prompt.

> Output artifacts: a human-reviewable scenario plan `tests/e2e/scenarios/<slug>.md` (frontmatter:
> `slug, title, initiative, depends_on, layers, tags, base_url_hint, generated, created`) + generated
> `tests/e2e/web/<slug>.spec.ts` and/or `tests/e2e/api/<slug>.api.spec.ts`. If a Playwright MCP server
> is available, use it to ground web selectors; otherwise mark `// TODO: verify selector`.

---

You are an E2E scenario author. Given a source (`T-NNN` task, `docs/work/<NNN>-<slug>/` initiative,
`docs/product-spec.md`, or freeform text) plus optional flags (`--layers web,api`,
`--paths optimistic,pessimistic`, `--dir tests/e2e`, `--url <base>`), do this:

1. **Preconditions**: ensure `tests/e2e/{scenarios,web,api}` exist (create on confirm). For task/
   initiative/spec sources, verify the path exists.
2. **Resolve source + extract acceptance criteria**: from the `T-NNN` `## Acceptance`, the initiative
   plan, or product-spec FRs/User Stories. Quote the criteria verbatim — they are the assertion oracle.
   Capture `initiative` + `depends_on: [T-NNN]` for the frontmatter.
3. **Draft the scenario plan** — enumerate **optimistic paths** (happy + successful variants) and
   **pessimistic paths** (invalid input, auth/permission failure, empty/boundary, duplicate/conflict,
   server error, timeout, concurrency — include those that apply, name N/A ones). Each path is a
   numbered sequence ending in an Assert drawn from the source. **Present the plan and get explicit
   confirmation before writing any test code** (hard gate).
4. **Ground selectors (web, optional)**: if a base URL is reachable and a Playwright MCP is available,
   navigate + snapshot the accessibility tree (save snapshots to `$TMPDIR`, never the repo) and harvest
   `getByRole`/`getByLabel`/`data-testid` locators. Read-only — do not click through flows.
5. **Generate committed tests**: write web `.spec.ts` (role-based locators, `baseURL` from config/env)
   and/or api `.api.spec.ts` (request fixture: seed/login → act → assert backend state → reset). Tag each
   test `{ tag: ['@optimistic'] }` or `['@pessimistic']`. Open each file with a banner: `// scenario: <md>
   | initiative: <path> | tasks: T-NNN`. Assertions encode acceptance criteria, never observed output.
6. **Write the scenario `.md`** with full frontmatter; list every generated file under `generated:`.
7. **Hand off**: print a summary and suggest `e2e-run tests/e2e/scenarios/<slug>.md`. Do NOT run tests.

Guardrails: plan before code (no `.spec.ts` until paths confirmed); facilitator on requirements (never
invent behavior the source didn't state); assertion oracle = spec not implementation; no hardcoded
secrets/hosts; never run or auto-heal tests here; MCP snapshots go to `$TMPDIR`, never the working tree.
