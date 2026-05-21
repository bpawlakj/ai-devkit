---
name: discover
description: >
  Facilitate a structured discovery conversation that turns an idea —
  greenfield or brownfield — into discover-notes.md, the input to /product-spec.
  Auto-detects context type from project markers in cwd (brownfield) or
  absence thereof (greenfield) and adapts all six discovery phases accordingly.
  For brownfield, automatically scans docs/product-spec.md, docs/architecture/,
  and docs/work/ for inheritable state (vision, persona, access control,
  business logic, FRs, NFRs) and switches to delta-only elicitation — systems
  evolve, they do not rebuild. Inheritance is written to a ## Inherited state
  section so each phase only asks what is changing.
  Use when the user is starting a new project from scratch OR shaping a
  meaningful change to an existing system (new module, significant feature,
  architectural improvement). Trigger phrases: "new project", "from scratch",
  "starting an app", "shape an idea", "brainstorm a product", "greenfield",
  "I have an idea", "existing project", "brownfield".
  Use BEFORE /product-spec, not in place of it.
argument-hint: "[freeform idea]"
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - Skill
---

# Discover: Facilitate Discovery (Greenfield & Brownfield) Before /product-spec

This skill walks a user from "I have an idea" (greenfield) or "I want to change this system" (brownfield) to a structured `docs/discover-notes.md` that `/product-spec` can turn into a spec that conforms to the locked schema.

The skill is a **facilitator**, not a content generator. It NEVER writes vision, FRs, business-logic rules, or any other domain content the user did not say. Its value is the question shape and the order of questions, not the answers it offers.

The locked schema both this skill and `/product-spec` conform to lives at `references/product-spec-schema.md` (relative to this SKILL.md). Read it before producing any artifact and re-check against it at every checkpoint write.

## When to use, when to skip

**Use when**: the user describes a new project idea (greenfield), a meaningful change to an existing system — new module, significant feature, architectural improvement (brownfield), or a product they want to rebuild from first principles. Use also when an existing `docs/discover-notes.md` is incomplete and needs resuming. The skill auto-detects context type from project markers in cwd and adapts.

**Skip when**: the project already has a product spec, or the user is reasoning about a single bug / refactor / small feature within an existing codebase that doesn't warrant a full spec.

## Relationship to other skills

- `/kickoff` — scaffolds the `/docs` skeleton (`architecture/`, `analyzes/`, `reference/`, `work/`) plus READMEs. `/discover` requires `docs/` to exist; if absent, it delegates to `/kickoff` via the `Skill` tool (Step 0 below).
- `/product-spec` — consumes `discover-notes.md`. The handoff is the `## Step 8` clipboard write.
- `docs/reference/` — any file type (`.md`, `.pdf`, `.docx`, `.xlsx`, `.png`, link-collection `.md`, etc.) the user has placed there as input material. `/discover` scans this directory once at Step 0.8, lets the user pick which items are in-scope, and threads them through every phase as supporting evidence.

## Initial Response

When this skill is invoked:

1. **If a freeform idea was provided as the argument** (e.g. `/discover a recipe app that suggests meals from what's in your fridge`), capture it verbatim as the **seed idea**. Do not rephrase. Proceed to Step 0.
2. **If a file path was provided** (e.g. `/discover @notes/idea.md`), read it FULLY and use its contents as the seed. Proceed to Step 0.
3. **If nothing was provided**, respond with:

```
I'll help you shape an idea into structured notes that /product-spec can turn into
a real spec — whether you're starting from scratch (greenfield) or shaping a
change to an existing system (brownfield).

Please share:
1. The seed idea — what do you want to build or change, in your own words?
2. (Optional) Any rough notes, sketches, or links I should read

Tip: pass the idea inline — `/discover a recipe app that uses fridge contents`
     or for brownfield — `/discover add a recommendation engine to my recipe app`

If you have existing material (briefs, PDFs, client requirements, link
collections), drop it in `docs/reference/` before running this skill — I'll
scan that folder at Step 0.8 and let you mark what's in-scope.
```

Then wait.

## Process

### Step 0: Check workspace precondition

Check the workspace scaffold by testing the foundation path:

```bash
test -d docs
```

If it exists, proceed to Step 0.5.

If missing, the project has not been initialized. Ask:

AskUserQuestion:
- question: "This directory isn't initialized (docs/ is missing). Run /kickoff now?"
  header: "Init?"
  options:
  - label: "Yes — run /kickoff (Recommended)"
    description: "Scaffolds the /docs skeleton (architecture/, analyzes/, reference/, work/) with READMEs, then continues discovery."
  - label: "No — stop here"
    description: "Exit without changes. You'll need to initialize before discover can run."
  multiSelect: false

On "Yes": invoke `/kickoff` via the **Skill** tool (NOT via Bash). When `/kickoff` returns, re-check the precondition; if it now passes, continue to Step 0.5. On "No": print "Stopping. Run `/kickoff` when ready, then re-invoke `/discover`." and STOP.

Do not duplicate `/kickoff`'s scaffold logic. The `Skill` tool is the correct delegation path.

### Step 0.5: Resume detection

Before starting fresh, check for a prior session:

```bash
test -f docs/discover-notes.md
```

If absent, proceed to Step 1 with a fresh session.

If present, read the file FULLY. Parse the frontmatter `checkpoint:` block per the schema reference (`references/product-spec-schema.md`, "discover-notes.md checkpoint format" section). Extract: `current_phase`, `phases_completed`, `frs_drafted`, `quality_check_status`.

Summarize what you found:

```
Found a prior discover session at docs/discover-notes.md:


  Project:                 [from frontmatter project field, or "(unnamed)"]
  Current phase:           [N — Phase name]
  Phases completed:        [list]
  FRs drafted so far:      [count]
  Quality check status:    [pending | warned | accepted]
```

Then ask:

AskUserQuestion:
- question: "How would you like to proceed?"
  header: "Resume?"
  options:
  - label: "Resume from Phase [next] (Recommended)"
    description: "Pick up where the prior session left off. Completed phases are summarized, not replayed."
  - label: "Restart from scratch"
    description: "Archive the existing discover-notes.md to docs/_archive/ and start a new session."
  - label: "Cancel"
    description: "Exit without changes."
  multiSelect: false

On "Resume": jump directly to the next unfinished phase (Step `current_phase` + (1 if current is in `phases_completed` else 0)). Do NOT re-run completed phases — only summarize each one back to the user in 1–2 sentences ("Phase 1 captured: <one-line problem>; Phase 2 captured: <one-line persona>; …") so they have context for what was already decided.

On "Restart": move the existing file to `docs/_archive/discover-notes-<YYYY-MM-DD-HHMM>.md` (create the archive directory if absent), then proceed to Step 1 with a fresh session.

On "Cancel": STOP without changes.

### Step 0.7: Context type detection

Before entering the discovery loop, determine whether this is a greenfield or brownfield session. The detection runs once; the result (`context_type`) is written into discover-notes.md frontmatter and governs phase behavior for the rest of the session.

**Auto-detection**: score cwd across three signal tiers. A single manifest file isn't enough — an empty `npm init -y` directory shouldn't trigger brownfield.

```bash
# Tier 1 (strong): version control with history
git log --oneline -1 2>/dev/null && echo "T1:git-history"

# Tier 2 (medium): lockfiles prove real dependency resolution happened
ls package-lock.json yarn.lock pnpm-lock.yaml Cargo.lock poetry.lock go.sum Gemfile.lock composer.lock 2>/dev/null | while read f; do echo "T2:$f"; done

# Tier 3 (weak): manifest files alone — could be a fresh init
ls package.json Cargo.toml pyproject.toml go.mod Gemfile composer.json 2>/dev/null | while read f; do echo "T3:$f"; done

# Bonus signals (confirm, don't trigger alone): source dirs, framework configs, CI
ls -d src/ app/ lib/ .github/ .gitlab-ci.yml Dockerfile tsconfig.json next.config.* vite.config.* 2>/dev/null | while read f; do echo "B:$f"; done
```

Scoring:
- **Tier 1 hit** (git history exists) → strong brownfield signal
- **Tier 2 hit** (lockfile exists) → strong brownfield signal
- **Tier 1 + Tier 2** → high-confidence brownfield
- **Tier 3 only** (manifest, no lockfile, no git) → ambiguous — could be a fresh `npm init`
- **No signals** → greenfield

