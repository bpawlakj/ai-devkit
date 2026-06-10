---
title: Does a /frame skill pass ai-devkit's test-of-inclusion?
date: 2026-06-11
type: technology-evaluation
status: decided
decision: "Conditional pass. /frame's job (separate observation from stated cause, parallel hypothesis subagents, confidence-gated reframed problem statement) is distinct from every existing skill and operationalizes CLAUDE.md §12; no hard trigger collisions. Adoption is approved ONLY with two conditions: (1) the Frame Brief gets a mechanical consumer (docs/work/<NNN>/frame.md read by /save-plan + /atomize — lifted problem statement, LOW-confidence warning), since ai-devkit has no /plan skill and an unconsumed brief is an orphaned artifact; (2) triggers.json gains frame discrimination cases incl. the 'just fix it' adversarial negative."
related:
  - docs/analyzes/ai-devkit-vs-10x-cli-comparison.md
  - docs/analyzes/sl-aidlc-external-repos-borrow-scan.md
---

# Does a /frame skill pass ai-devkit's test-of-inclusion?

## Context

`docs/analyzes/ai-devkit-vs-10x-cli-comparison.md` named a `/frame`-like skill
one of the three cheapest borrows from 10x-cli, "behind a test-of-inclusion".
The borrow scan's Tier-2 gate (and the pre-mortem of
`docs/analyzes/sl-aidlc-external-repos-borrow-scan.md`) requires every new
skill to prove it does not duplicate an existing skill's job before any code is
written — trigger collision and skill sprawl are the documented failure mode.
This evaluation runs that gate for `/frame`.

## Question

Does a `/frame` skill — pre-planning problem framing: observation vs stated
cause, parallel hypothesis investigation, confidence-gated reframe — have a job
no existing ai-devkit skill (or inline rule) already owns, and a trigger
boundary that won't collide?

## Findings

Investigation mode: 2 parallel subagents — a full read of
`10x-frame/SKILL.md` (+ its consumer coupling in `10x-plan`), and a
trigger-collision audit across ai-devkit skills, CLAUDE.md, and
`evals/triggers.json`.

### What the skill actually does (per 10x-frame)

- **Locks the observation/cause separation** (`10x-frame/SKILL.md:60-87`):
  extracts reported observation, user's stated cause, and proposed direction as
  three separate items; "the framing is locked… even if the user pushes back
  ('just plan the fix'), do not collapse the observation into the framing."
- **Dimension map → parallel hypothesis subagents** (`:113-155`): 2–4 read-only
  subagents, each briefed "if the framing broke at THIS dimension, what
  evidence would we expect, and does it exist?"
- **Confidence gate** (`:257-264`): HIGH/MEDIUM proceed to planning; LOW =
  "recommend further reproduction before planning."
