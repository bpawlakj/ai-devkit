---
applyTo: "**/*.tsx,**/*.jsx,**/*.vue,**/*.svelte,**/*.html,**/*.component.ts,**/*.component.html"
---
# Accessibility Standards (WCAG)

Accessibility is built in from the first line of UI, never retrofitted. An inaccessible component is incomplete — a missing label or unreachable control is a bug, not a follow-up. Target WCAG 2.2 AA. Prefer native semantics over ARIA.

## Semantics and structure
- Native elements for meaning: `<button>` for actions, `<a href>` for navigation, landmarks (`<nav>`/`<main>`/`<header>`/`<footer>`), `<ul>`/`<ol>` for lists. A `<div onClick>` is not a button.
- One `<h1>` per page; headings descend without skipping (`h1 → h2 → h3`); style size with CSS, not heading level.
- Every region sits inside a landmark.

## Names, labels, images
- Every form control has a programmatic label (`<label for>`, wrapping `<label>`, or `aria-label`/`aria-labelledby`). Placeholder ≠ label.
- Interactive elements have an accessible name (visible text or `aria-label` when icon-only).
- `<img>` has `alt` — descriptive when meaningful, `alt=""` when decorative.
- Associate errors with fields via `aria-describedby`; group controls with `<fieldset>` + `<legend>`.

## Keyboard and focus
- Everything interactive is keyboard-reachable and operable (Tab/Shift-Tab, Enter/Space); no keyboard traps.
- Focus always visible — never `outline: none` without a clear `:focus-visible` replacement.
- Manage focus on route change, dialog open/close, dynamic content; logical tab order; avoid positive `tabindex`.

## Color, motion, dynamic content
- Never convey meaning by color alone; text contrast ≥ 4.5:1 (≥ 3:1 large text / UI boundaries).
- Honor `prefers-reduced-motion`; nothing flashes > 3×/second.
- Announce async updates via `aria-live` / `role="status"` / `role="alert"`.

## ARIA — only when native won't do
- Use ARIA only to fill a real gap (`role="tab"`, `aria-expanded`, `aria-current`); a wrong role is worse than none.
- Keep ARIA state synced with actual state.

## Definition of done
- Accessibility is part of an increment's definition of done — verifiable, not aspirational.
- Verify keyboard-only, a screen-reader pass on changed flows, and an automated check (axe / Lighthouse / `@axe-core/playwright`) in CI.
- `getByRole`-style selectors double as an a11y check: if a control can't be selected by role+name, assistive tech can't reach it either.
