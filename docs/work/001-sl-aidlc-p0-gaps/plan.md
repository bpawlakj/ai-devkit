# SL AiDLC P0 gaps — close the three v1-MUSTs ai-devkit fails today

Source: `docs/analyzes/sl-aidlc-requirements-gap.md` (Bucket A, P0 roadmap).

ai-devkit is the strongest "Assemble" candidate for SL AiDLC's D-A decision, but the gap analysis
found **three SL AiDLC v1-MUST requirements ai-devkit does not satisfy today**. Closing these turns
ai-devkit from "strong base with caveats" into "satisfies the SL v1 Execution MUSTs" — the decisive
evidence for D-A. Each item stays general-purpose (no SL-specific content; see the gap doc's
Bucket B for what is intentionally excluded).

## P0-1 — EVAL harness (`/eval` skill + `evals/` convention)

Closes **EVAL-05 / EVAL-07**. Without a concrete eval harness, P10 (resilience to model change)
cannot hold and the "no demo-driven AI" anti-pattern is unenforceable. EVAL-07 demands a *concrete*
v1 harness, not just the principle.

A new `/eval` skill plus an `evals/` directory convention: golden tasks with expected outcomes, a
recorded baseline, pass/fail acceptance thresholds, and a "run on model/harness upgrade → diff
against baseline" regression command. Reuse: BMAD ships an `evals/` directory as prior art;
`/ci-setup` already wires coverage gates, so the eval run can hook the same CI surface and
AI-reviewer recipe.

## P0-2 — Accessibility by design (`rules/accessibility.md` + DoD)

Closes **A11Y-01..03 / P11**. Accessibility is a first-class, day-one requirement in SL AiDLC,
never a retrofit, and part of an increment's definition of done (A11Y-03 links INC-02 / TEST-03).
ai-devkit only touches it incidentally today.

A new auto-active `rules/accessibility.md` (13th rule) — WCAG essentials, semantic landmarks, form
labels, `aria-*`, contrast, keyboard support — gated to UI file globs; plus an A11Y line in
`/scenario` path generation and in `/implement` Step-4 definition-of-done; mirrored to
`copilot/instructions/accessibility.md`. Reuse: `rules/e2e-testing.md` already prefers role-based
selectors; the 12 existing rules give the exact authoring + activation pattern.

## P0-3 — Living numbered decision-log convention

Closes **ART-03**. ART-03 requires a decisions log as a *required living artifact*, each entry
numbered (D-01, D-02…) with date, rationale, and context. ai-devkit keeps ADRs in
`docs/architecture/` but does not enforce a numbered living log.

A thin convention: a numbered `docs/architecture/decisions/` ADR log (D-NNN,
date/context/rationale/status) scaffolded by `/setup`, appended by `/research` when a decision is
reached, and referenced from `/implement`. Reuse: OpenSpec's `changes/` + lightweight-decision-log
pattern; the existing `docs/architecture/` directory and `/research` snapshot shape. Keep it a
convention + tiny scaffold, not a heavyweight new skill.
