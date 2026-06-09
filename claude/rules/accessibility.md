---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.vue"
  - "**/*.svelte"
  - "**/*.html"
  - "**/*.component.ts"
  - "**/*.component.html"
---
# Accessibility Standards (WCAG)

Accessibility is built in from the first line of UI, never retrofitted. An inaccessible component is incomplete — treat a missing label or an unreachable control as a bug, not a follow-up ticket. Target WCAG 2.2 AA. Prefer native semantics over ARIA: the first rule of ARIA is don't use ARIA when a native element does the job.

## Semantics and structure

- Use native elements for their meaning: `<button>` for actions, `<a href>` for navigation, `<nav>`/`<main>`/`<header>`/`<footer>` landmarks, `<ul>`/`<ol>` for lists. A `<div onClick>` is not a button.
- One `<h1>` per page; headings descend without skipping levels (`h1 → h2 → h3`). Headings convey structure, not size — style with CSS.
- Every page region is inside a landmark so screen-reader users can jump between them.

## Names, labels, and images

- Every form control has a programmatic label — `<label for>`, wrapping `<label>`, or `aria-label`/`aria-labelledby`. Placeholder text is not a label.
- Interactive elements have an accessible name (visible text, or `aria-label` when icon-only).
- `<img>` has `alt`: descriptive for meaningful images, `alt=""` for decorative ones.
- Group related controls (`<fieldset>` + `<legend>`); associate errors with their field via `aria-describedby`.

## Keyboard and focus

- Every interactive control is reachable and operable by keyboard (Tab/Shift-Tab, Enter/Space). No keyboard traps.
- Focus is always visible — never `outline: none` without an equally clear replacement (`:focus-visible`).
- Manage focus on route change, dialog open/close, and dynamic content: move focus to the new context; return it on close. Don't rely on DOM order alone for modals.
- Logical tab order follows reading order; avoid positive `tabindex`.

## Color, motion, and dynamic content

- Don't convey information by color alone — pair with text, icon, or pattern.
- Text contrast ≥ 4.5:1 (≥ 3:1 for large text and UI component boundaries).
- Honor `prefers-reduced-motion`; no content flashes more than 3×/second.
- Announce async updates (validation, toasts, loading) via an `aria-live` region or a role like `status`/`alert`, so they aren't silent to assistive tech.

## ARIA — only when native won't do

- Reach for ARIA only to fill a gap native HTML can't (e.g. `role="tab"`, `aria-expanded`, `aria-current`). A wrong ARIA role is worse than none.
- Keep ARIA state in sync with actual state (`aria-expanded`, `aria-selected`, `aria-checked`).

## Definition of done

- Accessibility is part of an increment's definition of done — verifiable, not aspirational (links the `## Acceptance` criteria in `/implement` and the path assertions in `/scenario`).
- Verify with the keyboard (no mouse), a screen-reader pass on new/changed flows, and an automated check (axe / Lighthouse / Playwright's `@axe-core/playwright`) in the quality gate.
- Role-based test selectors (`getByRole`) double as an accessibility check — if you can't select a control by role+name, neither can assistive tech (see `e2e-testing.md`). `react.md` / `angular.md` cover framework-specific a11y patterns.
