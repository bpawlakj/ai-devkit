---
title: EARS notation — worth borrowing into ai-devkit acceptance criteria?
date: 2026-06-10
type: technology-evaluation
status: decided
decision: "Do not adopt EARS as a convention — it adds syntax without new semantics (the oracle rule + observable-behavior guard already exist), and the marginal value does not justify another convention to police. One salvage: task-schema gains a single un-branded hint to phrase failure/edge criteria as 'If <trigger>, then <expected response>'."
related:
  - docs/analyzes/sl-aidlc-external-repos-borrow-scan.md
  - docs/analyzes/sl-aidlc-ai-devkit-combined-workflow.md
  - ../sl-aidlc/docs/02-research-existing-approaches.md
---

# EARS notation — worth borrowing into ai-devkit acceptance criteria?

## Context

SL AiDLC's research doc (`sl-aidlc/docs/02-research-existing-approaches.md` §2.5)
evaluated Amazon Kiro and concluded "EARS notation is worth borrowing for
acceptance criteria; the tool itself carries the lock-in we want to avoid." The
ai-devkit borrow scan (`docs/analyzes/sl-aidlc-external-repos-borrow-scan.md`)
covered OpenSpec, Spec Kit, BMAD, mattpocock/skills, gh-aw, GNAP and others — but
**not Kiro**, so EARS was the one flagged borrow candidate with no ai-devkit
verdict. This evaluation closes that hole.

## Question

Should ai-devkit adopt the EARS notation (Easy Approach to Requirements Syntax)
as a convention for writing acceptance criteria — and if so, where (task-level
`## Acceptance`, product-spec, both) and how strictly?

## Findings

Investigation mode: 3 parallel subagents (canonical sources, adoption/criticism,
ai-devkit current state).

### What EARS is