Decision logic:
- **Any Tier 1 or Tier 2 hit** → propose `context_type: brownfield`
- **Tier 3 only** → propose brownfield but flag the ambiguity: "I found a manifest file but no lockfile or git history — this might be a freshly initialized project rather than a real brownfield."
- **No signals** → propose `context_type: greenfield`

Print what was detected:

- **High-confidence brownfield** (T1 or T2):
  ```
  This looks like an existing project:
    [list detected signals, e.g. "git history (47 commits)", "package-lock.json", "src/ directory"]
  I'll run in brownfield mode — focusing on what exists, what's changing,
  and what must be preserved.
  ```

- **Ambiguous** (T3 only):
  ```
  I found [manifest file] but no lockfile or git history — this could be a
  freshly initialized project or a real brownfield. I'll propose brownfield
  mode, but override to greenfield if you're starting from scratch.
  ```

- **Greenfield** (no signals):
  ```
  No project markers found in this directory — I'll run in greenfield mode,
  which assumes you're starting from scratch.
  ```

Then confirm with the user:

AskUserQuestion:
- question: "Detected context: [greenfield|brownfield]. Is this correct?"
  header: "Context"
  options:
  - label: "[Greenfield|Brownfield] — correct (Recommended)"
    description: "[Auto-detected mode description]"
  - label: "[Other mode] — override"
    description: "Switch to [other mode] instead."
  multiSelect: false

Write the confirmed `context_type` into the discover-notes.md frontmatter (alongside `checkpoint:`) immediately. This value is load-bearing for `/product-spec`'s auto-routing.

On resume (Step 0.5), if discover-notes.md already has `context_type:` in frontmatter, skip auto-detection — the mode is locked from the prior session.

### Step 0.8: Reference materials scan

Scan `docs/reference/` for input material the user has placed there. This is a one-time load — selected items are referenced throughout Steps 1–6 as supporting evidence.

```bash
test -d docs/reference && find docs/reference -maxdepth 2 -type f \
  ! -name 'README.md' \
  -printf '%p\t%s\t%TY-%Tm-%Td\n' 2>/dev/null \
  | sort
```

If `docs/reference/` is absent or contains only `README.md`, print one line — "No reference materials found in `docs/reference/`. Continuing without external context." Then jump to the Discovery pattern.

Otherwise, list what was found in a table:

```
Found reference materials in docs/reference/:

  [#]  [path]                             [type]  [size]  [last modified]
  1    client-brief.pdf                   pdf     420KB   2026-04-10
  2    client-brief.md                    md      2.1KB   2026-04-10
  3    competitor-analysis.xlsx           xlsx    180KB   2026-04-15
  4    links-payments-integration.md      md      3.4KB   2026-05-02
  5    existing-api-contracts.md          md      8.0KB   2026-03-18
```

Then ask:

