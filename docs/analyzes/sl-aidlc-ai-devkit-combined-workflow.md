---
title: Combined workflow — sl-aidlc process layer over ai-devkit execution engine
date: 2026-06-10
type: investigation
status: open
decision: null
related:
  - docs/analyzes/sl-aidlc-project-analysis-investigation.md
  - docs/analyzes/sl-aidlc-requirements-gap.md
  - docs/analyzes/sl-aidlc-external-repos-borrow-scan.md
  - ../sl-aidlc/wow/operating-model.md
  - ../sl-aidlc/docs/01-requirements-v2.md
---

# Combined workflow — sl-aidlc process layer over ai-devkit execution engine

## Context

Follow-up to `docs/analyzes/sl-aidlc-project-analysis-investigation.md` (the
full-picture analysis of sl-aidlc). After establishing what sl-aidlc is — a
design-phase process blueprint with its key decision D-A (Build vs Assemble) still
open — the natural next question was: **what would the day-to-day workflow look like
if sl-aidlc is combined with ai-devkit** (the Assemble path)?

This document is a projection, not a record of an adopted process. It synthesizes
the mapping already implicit in `docs/analyzes/sl-aidlc-requirements-gap.md` into a
single operational walkthrough. Status is `open` because the combination is gated
on sl-aidlc's D-A decision, which awaits 6 spike readouts.

## Question

If sl-aidlc selects "Assemble + thin layer" with ai-devkit as the execution base,
what is the concrete workflow for one increment — which sl-aidlc process step maps
to which ai-devkit skill, which role drives it, and what glue is still missing?

## Findings

### Layer model

The combination is not a merger of two competing toolkits — the layers stack:

- **sl-aidlc = process layer**: who decides, when, at which gate; human roles;
  weekly Thursday cadence; the foundation layer (department-owned context); the
  decision log as organizational memory (`sl-aidlc/wow/operating-model.md`,
  `sl-aidlc/foundation/OWNERSHIP.md`).
- **ai-devkit = execution engine**: the skills that perform the actual work between
  gates (`/discover` → `/product-spec` → `/research` → `/save-plan` → `/atomize` →
  `/implement` → `/scenario` → `/e2e-run`, plus `/repo-map`, `/eval`, `/agents-md`).
- **Shared artifacts = the connective tissue**: PRD, plan, T-NNN tasks,
  DECISIONS.md — repo files both layers read and write. The file-shape rules for
  this (append-only vs derived vs authored, CODEOWNERS, PR-as-gate) are being
  designed on sl-aidlc's `integration/ai-devkit-shared-files` branch.

### One-increment lifecycle

```
Backlog item / feature
        │
        ▼
┌─ DISCOVERY (async, between sessions) ────────────────────────┐
│  PM/PO:     /discover (brownfield auto-detect, inherits      │
│             prior state)                                      │
│  Architect: /research → docs/analyzes/ + D-NNN entry          │
│  Dev/Arch:  /repo-map (brownfield context, CTX-01/02)         │
│  sl-aidlc "spikes" are exactly these /research runs           │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
   THURSDAY GATE (1h, exactly one decision, quorum +
   async objection window until Monday)
   → scribe records D-NN in DECISIONS.md
   → ai-devkit's D-NNN decision-log convention and sl-aidlc's
     living log are the same shape (ART-03)
        │
        ▼
┌─ REFINEMENT ─────────────────────────────────────────────────┐
│  /product-spec → living PRD (sl-aidlc prd/, ART-04,           │
│                  owned by PM/PO)                              │
│  plan mode → /save-plan → docs/work/NNN-slug/plan.md          │
│  /atomize → T-NNN atomic tasks = small increments (INC)       │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
┌─ EXECUTION (roles in parallel, async) ───────────────────────┐
│  Dev: /implement T-NNN (pre/per/post gates; frontmatter       │
│       status writeback = ART-05 v1 one-directional sync)      │
│  QA:  /scenario → /e2e-run (tests in parallel, TEST-01)       │
│  Sec: /threat-model, /security-review                         │
│  sl-aidlc foundation/ surfaces to all skills via /agents-md   │
│  → AGENTS.md (design system, policies, security baselines     │
│    consumed as project rules, never baked into the toolkit)   │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
   HUMAN GATE: fresh-model verification
   (/code-review, /eval, e2e — the author never grades its
    own output; a separate agent tries to refute success;
    then human approval)
        │
        ├─→ next increment
        └─→ backpropagation: plan changed →
            /atomize (reconciliation mode) → revised T-NNN
            + a D-NN entry recording the implementation-driven
            change
```

### Role-to-skill mapping

| sl-aidlc role | ai-devkit tooling |
|---|---|
| PM/PO | `/discover`, `/product-spec` (living PRD) |
| Architect | `/research`, `/repo-map`, D-NNN decision records |
| Developer | `/implement`, `/ci-setup`, per-language auto-active rules |
| QA | `/scenario`, `/e2e-run`, `/eval` |
| Designer/UX | **gap** — no skill; `foundation/design-system` reaches agents via AGENTS.md only |
| Scrum Master | outside tooling — operating model, sessions, ISSUES.md |

### Requirement-level alignment (key anchors)

