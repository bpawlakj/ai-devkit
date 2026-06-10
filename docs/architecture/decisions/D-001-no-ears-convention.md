---
id: D-001
title: Do not adopt EARS; keep one If/then hint for failure-path criteria
date: 2026-06-10
status: accepted
supersedes: null
superseded_by: null
analysis: ../../analyzes/ears-notation-adoption-evaluation.md
---

## Context

SL AiDLC's tool research flagged Kiro's EARS notation as worth borrowing for
acceptance criteria; the ai-devkit borrow scan had never evaluated it. Research
confirmed EARS is proven in industry (Rolls-Royce, Intel, NASA) but found no
empirical evidence it improves AI-agent output — and the one large LLM+EARS data
point is negative (Kiro generated 16 EARS criteria for a small bug fix).
ai-devkit already enforces the semantic half of EARS's value: the oracle rule
(assertions from spec, never code) and the observable-behavior requirement in
`/implement` and `/scenario`. A conditional borrow was considered and overturned:
it required an anti-padding guard — a rule policing a rule — which is
over-engineering by its own shape, for minimal added value and extra token cost.

## Decision

We will NOT adopt EARS as an acceptance-criteria convention. Task-level
`## Acceptance` stays freeform under the existing observable-behavior + oracle
guards. One salvage: the task schema gains a single un-branded hint — phrase
failure/edge criteria as `If <trigger>, then <expected response>` — because
under-specified pessimistic criteria were the one real weakness the research
found. No named notation, no guard, nothing to police.

## Consequences

Easier: no new convention to maintain or police; no template-driven criteria
inflation; `## Acceptance` stays cheap to write and read. Harder: task-level
criteria keep no uniform syntax — acceptable, since the semantic guards carry
the load. Follow-up: observe whether the single If/then hint sharpens
failure-path criteria in `/atomize` output; if not, the next cheapest step is a
`/scenario`-side hint — full EARS stays off the table unless empirical evidence
of agent-output benefit appears.
