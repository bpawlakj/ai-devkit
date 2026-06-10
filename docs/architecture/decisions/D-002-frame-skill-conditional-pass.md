---
id: D-002
title: /frame passes the test-of-inclusion — adoption conditional on a brief consumer
date: 2026-06-11
status: accepted
supersedes: null
superseded_by: null
analysis: ../../analyzes/frame-skill-inclusion-test-evaluation.md
---

## Context

The ai-devkit vs 10x-cli comparison named a `/frame`-like skill (pre-planning
problem framing: observation vs stated cause, parallel hypothesis subagents,
confidence-gated reframe) one of three cheapest borrows, behind the Tier-2
test-of-inclusion. The collision audit found no existing skill owning that job
(/discover, /research, /repo-map adjacent but separable) and an anchor in
CLAUDE.md §12 (Root Cause Over Retry). The binding risk: ai-devkit has no
/plan skill, so an unconsumed Frame Brief is an orphaned artifact — in 10x,
half of frame's value is its mechanical consumer (10x-plan treats the brief as
authoritative and halves its questioning).

## Decision

We will treat `/frame` as having PASSED the test-of-inclusion, and approve
authoring it ONLY as a three-part change: (1) the skill itself, writing
`docs/work/<NNN>-<slug>/frame.md`; (2) a consumer — `/save-plan` lifts the
reframed problem statement into plan.md and `/atomize` surfaces
`confidence: LOW` as a warning on derived tasks; (3) `evals/triggers.json`
gains frame discrimination cases including the adversarial negative "the test
is failing, just fix it" → should_trigger: false (CLAUDE.md §6 fast path stays
out of frame's territory).

## Consequences

Easier: the §12 principle gets an enforceable gate and a durable artifact;
misframed tasks get caught before planning. Harder: adoption is a 3-part
change, not a drop-in; frame adds a 2–4-subagent token cost per invocation, so
its trigger boundary must stay narrow. Follow-ups: audit
`maister:quick-bugfix` for pre-diagnosis overlap before authoring; after the
first initiative using /frame, review whether any brief materially changed a
plan — if none did, revisit this decision (supersede path).
