---
title: ai-devkit coverage of SL AiDLC requirements — gap analysis + remediation roadmap
date: 2026-06-09
type: analysis
status: draft
decision: "ai-devkit is a strong Assemble base for SL AiDLC Execution; close 3 v1-MUST gaps (EVAL harness, A11Y-by-design, living decision log) + 4 general gaps in ai-devkit; keep SL-specific concerns (MIN, SL Design System) in the sl-aidlc foundation layer."
related: []
---

# ai-devkit coverage of SL AiDLC requirements — gap analysis + remediation roadmap

## Context

Sanoma Learning's **SL AiDLC** is an AI-native software-delivery process (two modes — Discovery
and Execution — with living artifacts as the single source of truth and humans holding decision
authority at gates). Its highest-order open decision is **D-A: Build vs Assemble** — build a
proprietary harness, or *assemble* the process from existing tools plus a thin glue layer.

**ai-devkit is the strongest concrete candidate for the "Assemble + thin layer" option.** It is a
working toolkit, not a hypothesis: a portable Claude Code / Copilot configuration providing a
Discovery → Plan → Execute → Test → Audit workflow (`/discover` → `/product-spec` → `/research` →
`/save-plan` → `/atomize` → `/implement` → `/scenario` → `/e2e-run`), per-language auto-active
rules, specialised agents, safe cloud access, and an owned, versioned release cadence.

This document measures ai-devkit against the **~75 requirements** in
`sl-aidlc/docs/01-requirements-v2.md` and the **coverage matrix** in
`sl-aidlc/docs/02-research-existing-approaches.md` §3, then lays out **how best to close the real
gaps** — three of which are explicit **v1-MUST** requirements ai-devkit does not yet satisfy.

**Scope of this analysis (deliberate):** ai-devkit is a *general* toolkit. Gaps that are specific
to Sanoma Learning's domain (minors / EU AI Act compliance; the SL Design System) are **out of
scope for the general toolkit** and are flagged as belonging to the SL foundation/extension layer.
This matches ai-devkit's own stack-openness and anti-duplication philosophy: language- and
org-specific knowledge lives in rules/foundation, not in the neutral workflow.

**State assessed:** current working tree including the `[Unreleased]` CHANGELOG — i.e. `/repo-map`
and `/ci-setup` count as present. Rating ai-devkit on shipped-only state would understate it (most
notably for context/code-intelligence).

---

## Coverage summary — the `ai-devkit` matrix column

Same legend as the source matrix: **● strong · ◐ partial · ○ none/weak**. The first block is the
§3 matrix rows; the second block is the v2.2 requirement areas that post-date that matrix (CTX,
MIN, GOV, FND, INT).

| Requirement area | ai-devkit | Evidence / note |
|------------------|:---:|---|
| ROLE — role coverage (PM/Arch/Dev/QA/UX/SM) | ◐ | Dev, QA, PM, Arch-ish, Sec via skills + maister; **no UX Researcher, Designer, Scrum Master** |
| ROLE — parallel work | ○ | Single-operator, single session, sequential. Worktree isolation = parallel *agents under one operator*, not parallel *humans* |
| ART-05 — bidirectional spec↔impl sync | ◐ | Frontmatter writeback (`/implement` writes `status`/`commit`) + `/atomize` reconciliation = **exactly ART-05 v1 (one-directional + decision log)**. Full bidirectional is horizon |
| ART — living decision log | ◐ | `docs/architecture/` ADRs + `/research` snapshots; **no enforced numbered D-NNN living log** like OpenSpec |
| PROC — greenfield | ● | `/discover` → `/product-spec` → plan → `/atomize` → `/implement` |
| PROC — brownfield / injectable | ● | `/discover` auto-detects brownfield + inherits state; `/agents-md`; `/repo-map` |
| INC — small increments + gates | ● | Atomic `T-NNN` tasks, pre/per/post gates, human review, never-edit-done |
| MOD — modularity / extensions | ● | Composable skills, per-language rules, `extensions/` + `/ci-setup` recipes |
| MOD — agent/model/tech agnostic | ● | Claude + Copilot; runner auto-detected. **Caveat: no .NET/C# rule** though MOD-08 lists .NET |
| SKILL — token economy (model per task) | ◐ | Skills/agents accept a model override; maister assigns models. No systematic "default model per skill" doc |
| SEC — agent guardrails / prompt-injection | ◐ | `cloud-guard` (PreToolUse), M1L3 permission policy, `security-reviewer`. **No gh-aw safe-output/scoped-apply + firewall** |
| SEC — security/privacy of built product | ◐ | `rules/security.md` (OWASP/STRIDE/secrets), `/threat-model`, e2e security pass. **No GDPR/privacy-by-design defaults** |
| A11Y — accessibility by design | ○ | `rules/e2e-testing.md` + react/angular rules touch a11y; `/open-web` snapshots it. **Not first-class; no WCAG in DoD** |
| ONB — onboarding for low-maturity devs | ◐ | `/setup` one command, progressive skill flow, `setup.sh` installer. Visible-flow UI is `[conditional]` |
| EVAL — skill/output evaluation | ○ | **No eval harness.** `/rule-review` audits rule files, but that is not output/skill evaluation |

