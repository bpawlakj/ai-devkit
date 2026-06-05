---
name: setup
description: Initialize the /docs directory in this project — scaffold docs/{architecture,analyzes,reference,work}/ plus the tests/e2e/ home for /scenario, with README.md files if absent. Idempotent. For brownfield projects, also offers to run Claude Code's built-in /init to generate CLAUDE.md from codebase analysis.
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
  - Skill
---

# /setup — Initialize /docs Directory

Scaffold the `/docs` directory skeleton (`architecture/`, `analyzes/`, `reference/`, `work/`) plus a `README.md` in each (and at `docs/` root), and the `tests/e2e/` home that `/scenario` writes into, so the project-documentation and E2E-scenario conventions have a place to land. Idempotent: each artifact is independently create-if-absent; re-running on a project where everything is already present is a no-op.

For **brownfield projects** (existing codebase detected), additionally offers to run Claude Code's built-in `/init` to generate `CLAUDE.md` from codebase analysis (Step 7). This pairs naturally: workspace conventions scaffolded by `/setup` + AI context populated by `/init` = complete one-command onboarding for an existing repo.

This skill is the explicit entry point for users who want to scaffold workflow conventions up-front. It is NOT a precondition for downstream skills — `/discover`, `/product-spec`, and `/atomize` self-bootstrap or delegate here when needed.

## Structure rationale

```
docs/
├── README.md                    # navigation pointer to all subdirs
├── product-spec.md              # (created by /product-spec) — what the product IS
├── discover-notes.md            # (created by /discover) — transient discovery captures
├── architecture/                # design decisions, system docs, integration designs
├── analyzes/                    # research/evaluation BEFORE decisions (e.g. "should we adopt X?")
├── reference/                   # operational specs (vendor configs, limits, schemas)
└── work/                        # plans + tasks, folder-per-initiative (NNN-<slug>/)

tests/
└── e2e/                         # (E2E scenario home for /scenario + /e2e-run)
    ├── scenarios/               #   scenario plans (<slug>.md, depends_on links)
    ├── web/                     #   generated Playwright web tests (.spec.ts)
    └── api/                     #   generated Playwright API tests (.api.spec.ts)
```

**Why this shape, not `context/{changes,archive,foundation}/`:** real engineering projects accrete documentation by *type* (architecture, research, reference, work-in-flight), not by *change-id*. People look up "what's the auth architecture?" much more often than "what was decided on change-id-XYZ?". The split also matches conventions used in mature repos.

**Why `work/` over separate `plan/` + `tasks/`:** at small scale (1-5 items) the split is artificial; prefix discipline (`P-XXX`, `T-XXX`) preserves semantic distinction in one folder. Easy to split later (`mkdir plan tasks && mv P-* plan/ && mv T-* tasks/`) if the project grows to dozens of items.

## Process

### Step 1: Scaffold `docs/` + `README.md`

If `docs/` exists, leave it untouched and note `present`. Otherwise create with `mkdir -p` and note `created`.

If `docs/README.md` exists, leave it. Otherwise write this canonical content:

```
# Project Documentation

Layout:

- **`product-spec.md`** — what this product is (created by `/product-spec`).
- **`discover-notes.md`** — transient discovery notes (created by `/discover`, input to `/product-spec`).
- **`architecture/`** — design decisions and system docs (e.g. auth flow, data flow, integration designs).
- **`analyzes/`** — research and evaluation done BEFORE decisions (e.g. "should we adopt X?").
- **`reference/`** — operational specs (vendor configs, limits, model lists, API contracts).
- **`work/`** — in-flight initiatives. One folder per initiative: `NNN-<slug>/` with `plan.md`, `index.md`, and `T-NNN-*.md` task files.

## Conventions

- **Living docs** live at `docs/` root and in `architecture/`, `reference/` — edit-in-place as the project evolves. Don't create dated copies.
- **Research docs** in `analyzes/` are point-in-time snapshots — don't edit retroactively. Add a follow-up doc if findings change.
- **Work items** in `work/` follow folder-per-initiative: each gets a folder `NNN-<slug>/` with a `plan.md` (the "thinking doc"), task files `T-NNN-*.md` (atomic units of work), and an `index.md` (derived view of task status). Create via `/atomize`.
```

