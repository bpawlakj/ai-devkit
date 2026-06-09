---
title: E2E scenario authoring + execution skill — web (Playwright) + backend (API)
date: 2026-06-04
type: decision
status: decided
decision: "Build a thin ai-devkit skill (/e2e) on Playwright's two-tier pattern — plan as Markdown → ground live → emit committed .spec.ts; web via browser + backend via Playwright request fixture in one runner; dedicated API tools (Hurl/Schemathesis) as opt-in extension; mandatory human-review gate, no silent auto-heal."
related: []
---

# E2E scenario authoring + execution skill — web (Playwright) + backend (API)

## Context

ai-devkit is a toolkit of Claude Code skills covering the SDLC pipeline
(`/discover` → `/product-spec` → `/save-plan` → `/atomize` → `/implement`).
The pipeline ends at implementation; there is no skill that **authors durable,
re-runnable end-to-end scenarios** and executes them. The user wants to fill
that gap: a skill that creates varied E2E scenarios and runs them — Playwright
for web, REST API / other tools for backend.

The closest existing pieces are all *ephemeral live verification*, not scenario
authoring: Claude Code's built-in `/verify` and `/run` (launch the app, observe
once), ai-devkit's `/open-web` (read one page via Playwright MCP), and the
maister plugin's `e2e-test-verifier` agent (interactive browser verification
that, by its own contract, **does not generate test files**). None of them
produce a committed, CI-runnable scenario artifact. That is the gap.

This research decides the **shape** of the new skill — authoring artifact,
execution model, backend coverage, and build-vs-reuse — before any code.

## Question

For an ai-devkit skill that must author *and* run E2E scenarios across web and
backend with minimal tool sprawl: what intermediate scenario artifact should it
produce, should scenarios be ephemeral (live-driven each run) or codified into
committed test files, should backend API steps use Playwright's own `request`
fixture or a dedicated API tool, and should we build a thick custom runner/DSL
or a thin wrapper over Playwright's official tooling?

## Findings

### The authoring artifact: Markdown plan → generated TypeScript, not a DSL

