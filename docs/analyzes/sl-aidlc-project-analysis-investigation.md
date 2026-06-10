---
title: SL AiDLC project analysis — full-picture investigation
date: 2026-06-09
type: investigation
status: decided
decision: "sl-aidlc is a design-phase, pre-pilot process blueprint: a comprehensive, internally consistent AI-native delivery process (~75 requirements, federated foundation layer, weekly decision-gate operating model) that is 2 days old, with a working decision log but zero execution evidence — all 14 downstream decisions blocked on D-A (Build vs Assemble), which itself waits on 6 unstarted spike readouts."
related:
  - docs/analyzes/sl-aidlc-requirements-gap.md
  - docs/analyzes/sl-aidlc-external-repos-borrow-scan.md
  - ../sl-aidlc/README.md
  - ../sl-aidlc/docs/01-requirements-v2.md
  - ../sl-aidlc/docs/03-direction-assessment.md
---

# SL AiDLC project analysis — full-picture investigation

## Context

The `sl-aidlc` repository was added as a working directory to this session and the
maintainer asked for a full analysis of the project. Two prior point-in-time analyses
exist in this repo — `docs/analyzes/sl-aidlc-requirements-gap.md` (maps SL AiDLC
requirements onto ai-devkit) and `docs/analyzes/sl-aidlc-external-repos-borrow-scan.md`
(extracts liftable artifacts from the external repos SL AiDLC researched) — but both
view sl-aidlc *through the lens of ai-devkit*. No document yet records what sl-aidlc
**is** on its own terms: its purpose, structure, process design, artifact model, and
actual execution state. This investigation fills that gap.

## Question

What is the sl-aidlc project — its purpose, structure, methodology, artifact flow,
and current state of execution — as a full-picture factual synthesis, independent of
any specific downstream decision?

## Findings

Investigation mode: 3 parallel Explore subagents (identity/top-level docs,
methodology directories, execution state + git history), plus the two prior analyses
read fully as context.

### Identity and purpose

SL AiDLC (AI-driven Development LifeCycle) is **Sanoma Learning's blueprint for a
repeatable software-delivery process in which AI leads execution while humans retain
decision authority at every gate** (`sl-aidlc/README.md:5-7`). It explicitly targets
friction in *thinking, context handling, and decisions* — not code generation
(`sl-aidlc/README.md:17`, `sl-aidlc/docs/01-requirements-v2.md:15`). The first
proving ground is the New Secondary Platform (NSP) (`sl-aidlc/README.md:99`). The
repo is the single source of truth for the process design itself and is positioned
as **the first pilot of its own process** (`sl-aidlc/README.md:9`,
`sl-aidlc/SETUP.md`). License: all rights reserved, internal only
(`sl-aidlc/LICENSE`).

### Process design

- **Two phases with a light, reversible boundary**: Discovery (structured,
  convergent) → Execution (parallel, fast) (`sl-aidlc/README.md:19-36`).
- **Human-parallel model**: six roles (Developer, Designer/UX, QA, PO/PM, Scrum
  Master, Architect) work simultaneously rather than in relay; validated by the
  AcceleraTTy 2023 hackathon where a month-long feature shipped in one day — an
  n=1 data point the project itself flags as a calibration risk
  (`sl-aidlc/README.md:41-52`, `sl-aidlc/docs/03-direction-assessment.md`).
- **Operating model** (`sl-aidlc/wow/operating-model.md`): a 1-hour Thursday
  session is a *decision gate, not a working session* — recap (0–5), spike readout
  (5–10), exactly one decision (10–45), next-work assignment (45–55), scribe
  records the decision (55–60). Rotating facilitator + scribe; quorum rule with an
  async objection window until Monday. Async spikes and drafting happen between
  sessions (`sl-aidlc/docs/04-session-plan.md`).
- **Quality spine**: small increments before decisions stabilize; fresh-model
  verification at every gate (a separate agent — not the implementer — tries to
  refute success before human approval); backpropagation of implementation
  discoveries into the spec (`sl-aidlc/README.md:76-78`).
- **Tooling stance**: GitHub is the only source of truth; Jira is a stakeholder
  mirror only (`sl-aidlc/README.md:168-169`).

### Repository structure and artifact flow

The folder map encodes the lifecycle (`sl-aidlc/README.md:243-256`):