### Step 2: Scaffold `docs/architecture/` + `README.md`

If missing, create. README content:

```
# Architecture

Design decisions and system documentation. These are LIVING docs — edit in place as the system evolves.

Examples of what goes here:

- `auth-and-providers.md` — how authentication and provider integrations work
- `chat-flow.md` — request/response flow through the system
- `memory-architecture.md` — how memory is structured and retrieved
- `tool-filtering.md` — how tools are selected per request
- `security-review.md` — security posture, threat model
- `integration-<name>.md` — how a third-party system is integrated

Naming: kebab-case, descriptive. No prefixes (these aren't sequential).

When something is fully superseded (replaced rather than refined), move it to `docs/_archive/YYYY-MM-DD-<doc>.md` and write the replacement at the original path.
```

### Step 3: Scaffold `docs/analyzes/` + `README.md`

If missing, create. README content:

```
# Analyzes

Research and evaluation done BEFORE making a decision. Examples:

- `koog-ai-evaluation.md` — should we adopt Koog as a dependency? (decision: no, here's why)
- `data-masking-analysis.md` — comparison of approaches for PII masking
- `<technology>-evaluation.md` — pros/cons before adoption

These are **point-in-time snapshots**. Don't edit retroactively after a decision is made — the doc records the reasoning at that moment. If findings change later, write a follow-up.

Each analysis should include:
- **Date** in frontmatter or first heading
- **Decision** (or "open" if undecided)
- **Reasoning** with evidence
- **Alternatives considered**
```

### Step 4: Scaffold `docs/reference/` + `README.md`

If missing, create. README content:

```
# Reference

Operational specs and vendor-specific data. Examples:

- `<vendor>-models.md` — list of models available from a provider, with capabilities
- `<vendor>-timeout.md` — rate limits and timeouts
- `<api>-contracts.md` — API contract spec
- `<config>-schema.md` — config file schema reference

These are factual reference data — not decisions, not plans. Update when the underlying source changes.
```

### Step 5: Scaffold `docs/work/` + `README.md` + initial `STATUS.md`

If missing, create. README content:

```
# Work

In-flight initiatives. One folder per initiative, named `NNN-<slug>/` where `NNN` is a zero-padded sequential number and `<slug>` is a 3-5 word descriptor.

`STATUS.md` (sibling to this README) is an auto-generated cross-initiative overview ("where are we now"). It is rewritten by `/save-plan`, `/atomize`, and `/implement` after each state change. Do not edit by hand — change `plan.md` / `T-*.md` frontmatter and the next skill invocation will refresh it. Top-down product sequencing (foundations + slices, "where are we going") lives separately at `docs/roadmap.md`, hand-edited.

## Layout per initiative

```
docs/work/004-observability-otel/
├── plan.md                          # the "thinking doc" — Problem, Current State, Solution
├── index.md                         # derived view: which tasks are pending/in-progress/done/obsolete
├── T-001-otel-deps.md               # atomic task with status frontmatter
├── T-002-tracing-config.md
└── T-003-metrics-bridge.md
```

## Conventions

- **`plan.md`** is the living plan. Edited in place when scope changes.
- **`T-NNN-<slug>.md`** files are atomic tasks. Each has frontmatter with `status` (pending | in-progress | done | obsolete), `depends_on`, `blocks`, etc.
- **`index.md`** is a DERIVED view generated by `/atomize` — don't edit it directly. T-*.md frontmatter is the source of truth; index is regenerated.
- **Already-implemented tasks (status: done) are never edited.** If the plan changes after a task is done, write a NEW follow-up task that modifies the existing implementation.

## Workflow

1. After `/plan` in Claude Code, copy the approved plan into a new `docs/work/NNN-<slug>/plan.md`.
2. Run `/atomize <folder>` to decompose the plan into T-NNN task files + initial index.md.
3. As tasks are implemented, update their status frontmatter (or rely on `/atomize` reconciliation to detect via git log + file existence).
4. When the plan changes, edit `plan.md`, then re-run `/atomize <folder>` — it will reconcile: propose new tasks for new requirements, mark removed requirements as obsolete, suggest follow-ups for changes to already-done work.
```