Requirement areas added in SL AiDLC v2.2 (not in the §3 matrix):

| Requirement area | ai-devkit | Evidence / note |
|------------------|:---:|---|
| CTX — context / code intelligence | ◐ | **`/repo-map`** ("Wide Scan" → `docs/architecture/repo-map.md`) gives evidence-based brownfield context, covering CTX-01/02 v1. Still grep/AST-based, not the MCP semantic/symbol retrieval CTX-03 prefers |
| MIN — minors & high-risk AI compliance | ○ | None. **SL-specific — out of scope for general ai-devkit** (see Bucket B) |
| GOV — operating model & ownership | ◐→● | ai-devkit **is itself** a model of GOV-02: `VERSION`, `CHANGELOG`, `setup.sh --check`/update, pinned MCP servers. GOV-01 named owner is an org concern, not a tool feature |
| FND — foundation layer | ◐ | Mechanism exists (`~/.claude/rules/` + `AGENTS.md` + `docs/reference/`); **governance missing**: per-domain versioning/pinning, precedence, department ownership formalised |
| INT — integrations | ◐ | Bitbucket (`/bitbucket-review`) + AWS (`/aws`). **No Jira, no Slack-as-notification, no Confluence/Miro** |

**Reading it:** ai-devkit is **●** on exactly the parts the SL research calls "expensive, generic,
already exists" (greenfield/brownfield, increments+gates, modularity, agnosticism, owned product).
That is the core of the Assemble thesis. The gaps cluster into three distinct buckets below — and
only one of them is ai-devkit's to fix.

---

## Gap inventory — three buckets

### Bucket A — General gaps ai-devkit should close (in scope)

Each gap names the requirement(s) it serves, its current rating, the recommended approach (reusing
existing ai-devkit patterns wherever possible), and a rough effort (**S/M/L**).

#### A1 — EVAL harness · EVAL-05 / EVAL-07 · ○ · **v1-MUST** · Effort L
SL AiDLC elevates evals to MUST: without them, P10 (resilience to model change) cannot hold and the
"no demo-driven AI" anti-pattern is unenforceable. EVAL-07 demands a *concrete* v1 harness — golden
tasks, a baseline, acceptance thresholds, and a regression check on every model/harness upgrade.
ai-devkit has none.
**Approach:** a new `/eval` skill + an `evals/` directory convention — golden tasks with expected
outcomes, a recorded baseline, pass/fail thresholds, and a "run on model upgrade → diff against
baseline" command. Reuse: BMAD ships an `evals/` directory as prior art; `/ci-setup` already wires
coverage gates, so the eval run can hook the same CI surface and AI-reviewer recipe.

#### A2 — Accessibility by design · A11Y-01..03 / P11 · ○ · **v1-MUST** · Effort M
A11Y is a first-class, day-one requirement in SL AiDLC, never a retrofit, and part of an
increment's definition of done (A11Y-03 links INC-02 / TEST-03). ai-devkit only touches it
incidentally.
**Approach:** a new auto-active `rules/accessibility.md` (13th rule) — WCAG essentials, semantic
landmarks, form labels, `aria-*`, contrast, keyboard support — gated to UI file globs; plus an A11Y
line in `/scenario` path generation and in `/implement` Step-4 definition-of-done. Reuse:
`rules/e2e-testing.md` already prefers role-based selectors (a11y-friendly), and the 12 existing
rules give the exact authoring + activation pattern to copy. Mirror to
`copilot/instructions/accessibility.md`.

