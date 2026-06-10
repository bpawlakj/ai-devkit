---
id: T-006
title: Git guardrails folded into cloud-guard.sh
status: pending
plan: ../plan.md
created: 2026-06-10
completed: null
commit: null
depends_on: []
blocks: []
plan_anchor: P1-6
---

## Scope

- `claude/scripts/cloud-guard.sh` — add dangerous-git pattern block
- Hook tests (bats) — new cases for the git patterns

## Approach

One more pattern block in the existing PreToolUse hook that already covers
AWS/kubectl/helm — NOT a second hook (borrow scan Tier 1.4, mattpocock
git-guardrails mechanism: grep pattern array → exit 2). Patterns: `git push
--force` (and `-f`), `git reset --hard`, `git clean -fd`, `git branch -D`,
`git checkout .` (and `git checkout -- .`). Keep plain `git push` allowed —
the M1L3 permission policy already routes it to ask; the guard blocks only the
destructive/history-rewriting forms.

## Acceptance

- If a Bash tool call contains a blocked git pattern, then cloud-guard exits 2
  and the command is prevented, with a one-line reason printed.
- Plain `git push`, `git checkout <branch>`, `git branch -d` (lowercase) pass
  through unblocked.
- Existing cloud-guard behavior (AWS/kubectl/helm patterns) unchanged.
- Bats tests cover at least one blocked and one allowed example per new pattern
  group and pass.
