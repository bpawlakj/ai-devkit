---
id: T-004
title: Shared fresh-verification reference cited from /implement + /scenario
status: done
plan: ../plan.md
created: 2026-06-10
completed: 2026-06-10
commit: 44fc570
depends_on: []
blocks: []
plan_anchor: P1-4
---

## Scope

- New shared reference `references/fresh-verification.md` (location: a shared
  spot reachable from the three skills — decide during implementation; candidate:
  `claude/skills/implement/references/` with cross-links, or a top-level shared
  references dir if one exists)
- `claude/skills/implement/SKILL.md` Step 5 — cite it
- `claude/skills/scenario/SKILL.md` — cite it
- `claude/skills/eval/SKILL.md` — point its existing fresh-judge wording at the
  same file instead of restating

## Approach

Extract the verification-by-fresh-model pattern (Anthropic best practices +
Squad convergent evidence, per the borrow scan): the verifier sees ONLY the diff
+ acceptance criteria — never the reasoning that produced them — and is told to
flag correctness/requirement gaps only (a gap-hunting reviewer over-reports on
style). One source of truth, three citations. The cheapest high-leverage borrow
in the scan (Tier 1.2).

## Acceptance

- `fresh-verification.md` exists and states: blind-to-reasoning constraint,
  diff+acceptance-only input, correctness/requirement-gaps-only output.
- `/implement`, `/scenario`, and `/eval` each reference the shared file; no
  skill restates the full pattern inline.
- If a verification subagent prompt is constructed per these skills, then it
  contains no implementer reasoning/chain-of-thought — only the diff and the
  acceptance criteria.