- **Scope is broader than bugs** (`:22-23`): bug-shape, scope-shape ("is this
  even the right scope"), design-shape, assumption-shape. Skips mechanical
  changes and already-verified framings (`:25-26`).
- **Output**: an ~80–150-line Frame Brief whose heart is the hypothesis
  investigation table; stated as "useful standalone… does not require
  /10x-plan to follow" (`:35-36`).

### The coupling caveat — where half the value lives

In 10x, the brief has a mechanical consumer: `10x-plan` treats it as
authoritative (`10x-plan/SKILL.md:65-69` — copies the reframed problem
statement as the task definition, lifts the hypothesis table into Current State
Analysis, never re-questions the framing), cuts planning questions roughly in
half (`:60`), skips all diagnostic question categories (`:207`), and surfaces
`Confidence: LOW` as an open risk. **ai-devkit has no `/plan` skill** —
planning happens in Claude Code's built-in plan mode, which cannot be taught to
consume a file. Without a consumer, the brief is an orphaned input (the exact
anti-pattern CLAUDE.md §10 names), and the skill's value drops to the
diagnosis discipline plus a discussion artifact — real, but maybe 60% of the
original.

### Collision audit (verdicts per candidate)

| Candidate | Claimed job | Verdict |
|---|---|---|
| `/discover` | product-level elicitation → spec; skips "single bug / refactor" | **clear** — frame is diagnosis upstream of scoping |
| `/research` | per-decision evaluation ("should we adopt X") | **adjacent, sequenceable** — frame surfaces the problem; research evaluates alternatives once framed |
| `/repo-map` | evidence map of an unfamiliar repo | **adjacent, complementary** — frame may use it for territory, no query overlap |
| `/atomize`, `/save-plan`, `/implement` | decompose / persist / execute an existing plan | **clear** — all post-plan; frame is pre-plan |
| `/rule-review` | audit rules files | **clear** — different domain |
| CLAUDE.md §12 "Root Cause Over Retry" | inline mandate: diagnose before retry | **partial overlap by design** — §12 is the principle; /frame would be its operationalization (an anchor, not a duplicate — the `/agents-md` doctrine asks new rules/skills to be anchored in exactly this way) |
| CLAUDE.md §6 "bug report: just fix it" | inline: don't over-process simple fixes | **boundary to encode** — the trigger discrimination must keep simple fixes OUT of /frame |
| `evals/triggers.json` | routing discrimination fixture | no frame cases yet — must be added on adoption |
| `maister:quick-bugfix` | "quick bug fix with TDD red/green gates and complexity escalation" | **unaudited risk** — possibly contains its own pre-diagnosis; flagged as an open question, not a blocker (plugin skill, different layer) |

No hard collisions. The distinguishing trigger exists and is statable: /frame
owns "is this the right problem?" queries ("diagnose before we fix", "challenge
my framing", "is this even the right scope"); it must NOT own "just fix it"
(§6) or "evaluate X vs Y" (/research) or "map this repo" (/repo-map).

## Alternatives considered

- **Option A — Conditional pass (CHOSEN).** Passes the inclusion gate; author
  only together with (1) a brief consumer — `docs/work/<NNN>-<slug>/frame.md`
  read by `/save-plan` (lift the reframed problem statement into plan.md) and
  `/atomize` (surface `confidence: LOW` as a warning on derived tasks) — and
  (2) `triggers.json` discrimination cases incl. the "just fix it" negative.
  - Pros: keeps the gate honest (no orphaned artifact); the consumer is cheap
    (two small skill edits, no new machinery); anchors §12.
  - Cons: adoption is a 3-part change, not a drop-in skill; delays availability.
  - Verdict: chosen.
- **Option B — Unconditional pass, author now.**
  - Pros: fastest; brief has standalone discussion value.
  - Cons: ships the orphaned-input anti-pattern on day one; pre-mortem's
    "briefs nobody reads" outcome. Rejected.
- **Option C — Fail the gate (don't adopt).**
  - Pros: §12 + native agent diagnosis already push the behavior; zero sprawl.
  - Cons: discards the two pieces inline rules can't provide — the *enforced
    gate* (LOW confidence blocks planning) and the *parallel hypothesis
    machinery* with a durable artifact; the collision audit found a genuinely
    unowned job. Rejected.

## Anti-bias cross-check

### Devil's advocate

The strongest case against: a competent agent already separates observation
from cause when debugging — it's what §12 demands and what good practice looks
like without any skill. What /frame adds is ceremony around behavior that
should be ambient, and ceremony has a token bill (2–4 subagents per
invocation) plus a trigger surface that brushes against the §6 "just fix it"
fast path. The conditional-pass design answers the orphaned-artifact problem
but not the deeper one: if the agent is already doing implicit framing,
the skill's marginal value concentrates in the rare misframed-task case — and
we have no measurement of how often that case occurs in real ai-devkit usage.
Adopting on vibes would be the thing /frame itself exists to prevent.

### Pre-mortem

Six months on: /frame fires on routine bug reports ("why is this failing" was
too broad a trigger), users learn to bypass it, and the briefs in `docs/work/`
go unread because /save-plan's lift was implemented but plan mode itself never
sees them mid-planning. Signals visible today: no /plan skill to consume the
brief at the moment it matters (during planning, not after); §6 explicitly
encourages the opposite reflex for simple bugs; the only large adoption datum
(10x) has the consumer we lack. Mitigation encoded in the decision: the
trigger fixture must contain the "just fix it" negative before the skill
ships, and adoption is reviewed against actual usage (did any brief change a
plan?) after the first initiative that uses it.

## Decision (if any)

**Conditional pass.** /frame clears the test-of-inclusion: its job is owned by
no existing skill, its triggers are separable, and it operationalizes
CLAUDE.md §12. Authoring is approved only as a 3-part change: the skill + a
brief consumer (`/save-plan` lift + `/atomize` LOW-confidence warning) +
`triggers.json` discrimination cases (incl. "the test is failing, just fix
it" → `should_trigger: false`). Recorded as
`docs/architecture/decisions/D-002-frame-skill-conditional-pass.md`.

## Open questions

- **`maister:quick-bugfix` overlap** — does the plugin's complexity-escalation
  path already perform pre-diagnosis? Audit before authoring; if it does, the
  frame trigger boundary must exclude its territory explicitly. Owner:
  maintainer.
- **Usage evidence** — after the first initiative that uses /frame, check
  whether any brief materially changed a plan (the pre-mortem's review gate).
- **Upstream-artifact scaling** — the companion borrow (question depth shrinks
  with settled artifacts) is a separate, skill-less principle; it can be
  adopted independently of /frame and would multiply frame's value if a /plan
  consumer ever exists. Path: separate small change to /atomize + plan-mode
  usage guidance.