Created by Alistair Mavin et al. at Rolls-Royce, published at IEEE RE'09
([paper, DOI 10.1109/RE.2009.9](https://ieeexplore.ieee.org/document/5328509)),
originally for extracting aero-engine control requirements from airworthiness
regulation. Five single-sentence patterns plus a complex combination
([alistairmavin.com/ears](https://alistairmavin.com/ears/)):

| Pattern | Template |
|---|---|
| Ubiquitous | `The <system> shall <response>` |
| Event-driven | `When <trigger>, the <system> shall <response>` |
| State-driven | `While <state>, the <system> shall <response>` |
| Unwanted behaviour | `If <trigger>, then the <system> shall <response>` |
| Optional feature | `Where <feature included>, the <system> shall <response>` |
| Complex | combinations, e.g. `While <state>, when <trigger>, the <system> shall <response>` |

The RE'09 case study targeted 8 natural-language problems (ambiguity, vagueness,
complexity, omission, duplication, wordiness, inappropriate implementation,
untestability); rewriting 36 raw requirements into 47 EARS requirements cut
average word count 36.9 → 25.6 and eliminated 5 of the 8 problem classes
([open PDF](https://ccy05327.github.io/SDD/08-PDF/Easy%20Approach%20to%20Requirements%20Syntax%20%28EARS%29.pdf)) —
authors note small-sample limitations. Industrial adoption is broad: Airbus,
Bosch, Dyson, Honeywell, Intel, NASA, Rolls-Royce, Siemens
([alistairmavin.com/ears](https://alistairmavin.com/ears/)); Intel reported rapid
internal adoption ([Terzakis, ICCGI 2013](https://www.iaria.org/conferences2013/filesICCGI13/ICCGI_2013_Tutorial_Terzakis.pdf),
qualitative only).

### EARS in AI coding tools

- **Amazon Kiro** uses EARS as the format for acceptance criteria in
  `requirements.md` (`WHEN [condition] THE SYSTEM SHALL [behavior]`), claiming
  clarity/testability/traceability ([kiro.dev specs docs](https://kiro.dev/docs/specs/feature-specs/)).
- **GitHub spec-kit** has an open feature request to integrate EARS — not
  built-in ([spec-kit#1356](https://github.com/github/spec-kit/issues/1356));
  a VS Code feature request asks to copy Kiro's EARS requirements.md
  ([vscode#261160](https://github.com/microsoft/vscode/issues/261160)).
- **No empirical evidence** that EARS-formatted requirements improve coding-agent
  output. All such claims are vendor/advocacy; academic work covers LLMs
  *generating* EARS requirements, not agent outcomes
  ([arxiv 2310.13976](https://arxiv.org/pdf/2310.13976),
  [arxiv 2408.10886](https://arxiv.org/pdf/2408.10886)). (uncited beyond absence
  of evidence — treated as an open question, not a claim either way)

### Criticism and limits

- Poor fit for requirements with >3 preconditions, math-heavy or diagram-shaped
  content; "more valuable to convey meaning than force it into a template"
  ([QRA, When not to use EARS](https://qracorp.com/when-not-to-use-ears/)).
- **The over-generation failure mode**: Birgitta Böckeler (Thoughtworks) ran Kiro
  on a small bug fix and got 4 user stories with 16 EARS acceptance criteria —
  cited as evidence that spec/EARS ceremony scales poorly downward
  ([Marmelab, "Waterfall Strikes Back"](https://marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back.html),
  [HN thread](https://news.ycombinator.com/item?id=45935763)). Templates invite
  LLMs to fill them with padding.
- vs Gherkin: complementary, not competing — Gherkin is an executable,
  multi-line collaboration format; EARS is a single-sentence behavior contract.

### Current state in ai-devkit

- Task-level `## Acceptance` is **format-free**: the schema prescribes only
  "observable behavior, test cases, manual verification steps"
  (`claude/skills/atomize/references/task-schema.md:46-48`).
- The **semantic** half of what EARS provides is already enforced: `/implement`
  Step 4's oracle rule (assertions come from `## Acceptance`/spec, never from the
  implementation; `claude/skills/implement/SKILL.md:189-192`) and Step 3's
  vagueness gate ("What observable change proves this task is done?");
  `/scenario` quotes acceptance criteria verbatim as the assertion oracle
  (`claude/skills/scenario/references/scenario-schema.md:50-54,119-121`).
- Product-spec level already uses **Given/When/Then** for User Stories plus
  bulleted acceptance criteria (`claude/skills/discover/references/product-spec-schema.md:100-113`)
  — a second syntax exists there by design and is not in conflict (GWT describes
  a scenario flow; EARS states an atomic behavior contract).
- No EARS/Gherkin conventions anywhere in the repo today; Gherkin-as-artifact was
  explicitly rejected in `docs/analyzes/e2e-scenario-skill-web-backend-decision.md`.

### Fit assessment

The natural slot is the task-level `## Acceptance` section — the one place with
no prescribed shape. Two mappings make EARS attractive there:

1. **Unwanted-behaviour pattern → pessimistic paths**: `If <trigger>, then the
   <system> shall <response>` maps 1:1 onto `/scenario`'s `@pessimistic` path
   type — today pessimistic acceptance criteria are the most under-specified.
2. **Trigger/response structure → arrange/act/assert**: an event-driven EARS
   criterion is directly transcribable into a test (`When` = act, `shall` =
   assert), reinforcing the existing oracle rule rather than replacing it.

The binding risk is the Kiro/Böckeler failure mode: a mandatory template makes
`/atomize` (an LLM) over-generate ceremonial criteria. Any adoption must be a
*recommended pattern with an anti-padding guard*, not a required syntax.

## Alternatives considered

- **Option A — Borrow conditionally (initially chosen, overturned).** EARS as the recommended pattern
  for *behavioral* criteria in task-level `## Acceptance`; non-behavioral
  criteria ("README updated") stay plain bullets; explicit anti-padding rule
  (criteria enumerate real behaviors, not template filler); product-spec GWT
  untouched.
  - Pros: near-zero surface (a schema note + skill prompt lines); strengthens
    the weakest spot (pessimistic criteria); reinforces the oracle rule;
    keeps the lean-convention philosophy.
  - Cons: two notations across levels (GWT at spec, EARS at task) — mitigated by
    their different jobs; padding risk persists and needs the guard.
  - Verdict: initially chosen at the anti-bias gate, then overturned on maintainer
    review — the deciding observation: a convention that needs a second rule
    (anti-padding guard) to police itself is over-engineering by its own shape,
    and the added value over the existing semantic guards is minimal.
- **Option B — Adopt EARS as mandatory task syntax.**
  - Pros: maximal consistency, machine-checkable.
  - Cons: reproduces Kiro's documented failure (16 criteria for a bug fix);
    contorts non-behavioral criteria into "shall" sentences; against ai-devkit's
    restraint-first doctrine. Rejected.
- **Option C — Don't borrow; keep freeform + oracle rule.**
  - Pros: zero new convention; the semantic guards already exist.
  - Cons: leaves task-level criteria shapeless where a cheap, proven pattern
    (especially If/then for unwanted behavior) demonstrably sharpens them; the
    SL research already flagged the borrow as worthwhile.
  - Verdict: **CHOSEN, in a variant** — no EARS convention, no guard, but the one
    demonstrably useful piece is salvaged as a single un-branded line in the task
    schema: failure/edge criteria phrased as "If <trigger>, then <expected
    response>". One line of guidance, no named notation, nothing to police.

## Anti-bias cross-check

### Devil's advocate

ai-devkit already owns the load-bearing half: the oracle rule and the
observable-behavior requirement are *semantic* guards, and EARS adds only
*syntax*. The strongest case against borrowing is that syntax without new
semantics is ceremony — and worse, ceremony that LLMs actively abuse: the
Böckeler/Kiro case shows a template invites over-generation, so the borrow could
*degrade* `## Acceptance` quality, the opposite of its intent. Two notations
(GWT at spec level, EARS at task level) also add a small learning cost. The
chosen mitigation — recommended-not-required + anti-padding guard + bullets for
non-behavioral criteria — directly answers this, but if the guard proves
unenforceable in `/atomize` output, Option C is the honest fallback.

### Pre-mortem

Six months on, `/atomize` emits ten "THE SYSTEM SHALL" sentences per trivial
task; users stop reading `## Acceptance`; review quality drops — exactly the
Kiro failure we documented and then walked into. Signals at decision time: no
empirical evidence EARS helps agent output; the only large-scale LLM+EARS data
point (Kiro) is the negative one; templates+LLMs over-generate. The guard that
must hold: criteria count is bounded by real behaviors, and `/implement` Step 3's
vagueness gate is matched by a new conciseness gate.

## Decision (if any)

**Do not adopt EARS as a convention.** The semantic half of its value (criteria
must be observable behavior; assertions come from the spec, never the code) is
already enforced by `/implement` and `/scenario`; what remains is syntax, and a
syntax that demonstrably invites LLM over-generation (the Kiro/Böckeler case) and
would have required its own anti-padding guard — a rule policing a rule, which is
the over-engineering tell. Token cost and convention-maintenance cost exceed the
minimal added value. **One salvage**: the task schema gains a single un-branded
hint — failure/edge criteria phrased as `If <trigger>, then <expected response>`
(`claude/skills/atomize/references/task-schema.md`, `## Acceptance` section) —
because under-specified pessimistic criteria were the one real weakness found.
Recorded as `docs/architecture/decisions/D-001-no-ears-convention.md`.

## Open questions

- **Does the single If/then hint measurably sharpen pessimistic criteria?** Path:
  observe `/atomize` output over the next initiatives; if failure-path criteria
  remain vague, the hint alone was insufficient — revisit (a `/scenario`-side
  hint would be the next cheapest step, full EARS still off the table unless new
  evidence appears). Owner: maintainer.
- **EARS in product-spec acceptance bullets?** Out of scope and now unlikely —
  GWT + bullets work there; reopen only with empirical evidence that structured
  notations improve agent output.