The dominant 2026 pattern is a structured **plain-language Markdown plan** that
an agent then turns into test code — *not* Gherkin, YAML, or a JSON DSL as the
spec layer. Playwright's official **Test Agents** (shipped v1.56+) formalize
this: a *Planner* explores the app and emits a human-readable Markdown plan
(`specs/*.md` — app overview, "Before Each" preconditions, numbered scenarios
with deterministic assertions), a *Generator* turns the plan into TypeScript,
and a *Healer* repairs failing tests.
[Playwright Test Agents](https://playwright.dev/docs/test-agents)
The Copilot/MCP community independently converged on the same 1:1
Markdown-prompt → generated-test pattern, explicitly rejecting Gherkin/YAML/code
as the spec layer.
[dev.to/yerac](https://dev.to/yerac/from-acceptance-criteria-to-playwright-tests-with-mcp-4ka6)
YAML-as-spec frameworks exist (terryso) but draw community skepticism.
[currents.dev — state of Playwright AI 2026](https://currents.dev/posts/state-of-playwright-ai-ecosystem-in-2026)

### The execution model: two-tier "explore live → codify into committed spec"

Consensus is a two-tier split: use MCP / live-agent verification for
*discovery and exploratory* testing, then **codify critical paths into committed
`.spec.ts`** for CI/regression. The live tier grounds selectors against the real
app (emitting only verified selectors); the committed tier is what runs in CI
with parallelism and auto-wait.
[Playwright Test Agents](https://playwright.dev/docs/test-agents)
The reason it is two tiers and not one: MCP is roughly **4× more token-heavy**
than the file-based path (~114K vs ~27K tokens for an equivalent task via the
v1.58 Playwright CLI), so live MCP is not a per-run CI mechanism.
[halmurattahir.com](https://www.halmurattahir.com/blog/ai-testing/playwright-mcp-vs-cli-vs-agents-2026/),
[codersera.com](https://codersera.com/blog/generate-playwright-tests-claude-code-cursor-2026/)
Official docs now position MCP for *agentic exploration* and the **CLI + Skills**
path as the lower-token route for coding agents in large codebases.
[playwright.dev/mcp/introduction](https://playwright.dev/mcp/introduction)

### Tooling maturity caveat

The Playwright MCP server (`@playwright/mcp`, microsoft/playwright-mcp) is the
de-facto standard and actively maintained, but **version-wise still pre-1.0**
(~v0.0.75, May 2026) — neither repo nor docs claim GA/stable.
[github.com/microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)
This is the single biggest tooling uncertainty and argues for depending on the
file-based Playwright project (stable, GA) as the durable artifact, with MCP only
in the exploratory tier.

### Web framework choice: Playwright is the agent default

For an AI-agent-driven workflow in 2026, Playwright is the safe default. One-line
verdicts on alternatives:
[BrowserStack 2026](https://www.browserstack.com/guide/cypress-vs-selenium-vs-playwright-vs-puppeteer),
[quashbugs.com](https://quashbugs.com/blog/selenium-alternatives-2026)
- **Cypress** — close second for front-end teams who prize debugging; weaker multi-tab/cross-origin.
- **Selenium** — only for legacy / widest language+browser+mobile reach; not agent-friendly.
- **WebdriverIO** — strong for native-mobile/cloud-grid; no agent advantage over Playwright.
- **Puppeteer** — "no reason to choose over Playwright for testing in 2026."

For business-readable suites, **playwright-bdd** compiles Gherkin `.feature` →
Playwright runner, but adds a two-layer indirection (feature + step defs) the
agent must keep in sync — a cost for AI authoring. Keep it as an opt-in for
stakeholder-facing suites only; default to plain TS `describe/test` (least
indirection, easiest single-file authoring/refactor).
[github.com/vitalets/playwright-bdd](https://github.com/vitalets/playwright-bdd),
[testdino.com/blog/playwright-bdd](https://testdino.com/blog/playwright-bdd)

### Backend / API: Playwright `request` fixture for both, dedicated tool only on a real gap

Playwright's built-in `request` / `APIRequestContext` (GA) sends HTTP without a
browser and — critically — **shares auth/cookies/storage with the browser
context**. The established mixed-scenario flow is: seed/login via API → drive UI
→ assert backend state via API (especially data not shown in the UI) → reset via
API. One runner, one CI job, one report.
[playwright.dev/docs/api-testing](https://playwright.dev/docs/api-testing),
[combined UI+API testing](https://medium.com/@whafner0/combined-ui-api-testing-with-playwright-fbe91779eeb8)

Playwright's request layer is **not enough** when you need property-based
fuzzing, consumer-driven contracts, or load — it does none natively. Dedicated,
CLI/git-friendly tools worth naming:
[getautonoma.com](https://getautonoma.com/blog/playwright-api-testing-guide)
- **Hurl** (GA) — plain-text `.hurl` HTTP files, JSONPath asserts, request chaining/capture, single Rust binary. Most agent/git-friendly for browser-free API specs. [github.com/Orange-OpenSource/hurl](https://github.com/Orange-OpenSource/hurl)
- **Schemathesis** (GA) — property-based + **stateful** tests auto-derived from an OpenAPI/GraphQL spec; covers sequences other tools skip. [github.com/schemathesis/schemathesis](https://github.com/schemathesis/schemathesis)
- **Bruno** (GA) — git-native `.bru` collections, `bru run` CLI. [docs.usebruno.com/bru-cli](https://docs.usebruno.com/bru-cli/overview)
- **Step CI** (GA, MIT) — generates multi-step YAML workflows from OpenAPI; HTTP/gRPC/WebSocket. [docs.stepci.com/import/openapi](https://docs.stepci.com/import/openapi.html)
- **Pact** (contract), **k6** (load+functional checks), **Tavern** (YAML/pytest), **Karate/REST-assured** (JVM) — duplicate Playwright's request layer without the shared-state payoff inside a Playwright-centric skill.

**Subagent verdict:** for one skill covering web + backend with minimal sprawl,
**Playwright for both is the pragmatic 2026 answer**; add exactly one dedicated
tool only on a concrete gap — Hurl (language-agnostic plain-text API specs) or
Schemathesis (OpenAPI fuzz/stateful coverage Playwright can't produce).

### Known failure modes of AI-authored E2E (must design against)

- **Auto-heal that optimizes for green, not correct.** An agent allowed to
  regenerate until tests pass optimizes for success, not correctness — self-heal
  must emit **PR-reviewable patches, never silent rewrites**, preserving the
  audit trail.
  [dev.to/yerac](https://dev.to/yerac/from-acceptance-criteria-to-playwright-tests-with-mcp-4ka6),
  [qawolf.com](https://www.qawolf.com/blog/self-healing-test-automation-types)
- **Asserting against the implementation.** The assertion oracle must come from
  spec/acceptance criteria, not the code's own output (mirrors ai-devkit's
  existing `/implement` oracle rule).
- **Brittle selectors** → role-based (`getByRole`/`getByLabel`), `data-testid`,
  accessibility snapshots. But selectors are only ~28% of failures — timing,
  strict visual asserts, and bad test data dominate; a stable app contract
  (durable test-ids) is the precondition.
  [getautonoma.com — AI e2e](https://getautonoma.com/blog/ai-e2e-testing),
  [augmentcode.com](https://www.augmentcode.com/guides/why-ai-coding-agents-fail-e2e-tests)

### Repo context — what exists, what to reuse, what not to duplicate

- **`/open-web`** (`claude/skills/open-web/SKILL.md`) — drives the maister
  Playwright MCP (`mcp__plugin_maister_playwright__browser_*`) to read one page;
  headed browser inherits an auth session. Reuse: the MCP tool set + screenshot
  conventions. Not a test framework.
- **maister `e2e-test-verifier` agent** — live interactive browser verification
  against `spec.md`, emits a locked 12-section report; **does not generate test
  files**. The new skill must *complement* this (it owns the ephemeral live tier
  and the verification report), not duplicate it.
- **maister `test-suite-runner` agent** — runs the full suite; don't re-run units.
- ai-devkit ships **no** `/verify` or `/run` skill of its own — those in the
  session list are Claude Code built-ins (ephemeral, single-observation).
- **House conventions** the skill must follow: SKILL.md frontmatter
  (`name`/`description`/`argument-hint`/`allowed-tools`), `Step 0…N` body,
  `references/` for schemas, `scripts/` for helpers, a `copilot/prompts/` mirror,
  and a `tests/*.bats` file. The `/implement` `extensions/` mechanism (opt-in
  `*.opt-in.md` descriptor + full rules) is the established pattern for the
  dedicated-API-tool opt-in.

## Alternatives considered

- **Option A — Thin Playwright two-tier skill (LEADING / chosen).**
  Plan scenarios as Markdown from spec/acceptance → ground selectors live →
  generate committed `.spec.ts`; web via browser, backend via `request` fixture
  in one runner; mirror Playwright Test Agents; dedicated API tools as opt-in
  extension; mandatory human-review gate.
  - Pros: rides stable GA Playwright project as the durable artifact; one runner
    for web+API; aligns with official + community consensus; minimal tool sprawl;
    complements maister e2e-test-verifier cleanly.
  - Cons: depends on the target project having (or bootstrapping) a Playwright
    setup; must track Playwright Test Agents' evolving output style.
  - Verdict: **chosen** — best value/risk; cross-check reinforced the "thin"
    framing.

- **Option B — Live-MCP-only scenario skill (generalized e2e-test-verifier).**
  Drive the browser each run, no durable file.
  - Pros: zero test-project setup; self-healing during the run.
  - Cons: ephemeral (no CI value), ~4× token cost, duplicates maister's agent.
  - Verdict: rejected as the primary model; it *is* the exploratory tier, which
    Option A delegates to existing tooling.

- **Option C — Custom YAML/JSON scenario DSL + runner.**
  - Pros: fully controlled, tool-agnostic surface.
  - Cons: reinvents Playwright; community openly skeptical; high maintenance.
  - Verdict: rejected — weakest option per multiple sources.

- **Option D — Gherkin / playwright-bdd as the default artifact.**
  - Pros: business-readable.
  - Cons: two-layer indirection hurts AI authoring/refactor.
  - Verdict: rejected as default; viable as an opt-in for stakeholder suites.

- **Option E — Multi-tool from day one (Playwright web + Bruno/Hurl API).**
  - Pros: best-of-breed per layer.
  - Cons: tool sprawl, two runners, split reports, more deps to bootstrap.
  - Verdict: rejected as default; folded into Option A as an opt-in extension.

## Anti-bias cross-check

### Devil's advocate

The strongest case against building anything: Playwright already ships the
Planner/Generator/Healer **Test Agents** as official, fast-moving tooling. A
custom ai-devkit skill that wraps them is drift-prone — the moment Playwright
changes its plan format or agent CLI, the wrapper generates stale-style tests
and becomes maintenance debt. The honest move might be to write *documentation*
("here's how to invoke Playwright's own agents") plus a one-page convention,
rather than a skill. A second-order risk: the only browser MCP wired into this
repo is maister's *headed, read-oriented* server (built for `/open-web`), while
the Generator wants filesystem access and an installed Playwright project — so
the skill's real value may be **bootstrapping a Playwright project**, not
authoring, and that's a much smaller thing than "an e2e scenario skill." This
critique is why the decision is explicitly *thin*: orchestrate Playwright's
agents + add only ai-devkit conventions (spec anchoring, `docs/work/`
integration, two-tier discipline, human-review gate). If even that proves too
thin once Test-Agents-in-Claude-Code is verified, the fallback is documentation,
not a thick runner.

### Pre-mortem

Six months out, the post-mortem reads: we shipped the skill, wired in
auto-heal, and it quietly regenerated tests until they went green — optimizing
for *pass*, not *correctness*. The suite filled with brittle, self-confirming
tests; a real regression slipped through because a healed test had been rewritten
to match the bug; devs lost trust and went back to manual `/verify`. The signals
we ignored were all in this research: MCP was never GA; auto-heal must produce
PR-reviewable patches not silent rewrites; selectors are only ~28% of flakiness
(timing + test data dominate); and the assertion oracle must come from the spec,
not the implementation. Mitigation baked into the decision: **mandatory
human-review gate on every generated/healed test, no silent regeneration**, and
spec-derived assertions.

## Decision

**Build a thin ai-devkit skill (working name `/e2e`) on Playwright's two-tier
pattern.** Author scenarios as a Markdown plan from `spec.md` / acceptance
criteria → ground selectors against the live app (exploratory tier, may use the
maister Playwright MCP or delegate to `e2e-test-verifier`) → generate a
**committed Playwright `.spec.ts`** that covers web (browser) and backend
(Playwright `request` fixture) in one runner. Mirror Playwright's official Test
Agents (Planner/Generator/Healer) rather than inventing a DSL. Dedicated API
tools (**Hurl** for plain-text browser-free specs, **Schemathesis** for
OpenAPI-derived stateful fuzz) ship as an **opt-in extension**, following the
`/implement` `extensions/` pattern. A **human-review gate is mandatory** on every
generated or healed test — no silent auto-heal. Rationale: maximizes reuse of
stable GA tooling, keeps web+API in one runner with shared auth/state, fills the
real gap (durable re-runnable scenarios) without duplicating maister's live
verifier, and designs against the documented AI-authoring failure modes.

## Open questions

- **Playwright Test Agents usability from Claude Code CLI** — they shipped
  primarily as VS Code / Copilot integration. Before building, verify the
  Planner/Generator/Healer can be driven from Claude Code (CLI invocation or
  equivalent), or whether the skill must reimplement the plan→generate loop over
  the Playwright CLI directly. *Resolution path:* spike against
  `playwright.dev/docs/test-agents` + the Playwright CLI in a scratch project.
  This is the gating unknown for the "thin wrapper" framing.
- **MCP server fit** — maister's MCP is headed/read-oriented; confirm whether it
  exposes locator-generation / filesystem-write paths the Generator needs, or
  whether the skill should depend on a project-local `@playwright/test` install
  instead of MCP for the codify tier. *Resolution path:* inspect available
  `mcp__plugin_maister_playwright__*` tools vs `@playwright/mcp` capabilities.
- **Boundary with `e2e-test-verifier`** — define precisely which skill owns the
  exploratory tier and the verification report, so the two don't both try to
  drive the browser. *Resolution path:* design note during `/save-plan`.
- **Backend-only scenarios without a web tier** — decide whether `/e2e` handles
  pure-API initiatives via the Playwright `request` fixture alone, or routes
  them straight to the Hurl/Schemathesis extension. *Owner:* skill author.
