---
id: T-002
title: Accessibility by design — rules/accessibility.md + DoD lines
status: pending
plan: ../plan.md
created: 2026-06-09
completed: null
commit: null
depends_on: []
blocks: []
plan_anchor: p0-2-accessibility-by-design-rules-accessibility-md-dod
---

## Scope

- New auto-active rule `claude/rules/accessibility.md` (13th rule): WCAG essentials, semantic
  landmarks, form labels, `aria-*`, colour contrast, keyboard support, focus management. Gated to
  UI file globs (e.g. `*.tsx`, `*.jsx`, `*.vue`, `*.html`, `*.component.ts`).
- A11Y line added to `/scenario` path generation (accessibility assertions in generated scenarios).
- A11Y line added to `/implement` Step-4 definition-of-done (an increment isn't done if it
  regresses accessibility; links INC-02 / TEST-03).
- Copilot mirror: `copilot/instructions/accessibility.md`.
- README rules table gains the `accessibility` row; rules count 12 → 13; `CHANGELOG.md`
  `[Unreleased]` entry.

## Approach

- Copy the exact authoring + activation pattern of the existing 12 rules (frontmatter glob gating,
  concise BAD/GOOD snippets, U-shaped layout).
- Cross-link `rules/e2e-testing.md` (already prefers role-based, a11y-friendly selectors) and
  `rules/react.md` / `rules/angular.md` (which touch a11y) — extend, do not duplicate.
- Keep WCAG guidance general (no SL Design System specifics — that is Bucket B, out of scope here).

## Acceptance

- Editing a UI file surfaces the accessibility rule as active context.
- `/scenario` output includes at least one accessibility assertion for learner/user-facing paths.
- `/implement` Step-4 DoD checklist includes an accessibility check.
- Copilot instruction mirrors the rule.
- Closes A11Y-01..03 / P11: accessibility is first-class and part of an increment's DoD, not a
  retrofit.

## Notes

Effort: M.