After writing the README, also seed `docs/work/STATUS.md` by calling the regenerator (it writes a placeholder when the folder has no initiatives yet):

```bash
bash ~/.claude/scripts/regenerate-status.sh
```

If the regenerator script is absent (older ai-devkit install without scripts layer), skip silently — `/save-plan` will create STATUS.md on the first initiative.

### Step 5.5: Scaffold `tests/e2e/` + `README.md`

This is the home `/scenario` writes scenario plans and generated tests into, and `/e2e-run` reads from. Create-if-absent, idempotent — never touch an existing `tests/` layout.

If `tests/e2e/` exists, leave it untouched and note `present`. Otherwise `mkdir -p tests/e2e` and note `created`. (Leave the `scenarios/` / `web/` / `api/` subdirs to `/scenario` — it creates them when it first writes, so the scaffold stays empty-but-documented rather than littered with empty dirs.)

If `tests/e2e/README.md` exists, leave it. Otherwise write this canonical content:

```
# End-to-End Tests

Home for E2E scenarios authored by `/scenario` and run by `/e2e-run`.

## Layout

- **`scenarios/<slug>.md`** — scenario plan: a human-reviewable enumeration of
  optimistic + pessimistic paths, with frontmatter linking back to the work that
  motivated it (`depends_on: [T-NNN]`, `initiative:`) and the full `generated:`
  file list. This is the durable record; the test files are generated from it.
- **`web/<slug>.spec.ts`** — generated Playwright web tests (browser), tagged
  `@optimistic` / `@pessimistic`.
- **`api/<slug>.api.spec.ts`** — generated Playwright API tests (the `request`
  fixture: seed/login → act → assert backend state → reset).
- **`extensions.md`** — written by `/e2e-run` when an opt-in API runner (Hurl,
  Schemathesis) is enabled for this project.

## Conventions

- Author with `/scenario <T-NNN | initiative | spec | freeform>`; run with
  `/e2e-run <scenario | initiative | T-NNN | all>`.
- Base URLs and secrets come from env / Playwright config — never hardcoded.
- Assertions encode acceptance criteria, never observed implementation output.
- `/e2e-run` is report-only on failure — it never regenerates or "heals" tests.
- This directory is separate from any unit-test directory on purpose, so the two
  never collide. Add `playwright-report/` and `test-results/` to `.gitignore`.
```

### Step 6: Print summary

Print a status block per artifact:

```
docs/                            [created|present]
docs/README.md                   [created|present]
docs/architecture/               [created|present]
docs/architecture/README.md      [created|present]
docs/analyzes/                   [created|present]
docs/reference/                  [created|present]
docs/reference/README.md         [created|present]
docs/work/                       [created|present]
docs/work/README.md              [created|present]
docs/work/STATUS.md              [created|present]
tests/e2e/                       [created|present]
tests/e2e/README.md              [created|present]
```

Then a one-paragraph guide:

- `docs/architecture/` — design decisions; edit in place.
- `docs/analyzes/` — research snapshots; don't retroactively edit.
- `docs/reference/` — vendor specs and operational data.
- `docs/work/` — initiatives. Use `/atomize` to manage plan → tasks decomposition.
- `docs/product-spec.md` — created by `/product-spec` when you run the discovery chain.
- `tests/e2e/` — E2E scenario home. Use `/scenario` to author scenarios and `/e2e-run` to run them.

Then proceed to Step 7 (brownfield check).

### Step 7: Brownfield detection + optional /init

After scaffolding finishes, detect whether this is a brownfield project (existing codebase) and, if so, offer to run Claude Code's built-in `/init` to generate `CLAUDE.md` from codebase analysis. This gives brownfield users a complete one-stop onboarding: workspace conventions scaffolded + AI context populated.

