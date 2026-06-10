---
id: T-001
title: GDPR / privacy-by-design section in rules/security.md
status: pending
plan: ../plan.md
created: 2026-06-10
completed: null
commit: null
depends_on: []
blocks: []
plan_anchor: P1-1
---

## Scope

- `claude/rules/security.md` — new `## Privacy / GDPR` section
- `copilot/instructions/security.instructions.md` — mirrored section

## Approach

Extend the existing security rule (keep its structure, tone, and BAD/GOOD snippet
style): data minimisation (collect only what the feature needs), pseudonymisation
of personal identifiers in logs/analytics, lawful-basis routing (consent vs
contract vs legitimate interest — name which applies), retention limits (no
indefinite personal-data storage; TTL or deletion path required). Generic GDPR
only — minors-specific compliance (MIN) stays in the SL foundation layer per the
gap analysis Bucket B. Closes SEC-06.

## Acceptance

- `claude/rules/security.md` contains a Privacy / GDPR section covering
  minimisation, pseudonymisation, lawful basis, and retention, in the rule's
  existing style.
- Copilot mirror carries the same content.
- If a code change introduces personal-data collection without a stated lawful
  basis or retention path, then the rule flags it as a violation (rule text makes
  this checkable in review).
- Existing bats tests still pass (`tests/`).