#### A3 — Living numbered decision log · ART-03 · ◐ · **v1-MUST (per SL)** · Effort S–M
ART-03 requires a decisions log as a *required living artifact*, each entry numbered (D-01, D-02…)
with date, rationale, and context. ai-devkit keeps ADRs in `docs/architecture/` but does not
enforce a numbered living log.
**Approach:** a thin convention — a numbered `docs/architecture/decisions/` ADR log (D-NNN,
date/context/rationale/status) scaffolded by `/setup`, appended by `/research` when a decision is
reached, and referenced from `/implement`. Reuse: OpenSpec's `changes/` + lightweight-decision-log
pattern; the existing `docs/architecture/` directory and `/research` snapshot shape. Keep it a
convention + tiny scaffold, not a heavyweight new skill.

#### A4 — Privacy / GDPR by default · SEC-06 · ◐ · Effort S
SEC-06 wants privacy-by-design enforced *in skills* — data minimisation, pseudonymisation, lawful
basis. `rules/security.md` covers product security (OWASP/STRIDE/secrets) but not privacy.
**Approach:** extend `rules/security.md` with a Privacy / GDPR section (data minimisation,
pseudonymisation, lawful-basis routing, retention) — auto-active, low effort, high leverage. Mirror
the addition to `copilot/instructions/security.md`. (Note: *minors-specific* compliance is MIN →
Bucket B; this is generic GDPR only.)

#### A5 — .NET / C# rule · MOD-08 · missing · Effort M
MOD-08 requires supporting the org's heterogeneous stack, which explicitly includes **.NET** — yet
ai-devkit ships rules for 12 languages with **no `dotnet`/C# rule**.
**Approach:** add `rules/dotnet.md` + `copilot/instructions/dotnet.md` following the exact shape of
the existing per-language rules (idioms, nullable reference types, async/await, DI, xUnit/NUnit +
Testcontainers, analyzers). Add the formatter hook (`dotnet format`) to the PostToolUse pattern.

#### A6 — Safe-output / scoped-apply pattern · SEC-01 / SEC-04 · ◐ · Effort M
SEC-01/04 reference the gh-aw pattern: the agent emits *intended* actions, a separate scoped job
applies only what is permitted (hard per-operation limits), the agent never holds write
credentials, execution sits behind a network allowlist/firewall. ai-devkit has guardrails
(`cloud-guard`, M1L3 permissions) but not this full architecture.
**Approach:** document the safe-output/scoped-apply pattern as a reference (and a `rules/`
note), and wire it where ai-devkit already owns execution surface — `/ci-setup` is already
self-hosted-runner aware, so the scoped-apply job belongs there. This is a doc/reference + CI
recipe, **not** a bespoke runtime — keep it thin.

#### A7 — Token economy / model-per-skill · SKILL-04 / SKILL-05 · ◐ · Effort S
SKILL-04/05 want a default model per skill, optimising cost and quality per task. ai-devkit lets
skills/agents override the model but ships no guidance on *which* model per task.
**Approach:** document a per-skill `model:` hint convention in skill frontmatter + a recommended
"model per task" reference table (cheap model for mechanical/extraction skills, capable model for
design/review/eval). Reuse: the `Agent`/skill model-override mechanism already exists; this is
guidance + defaults, not new machinery.

#### A8 — Context/code-intelligence completion · CTX-01..03 · ◐ via `/repo-map` · Effort S (defer extension)
`/repo-map` already delivers an evidence-based brownfield context layer (CTX-01/02 v1) — the single
biggest documented cause of brownfield agent failure. CTX-03 additionally *prefers* structured
(e.g. MCP-based) semantic/symbol retrieval over agent grep-and-backtrack.
**Approach:** record `/repo-map` as the v1 context layer satisfying CTX-01/02; **defer** an
MCP-based semantic/symbol-retrieval extension (CTX-03) as a future `extensions/` recipe. Mostly a
mapping/positioning task now; the extension is later, demand-driven work.

#### A9 — Integrations: Jira / Slack-as-notification / Confluence · INT-01 / INT-04 / INT-05 · ◐ · Effort L · **defer**
ai-devkit covers Bitbucket + AWS but not Jira (MUST), Slack-as-artifact-change-notification (MUST),
or Confluence/Miro (SHOULD).
**Approach:** MCP-based — document recommended MCP servers + thin skills for Jira issue sync and a
Slack change-notification hook. **Lower priority / defer** until P0–P1 land; the notification piece
also overlaps the process-layer (Bucket C) and should be designed with it.

### Bucket B — SL-specific, NOT general ai-devkit (→ sl-aidlc foundation/extension)