**Detection — keep it fast** (two bash calls, no file reading):

```bash
# Tier 1 (strong): version control with history
git log --oneline -1 2>/dev/null

# Tier 2 (strong): lockfiles prove real dependency resolution
ls package-lock.json yarn.lock pnpm-lock.yaml Cargo.lock poetry.lock go.sum Gemfile.lock composer.lock 2>/dev/null
```

Classify:

- **Any Tier 1 OR Tier 2 hit** → brownfield
- **No hits** → greenfield

**If greenfield**: print one line — "Greenfield project — no existing code to analyze. Skipping /init suggestion." Then STOP.

**If brownfield**: check whether `CLAUDE.md` already exists at repo root.

```bash
test -f CLAUDE.md
```

- **`CLAUDE.md` exists**: print one line — "Brownfield detected. CLAUDE.md already present — skipping /init suggestion." Then STOP. (Do not offer to regenerate; user can re-run `/init` manually if they want.)
- **`CLAUDE.md` absent**: ask via AskUserQuestion:

AskUserQuestion:
- question: "Brownfield project detected (signals: <list detected — e.g. 'git history (47 commits), package-lock.json'>). Run /init now to generate CLAUDE.md from codebase analysis?"
  header: "Run /init?"
  options:
  - label: "Yes — run /init (Recommended)"
    description: "Claude Code's built-in /init scans the repo and writes CLAUDE.md with project-specific conventions, build commands, and code patterns. Pairs naturally with the docs/ scaffold just created."
  - label: "No — skip"
    description: "Exit here. You can run /init manually later if needed."
  multiSelect: false

**On "Yes"**: invoke `init` via the **Skill** tool (NOT via Bash). This delegates to Claude Code's built-in skill — do not duplicate its logic here.

When `init` returns:
- If it succeeded (CLAUDE.md now exists), print one line: "CLAUDE.md generated. Workspace fully onboarded."
- If it failed (e.g. error, user cancelled inside /init), print: "/init did not complete. The docs/ scaffold is intact — you can re-run /init manually later."
- Either way, do NOT roll back any of Steps 1-6's writes. The docs/ scaffold is independent of /init's success.

**On "No"**: print one line — "Skipped /init. You can run it manually any time."

In all cases, STOP after this step. Do not chain into further skills.

## Notes

- **Idempotent (Steps 1-6).** Re-running `/setup` on a project where all artifacts already exist is a no-op for the scaffolding phase (with a status print). Step 7 (brownfield detection) is also idempotent — if `CLAUDE.md` already exists, `/init` is not offered.
- **No forced ordering.** All scaffold artifacts are independent. If only some exist, create the missing ones and leave the existing ones alone.
- **Not a precondition.** Other skills self-bootstrap. `/setup` is for users who like to set up the `/docs` skeleton up-front.
- **Optional dirs not scaffolded:** `prototypes/`, `_archive/`, dated subdirs. Users add these when needed. The five baseline `docs/` dirs cover ~90% of cases.
- **`tests/e2e/` is scaffolded but its subdirs are not.** Only `tests/e2e/` + its README are created; `/scenario` creates `scenarios/` / `web/` / `api/` lazily when it first writes, so the scaffold doesn't litter empty dirs. An existing `tests/` layout is never modified — only the `e2e/` subdir and its README are create-if-absent.
- **Brownfield + /init pairing rationale:** scaffolding workspace conventions and generating CLAUDE.md are two halves of the same task — "make this repo legible to me and to AI agents". Doing them together means a brownfield user gets full onboarding in one command without remembering the second step.
- **Why delegate to Claude Code's built-in `/init` rather than reimplement:** /init is maintained by Anthropic and improves over time. Wrapping it via the Skill tool means `/setup` automatically benefits from upstream improvements without changes here.
- **Step 7 also fires when `/setup` is delegated from another skill** (e.g. `/discover` invoking `/setup` when `docs/` is missing). User gets one extra question in nested cases — preferred over inconsistent behavior between direct and nested invocations.