| Directory | Role | Current state |
|---|---|---|
| `docs/` | 5 read-only reference documents (see below) | Complete, substantive |
| `wow/` | Operating model + ubiquitous language (95+ terms, one term = one meaning) | Drafted, pending ratification |
| `foundation/` | Federated org context: architecture, infrastructure, security, design-system, policies — each owned by a department per `foundation/OWNERSHIP.md`, versioned and pinned by projects (FND-04), deviations logged (FND-05) | All stubs/placeholders |
| `prd/`, `refinement/`, `development/`, `tests/` | Living artifacts to be created during the pilot (PRD → refined slices → increments → parallel tests) | Placeholders / `.gitkeep` only |
| `decisions/` + `DECISIONS.md` | Living numbered decision log (D-NN, date/rationale/owner/status) + long-form records | Working: 2 entries |
| `spikes/` | 6 tool-trial scaffolds (BMAD, OpenSpec, Intent, mattpocock/skills, GNAP, gh-aw) | Scaffolds only, no readouts |
| `sessions/` | Thursday session notes | Template + unexecuted session-00 scaffold |
| `scripts/` | Repo/issue bootstrap automation (`setup-repo.sh`, `create-issues.sh`) | Working; the only executable code in the repo |

The documented flow: backlog decision/feature → Discovery spike (async, time-boxed)
→ Thursday gate (one decision, human quorum) → Execution increment (small slice,
all roles in parallel) → human gate (fresh-model verification + approval) → next
increment or backpropagation (`sl-aidlc/README.md:56-73`).

The five `docs/` references are the intellectual core:

1. `01-requirements-v2.md` (~40KB) — 13 requirement categories, 75+ MUST/SHOULD/COULD
   items, principles P1–P13, v1-vs-horizon staging.
2. `02-research-existing-approaches.md` (~28KB) — competitive research over ~14
   external tools; concludes "assemble + thin layer" is viable and names what nobody
   solves (human-role parallelism, cross-role notification, bidirectional sync).
3. `03-direction-assessment.md` — critical self-assessment naming three calibration
   risks: big-bang ambition vs incrementality, conditional build assumptions, and
   over-anchoring on the n=1 AcceleraTTy result.
4. `04-session-plan.md` — the gate-session operating contract.
5. `05-stress-test-2026.md` — market stress-test that added three requirement areas
   (CTX context intelligence, MIN minors/high-risk-AI compliance, GOV governance).

### Execution state (hard evidence)

- **Git history**: first commit 2026-06-06, last 2026-06-07 — the repo is **2 days
  old** at analysis time, with 14 commits by 2 authors (Rafał Czochara: 11, Claude: 3;
  scaffolding, decision templates, README, logo). Current local branch:
  `integration/ai-devkit-shared-files`; working tree clean. (git log/branch/status,
  2026-06-09.)
- **Decisions**: 1 ACCEPTED — D-02 (2026-06-06): validation via incremental pilots
  embedded in NSP instead of a post-design hackathon, because "hackathon (n=1,
  controlled) gives weak signal" (`sl-aidlc/DECISIONS.md:16-21`). 1 PROPOSED — D-01
  (operating model), awaiting Session 0 ratification. **14 BLOCKED** — D-A through
  D-O per `sl-aidlc/ISSUES.md`.
- **The critical path**: **D-A (Build vs Assemble) gates D-B through D-H** and
  requires all 6 spike readouts first; all six spikes are ⏳ with scaffold READMEs
  ("why / questions / try" instructions) and no results
  (`sl-aidlc/decisions/D-A-build-vs-assemble.md`, `sl-aidlc/spikes/*/README.md`).
- **No execution artifacts**: `development/` and `tests/` contain only `.gitkeep`;
  Session 0 has not been held; no NSP pilot project selected; planned integrations
  (Jira, Slack, Confluence, Miro) are scoped but unimplemented.
