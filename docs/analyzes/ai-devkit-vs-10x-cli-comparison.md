---
title: ai-devkit vs 10x-cli — skill-set comparison and the "superseded" verdict
date: 2026-06-11
type: investigation
status: decided
decision: "Neither supersedes the other — they are two halves of one system: 10x-cli owns the deeper pre-code thinking layer (frame → question-scaled plan → plan-review) and the greenfield bootstrap; ai-devkit owns the verification/quality/runtime layer (eval harness, E2E generation+execution, 14 auto-active rules, enforceable guards, D-NNN log) plus governance (internal ownership, versioned releases, Copilot mirrors). The sl-aidlc PDF's 'ai-devkit largely superseded by 10x-cli' rated a v1.10.0 snapshot and undercounts the current state by one release; its 'SKILL-02 absent from all six' is falsified by ds-impl (full SLDS Figma→Angular pipeline) in this very collection. Cheapest borrows for ai-devkit: upstream-artifact scaling, a /frame-like skill, stack-assess compensation entries."
related:
  - docs/analyzes/sl-aidlc-requirements-gap.md
  - docs/analyzes/sl-aidlc-external-repos-borrow-scan.md
  - docs/analyzes/sl-aidlc-ai-devkit-combined-workflow.md
  - ../sl-aidlc/docs/07-gap-analysis-sibling-projects.pdf
---

# ai-devkit vs 10x-cli — skill-set comparison and the "superseded" verdict

## Context

`sl-aidlc/docs/07-gap-analysis-sibling-projects.pdf` (June 2026) compares six
sibling projects against the SL AiDLC requirements and concludes for D-A:
"assemble from siblings", with 10x-cli as the workflow substrate and ai-devkit
demoted to "a source of language-specific coding rules and the three specialized
review agents, layered under the 10x-cli workflow" — described as "now largely
superseded by 10x-cli". That assessment was made against **ai-devkit v1.10.0**
("10 skills, 12 coding rules, 7 commands, 3 agents, 8 hooks"); the current state
is 16 skills, 14 rules, 9 hooks plus the entire `[Unreleased]` block (P0 + P1
initiative work). This investigation compares the actual 10x-cli skill corpus —
read in full from a local copy — against ai-devkit's current state, to test the
"superseded" verdict.

## Question

Skill-for-skill and architecture-for-architecture: what does 10x-cli have that
ai-devkit lacks, what does ai-devkit have that 10x-cli lacks, and does the PDF's
"layer ai-devkit under 10x-cli" recommendation hold against current state?

## Findings