- **ART-03 living decision log**: sl-aidlc's `DECISIONS.md` D-NN format and the
  D-NNN convention adopted in the borrow scan are deliberately the same shape.
  > Ref: docs/analyzes/sl-aidlc-external-repos-borrow-scan.md — Tier 1 adopts the
  > numbered D-NNN decision-log convention (OpenSpec delta markers + Spec Kit
  > numbering), closing A3, a v1-MUST.
- **ART-05 spec↔impl sync (v1)**: `/implement` frontmatter writeback +
  `/atomize` reconciliation already equal the v1 staging (one-directional +
  decision log); full bidirectional sync remains horizon.
  > Ref: docs/analyzes/sl-aidlc-requirements-gap.md — frontmatter writeback +
  > reconciliation = "exactly ART-05 v1".
- **Fresh-model verification at gates**: sl-aidlc requires it at every gate
  (`sl-aidlc/README.md:77`); ai-devkit's `/eval` implements the fresh-judge
  pattern, with `/implement`/`/scenario` to cite a shared
  `references/fresh-verification.md` per the borrow scan's Tier 1.
- **Foundation consumption**: SL-specific content (MIN minors compliance, SL
  Design System) stays in `sl-aidlc/foundation/`, owned by departments, and enters
  the workflow through `/agents-md`'s AGENTS.md shim — never as general ai-devkit
  defaults (Bucket B discipline).

### What the combination does NOT provide (white space — Bucket C)

These are the items sl-aidlc's own research (`sl-aidlc/docs/02-research-existing-approaches.md`
§4) flags as unsolved by *every* surveyed tool; they are the "thin layer" sl-aidlc
must build:

1. **Human-role parallelism** (ROLE-02/04/07) — ai-devkit is single-operator;
   worktree isolation parallelizes *agents under one operator*, not *humans*. Six
   people working simultaneously around shared artifacts needs the shared-files
   protocol (append-only/derived/authored file shapes, CODEOWNERS from
   `foundation/OWNERSHIP.md`, PR-as-gate) under design on the
   `integration/ai-devkit-shared-files` branch, possibly with a GNAP-style
   coordination board.
2. **Cross-role change notification** (ART-07) — the "Figma changed → PM updates
   PRD → Dev and QA get signaled" loop. Manual today.
3. **SL integrations** — Jira as stakeholder mirror, Slack as notification
   channel (deferred to P3 in the gap-analysis roadmap, INT-01/04/05).

### Remaining v1-MUST gaps on the ai-devkit side

Of the three v1-MUST gaps the gap analysis identified: `/eval` (EVAL-07) has since
shipped; **accessibility-by-design (A11Y, A2)** and the **scaffolded numbered
decision log (ART-03, A3)** remain open as of this writing.

## Alternatives considered

(N/A — investigation/projection, not selection. The Build-vs-Assemble alternatives
belong to sl-aidlc's D-A record, not this document.)

## Anti-bias cross-check

### Devil's advocate

This projection assumes the answer to D-A before sl-aidlc has decided it. All six
spike readouts are unstarted; BMAD, OpenSpec, GNAP, gh-aw, Intent, or a bespoke
build could still win or reshape the mapping. The walkthrough also quietly assumes
the hardest part — six humans operating ai-devkit sessions in parallel against
shared files — works, when that is precisely the load-bearing, unvalidated bet
(n=1 AcceleraTTy). A skeptic would say this document draws the easy 80% (skill
mapping) and waves at the hard 20% (coordination substrate) that determines whether
the combination functions at all.

### Pre-mortem

Six months on, the combined workflow was adopted on paper but increments kept
serializing: roles waited on each other because the shared-files protocol and
notifications (Bucket C) lagged behind the skill layer, and the "parallel roles"
box in the diagram never materialized. Alternatively, D-A chose differently and
this document — read without its `status: open` flag — anchored ai-devkit work on
an integration that never happened. Signals to watch: the integration branch
stalling, spike readouts favoring another base, Session 0 slipping.

## Decision (if any)

None — this is a projection of the Assemble path, explicitly gated on sl-aidlc's
D-A decision. Status: open.

## Open questions

- **D-A (Build vs Assemble)** — the gate for everything here. Owner: sl-aidlc team.
  Path: 6 spike readouts → Thursday decision session; re-check
  `sl-aidlc/DECISIONS.md` before acting on this projection.
- **Shared-files protocol** — does the `integration/ai-devkit-shared-files` branch
  converge on file-shape rules that make multi-human parallelism real? Path:
  follow-up `/research` once the branch stabilizes.
- **A2 (accessibility rule) and A3 (decision-log scaffold)** — the two remaining
  ai-devkit v1-MUST gaps. Owner: ai-devkit maintainer. Path: `/save-plan` →
  `/atomize` per the gap-analysis roadmap.
- **UX role tooling** — Designer/UX has no ai-devkit skill; is AGENTS.md-mediated
  foundation access enough, or does a UX skill clear the test-of-inclusion? Path:
  borrow-scan Tier 2 gate (BMAD persona shape as prior art).
- **Notification mechanism (ART-07)** — designed with the process layer, not as an
  ai-devkit feature; candidate substrate: GNAP-style `messages/` + Slack mirror.