- **Verdict from evidence**: design phase, pre-pilot — roughly 95% process design /
  <5% execution. The design itself is comprehensive and internally consistent; the
  process *is* already running in one narrow sense (the decision log works — D-02
  was made and recorded per the project's own template).

### Relationship to ai-devkit (cross-reference, not the focus)

> Ref: docs/analyzes/sl-aidlc-requirements-gap.md — ai-devkit is the strongest
> concrete candidate for SL AiDLC's "Assemble + thin layer" option (decision D-A);
> it is strong on exactly the parts SL research calls "expensive, generic, already
> exists", with three v1-MUST gaps (EVAL harness, A11Y, numbered decision log)
> identified for closure.

> Ref: docs/analyzes/sl-aidlc-external-repos-borrow-scan.md — the external repos
> sl-aidlc is spiking (BMAD, OpenSpec, GNAP, gh-aw, mattpocock/skills) were already
> scanned for ai-devkit borrow value; process-layer items (GNAP board, safe-output)
> were explicitly routed to sl-aidlc's layer, not ai-devkit.

The `integration/ai-devkit-shared-files` branch (currently checked out in the
sl-aidlc working copy) is where the shared-files protocol between the two projects
is being discussed — evidence the Assemble path is actively explored.

## Alternatives considered

(N/A — investigation, not selection.)

## Anti-bias cross-check

### Devil's advocate

The "95% plan / <5% delivered" framing may apply the wrong category. At this stage
the *product is the process design itself*, so complete, coherent design artifacts
ARE the deliverable — not evidence of its absence. The repo is 48 hours old;
characterizing "execution maturity" of anything after two days is premature by
construction. Moreover, the process is already executing itself in the only way it
can at this stage: the decision log works (D-02 was made, recorded, and follows the
project's own template), the operating model is drafted and queued for its own
ratification gate. Finally, the obvious external criticisms — n=1 AcceleraTTy
anchoring, big-bang ambition of 75+ requirements before a single pilot — are
**already raised by the project itself** in `sl-aidlc/docs/03-direction-assessment.md`;
this analysis discovers nothing about sl-aidlc that sl-aidlc does not say about
itself. Resolution: the verdict stands but is phrased as a stage description
("design phase, pre-pilot"), not a deficiency claim, and the self-awareness is
recorded as a strength.

### Pre-mortem

Six months on, this snapshot misled readers in one of two ways. (1) Staleness: at
~7 commits/day the repo outran the snapshot within a week — Session 0 was held, D-A
was decided, NSP pilots started — yet readers kept citing "everything is blocked on
D-A". The `date:` field and the explicit 2-day-old caveat were the guards we relied
on; a reader who skips frontmatter misses them. (2) Misreading: "95% plan" was read
as "it's just documents", deflating sl-aidlc's weight in ai-devkit decisions even
though D-A may select ai-devkit as the Assemble base — the signal we could have
ignored is that the checked-out integration branch already shows active convergence
between the two projects. Mitigation: this doc states both caveats inline, and any
consumer making a decision against sl-aidlc state MUST re-check
`sl-aidlc/DECISIONS.md` and `git log` first.

## Decision (if any)

sl-aidlc is a **design-phase, pre-pilot process blueprint**: a comprehensive,
internally consistent, self-critical AI-native delivery process design (two-phase
model, human-parallel roles, weekly decision gates, federated foundation layer,
~75 staged requirements) that is 2 days old, with a working decision log and
bootstrap automation but no execution artifacts yet — all downstream decisions
blocked on D-A (Build vs Assemble), which waits on 6 unstarted spike readouts.
This is a stage description, not a deficiency claim; the snapshot will age fast.

## Open questions

- **D-A outcome (Build vs Assemble)** — gates everything downstream, including
  whether ai-devkit becomes the Assemble base. Owner: sl-aidlc team (Thursday
  gate). Path: 6 spike readouts → decision session; re-check
  `sl-aidlc/DECISIONS.md` before relying on this snapshot.
- **Session 0 / D-01 ratification** — has the operating model been ratified since
  2026-06-09? Path: `sl-aidlc/sessions/` and `DECISIONS.md`.
- **First NSP pilot selection (D-C)** — which product increment pilots the process
  first? Depends on D-A. Owner: sl-aidlc team.
- **Shared-files protocol** — the `integration/ai-devkit-shared-files` branch
  carries the ai-devkit↔sl-aidlc integration design; its conclusions are not yet
  analyzed in this repo. Path: a focused follow-up `/research` once the branch
  stabilizes.
- **Foundation content** — all five foundation domains are stubs; when departments
  author real content, the FND-04 versioning/pinning mechanics become testable.
  Owner: SL departments per `sl-aidlc/foundation/OWNERSHIP.md`.