Investigation mode: 3 parallel Explore subagents over
`/Users/bartosz.pawlak/Projects/skills` (22 `10x-*` skills + `ds-impl`; the
known 24-skill set's `10x-tdd` and `10x-e2e` are absent from this copy).
ai-devkit state: this repo at `87f5557` (post initiative 002).

### Shared DNA

Both toolkits descend from the same 10xDevs lineage and share core mechanics:
locked schemas under `references/`, refusal-and-redirect protocols, SHA
write-back after commits, `git add` by path (never `-A`), append-only
`lessons.md`, facilitator-not-author discovery, checkpoint/resume. The
comparison is between siblings, not strangers.

### Architecture

| | 10x-cli | ai-devkit |
|---|---|---|
| Artifact model | `context/foundation/` (living) + `context/changes/<id>/` (scoped) + `context/archive/` (immutable; all skills refuse to write there) | `docs/` (product-spec, analyzes, architecture/decisions) + `docs/work/NNN/` (T-NNN tasks) + derived STATUS.md |
| Unit of work | change folder with `change.md`; plan.md `## Progress` checkboxes as the state machine (SHA per step) | atomic T-NNN files with frontmatter `status`/`commit`/`depends_on` |
| Decision record | embedded in artifacts + `lessons.md`; **no numbered decision log** | **numbered living D-NNN log** (`docs/architecture/decisions/`) + `/research` snapshots |
| Delivery/governance | course-owned CLI (`@przeprogramowani/10x-cli`) — external owner, fork required for SL (PDF's own GOV caveat) | `setup.sh` + VERSION + CHANGELOG; internal ownership |
| Harness | Claude Code only (host-agnostic markdown) | Claude Code + Copilot mirrors |
| Runtime guardrails | none (refusals are in-skill prose) | enforceable hooks: git/rm safety guard, cloud-guard (AWS/kubectl/helm), M1L3 permission policy, 7 formatter hooks |
| Per-skill model guidance | none (explicitly host-managed) | `docs/model-per-skill.md` (archetype→tier + judge-never-weaker rule) |

### Skill-for-skill mapping

| 10x-cli | ai-devkit | Edge |
|---|---|---|
| 10x-init | /setup | ≈ (setup also scaffolds `decisions/` + `tests/e2e/`) |
| 10x-shape | /discover | ≈ near-identical (6 phases, Socratic challenge, checkpoint); shape has finer-grained resume checkpoints |
| 10x-prd | /product-spec | ≈ (same locked schema lineage, 10/11 sections) |
| 10x-roadmap | `docs/roadmap.md` via /save-plan | 10x (auto-researched baseline; roadmap items closed by 10x-archive) |
| 10x-research | /research (decisions) · /repo-map+Explore (code) | ai-devkit for decision research (anti-bias cross-check, `docs/reference/`, D-NNN record); 10x-research is codebase exploration, a different job |
| 10x-tech-stack-selector + 10x-bootstrapper (+ starter-registry.yaml) | **none** | 10x — greenfield stack selection + scaffolding is a real ai-devkit gap |
| 10x-stack-assess | /repo-map + /agents-md | different jobs: stack-assess scores 4 agent-readiness gates and emits **ready-to-paste AGENTS.md compensation entries**; /repo-map builds an evidence map (territory, cycles, blast radius) 10x has no equivalent of |
| 10x-health-check | none — **deliberately not adopted** | fails ai-devkit's test-of-inclusion: its slices are already covered piecemeal (`/repo-map` structural/testability risk, `/ci-setup` CI gap + coverage gate, `rules/security.md` dependency scanning, `/implement` red-baseline gate, maister `reviews-production-readiness`); the unique remainder is a consolidated hygiene report, not a new capability. If ever needed: install the 10x copy as-is (host-agnostic SKILL.md), or add a cheap "health" signal subagent to `/repo-map`'s Wide Scan — never a new skill (trigger collision with `/repo-map` is the documented sprawl failure mode) |
| 10x-new / frame / plan / plan-review | plan mode → /save-plan → /atomize | **10x — its strongest layer** (see below) |
| 10x-implement | /implement | ≈ twins (gates, manual confirm, SHA write-back, dirty-path prompt); ai-devkit adds **opt-in extensions** (security-baseline diff gate) and runner auto-detection (10x runs plan-authored commands verbatim) |
| 10x-impl-review | /implement Step 5 + `fresh-verification.md` | **ai-devkit** — 10x-impl-review spawns same-session general-purpose subagents; ai-devkit's shared contract enforces blind-to-reasoning fresh verification (closer to TEST-04) |
| 10x-test-plan | /scenario + /e2e-run + /eval | disjoint: 10x plans a risk-mapped (R1–R5) phased test **strategy** with a cookbook (no ai-devkit equivalent) but **runs and generates nothing**; ai-devkit generates committed Playwright specs and executes them |
| 10x-lesson / 10x-agents-md / 10x-rule-review | lessons.md convention / /agents-md / /rule-review | ≈ (ai-devkit rule-review adds cross-tool drift + dead-rule grep) |
| 10x-infra-research | ad-hoc /research | 10x (dedicated, with three anti-bias cross-checks) |
| 10x-archive | /atomize obsolete-status + STATUS.md | 10x (immutable archive + write-refusal guard across all skills) |
| ds-impl | **none** | 10x-side; see correction below |

### What ai-devkit genuinely lacks (10x's thinking layer)

1. **Upstream-artifact scaling** (`10x-plan` Step 1.0): planning question count
   shrinks as upstream artifacts settle decisions — task-only 11–15 questions
   (HIGH complexity) down to 1–7 with frame+research present. "Every artifact
   passed in is a source of decisions already made… Don't ask the user what they
   already wrote down." ai-devkit applies this only in `/discover` brownfield
   inheritance; plan mode and `/atomize` have no equivalent principle.
2. **`10x-frame`** — first-class problem framing: locks the separation of
   observation from stated cause, spawns 2–4 parallel hypothesis subagents, and
   emits a confidence level (HIGH/MEDIUM/LOW) that **gates** `10x-plan` entry
   (LOW = go reproduce first). No ai-devkit equivalent; matches the `/grill`
   Tier-2 candidate from the borrow scan and would pass the test-of-inclusion
   (distinct from forward-eliciting /discover and from /research).
3. **`10x-plan-review`** — substance review of the *plan* before any code
   (feasibility, drift, architecture fit, triage verdicts). ai-devkit reviews
   specs (maister) and implementations, not plans natively.
4. **Compensation over replacement** (`10x-stack-assess`): 4 agent-readiness
   gates (typed / convention-based / training-data-popular per language family /
   well-documented) → per-failed-gate, ready-to-paste CLAUDE.md/AGENTS.md
   entries; never a rewrite demand.
5. Greenfield bootstrap (selector + starter registry + bootstrapper),
   infra-research, immutable archive with refusal guard. (10x-health-check is
   excluded from this gap list on purpose — see the mapping table: it fails the
   test-of-inclusion against existing coverage.)

### What 10x-cli genuinely lacks (ai-devkit's verification/runtime layer)

1. **Any eval harness** — no golden tasks, no baseline, no thresholds, no
   regression check on model change, no cost telemetry, anywhere in the corpus
   (confirmed by cross-cutting scan). The test-plan cookbook is patterns, not an
   oracle. ai-devkit's `/eval` (golden tasks + git-tracked stamped baseline +
   fail-on-regression + `gen_ai.*` cost fields + triggers.json routing
   discrimination) is exactly what the PDF's EVAL-07 row asks for — and the PDF
   itself concedes 10x-test-plan "plans tests but does not run a cross-model
   regression harness".
2. **Runtime guardrails** — zero hooks; all 10x safety is prose-level refusal.
   ai-devkit enforces: destructive-git/rm guard, cloud write-op guard, M1L3
   permissions, formatter hooks.
3. **14 auto-active language rules** incl. accessibility (WCAG 2.2 AA) and
   security+GDPR — the layer the PDF explicitly says to keep from ai-devkit.
4. **E2E generation + execution** (`/scenario` + `/e2e-run`); this 10x copy has
   no `10x-e2e`/`10x-tdd` at all.
5. Numbered **D-NNN decision log** (10x embeds decisions in artifacts —
   weaker against ART-03's "numbered living log" wording), fresh-verification
   as an enforced contract, model-per-skill guidance, trigger-discrimination
   fixture (23 overlapping skills, no routing test), `/bitbucket-review`,
   `/open-web`, `/ci-setup`, Copilot mirrors, owned release cadence.

### Correction to the PDF: SKILL-02 is not "absent from all six"

> Ref: ../sl-aidlc/docs/07-gap-analysis-sibling-projects.pdf — "SKILL-02 — SL
> Design System awareness: Absent from all six. No skill suggests SL DS
> components before custom builds."

The examined collection contains **`ds-impl`**: a 10-step Figma→Angular pipeline
that searches the SLDS registry (`search_design_system`), maps Figma elements to
`@sl-design-system/angular/*` components before generating custom code, verifies
extracted design tokens, and geometrically verifies the result (±2px layout /
±4px text) against Figma coordinates, writing decisions to
`context/foundation/ds-decisions/<screen>.md`. Whether it was out of the PDF's
scoped corpus or simply newer, the SKILL-02 row should read "exists as a working
pipeline (ds-impl), maturity to be assessed" — a materially different input to
the FND/SKILL-02 sequencing in the PDF's section 8.

### Where the PDF's verdict stands and where it doesn't

Still accurate: 10x-cli is the more complete **pre-code workflow** (frame →
scaled plan → plan-review have no ai-devkit equivalents); both toolkits are
single-operator (ROLE-02/04/07 unsolved by either — the PDF's central structural
finding holds); CTX retrieval and call-graph remain absent from both.

Outdated or asymmetric: the EVAL-07, TEST-04, ART-03, A11Y, SEC-06 and MOD-08
rows all flip toward ai-devkit on current state (see
`docs/analyzes/sl-aidlc-requirements-gap.md` follow-through — P0 and P1
initiatives closed); the governance argument favors ai-devkit (internal, owned,
versioned) over a course-owned CLI the PDF itself says must be forked; and the
"coding rules layer" framing ignores that the verification layer (eval, E2E,
guards) does not exist in 10x-cli at all.

## Alternatives considered

(N/A — investigation. The D-A assembly decision belongs to sl-aidlc; this doc
corrects one input to it.)

## Anti-bias cross-check

### Devil's advocate

The strongest case for the PDF's verdict: SL AiDLC's binding constraint is the
*workflow substrate* — the thing six humans run a process on — and there 10x-cli
is genuinely deeper where it counts most for daily work (question-scaled
planning, framing gate, plan review). The eval/guardrail/rules layer ai-devkit
leads on is plumbing that can be bolted under any substrate, which is exactly
what the PDF proposes; "superseded for workflow purposes" (the PDF's literal
phrase) is then defensible even today. Also, this comparison was authored by the
maintainer-side of ai-devkit with subagent evidence about 10x but session-deep
knowledge of ai-devkit — an asymmetry that risks flattering the home team; the
mapping table's "≈" rows deserve independent verification before being cited in
D-A. Finally, the local 10x copy is incomplete (no 10x-tdd/10x-e2e), so the E2E
gap claim is about *this copy*, not necessarily the shipped CLI.

### Pre-mortem

Six months on, this doc was cited in the D-A session as "ai-devkit caught up" —
and the merge of the two toolkits never happened because each side kept
deep-linking its own conventions (context/ vs docs/work/), producing a
two-substrate sprawl that satisfied nobody. Signals visible now: the artifact
models are structurally incompatible (change folders vs task files), the PDF
already warned about assemble-sprawl (GOV-02), and nobody owns the
reconciliation. Mitigation: treat this doc as input to a *deliberate* layering
decision (who owns which layer), not as license to run both workflows side by
side.

## Decision (if any)

The "superseded" framing is rejected in both directions; the two toolkits are
complementary halves (thinking layer vs verification/runtime layer), and the
PDF's assessment should be re-run against ai-devkit ≥ current `main` before
D-A. Recorded for ai-devkit's own roadmap: the three cheapest borrows from
10x-cli are (1) the upstream-artifact scaling principle (into plan mode usage +
`/atomize`), (2) a `/frame`-like skill (Tier-2 candidate, passes
test-of-inclusion), (3) stack-assess-style compensation entries as a
`/repo-map`→`/agents-md` bridge. No D-NNN record — the binding decision (D-A)
belongs to sl-aidlc, not this repo; the borrow candidates each still require
their own test-of-inclusion before authoring.

## Open questions

- **Does the shipped `@przeprogramowani/10x-cli` include 10x-tdd / 10x-e2e?**
  This copy lacks them; the E2E-gap claim should be re-verified against the CLI
  manifest before citing in D-A. Owner: maintainer.
- **ds-impl provenance and maturity** — is it part of 10x-cli proper or a
  Sanoma-side addition? Either way it changes the PDF's SKILL-02 row. Path: ask
  the sl-aidlc team / check the CLI manifest.
- **Layering decision** — if D-A picks "assemble from siblings", who owns the
  seam between 10x's `context/` model and ai-devkit's `docs/` model? The
  pre-mortem's sprawl risk lives exactly there. Path: a joint design note on the
  sl-aidlc `integration/ai-devkit-shared-files` branch.
- **Borrow candidates** — run `/frame`, upstream-scaling, and compensation
  through the test-of-inclusion (borrow-scan Tier-2 gate) before authoring
  anything. Owner: maintainer.
