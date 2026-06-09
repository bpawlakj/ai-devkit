---
title: SL AiDLC external repos — concrete borrow scan for ai-devkit
date: 2026-06-09
type: investigation
status: decided
decision: "Borrow in three tiers, restraint-first. Tier 1 (conventions/concrete mechanisms — decision-log shape, shared fresh-verification reference, /eval improvements, git-guardrails fold-in, OTel cost spans) is recommended now; Tier 2 (new skills /grill /handoff /architecture-review /quickstart) each pass a test-of-inclusion before creation; Tier 3 (GNAP board, gh-aw safe-output, BMAD personas) defers to sl-aidlc/extensions. The binding risk for ai-devkit is bloat, not missing features."
related:
  - docs/analyzes/sl-aidlc-requirements-gap.md
  - ../sl-aidlc/docs/02-research-existing-approaches.md
---

# SL AiDLC external repos — concrete borrow scan for ai-devkit

## Context

`sl-aidlc/docs/02-research-existing-approaches.md` evaluated ~14 external
tools/repos against the SL AiDLC requirement set and recommended "assemble + thin
layer." `docs/analyzes/sl-aidlc-requirements-gap.md` then mapped those
requirements onto ai-devkit and bucketed the gaps (A = close in ai-devkit, B =
SL-specific, C = process layer), referencing external patterns *abstractly*
("reuse BMAD `evals/`", "OpenSpec `changes/`", "gh-aw safe-output").

This document is the missing concrete layer: I visited the priority repos and
extracted **specific, liftable artifacts** — file shapes, mechanisms, snippets —
and rated each for ai-devkit, filtered through Bucket A gaps and the process
layer. It is a companion to the gap analysis, not a replacement.

## Question

For each external repo in doc 02 (scoped to ai-devkit's Bucket-A gaps + the
SL process layer), what concrete artifact can ai-devkit borrow, what gap does it
close, and — given ai-devkit's competitive edge is being a *lean, composable*
Assemble base — what should it deliberately NOT borrow?

## Findings

Investigation mode: 5 parallel subagents over OpenSpec + Spec Kit, BMAD-METHOD,
mattpocock/skills, gh-aw + GNAP + open-gitagent, and Anthropic best-practices +
Harper Reed + Squad + ghuntley. Verdicts are HIGH/MEDIUM/LOW borrow-value **for
ai-devkit specifically**.

### Decision-log + artifact standard (closes A3, a v1-MUST)

- **OpenSpec `ADDED`/`MODIFIED`/`REMOVED` delta markers** and the `specs/`
  (source-of-truth) vs `changes/` (proposed delta) split. HIGH. ai-devkit should
  express brownfield `plan.md` (and the brownfield product-spec template) as
  diffs against a baseline using these three headers — it matches `/discover`'s
  existing "Inherited state" and makes change reviewable. [OpenSpec concepts](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md)
