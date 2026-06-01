---
paths:
  - "**/*.e2e.ts"
  - "**/*.e2e.tsx"
  - "**/e2e/**/*.ts"
  - "**/tests/e2e/**"
  - "**/playwright/**/*.ts"
  - "**/playwright.config.*"
---
# End-to-End Testing Standards

E2E tests exist to catch what unit tests and per-edit hooks cannot: bugs that only appear when a request crosses system boundaries (auth → routing → API → DB → render). They are expensive, so each one must earn its place.

## When a behavior needs E2E (vs a unit test)

- The risk crosses **multiple system boundaries** (auth, routing, API, database) or exists **only in the rendered UI** → E2E.
- Otherwise a unit/integration test is cheaper and more precise — don't reach for E2E by default.
- Mock only **expensive or non-deterministic external** services (LLM, payments) at the HTTP layer. Keep internal boundaries real — mocking them makes the test lie about integration.

## Writing a test

- **Role-based selectors** (`getByRole`, `getByLabel`) over CSS/structure (`div:nth-child(3) > button`). Structural selectors break on unrelated markup changes.
- **Independent tests**: each test does its own setup → act → assert → cleanup. No shared mutable state, no order dependence — a second run must pass as cleanly as the first.
- **Wait for state, not time**: `waitForResponse` / `toBeVisible`, never `waitForTimeout(ms)`. Fixed sleeps are flaky and slow.
- **Unique data** per run (`` `user-${Date.now()}@x.test` ``) so reruns don't collide with leftover rows.
- **Name the assertion after the risk it guards** — the test name should say what user-facing failure it prevents, not which function it calls.
- **Auth once via `storageState`**: log in a single time, save the state, inject it per test (`use: { storageState }` + a `setup` project). Login/register get their *own* dedicated tests; nothing else depends on the login UI.

## Quality gate — the five anti-patterns (reject on review)

1. **Naive assertion** — passes but doesn't actually check the risk.
2. **Brittle selector** — coupled to DOM structure or nth-child.
3. **Shared state** — tests leak into each other.
4. **`waitForTimeout`** — instead of waiting for a real response/state.
5. **No cleanup** — leftover rows break the next run (unique-constraint violations).

## Two checks that catch a fake-green test

- **Control question**: *would this assertion fail if the risk it guards actually materialized?* If not, the test protects nothing.
- **Deliberate breakage**: invert the protected behavior in the application code, confirm the test goes red, then **revert immediately — never commit the break**. A test that stays green when you break the code is theatre.

## Driving the browser

- For an agent **driving multi-step test scenarios** (click → fill → assert loops), prefer the Playwright **CLI** — the MCP server can cost ~4× the tokens. Reserve the Playwright MCP server (e.g. the `/open-web` skill) for one-shot reads of a rendered or auth-walled page.
- Reach for vision/screenshot verification only for layout regressions the accessibility tree can't express — it's a narrow supplement, not the default. Deterministic snapshot assertions are preferred for pixel regression.