AskUserQuestion:
- question: "Which materials are in-scope for this discovery session? Pick anything I should weave into the phases as context."
  header: "References"
  options:
  - one option per file found (label = filename, description = first 100 chars of the file's purpose if readable; for binaries, the sibling `.md` index if present, or "binary file — pair with a sibling .md index for searchable context")
  - "None — proceed without external materials"
  multiSelect: true

**For each selected item**, immediately read it (Read tool for `.md`, sibling `.md` for binaries) and capture in a session-local mental index:

- **Path** — full path under `docs/reference/`
- **Purpose tag** — what the file is FOR. Pick one: `existing-product-brief` / `client-requirements` / `competitor-data` / `external-link-index` / `api-contract` / `operational-spec` / `other`. The tag governs which phase the material is most relevant to.
- **One-line summary** — what's inside, in the user's-eye view.

Default phase-affinity by purpose tag (use as a hint, not a rule):

| Purpose tag                | Most relevant to phase                  |
|----------------------------|------------------------------------------|
| existing-product-brief     | Step 1 (Vision), Step 6 (Non-Goals)      |
| client-requirements        | Step 1, Step 4 (FRs)                     |
| competitor-data            | Step 1 (insight), Step 6 (Non-Goals)     |
| external-link-index        | Step 4 (FRs), Step 5 (Business Logic)    |
| api-contract               | Step 5 (Business Logic + NFRs)           |
| operational-spec           | Step 5 (NFRs), Step 6 (constraints)      |

Write the selected-materials list into `discover-notes.md` frontmatter under a `references:` key (alongside `checkpoint:` and `context_type:`):

```yaml
references:
  - path: docs/reference/client-brief.pdf
    purpose: existing-product-brief
    summary: "Stakeholder pitch from 2026-04-10 covering proposed v2 scope and personas."
  - path: docs/reference/links-payments-integration.md
    purpose: external-link-index
    summary: "Curated index of Stripe / Adyen vendor docs for payment integration research."
```

On "None": write `references: []` and proceed. This is valid — the gate is that the user explicitly considered external material, not that they used some.

If a `.md` sibling is missing for a binary (e.g. `client-brief.pdf` exists alone), surface a soft warning: "I can't read `client-brief.pdf` directly. Want me to skip it, or would you like to add a sibling `client-brief.md` index first? See `docs/reference/README.md` for the convention." Offer three options: skip / pause-to-add-index / read-binary-blindly (not recommended).

This step runs once. On resume (Step 0.5), if `references:` is already populated in frontmatter, skip the scan — the prior session's selections are locked. Print: "Using reference materials from prior session: [list]."

### Step 0.9: Inheritance scan (brownfield only — automatic)

**Greenfield sessions skip this step entirely** — there is nothing to inherit. Jump directly to the Discovery pattern.

For brownfield sessions, before entering the discovery loop, scan existing project artifacts that already describe the current state. Goal: detect what is already documented so subsequent phases ask only about the **delta** (what is changing), not the unchanged baseline. Systems evolve, not revolve — discover should not force the user to re-describe what is already on disk.

On resume (Step 0.5), if frontmatter already has `inherited_from:` populated, skip this step — inheritance is locked from the prior session. Print: "Inheriting from prior session: [list of sources]." Then continue.

**Detection — read these files in priority order:**

```bash
# 1. Canonical product spec (richest source)
test -f docs/product-spec.md && echo "FOUND: docs/product-spec.md"

# 2. Architecture / design docs
ls docs/architecture/*.md 2>/dev/null

# 3. Latest initiative plan (most recent delta already captured)
ls -dt docs/work/[0-9]*/ 2>/dev/null | head -1
```

If NONE of the three categories yields any file, print: "No existing artifacts found. Running brownfield mode without inheritance — each phase will elicit baseline + delta." Set `inherited_from: []` in frontmatter and proceed to Discovery pattern.

**Extraction — for each artifact found, read FULLY and extract inheritable elements:**

| Element                | Source (priority order)                                              |
|------------------------|----------------------------------------------------------------------|
| Vision / problem       | `docs/product-spec.md` § Vision                                      |
| Persona / user roles   | `docs/product-spec.md` § User & Persona; or architecture            |
| Access control model   | `docs/architecture/auth-*.md` or `docs/product-spec.md` § Access Control |
| Business logic / rule  | `docs/product-spec.md` § Business Logic                              |
| FRs (baseline)         | `docs/product-spec.md` § Functional Requirements                     |
| NFRs                   | `docs/product-spec.md` § Non-Functional Requirements                 |
| Existing non-goals     | `docs/product-spec.md` § Non-Goals                                   |
| `product_type`         | `docs/product-spec.md` frontmatter                                   |
| `target_scale`         | `docs/product-spec.md` frontmatter                                   |
| Latest delta context   | `docs/work/<latest>/plan.md` (most recent initiative)                |

For each element found, capture a one-line summary plus the source path.

**Present a summary table to the user:**

```
═══════════════════════════════════════════════════════════
  INHERITANCE SCAN — found existing artifacts
═══════════════════════════════════════════════════════════

  Element              Source                                  Inherited value (one-liner)
  ──────               ──────                                  ─────────────
  Vision               docs/product-spec.md                    Personal trainer billing automation focused on PL O1/O2 rules
  Persona              docs/product-spec.md                    Solo personal trainer running PL group + 1:1 sessions
  Access control       docs/architecture/auth.md               Email + password login; single-tenant; no roles
  Business logic       docs/product-spec.md                    Auto-classifies completed sessions as O1 (in package) or O2 (extra-paid)
  FRs (baseline)       docs/product-spec.md                    14 FRs across 4 areas: sessions, billing, clients, reports
  NFRs                 docs/product-spec.md                    Mobile-first web; PL locale; no offline requirement
  Non-Goals (existing) docs/product-spec.md                    Not multi-trainer; not desktop-first; not integrating with Glofox/Mindbody
  product_type         docs/product-spec.md                    web-app
  target_scale         docs/product-spec.md                    small (1 trainer in v1)
  Latest delta plan    docs/work/003-mobile-redesign/plan.md   Mobile redesign initiative — 8 tasks, last updated 2026-04-12

═══════════════════════════════════════════════════════════
```

Then ask:

AskUserQuestion:
- question: "I found existing artifacts describing the current system. How should I treat them?"
  header: "Inherit?"
  options:
  - label: "Inherit by reference, ask only about delta (Recommended)"
    description: "Each phase below will pre-load the inherited value and ask: 'is this changing in THIS initiative?'. Unchanged elements are written to discover-notes once as `## Inherited state` and never re-asked."
  - label: "Inherit, but show me each phase before confirming"
    description: "Same as above, but each phase explicitly displays the inherited content before asking the change/no-change gate. Slower but more auditable."
  - label: "Ignore — re-elicit everything from scratch"
    description: "Rare. Only if you're rebuilding from first principles (revolutionary change). The existing artifacts will not influence discovery."
  multiSelect: false

**On "Inherit (Recommended)" or "Inherit with review":**

1. Set frontmatter `inherited_from:` to the list of source paths, with each element's location:

```yaml
inherited_from:
  - path: docs/product-spec.md
    elements: [vision, persona, access_control, business_logic, frs_baseline, nfrs, non_goals, product_type, target_scale]
  - path: docs/architecture/auth.md
    elements: [access_control]
  - path: docs/work/003-mobile-redesign/plan.md
    elements: [latest_delta_context]
```

2. Write `## Inherited state` section as the FIRST section after frontmatter in `discover-notes.md`:

```markdown
## Inherited state

The following project elements are inherited from existing artifacts and treated as
**unchanged unless a later phase explicitly modifies them**. Inherited values are
authoritative — downstream `/product-spec` will fold them into the new spec verbatim
unless `## Vision & Problem Statement` (Step 1) or any other phase records a delta.

| Element              | Source                                          | Inherited value |
|----------------------|-------------------------------------------------|-----------------|
| Vision               | `docs/product-spec.md`                          | [one-liner]     |
| Persona              | `docs/product-spec.md`                          | [one-liner]     |
| Access control       | `docs/architecture/auth.md`                     | [one-liner]     |
| Business logic       | `docs/product-spec.md`                          | [one-liner]     |
| FRs (baseline)       | `docs/product-spec.md`                          | N FRs           |
| NFRs                 | `docs/product-spec.md`                          | [one-liner]     |
| Existing non-goals   | `docs/product-spec.md`                          | N items         |
| `product_type`       | `docs/product-spec.md` frontmatter              | [value]         |
| `target_scale`       | `docs/product-spec.md` frontmatter              | [value]         |

> Latest delta context: `docs/work/<latest>/plan.md` — used as situational context only, not inherited as authoritative state.
```

3. Store the FULL extracted content (not just the one-liners) in session-local memory. Each subsequent phase has access to the inherited values for that phase's section. Phases use this for the **delta gate** pattern (see "Delta gate" below).

**On "Ignore":** set `inherited_from: []` and proceed as if no artifacts existed. Inherited content is not surfaced to the user during phases.

**Delta gate pattern (used by Steps 1, 2, 4, 5, 6 in brownfield-inherit mode):**

Each phase opens with the inherited value visible, then asks ONE yes/no gate. If "no change," the phase writes one line to discover-notes (`<Phase section> — inherited; no change in this initiative.`) and skips to the next phase. If "yes, changing," the phase elicits ONLY the delta — never re-asks the baseline.

Phases in inherit mode produce three possible outputs per section:

- **Inherited unchanged**: one-line pointer to `## Inherited state`. Section is shorter than baseline mode.
- **Inherited with delta**: inherited value PLUS captured change. Both visible in the section so /product-spec can compose.
- **Fully replaced**: the change is large enough to override the inherited value entirely. Section reads like baseline brownfield mode.

### Discovery pattern (applies to every Step 1–6 below)

Every discovery phase follows the same loop. Internalize this before reading the per-phase steps; the per-phase content is what to ask, not how to ask.

The pattern is **facilitator stance + decision-point surfacing + recommended-answer + Socratic challenge**:

1. **Open the phase** with a one-line statement of what this phase produces, and a single open question to elicit the user's first attempt at it. (Facilitator stance: never generate the content yourself.)
2. **Surface 3–5 decision points** as multi-select questions when the user's first attempt has ambiguities. Use AskUserQuestion. Each option is a real position with a tradeoff, not a placeholder.
3. **Mark a recommended option** with "(Recommended)" in the label and place it first. Always include a "Not sure / haven't decided" option to mitigate decision fatigue.
4. **Lock the decision back to the user** as a one-line summary they confirm before you write to disk.
5. **Write the phase's section(s)** into `discover-notes.md` and bump `checkpoint.current_phase` and `checkpoint.phases_completed` per the schema.

**Hard rules**:

- NEVER generate content the user did not say. If a section needs a value the user has not provided, ask — don't invent. The exception is mechanical formatting (FR-NNN numbering, section headings, frontmatter scaffolding).
- NEVER pre-commit to a stack (framework, database, hosting platform, language family). The spec captures product-level priors only — `product_type`, `target_scale`, `timeline_budget`. Stack-shaped concerns are gathered downstream of `/product-spec`.
- **Reference materials are evidence, not authority.** When a selected `docs/reference/` item suggests an answer (e.g., a client brief names FRs, a competitor analysis hints at non-goals), surface it explicitly to the user: "The client brief mentions X — should we keep it, drop it, or restate it differently?" Never silently fold external content into discover-notes as if the user said it. Citation format inside discover-notes: `> Ref: docs/reference/<file> — <one-line claim>.`
- **Professional tone over startup clichés.** This skill is meant for business stakeholders, not pitch decks. Avoid "10x"-startup vocabulary: no "pain", "burning need", "killer feature", "rockstar user", "growth hack", "MVP magic", "ship it", "scope creep". Prefer neutral, precise language: **problem / friction / inefficiency / trigger event / current cost / current workaround / constraint / scope expansion / release**. Discovery is interview-grade research, not a hype document.
- **Adapt phrasing to the user's working language.** When the user writes in a non-English language, render prompts and section labels in idiomatic equivalents — DO NOT translate literally. Specifically for Polish: `problem` → "problem" (NOT "ból"); `friction` → "punkt tarcia" / "tarcie"; `trigger event` → "moment wyzwalający" / "moment, w którym to się dzieje"; `current workaround cost` → "koszt obecnego rozwiązania" / "ile dziś kosztuje obejście"; `current system` → "obecny system" / "stan obecny"; `must preserve` → "co musi zostać" / "czego nie wolno zepsuć"; `release` → "wdrożenie" / "wydanie" (NOT "ship"). When in doubt, ask the user how they'd phrase it themselves — that becomes the canonical label inside the discover-notes for that session.

### Step 1: Vision & problem

This phase produces the `## Vision & Problem Statement` and `## User & Persona` (primary persona only) sections of `discover-notes.md`. Two sections, not one, because the persona binds the problem. **Brownfield** also produces the `## Current System` section.

**Reference-material hook**: if any selected material has purpose `existing-product-brief`, `client-requirements`, or `competitor-data`, mention it upfront: "I'll keep the [filename] open as we talk — flag me if anything I capture contradicts it." Do NOT prefill the problem statement or persona from the brief; treat it as a check-against, not a source of truth.

#### Greenfield mode

Open with: "Let's start with the problem. In one or two sentences — who experiences it, in what situation does it occur, and what does dealing with it cost today?"

Listen. Echo back the four components separately:

```
Problem:         [the concrete inefficiency or unmet need]
Affected role:   [who experiences it — name a specific role, not "users"]
Trigger event:   [the situation in which the problem manifests]
Current cost:    [the existing workaround and what it costs in time / money / quality]
```

If any of the four is vague ("everyone", "always", "lots of problems"), follow up with a precision question: "What would have to be true for this to be the wrong problem to solve?" or "Name a specific person and a specific time in the last month when this happened."

Then surface decision points (use AskUserQuestion with 2–4 questions, **multiSelect on questions where multiple positions can co-exist**):

- Problem category — what kind of inefficiency is this? (workflow friction / missing capability / data fragmentation / decision overload / coordination overhead / regulatory or compliance gap / other)
- Differentiating insight — what does the user understand about this domain that incumbents do not? (Socratic prompt: "If this opportunity is obvious, why hasn't an existing player built it already?")
- Primary persona scope — who exactly is this for? (a specific role inside one organization / individuals across many organizations / a single named user including yourself / hobbyist niche / undecided)

#### Brownfield mode

**Inherit mode (Step 0.9 found existing artifacts):**

Open by surfacing the inherited baseline:

```
Inherited from `## Inherited state`:
  Current system:   [one-liner from product-spec or architecture]
  Persona:          [one-liner]
  Must preserve:    [implied from architecture + existing FRs marked preserved]
```

Then ask the delta gate ONLY:

- "What is the gap or unmet need that THIS initiative addresses? (One or two sentences — the rest of the system is inherited and unchanged.)"
- If the change touches the persona (new user role, expanded user base): "Does this initiative bring in a new role, or shift an existing role's behavior? If yes, describe; if no, persona is inherited unchanged."

Capture only the delta:

```
Gap / unmet need:  [the trigger for THIS initiative]
Persona delta:     [new/changed role, or "no change — inherited"]
```

Skip the full echo-back of current system / tech stack / users — those are in `## Inherited state` and not re-elicited.

Write to discover-notes:

- `## Vision & Problem Statement` — captures the gap/delta only, with a reference back to `## Inherited state` for the baseline.
- `## User & Persona` — either "Inherited from `## Inherited state` — no change in this initiative." OR the persona delta.
- `## Current System` is NOT rewritten — `## Inherited state` covers it.

**Baseline mode (Step 0.9 found nothing inheritable):**

Open with: "Let's start with the current system. In a few sentences — what exists today, who uses it, and what gap or unmet need is driving this change?"

Listen. Echo back five components separately:

```
Current system:    [what exists — name the product / service / module]
Tech stack:        [languages, frameworks, infrastructure the user mentions]
Users:             [who uses it today — name specific roles, not "users"]
Gap / unmet need:  [what is missing or no longer fit-for-purpose — the trigger for this change]
Must preserve:     [behavior, integrations, or data that cannot regress]
```

If the user can't articulate "must preserve", follow up with: "If this change broke something tomorrow, what's the first thing that would trigger an incident response?" or "What's the first thing an existing user would notice if it stopped working?"

Then surface decision points:

- Change category — what kind of change is this? (new module / significant feature / architectural improvement / migration / integration / other)
- Differentiating insight — what does the user understand about the current system that makes this change non-obvious? (Socratic: "Why hasn't this change been made already?")
- Primary persona scope — same as greenfield

Write the `## Current System` section first (brownfield-only section — describes what exists), then `## Vision & Problem Statement` (reframed as the delta: what's changing and why), then `## User & Persona`.

#### Both modes

Lock the captured content back matching the schema's section structure. Append to `discover-notes.md`. Bump `checkpoint.current_phase: 2` and add `1` to `checkpoint.phases_completed`.

### Step 2: Persona & access control

This phase produces the `## Access Control` section. Persona was captured in Step 1; here we ask how the persona reaches the product.

**Reference-material hook**: if any selected material has purpose `client-requirements` or `api-contract` and mentions auth (SSO, OAuth providers, role boundaries), surface those constraints: "The [filename] specifies [auth shape]. Is this still in scope, or has it changed?" Capture the user's answer; do not silently inherit the brief's auth model.

#### Greenfield mode

Open with: "How does this person get into the app? Login, a local profile, an access key, no auth at all?"

Use AskUserQuestion with options drawn from the most common shapes:

- Login (email + password / OAuth / passwordless) (Recommended for multi-user web/mobile)
- Local profile (data lives on-device, no server) (Recommended for solo / privacy-first)
- Access key (link or token; no account creation)
- N/A — single user, single device, no separation

If the answer is anything but N/A, ask one follow-up about role separation: is this a flat user model, or are there roles (e.g., admin / member / guest) that see different things? Follow-up: "What is the smallest access model that would still make the first release useful?"

#### Brownfield mode

**Inherit mode (`## Inherited state` has an access control entry):**

Open by showing the inherited model:

```
Inherited access control (from <source>): [one-liner — e.g. "Email + password login; single-tenant; no roles"]
```

Then the delta gate:

AskUserQuestion:
- question: "Does this initiative touch the access control or role boundaries?"
  header: "Auth change?"
  options:
  - label: "No change — inherit as-is (Recommended for non-auth initiatives)"
    description: "Access control is inherited from `## Inherited state`. The section will be written as a one-line pointer with no further questions."
  - label: "Yes — describe the delta"
    description: "Capture what is being added, modified, or removed from the current auth/role model. The inherited baseline stays visible; the delta is appended."
  multiSelect: false

On "No change": write `## Access Control` as:
```
Inherited from `## Inherited state` — no change in this initiative.
```

On "Yes — describe the delta": ask for the change ("What is being added / modified / removed?") and capture both lines:
```
Inherited baseline: [from `## Inherited state`]
Delta in this initiative: [user's change description]
```

Follow-up Socratic only if delta is captured: "What is the smallest access change that achieves the initiative's goal without disrupting existing users?"

**Baseline mode (no inheritance):**

Open with: "Describe the current auth and user roles in this system. How do users get in today, and what roles exist?"

Listen. Then ask what's changing:

- "Is the auth model changing as part of this work?" (yes — describe / no — keep as-is)
- "Are new roles being added, or are existing role boundaries shifting?" (yes — describe / no — keep as-is)

If the user says auth isn't changing, record the current auth model as `## Access Control` with a note: `No changes planned — current model preserved.` If changes are planned, capture both the current model and the planned changes.

Follow-up: "What is the smallest access change that achieves the initiative's goal without disrupting existing users?"

#### Both modes

Write the captured content as the `## Access Control` block per schema. Bump `checkpoint.current_phase: 3` and append `2` to `checkpoint.phases_completed`.

### Step 3: Scope and timeline discipline

This phase produces a draft `## Success Criteria` block (Primary / Secondary / Guardrails subsections per schema) and seeds the `timeline_budget` frontmatter field.

**Reference-material hook**: if any selected material describes an expensive scope item (e.g., a brief mentions "AI recommendations" or "real-time collaboration") that doesn't fit the timeline, name it during the scope/timeline check. Cite it: "The brief mentions X. Given a 3-week delivery window, X is the kind of capability I would defer from v1. Keep, defer, or remove entirely?"

#### Greenfield mode

Open with: "Sketch the smallest end-to-end user flow that would demonstrate the product works. Walk me through the first session, step by step."

Listen. Once the user describes the flow, echo it back as a numbered sequence ("1. user opens app, 2. user does X, 3. user sees Y, …") and ask: "Given roughly three weeks of part-time work, is this flow realistic to deliver?"

**Scope vs. timeline check**: if the flow has more than ~6 distinct user actions before producing value, OR the user's own estimate exceeds ~3 weeks of part-time work, OR the flow requires multiple integrations / external services / custom infrastructure before any user-visible value, surface the tradeoff explicitly. The goal is an informed decision, not enforcement — longer timelines are valid, but the user should choose them deliberately:

```
This first version is broader than what typically fits a 3-week part-time delivery window.
A common failure mode in new projects is finishing nothing because the first version
was scoped too widely. Two valid paths from here:

  Reduce scope — keep the timeline tight. Common moves:
    - Defer [identified expensive capability] to v2 once anything works end-to-end.
    - Replace [identified integration] with a manual or hardcoded version for v1.
    - Limit v1 to a single user (yourself) before opening it to others.

  Accept the longer timeline — and own the cost. A multi-week first version is
  achievable, but it requires sustained focus across evenings/weekends and
  tolerance for periods where progress is not externally visible. Projects that
  overrun their first estimate usually fail because of the gap between expected
  and actual effort, not because of the work itself.
```

Use AskUserQuestion with three options:

- **Reduce scope (Recommended)** — pick this if the cost above is new information; we will restart this step with a smaller first flow.
- **Accept the longer timeline — I understand the sustained effort required** — pick this only after a deliberate consideration of what multi-week part-time work looks like for your situation.
- **Restart Step 3 with a different first flow** — pick this if neither option fits and you want to redraw the first version from scratch.

If the user picks "Accept the longer timeline":

1. Capture their estimated `mvp_weeks` (ask if not already stated).
2. Append a `## Timeline acknowledgment` line under the timeline budget block in discover-notes recording: estimated weeks, that the user explicitly accepted the sustained-effort cost, and the date. Format: `Acknowledged on <YYYY-MM-DD>: <N>-week first version requires sustained effort; user accepted.`
3. Proceed without further reminders — the acknowledgment is the gate; repeating the warning is not.

#### Brownfield mode

Open with: "Describe the smallest incremental change that would demonstrate this improvement works. Walk me through how a user's experience changes — what do they do differently after this change is released?"

Listen. Echo back as a numbered delta-sequence: "1. user opens [existing feature], 2. they now see [new thing], 3. they can [new capability]…"

Then ask two brownfield-specific questions:

- "What is the impact radius of this change? Which existing features, integrations, or data flows could regress?" (Follow-up: "What is the first thing an existing user would notice if this change behaved incorrectly?")
- "Given roughly three weeks of part-time work, is this change realistic to deliver?" (same timeline discipline as greenfield)

**Scope vs. timeline check**: same logic as greenfield, reframed:

```
This change is broader than what typically fits a 3-week part-time delivery window.
A common failure mode in changes to existing systems is leaving the change half-done —
partially modified code is worse than the original. Two paths:

  Reduce scope — find the smallest slice that demonstrates the change works. Common moves:
    - Limit to one use case or one user role first.
    - Keep existing behavior as a fallback; add the new path alongside it.
    - Defer [identified expensive integration] to v2.

  Accept the longer timeline — same as greenfield: sustained effort, deliberately accepted.
```

Same AskUserQuestion options as greenfield.

#### Both modes

When the flow is locked, capture it as the `### Primary` success criterion (the flow working = the product/change worked). Ask once more for `### Secondary` (1 nice-to-have) and `### Guardrails` (1–2 things that must not break — privacy, performance floor, UX). For brownfield, guardrails should explicitly include existing behavior that must be preserved.

Set `timeline_budget.mvp_weeks` (greenfield) or `timeline_budget.delivery_weeks` (brownfield) in the frontmatter scaffold to the user's number — 1 if scoped down, the acknowledged estimate otherwise.

Write the `## Success Criteria` block. Bump `checkpoint.current_phase: 4` and append `3` to `checkpoint.phases_completed`.

### Step 4: Functional requirements & user stories

This phase produces the `## Functional Requirements` and `## User Stories` sections.

**Reference-material hook**: if any selected material has purpose `client-requirements`, `existing-product-brief`, or `external-link-index`, extract candidate FRs and present them as a multi-select pre-list:

> "I found these capabilities mentioned in [filename]:
>   - [candidate FR 1, paraphrased]
>   - [candidate FR 2, paraphrased]
> Which of these belong in the first release? Which should be dropped or deferred?"

Use AskUserQuestion (multiSelect). Capture only what the user picks. Annotate adopted FRs with a citation blockquote: `> Ref: docs/reference/<file> — listed as <verbatim phrase from source>.` This is the only place in the skill where pre-suggesting content is allowed, because the material is the user's own input.

For `api-contract` references, the contract may dictate technical capability boundaries — capture as a constraint in `## Open Questions` rather than as an FR; the contract maps to NFRs and business logic in Step 5.

#### Greenfield mode

Open with: "Now let's get concrete. From the first-release flow you sketched, what does the actor need to be *able* to do? List the capabilities — I'll format them as FRs."

Capture each capability as a single FR line per the schema format:

```
- FR-NNN: [Actor] can [capability]. Priority: must-have | nice-to-have
```

`NNN` is zero-padded three-digit, starting at `001`. Default `Priority: must-have` for anything in the first-release flow; ask explicitly if any capability is `nice-to-have`.

#### Brownfield mode

**Inherit mode (`## Inherited state` lists FRs from a prior product-spec):**

Open by surfacing the inherited FR set in a compact form:

```
Inherited FR baseline (from <source>): <N> FRs across <areas>.
The full list lives in `## Inherited state` and is preserved by default.
```

Then ask the delta gate as a multi-select:

AskUserQuestion (multiSelect: true):
- question: "Which inherited FRs does THIS initiative touch? Pick all that apply. The rest will stay inherited as `preserved` without re-listing."
  header: "FR delta"
  options:
  - one option per inherited FR (label: "FR-NNN: <one-liner>", description: "Pick to mark this FR as modified or removed in this initiative")
  - "None of the existing FRs change — this initiative only adds new capabilities"

For each FR the user picks, follow up: "How is FR-NNN changing? (modified — describe how / removed — describe why)". Capture as:

```
- FR-NNN: [Actor] can [capability]. Priority: must-have | nice-to-have. Change: modified | removed
  > Delta: <description of what's changing>
```

Then ask for genuinely new FRs:

"List any capabilities being ADDED in this initiative that don't exist in the inherited baseline. I'll number them starting after the highest existing FR id."

Capture new FRs with `Change: new`:

```
- FR-NNN+1: [Actor] can [capability]. Priority: must-have | nice-to-have. Change: new
```

**Preserved FRs are NOT re-listed.** Write a single line at the end of `## Functional Requirements`:

```
> All inherited FRs not listed above are preserved unchanged. See `## Inherited state` for the baseline.
```

**Baseline mode (no inheritance):**

Open with: "Now let's get concrete. From the change you described, what capabilities are being added, modified, or preserved? List them — I'll format them as FRs with a change category."

Capture each capability with an additional `Change:` tag:

```
- FR-NNN: [Actor] can [capability]. Priority: must-have | nice-to-have. Change: new | modified | preserved
```

- `new` — capability that doesn't exist in the current system
- `modified` — existing capability that's changing behavior
- `preserved` — existing capability that must continue working unchanged (defensive FR — makes preservation explicit)

Prompt the user to think about preserved FRs: "Which existing capabilities must explicitly survive this change? Making preservation explicit prevents accidental breakage." If the user identifies preserved FRs, capture them — they become guardrail-FRs for the brownfield spec.

#### Both modes

Group thematically with `###` subheadings if the FR count exceeds ~6 (e.g., `### Authentication`, `### Recipe matching`, `### Persistence`).

After FR capture, ask the user to translate at minimum the **first-release flow's primary path** (greenfield) or **primary change path** (brownfield) into a `### US-01:` user story with Given/When/Then per the schema. Each additional user story is optional but encouraged for any FR that has non-obvious acceptance criteria.

Update `checkpoint.frs_drafted` to the count of FR-NNN entries.

Bump `checkpoint.current_phase: 4.5` and proceed directly to the Socratic round (do NOT mark phase 4 complete in `phases_completed` until the Socratic round writes back).

### Step 4.5: Socratic challenge round

This is a dedicated batched round — exactly one challenge per **NEW or MODIFIED** FR captured in Step 4, no more, no less. **Inherited preserved FRs are NOT challenged again** — they passed their own Socratic round in the prior spec. The skill counts only FRs with `Change: new` or `Change: modified` (brownfield-inherit mode) or all FRs (greenfield / baseline brownfield).

For each FR-NNN in document order, ask:

```
FR-NNN: [Actor] can [capability]. Priority: ...
What would have to be true for this FR to be wrong — i.e., for releasing it to
hurt the product instead of help it? OR: what is the strongest counter-argument
to including this in the first version?
```

Use AskUserQuestion per FR with 2–4 options framed as plausible counter-arguments (drawn from the FR's domain — not generic). Always include a "No counter-argument; it stands as written" option as the LAST option (not first), so the question forces the user to consider the challenge before dismissing it.

Capture each user response as a `> Socratic:` blockquote underneath its FR in `discover-notes.md`:

```
- FR-001: User can save a recipe to favorites. Priority: must-have
  > Socratic: Counter-argument considered: "favorites duplicate the recipe list
  > if recipes are already small in number." Resolution: kept; favorites are
  > cross-session, the main list is per-fridge.
```

If a Socratic round prompts the user to revise an FR (e.g., split into two, demote to nice-to-have, drop entirely), update the FR line in place and re-emit `checkpoint.frs_drafted`.

Once every FR has a Socratic blockquote, append `4` to `checkpoint.phases_completed`, bump `checkpoint.current_phase: 5`.

### Step 5: Business logic & quality properties

This phase produces the `## Business Logic` and `## Non-Functional Requirements` sections. **Brownfield** also produces the `## Constraints & Preserved Behavior` section. Entities and fields are intentionally NOT captured as a separate section — they emerge from FRs and User Stories (Steps 4 and 4 of this skill respectively) and are pinned during downstream stack selection / implementation planning.

**Reference-material hook**:
- `api-contract` references: extract NFR candidates (latency targets, throughput limits, error budget, retention windows) and present as a checklist for the user to confirm/adjust.
- `operational-spec` references (rate limits, SLAs from vendor docs): treat as hard constraints — they bound what NFRs are achievable. Cite explicitly: `> Ref: <file> — vendor enforces <constraint>.`
- `external-link-index` references: if links point to vendor SLOs, regulatory guidelines, or domain-rule research, use them to challenge the user's one-sentence rule. ("The linked GDPR guideline says X — does your rule respect that, or are we accepting a constraint to break?")
- For brownfield: any reference describing the current system feeds directly into `## Constraints & Preserved Behavior`.

#### Greenfield mode

Open with: "Describe the rule of operation in ONE sentence — the domain decision your app makes that distinguishes it from a generic CRUD list."

If the user can produce the one-sentence rule, capture it as the first line of `## Business Logic`. Then ask for ≤ 3 supporting paragraphs explaining what inputs the rule consumes (as user-facing inputs, not system components), what its output is, and how the user encounters it in the product flow. Do NOT name the components or actors that perform the computation — those are downstream architecture choices. State the rule as if the implementation were unknown.

**Empty-CRUD anti-pattern detection**: if the user's "business logic" reduces to "users can add, view, update, and remove records" with no rule that the application itself applies (no recommendation, no prioritization, no classification, no validation, no scoring, no workflow, no calculation), surface this explicitly:

```
What you have described is a CRUD list — a well-known anti-pattern in new
products. Pure CRUD without a domain rule means the application provides no
value beyond what a spreadsheet or notes file already offers. There is no
meaningful product yet — only data entry.

A meaningful domain rule answers the question: "what does this application
decide for the user?". Common shapes:

  - Recommendation:  application suggests items based on user state
  - Prioritization:  application orders items by inferred urgency / importance
  - Classification:  application tags items by category / sentiment / quality
  - Validation:      application checks items against a domain rule and flags problems
  - Scoring:         application rates items so the user can compare them
  - Workflow:        application moves items through states with transition rules
  - Calculation:     application computes a value from inputs the user supplies

Which of these shapes applies to YOUR application?
```

Use AskUserQuestion with the rule shapes above as multi-select options (plus "I want to add a rule — give me a moment to think" and "I'm building this as pure CRUD anyway — record it"). If the user picks a rule, return to the one-sentence prompt. If they accept the empty-CRUD label, record it as `# TODO: domain rule — see Open Questions` per the schema and add an entry to a running `## Open Questions` block in discover-notes.md.

#### Brownfield mode

**Inherit mode (`## Inherited state` has a business logic entry):**

Open by showing the inherited rule:

```
Inherited domain rule (from <source>): [the existing rule, one sentence]
```

Then the delta gate:

AskUserQuestion:
- question: "How does THIS initiative interact with the domain rule?"
  header: "Rule change?"
  options:
  - label: "No change — infrastructure / refactor / non-domain work (Recommended for non-feature initiatives)"
    description: "The domain rule is inherited unchanged. Write a one-line pointer in `## Business Logic`."
  - label: "Modifies the existing rule"
    description: "Capture the modification — what the rule used to do, what it does now."
  - label: "Adds a NEW rule alongside the existing one"
    description: "Capture the new rule as a sibling — both rules coexist after this initiative."
  - label: "Replaces the existing rule"
    description: "Rare. Capture the new rule and mark the old one as superseded."
  multiSelect: false

On "No change": write `## Business Logic` as:
```
Inherited from `## Inherited state` — no change in this initiative. This is an infrastructure / technical change with no domain rule modification.
```

On "Modifies" / "Adds new" / "Replaces": capture the inherited rule plus the delta, both visible:
```
Inherited rule: [from `## Inherited state`]
Delta in this initiative: [user's description — "modification" / "new sibling rule" / "replacement, supersedes prior"]
```

**Baseline mode (no inheritance):**

Open with: "What is the existing domain rule — the decision your current system makes for the user? Then: does this change add a new rule, modify the existing one, or is it infrastructure-only (no rule change)?"

Listen. Classify the answer:

- **Adds a new domain rule** — capture as in greenfield (one-sentence rule for the new capability).
- **Modifies an existing rule** — capture the current rule first ("The system currently does X"), then the change ("This change modifies it to do Y"). Both lines go into `## Business Logic`.
- **Infrastructure-only** — the change doesn't touch domain logic (e.g., migration, performance improvement, integration). Record: "No domain logic change. This is an infrastructure/technical change." Skip the empty-CRUD check — it doesn't apply to brownfield infrastructure work.

**Constraints & preserved behavior (both inherit and baseline modes):**

After business logic, capture constraints and preserved behavior as `## Constraints & Preserved Behavior`:

- In inherit mode, start by surfacing inherited NFRs from `## Inherited state` and asking: "Do any of these need updating because of THIS initiative? If no, they remain authoritative."
- "What existing integrations, APIs, or data contracts must this change respect?" (always ask — even in inherit mode this is initiative-specific)
- "Are there data migrations involved? What happens to existing data?"
- "What backward compatibility guarantees are needed?"

#### Both modes

After business logic is locked (or its absence is recorded), ask one round on non-functional requirements: "Are there qualities the app must hold at its outer boundary — what a user, operator, or regulator could measure without inspecting the implementation? Think: response timing as the user perceives it, privacy commitments, accessibility, browser/device support, retention windows." For brownfield, add: "Are there existing externally-observable behaviors or SLAs that must not regress?"

Capture as `## Non-Functional Requirements` bullets per schema. Each NFR pairs a property with a measurable target (or a binary commitment) and avoids naming mechanism, enforcement strategy, runtime location, or UI affordance — those are downstream choices. If the user phrases an NFR mechanically ("rate-limit per IP", "spinner during load", "Postgres query < 50ms"), reflect it back in outside-observable form before capturing ("auth resists credential stuffing without locking out fat-finger users"; "continuous visible feedback during any operation > 2s"; "user-perceived response < 800ms p95").

Do NOT ask "what entities does the user create, read, update, or delete?" — entities are not a spec concern. The nouns the product manipulates surface in FRs (Step 4) and User Stories. If a field-level question seems needed to clarify a business rule, route it to `## Open Questions` for downstream resolution, not to a data-model capture.

Append `5` to `checkpoint.phases_completed`, bump `checkpoint.current_phase: 6`.

### Step 6: Product framing

This phase produces the `## Non-Goals` section plus the product-level frontmatter fields (`product_type`, `target_scale`, `timeline_budget`).

**Reference-material hook**: when surfacing the Non-Goals multi-select, draw candidate non-goals from selected materials. Examples:
- `competitor-data` reference → "[Competitor] does X. Are we explicitly NOT doing X?" → if confirmed, add to `## Non-Goals` with citation.
- `existing-product-brief` reference mentions a feature the user is now scoping out → "The brief mentions [feature]. If it is not part of the first release, that is a non-goal worth recording."
- `external-link-index` reference targets a technology — handle per Hard Rule #3 (capture in `## Forward: tech-stack`, not in spec sections).

Spec frontmatter is product-level only. Stack-shaped concerns — team composition, language preferences, technology avoid-lists, deployment mode/region/budget, CI/CD pipeline shape — and architectural commitments — implementation decisions, testing strategy, deployment plan — are NOT part of the spec. They are gathered downstream of `/product-spec`, after the product shape is locked. Asking them now invites the user to over-commit before stack selection has happened, and the answers usually need to be revisited once the stack is picked.

#### Greenfield mode

Open with: "Last phase — let's lock a few framing details, then list what the first release explicitly does NOT include. We're not selecting frameworks, deployment, or test/CI plans here — those decisions come after, during stack selection."

Ask the user these three short framing questions, ONE AT A TIME (a separate AskUserQuestion per question, not a single multi-question block). Phrase each question in plain language as suggested below — DO NOT print field names like `product_type` or `target_scale` in the question text or option labels. Map the user's answer to the underlying frontmatter field internally.

1. **What kind of thing are you building?**
   - Options: "A website or web app" / "An API or backend service" / "A command-line tool" / "A mobile app" / "A desktop app" / "A library or SDK" / "A data pipeline" — plus the free-text fallback.
   - Map the chosen label to `product_type`: web-app / api / cli / mobile / desktop / library / data-pipeline / other.

2. **Roughly how many people will use this once it's live?**
   - Options: "Just me, or a handful" / "Dozens to a hundred" / "Up to ten thousand" / "More than ten thousand".
   - Map the chosen label to `target_scale.users`: small / medium / large / enterprise.
   - After the answer, follow up with a short Socratic probe: "How would your domain rule change at 100x that scale?" Capture any insight as a one-line note in discover-notes' Vision section if it surfaces something new.

3. **Two quick questions about timing.**
   - Ask in one round: "Is there a hard deadline you're aiming for? If yes, what date — if no, just say 'no deadline'." (Map to `timeline_budget.hard_deadline`: an ISO date or `null`.)
   - Then: "Will this be after-hours work, or part of your day job?" (Map to `timeline_budget.after_hours_only`: bool.)
   - `timeline_budget.mvp_weeks` was already locked during Step 3 — don't re-ask it.

#### Brownfield mode

Open with: "Last phase — let's lock a few framing details and list what this change explicitly does NOT include. We're not changing the stack here — those decisions come after."

For brownfield, product framing questions become "is this changing?" yes/no gates plus constraint capture. **In inherit mode, the baseline values come from `## Inherited state` and are auto-confirmed unless the user flags a change**:

1. **Is the product type changing?**
   - Inherit mode: show `Inherited product_type: [value from `## Inherited state`]`. Default to "no change" — only ask if the initiative plausibly introduces a new product surface (e.g., adding a mobile app to a web-only product). If no change, write `product_type: <inherited>` to frontmatter with note: `Inherited — no change in this initiative.`
   - Baseline mode: if the existing system is a web app and this change doesn't alter that → record `product_type` as-is with note: `No change — existing [type].`
   - If the change introduces a new product surface (e.g., adding a CLI to a web app) → capture the new `product_type` alongside the inherited one.

2. **Is the user base changing?**
   - Inherit mode: show `Inherited target_scale: [value]`. Default to "no change" — only ask if the initiative plausibly opens to new users or a different scale tier.
   - Baseline mode: same pattern as before. Record current `target_scale` and whether the change affects it.

3. **Timing** — same two questions as greenfield (`hard_deadline`, `after_hours_only`). `timeline_budget.delivery_weeks` was already locked during Step 3. Inherited deadlines from prior spec are NOT relevant — timeline is per-initiative.

After framing, ask the constraints question. **In inherit mode, surface inherited constraints first**:

- Inherit mode opening: "From `## Inherited state`, the existing system constrains this change via: [list of inherited NFRs and integration contracts]. Are any of these constraints **relaxed, tightened, or removed** for THIS initiative? If not, they apply unchanged."
- Always ask: "Are there NEW constraints specific to this initiative? Think about: deployment windows, existing CI/CD requirements, backward compatibility with current API consumers, existing monitoring/alerting."

Capture in `## Constraints & Preserved Behavior` (extend the section created in Step 5).

#### Both modes

After product framing is locked, run **one** Non-Goals multi-select round. The shape is a multi-select exclusion list — aimed at *scope* exclusions (capabilities the first release will not build / change will not touch, quality dimensions it will not aim for), not technology exclusions. Ask:

```
What is this [first release / change] explicitly NOT doing? List anything that
should be excluded *now* so it is not reintroduced later by accident.
Functional non-goals (capabilities we will not build or change) and
non-functional non-goals (quality dimensions we will not aim for) both belong here.
```

Use AskUserQuestion with `multiSelect: true` and 3–5 options drawn from the user's domain — NOT generic. Examples (regenerate per project):

- "Avoid: building our own [domain algorithm — e.g., recommendation, scheduling, scoring]" — strong scope avoid; force a buy-vs-build decision now.
- "Avoid: [expensive infrastructure piece — e.g., local LLM, real-time sync, multi-region]" — strong scope avoid; the absence shapes the data flow.
- "Avoid: [secondary persona — e.g., shared decks, team workspaces, admin features]" — explicit single-tenant lock.
- "Avoid: [quality dimension — e.g., offline-first, full WCAG-AA, sub-100ms latency]" — explicit non-functional non-goal.
- For brownfield: "Avoid: [existing system change — e.g., migrating the database, rewriting auth, changing the deployment target]" — explicit existing-system non-goal.
- "Other (you tell me)" — free-text capture.

Append the picked items to `## Non-Goals` per schema (one-line rationale each). If technology avoids come up (e.g., "avoid: PHP", "avoid: monorepo"), DO NOT add them to `## Non-Goals` — capture them in discover-notes' body under a `## Forward: tech-stack` block (informational, not part of the spec schema) so a downstream chain step can pick them up.

**Do NOT** ask about implementation decisions, testing strategy, or deployment & CI/CD plan in this skill. Those concerns sit downstream of stack selection / stack assessment. If the user volunteers content of that shape, capture it in discover-notes under `## Forward: technical-roadmap` (informational; not a spec section) so a downstream skill can pick it up.

Append `6` to `checkpoint.phases_completed`, bump `checkpoint.current_phase: 7`. Proceed directly to Step 7.

### Step 7: Closing soft-gate cross-check

This phase runs the quality bar against everything captured. It is a **soft gate**: warns but allows override.

Read back the current `discover-notes.md` and check each of the following elements. For each, mark `present`, `inherited`, or `missing/weak`. **`inherited` counts as satisfying the gate** — it means the element was not re-elicited because it lives in `## Inherited state` and was not changed in this initiative.

1. **Access Control** — `## Access Control` block exists with a non-trivial value (not just empty placeholder), OR points to `## Inherited state` with "no change in this initiative".
2. **Business Logic (one-sentence rule)** — `## Business Logic` opens with a single declarative sentence (not a paragraph, not "TBD"), OR points to `## Inherited state`. For brownfield infrastructure-only changes, "No domain logic change" is valid.
3. **Project artifacts** — `discover-notes.md` itself exists with a valid frontmatter checkpoint. (This is always present at this point.)
4. **Timeline-cost acknowledged** — either `timeline_budget.mvp_weeks` / `delivery_weeks` ≤ 3, OR a `## Timeline acknowledgment` block exists in discover-notes recording that the user accepted the sustained-effort cost in Step 3. Longer timelines are valid; the gate is that the cost was surfaced and accepted, not that the timeline is short.
5. **Non-Goals** — `## Non-Goals` block exists with at least one entry. (Non-goals are always initiative-specific; inheriting them from prior spec is not enough — the initiative may have its own scope exclusions.)
6. **Preserved behavior** *(brownfield only)* — `## Constraints & Preserved Behavior` block exists and explicitly names what must not break, OR `## Inherited state` lists inherited constraints AND the initiative did not introduce new ones. Skip this check for greenfield sessions.
7. **Reference coverage** *(if any references were loaded in Step 0.8)* — every selected `docs/reference/` material was either cited at least once (`> Ref: docs/reference/<file> — ...`) or explicitly recorded as "loaded but not relevant" in a `## Reference notes` section. If a material was loaded but never surfaced anywhere, flag it: "Material [filename] was selected but never cited. Was it actually relevant?" Skip this check if `references: []`.
8. **Inherited state coverage** *(brownfield inherit mode only)* — `## Inherited state` exists with at least one element AND every phase section either (a) captures a delta or (b) explicitly points back to `## Inherited state`. A phase section that is empty / silent is a gap — it should say "inherited unchanged" or capture a change, not be blank.

Do NOT check for `## Testing Strategy`, `## Deployment & CI/CD`, or `## Implementation Decisions` — those are not part of the spec schema. They sit downstream of stack selection / stack assessment, not in the spec.

Print the result table:

```
═══════════════════════════════════════════════════════════
  QUALITY CROSS-CHECK
═══════════════════════════════════════════════════════════

  Access Control:           [present | inherited | missing — describe]
  Business Logic:           [present | inherited | missing — describe]
  Project artifacts:        present
  Timeline-cost ack:        [present | missing — describe]
  Non-Goals:                [present | missing — describe]
  Preserved behavior:       [present | inherited | missing — describe | n/a (greenfield)]
  Reference coverage:       [present | uncited: <files> | n/a (no refs loaded)]
  Inherited state coverage: [present (N elements) | n/a (no inheritance) | gaps: <phases>]

═══════════════════════════════════════════════════════════
```

For each `missing/weak`, **list it by name** with a one-line consequence: "Business Logic: not captured as a one-sentence rule — the spec will lack a domain decision, leaving downstream architecture choices unanchored." Generic "your spec has gaps" warnings nullify the gate; do not write them.

Then ask:

AskUserQuestion:
- question: "How would you like to proceed?"
  header: "Cross-check"
  options:
  - label: "Address gaps now"
    description: "Re-enter the relevant phase to fill in missing elements. Recommended if multiple elements are missing."
  - label: "Accept and finish"
    description: "Proceed despite the gaps. They will be recorded as warnings in the checkpoint and surfaced in /product-spec's Open Questions."
  - label: "Restart phase [N]"
    description: "Go back to a specific phase and rebuild from there."
  multiSelect: false

On "Address gaps now": ask which gap; jump back to the phase that owns it (Step 1–6); re-run that phase only; then return to Step 7.

On "Accept and finish": set `checkpoint.quality_check_status: warned` (if any gaps remain) or `accepted` (if all elements are present — 6 for greenfield, 7 for brownfield). Append a `## Quality cross-check` section to `discover-notes.md` listing every gap by name with its one-line consequence — `/product-spec` mirrors these into `## Open Questions`.

On "Restart phase [N]": move to that phase. Do NOT erase prior content; let the phase overwrite its own sections.

Append `7` to `checkpoint.phases_completed`, bump `checkpoint.current_phase: 8`. Proceed to Step 8.

### Step 8: Hand off

Final write of `discover-notes.md`:

- Confirm `checkpoint.quality_check_status` is either `warned` or `accepted` (never `pending` at this point).
- Bump `updated:` to today's date in the frontmatter.
- Re-validate against the schema reference one more time: for greenfield, the body should anticipate the 10 spec sections in the order the schema requires; for brownfield, the 11 brownfield spec sections. The frontmatter should be the full `checkpoint:` block plus `context_type`. Any forward-looking content captured in Step 6 stays in its `## Forward: ...` block — NOT folded into spec-schema sections.

Then copy the next-step command to clipboard and announce:

```bash
echo -n "/product-spec" | pbcopy 2>/dev/null || echo -n "/product-spec" | clip.exe 2>/dev/null || echo -n "/product-spec" | xclip -selection clipboard 2>/dev/null || true
```

```powershell
# PowerShell (Windows)
Set-Clipboard "/product-spec"
```

Print:

```
═══════════════════════════════════════════════════════════
  DISCOVERY COMPLETE
═══════════════════════════════════════════════════════════

  Project:                [project name]
  Context type:           [greenfield | brownfield (baseline) | brownfield (inherit)]
  Phases captured:        1, 2, 3, 4, 5, 6
  FRs drafted:            [count: N new, M modified, K inherited]
  Inheritance:            [N elements inherited from K sources — or "none"]
  References used:        [N cited / M loaded — or "none"]
  Quality check:          [warned | accepted]

  ► Notes:  docs/discover-notes.md
  ► Next:   /product-spec  (✓ copied to clipboard)
═══════════════════════════════════════════════════════════
```

STOP. Do not chain into `/product-spec` automatically — the user runs it when ready.

## Critical guardrails

1. **Facilitator, not generator.** The skill never writes domain content the user did not say. If a section needs a value the user has not provided, ask. The exception is mechanical formatting (FR-NNN numbering, schema heading scaffolds, frontmatter keys).

2. **Schema is the contract.** The shape of `discover-notes.md` and the embedded scaffold for the future spec are dictated by `references/product-spec-schema.md`. Re-check at every checkpoint write. If the schema changes mid-implementation, update this skill body to match — drift is the failure mode.

3. **Stack openness is binding.** Never ask about, recommend, or commit to a framework, database, language family, or specific platform. The spec captures product-level priors only (`product_type`, `target_scale`, `timeline_budget`); team composition, language preferences, deployment, and CI/CD shape are gathered downstream of `/product-spec`. If the user volunteers stack-shaped content, capture it in discover-notes' body under `## Forward: tech-stack` — not in spec-mapped sections.

4. **Anti-patterns are surfaced by name, not generically.** Empty-CRUD detection names the missing rule shapes and asks the user to pick one. Scope-too-wide detection names the expensive items and offers concrete reduction moves. Vague "your idea has issues" warnings nullify the gate; do not write them.

5. **Soft gate, not hard gate.** The closing cross-check WARNS but allows the user to override every gap. Override paths are recorded in the checkpoint as `quality_check_status: warned` and surfaced in `/product-spec`'s `## Open Questions`. Refusing to finish is not in scope.

6. **Mode-aware behavior.** The skill auto-detects context type (greenfield vs brownfield) from project markers in cwd and adapts all six discovery phases accordingly. For brownfield, the discovery loop shifts from "what are you building from scratch?" to "what exists, what's changing, what must be preserved?". If the user invokes this skill for a small-scope problem within an existing codebase (single bug, quick refactor), suggest a simpler reframing — `/discover` is for changes that warrant a full spec.

7. **Resume preserves prior work.** On resume, completed phases are SUMMARIZED in 1–2 sentences each, never re-run. The user's prior decisions are load-bearing; replaying them frustrates the user and risks contradicting earlier captures.

8. **Reference materials are evidence, not authority.** `docs/reference/` material is the user's own input, but it does NOT bypass the facilitator stance. Every claim drawn from a reference is surfaced to the user for confirmation, captured with a `> Ref: <file> — <claim>` citation, and re-checked at Step 7 for coverage. Step 4 (FRs) is the only phase where pre-suggesting content from a reference is allowed — and only as a multi-select the user actively picks from. Binary files (`.pdf`, `.docx`, `.xlsx`) MUST have a sibling `.md` index; reading binaries blindly is opted into explicitly by the user, not the default.

9. **Inherit-by-reference: systems evolve, they do not rebuild.** In brownfield mode, Step 0.9 automatically scans `docs/product-spec.md`, `docs/architecture/*.md`, and the latest `docs/work/*/plan.md` for elements that already describe the current system. Inherited elements (vision, persona, access control, business logic, FR baseline, NFRs, product_type, target_scale) are NOT re-elicited — each subsequent phase shows the inherited value and asks ONLY about the delta. The inherited content lives in a single `## Inherited state` section as the audit anchor; phases either point to it ("inherited; no change") or capture a delta alongside it. Re-elicitation is opt-in via the "Ignore" option at Step 0.9 and is reserved for revolutionary rebuilds (rare). This makes brownfield `/discover` proportional to the change, not to the system size.

## Notes

- This is a **discovery** skill. Output is `discover-notes.md`, not `product-spec.md`. `/product-spec` is the document generator.
- The schema reference (`references/product-spec-schema.md`) is the single source of truth. Any field name, section name, or checkpoint key referenced in this body MUST exist in the schema doc — if it doesn't, fix the schema doc first.
- For greenfield, the 10 spec sections are anticipated in `discover-notes.md` body order so `/product-spec` can map cleanly. For brownfield, the 11 brownfield spec sections are anticipated instead (see `references/product-spec-schema.md`). The names match exactly. Forward-looking content (tech-stack residuals; future technical-roadmap concerns) lives in separate `## Forward to ...` blocks in discover-notes' body and does NOT map into the spec.
- If the user pushes to skip a phase ("just generate the spec already"), explain the consequence: missing phases produce thin or incomplete spec sections that downstream skills cannot anchor against. Then offer to skip with the cost made explicit. The choice is theirs.
- **Reference workflow recap**: scan once in Step 0.8 → present multi-select → load selected items + sibling `.md` indexes for binaries → persist to `references:` frontmatter → cite during Steps 1–6 with `> Ref:` blockquotes → coverage-check in Step 7. The flow is deliberately one-pass; the skill does not re-scan `docs/reference/` mid-session, so the user should drop in their material before invoking `/discover`.
- **Inheritance workflow recap (brownfield only)**: at Step 0.9, scan `docs/product-spec.md` + `docs/architecture/*.md` + latest `docs/work/*/plan.md` → extract inheritable elements → present table → user picks "Inherit (Recommended)" / "Inherit with review" / "Ignore" → on inherit, write `## Inherited state` once and persist `inherited_from:` frontmatter → each phase opens with inherited value + a delta gate → phase output is either "inherited; no change" pointer OR captured delta alongside inheritance. Step 7 cross-check treats `inherited` as satisfying the gate. The skill never silently inherits without showing the user what is being inherited.
- **When inheritance triggers full re-elicitation**: if Step 0.9 finds artifacts but the user picks "Ignore", or if a phase's delta is large enough to override the inherited value entirely (e.g., the whole auth model is replaced), the phase reads like baseline brownfield — full echo-back, no shortcut. Inheritance is a default, not a constraint.