- **OpenSpec archived-proposal-as-record** (`changes/archive/{timestamp}-{name}/`,
  full context preserved). MEDIUM-HIGH. Backs A3: on initiative completion, emit a
  dated `D-NNN` decision entry rather than leaving loose ADRs. [OpenSpec README](https://github.com/Fission-AI/OpenSpec/blob/main/README.md)
- **Spec Kit `FR-NNN`/`SC-NNN` numbering, `[NEEDS CLARIFICATION]` in-artifact
  markers, and `memory/constitution.md`**. HIGH. The numbering convention is the
  direct model for `D-NNN` log entries; `[NEEDS CLARIFICATION]` mirrors
  ai-devkit's ambiguity gates as an *in-document* marker; `constitution.md` is a
  sibling "standing principles" file. [spec-template](https://github.com/github/spec-kit/blob/main/templates/spec-template.md), [constitution-template](https://github.com/github/spec-kit/blob/main/templates/constitution-template.md)
- NOT to borrow: OpenSpec's propose/apply CLI + branch-per-spec `specs/[branch]/`
  layout (conflicts with `docs/work/<NNN>-<slug>/`; `/save-plan`+`/atomize`+`/implement`
  already own that lifecycle).

### Verification spine — author never grades own output (anti-vibe-coding)

- **Anthropic verification-by-fresh-model**: a verification subagent sees only the
  diff + acceptance criteria, *not* the reasoning that produced it; tell it to flag
  correctness/requirement gaps only (a gap-hunting reviewer over-reports on style).
  HIGH. `/eval` already implements this (fresh-judge rubric grader); `/implement`
  Step 5 and `/scenario` do not state the blind-to-reasoning constraint. Extract a
  shared `references/fresh-verification.md` and cite it from `/implement`, `/eval`,
  `/scenario`. Cheapest high-leverage borrow in the whole scan. [Anthropic best practices](https://code.claude.com/docs/en/best-practices)
- Squad independently enforces the same rule ("rejected code is reviewed by a
  *different* agent, not revised by its author"). [Squad](https://github.blog/ai-and-ml/github-copilot/how-squad-runs-coordinated-ai-agents-inside-your-repository/) Convergent evidence, MEDIUM on its own.

### /eval improvements (the harness just shipped — these refine it)

- **BMAD declarative eval shape**: per-eval NL `expectations[]` (a checklist of
  plain-English assertions an LLM judge checks one-by-one) + a **pattern taxonomy**
  — A artifact-correctness, B process-discipline (inspects side-artifacts like a
  decision log/transcript), C config-compliance. HIGH. Add a `pattern:` dimension
  to golden tasks and prefer granular assertion checklists over one holistic
  rubric — grades more deterministically. [BMAD evals](https://github.com/bmad-code-org/BMAD-METHOD/tree/main/evals/bmm-skills/bmad-product-brief)
- **BMAD `triggers.json`** — a `{query, should_trigger}` corpus with adversarial
  negatives, testing skill *routing/dispatch* separately from output quality.
  HIGH. ai-devkit has many overlapping workflow skills and no test that trigger
  phrases fire correctly and don't over-trigger; add a per-skill trigger-discrimination
  fixture (bats or eval).
- Confirmed: BMAD ships **no runner, no baseline, no thresholds** in-repo, and only
  one skill has evals. ai-devkit's `baseline.json` + thresholds + regression loop is
  **ahead** — keep it; borrow only the pattern taxonomy + assertion granularity.

### Guardrails (trivial, complementary)

- **mattpocock git-guardrails** — a PreToolUse Bash hook (grep pattern array →
  exit 2) blocking `git push`/`reset --hard`/`clean -fd`/`branch -D`/`checkout .`.
  MEDIUM-HIGH. Identical mechanism to ai-devkit's `claude/scripts/cloud-guard.sh`,
  which covers AWS/kubectl/helm but **not git** — a complementary blind spot. Fold
  the git patterns into cloud-guard.sh (one more block), don't add a second hook.
  Adopt their interactive scope/customize/verify install UX. [git-guardrails](https://github.com/mattpocock/skills)
- **gh-aw safe-output / scoped-apply**: agent runs read-only and emits intended
  actions as JSONL; a separate scoped job applies only what's permitted, with
  per-op hard limits (`max:`), over-limit dropped-and-logged (run doesn't fail).
  HIGH concept, but CI-bound. ai-devkit's cloud-guard is a *block-list*; this is the
  inverse *positive-control*. Lift the JSONL contract + `max:`/filter schema into
  `/ci-setup` (A6) — not the 3-job GitHub-Actions sequencing. [gh-aw safe-outputs](https://github.github.io/gh-aw/reference/safe-outputs/)

### Cost/telemetry (EVAL-02)

- **open-gitagent OTel cost spans** using standard `gen_ai.*` semantic-convention
  keys (`gen_ai.usage.input_tokens`/`output_tokens`, `gitagent.cost_usd`), span
  content **never contains prompt/completion text**. HIGH. Maps cleanly onto
  `/eval`'s `baseline.json` — record cost + token counts per skill/run with a
  `skill.name` attr; reuse the no-prompt-text privacy rule. [open-gitagent](https://github.com/open-gitagent/gitagent)

### Token economy / onboarding / roles (MEDIUM — guidance, not machinery)

- **BMAD web-bundle doctrine** ("plan on flat-rate web subscription → build in
  metered IDE"). MEDIUM as *guidance* (A7) — planning skills could emit a portable
  bundle note. Confirmed: BMAD has **no per-agent model assignment**, so there is
  no model-routing recipe to lift; A7's "model per skill" must be authored, not
  borrowed. [web-bundles](https://docs.bmad-method.org/explanation/web-bundles/)
- **BMAD persona shape** (`principles`, `persistent_facts`) incl. an optional **UX
  Designer**, and the **scale heuristic** (story-count → Quick/Method/Enterprise
  flow depth). MEDIUM — the role fields are a clean shape for a future UX skill, the
  heuristic informs a scale-adaptive `/discover`. Take the definitions + heuristic,
  not BMAD's owned 4-phase orchestration.
- **mattpocock CONTEXT.md** — a pure glossary (term → definition + *Avoid*
  synonyms), for naming consistency + token economy. MEDIUM — a lightweight
  `docs/reference/glossary.md` consumed by `/discover`, `/scenario`, `/agents-md`.

### Process layer — defer to sl-aidlc (Bucket C, not a tool gap)

- **GNAP 4-file `.gnap/` board**: `agents.json` (humans + AI register identically
  via `type: "ai"|"human"`), `tasks/{id}.json` (state machine
  backlog→ready→in_progress→review→done), `runs/{id}.json` (carries
  `tokens`/`cost_usd`/`commits` — converges with EVAL-02), `messages/{id}.json`
  (`to: ["*"]`, `type: directive|status|request|alert` = cross-role notification).
  "git history IS the audit log." HIGH for the SL process layer — it is the
  concrete substrate for human-role parallelism + ART-07 notification that doc 02
  §4 called unsolved. But it is **Bucket C (sl-aidlc), not ai-devkit**, and
  RFC-draft maturity — adopt the file shapes as a convention, don't depend on the
  tooling. [GNAP](https://github.com/farol-team/gnap)

## Alternatives considered

- **Option A — Tiered, restraint-first borrow (CHOSEN).** Tier 1 conventions now;
  Tier 2 new skills behind a test-of-inclusion; Tier 3 deferred to sl-aidlc.
  - Pros: closes the P0 v1-MUST (A3) and the cheapest high-leverage win
    (fresh-verification) immediately; protects ai-devkit's lean/composable edge by
    gating new skills; routes process-layer items to where they belong.
  - Cons: slower than a feature sprint; some Tier-2 value sits unrealized until a
    skill clears its gate.
  - Verdict: chosen — matches the gap analysis's Bucket scoping and the doc's own
    warning about owned-process bloat.
- **Option B — Borrow broadly / feature sprint.** Create all candidate skills now.
  - Pros: fast capability gain.
  - Cons: replicates BMAD's "21 agents, steep learning curve" weakness; trigger
    collisions; erodes the "third way" advantage. Rejected.
- **Option C — Catalogue only, decide later.** Pure scan, no recommendation.
  - Pros: zero commitment. Cons: wastes the grounding; the P0 A3 win is unarguable
    and shouldn't wait. Rejected (folded into Tier sequencing instead).

## Anti-bias cross-check

### Devil's advocate
ai-devkit's standing in the SL research is the lean Assemble base that is "● on the
expensive generic parts." Its real risk is **bloat, not missing features**. Doc 02
praises mattpocock/skills precisely for the *third way* — small, composable, no
imposed flow — and dings BMAD for a steep 21-agent learning curve. Cherry-picking a
spree of skills would reproduce the over-ownership mattpocock warns against. Several
Tier-2 candidates overlap existing skills: `/grill` vs `/discover`, `/quickstart` vs
a `/discover --minimal`, `/architecture-review` vs `/repo-map`, and the
deliberately-dropped `/to-prd` vs `/product-spec`. The defensible core is Tier 1
(conventions + one shared reference + eval refinements), which adds almost no
surface area; every Tier-2 skill must justify itself against an existing one or it
is net-negative.

### Pre-mortem
Six months on, ai-devkit has 20+ skills with overlapping trigger phrases; the
dispatcher fires `/grill` when the user meant `/discover`, `/quickstart` collides
with `/discover`, and the toolkit that won on "lean + composable" now loses on
"confusing sprawl" — BMAD's documented failure, now self-inflicted. Signals we
ignored: the gap analysis scoped only Bucket A as in-scope and counselled restraint;
the source doc's own thesis that owning-the-process is the anti-pattern; the
test-of-inclusion that `/agents-md` already enforces for rules but we skipped for
skills.

## Decision

Borrow in **three tiers, restraint-first**:

- **Tier 1 — adopt now (conventions + refinements, near-zero new surface):**
  (1) the `D-NNN` numbered decision-log convention drawing on OpenSpec delta
  markers + Spec Kit numbering (closes A3, a v1-MUST); (2) a shared
  `references/fresh-verification.md` wired into `/implement` + `/scenario` (`/eval`
  already has it); (3) `/eval` refinements — pattern taxonomy (artifact/process/
  config) + granular NL-assertion checklists + a `triggers.json` discrimination
  fixture; (4) fold mattpocock git patterns into `cloud-guard.sh`; (5) `gen_ai.*`
  OTel cost/token into `baseline.json` (EVAL-02).
- **Tier 2 — new skills, each behind a test-of-inclusion vs the existing skill it
  resembles, before any code:** `/grill` (adversarial plan/spec stress-test before
  `/atomize` — distinct from forward-elicitation `/discover`), `/handoff`
  (cross-session context compaction — no current equivalent), `/architecture-review`
  (deletion-test + seam vocabulary + grilling loop — distinct from descriptive
  `/repo-map`), `/quickstart` (Harper's minimal `spec.md`/`plan.md`/`todo.md`
  on-ramp for low-maturity devs — likely a `/discover --minimal` flag, not a new
  skill).
- **Tier 3 — defer to sl-aidlc / `extensions/`:** GNAP `.gnap/` coordination board
  (process layer C), gh-aw safe-output/scoped-apply + firewall (A6, CI-bound),
  BMAD personas/scale-flow (role layer), CONTEXT.md glossary, web-bundle doctrine.

Rationale: Tier 1 closes the headline P0 gap and the cheapest high-leverage win
while adding no skill sprawl; Tier 2's gate preserves the lean/composable advantage
that *is* ai-devkit's value in the SL "build vs assemble" decision; Tier 3 sits
where the gap analysis already placed it.

## Open questions

- **Which Tier-2 skills clear the test-of-inclusion?** Owner: maintainer. Path: run
  each candidate through `/agents-md`'s inclusion test (does it duplicate an
  existing skill's job? cite the distinguishing trigger). Resolve before authoring.
- **`/quickstart` vs `/discover --minimal`** — new skill or a flag? Path: prototype
  the flag first; only promote to a skill if the minimal lane diverges materially.
- **Decision-log mechanics (A3)** — numbered `docs/architecture/decisions/D-NNN.md`
  files vs a single appended log? Path: a focused follow-up `/research` or design
  note; this scan only fixes the *shape* (numbered, dated, delta-aware), not the
  storage.
- **Trigger-collision audit** — before adding any Tier-2 skill, inventory current
  skill trigger phrases for overlap (the pre-mortem's failure mode). Owner:
  maintainer; the BMAD `triggers.json` borrow (Tier 1) is the tool for it.
- **GNAP/process layer** — belongs to the sl-aidlc `integration/ai-devkit-shared-files`
  branch, not this repo; cross-reference rather than build here.