These are real SL AiDLC MUSTs, but folding them into a neutral toolkit would violate ai-devkit's
stack-openness. They belong in the SL foundation layer (P13/FND) — owned by departments, consumed
as authoritative input — and may optionally ship as an *opt-in ai-devkit extension*, never as
baked-in default behaviour.

- **MIN — minors & high-risk AI compliance** (MIN-01..06, MUST for SL). DPIA / children's-risk-assessment
  gate, EU AI Act risk classification at Discovery, age-appropriate defaults. Lives in
  `foundation/security` + `foundation/policies`, consulted as foundation, versioned (MIN-06).
- **SL Design System awareness** (SKILL-02 / FUNC-03). Inherently internal; lives in
  `foundation/design-system` and is surfaced to skills via the project's `AGENTS.md` (the
  `/agents-md` shim), never as a general ai-devkit rule.

### Bucket C — Process-layer white space (→ sl-aidlc, not a tool gap)

The SL research itself (§4 "what nobody solves") flags these as unsolved across *all* external
tools — so they are not an ai-devkit shortfall; they are the "thin layer SL builds":

- **Human-role parallelism** (ROLE-02 / ROLE-04 / ROLE-07) — multiple human specialists working
  simultaneously around a shared, notifying artifact store. The load-bearing, n=1 bet.
- **Cross-role change notification** (ART-07) — the "Figma changed → PM updates PRD → Dev → QA"
  loop made event-driven.
- **Full bidirectional spec↔impl sync** (ART-05 horizon) — beyond the one-directional v1 that
  ai-devkit's frontmatter writeback already covers.

These are addressed by the **shared-files protocol** under discussion on the sl-aidlc
`integration/ai-devkit-shared-files` branch (file-shape rules: append-only / derived / authored;
CODEOWNERS from `foundation/OWNERSHIP.md`; PR-as-gate) plus a GNAP-style coordination substrate —
**at the process layer, not in ai-devkit.**

---

## Prioritized remediation roadmap

Priority is driven by SL AiDLC's v1-MUST set first, then value-vs-effort. Each item names the
requirement it closes and the ai-devkit pattern it reuses.

| Pri | Item | Closes | Effort | Reuses |
|-----|------|--------|:---:|--------|
| **P0** | A1 EVAL harness (`/eval` + `evals/`) | EVAL-05/07 | L | BMAD `evals/`, `/ci-setup` CI surface |
| **P0** | A2 `rules/accessibility.md` + DoD lines | A11Y-01..03, P11 | M | 12-rule pattern, `rules/e2e-testing.md` |
| **P0** | A3 Numbered decision-log convention | ART-03 | S–M | OpenSpec `changes/`, `docs/architecture/`, `/research` |
| **P1** | A4 GDPR section in `rules/security.md` | SEC-06 | S | existing security rule |
| **P1** | A5 `rules/dotnet.md` (+ Copilot, formatter hook) | MOD-08 | M | per-language rule shape |
| **P1** | A7 Model-per-skill convention + table | SKILL-04/05 | S | skill/agent model override |
| **P2** | A6 Safe-output/scoped-apply reference + CI recipe | SEC-01/04 | M | `/ci-setup` self-hosted runner |
| **P2** | A8 CTX MCP-retrieval extension | CTX-03 | S→ext | `/repo-map`, `extensions/` |
| **P3** | A9 Jira / Slack-notification / Confluence | INT-01/04/05 | L | MCP servers, `/bitbucket-review` shape |

**P0 is the headline:** ai-devkit fails three SL v1-MUSTs today (EVAL-07, A11Y, ART-03). Closing
P0 turns ai-devkit from "strong Assemble base with caveats" into "satisfies the SL v1 Execution
MUSTs" — the decisive evidence for D-A.

---

## Out of scope (explicit)

To prevent this analysis being read as ai-devkit under-delivering: Bucket B (MIN, SL Design System)
is **intentionally not** general-toolkit work — it is SL foundation, owned by departments. Bucket C
(human-role parallelism, cross-role notification, bidirectional sync) is **intentionally not** a
tool concern — it is the SL process layer. ai-devkit's job is the Execution engine; the SL-specific
foundation and the human-coordination layer sit above and beside it, by design.

---

## Next steps (not part of this doc)

- Feed P0/P1 items into ai-devkit's own `/save-plan` → `/atomize` to create tracked `T-NNN` tasks.
- On the sl-aidlc side: add the `ai-devkit` column to the §3 matrix and a note to
  `decisions/D-A-build-vs-assemble.md` ("ai-devkit as Assemble candidate — coverage + P0 gaps").
