# Kickoff — Initialize /docs Directory

Paste this prompt to Copilot CLI to scaffold the project documentation skeleton:

---

You are scaffolding the `/docs` directory in this project. The goal is idempotent: each artifact is independently create-if-absent. Re-running on a project where everything already exists is a no-op.

**Target structure:**

```
docs/
├── README.md
├── architecture/        — design decisions, system docs
├── analyzes/            — research/eval before decisions
├── reference/           — operational specs (vendor configs, limits)
└── work/                — in-flight initiatives (folder-per-initiative)
```

**Steps:**

1. **`docs/` + `README.md`** — if missing, create and write:

   ```
   # Project Documentation

   Layout:

   - `product-spec.md` — what this product is (created by product-spec workflow).
   - `discover-notes.md` — transient discovery notes (input to product-spec).
   - `architecture/` — design decisions, system docs.
   - `analyzes/` — research/evaluation done BEFORE decisions.
   - `reference/` — operational specs (vendor configs, limits, schemas).
   - `work/` — in-flight initiatives. One folder per initiative: `NNN-<slug>/` with `plan.md`, `index.md`, `T-NNN-*.md` task files.

   Living docs at root and in architecture/, reference/ are edited in place. Research docs in analyzes/ are point-in-time snapshots. Work items follow folder-per-initiative.
   ```

2. **`docs/architecture/` + `README.md`** — if missing, create with:

   ```
   # Architecture

   Design decisions and system documentation. Living docs — edit in place.

   Examples: `auth-and-providers.md`, `chat-flow.md`, `memory-architecture.md`, `security-review.md`.

   Naming: kebab-case, descriptive, no prefixes.
   ```

3. **`docs/analyzes/` + `README.md`** — if missing, create with:

   ```
   # Analyzes

   Research and evaluation done BEFORE making a decision. Examples:

   - `<technology>-evaluation.md` — pros/cons before adoption
   - `<approach>-comparison.md` — comparison of approaches

   Point-in-time snapshots — don't edit retroactively. Each analysis should include: date, decision (or "open"), reasoning with evidence, alternatives considered.
   ```

4. **`docs/reference/` + `README.md`** — if missing, create with:

   ```
   # Reference

   Operational specs and vendor-specific data. Examples:

   - `<vendor>-models.md`
   - `<vendor>-timeout.md`
   - `<api>-contracts.md`

   Factual reference data — update when the underlying source changes.
   ```

5. **`docs/work/` + `README.md`** — if missing, create with:

   ```
   # Work

   In-flight initiatives. One folder per initiative: `NNN-<slug>/` where NNN is zero-padded sequential and slug is 3-5 word descriptor.

   Per-initiative layout:
       docs/work/004-observability-otel/
       ├── plan.md              — the "thinking doc"
       ├── index.md             — derived view of task status
       ├── T-001-otel-deps.md   — atomic task
       ├── T-002-...
       └── T-003-...

   Conventions:
   - plan.md is the living plan — edit in place when scope changes.
   - T-NNN-<slug>.md files are atomic tasks with status frontmatter (pending | in-progress | done | obsolete).
   - index.md is a DERIVED view — don't edit directly. T-*.md frontmatter is the source of truth.
   - Already-implemented tasks (status: done) are NEVER edited. If the plan changes after a task is done, write a NEW follow-up task.

   Workflow:
   1. After planning, copy approved plan into docs/work/NNN-<slug>/plan.md.
   2. Decompose into T-NNN tasks (manually or via atomize prompt).
   3. Update status as tasks progress.
   4. When plan changes, edit plan.md and re-reconcile tasks.
   ```

6. **Print status block:**

   ```
   docs/                            [created|present]
   docs/README.md                   [created|present]
   docs/architecture/               [created|present]
   docs/architecture/README.md      [created|present]
   docs/analyzes/                   [created|present]
   docs/analyzes/README.md          [created|present]
   docs/reference/                  [created|present]
   docs/reference/README.md         [created|present]
   docs/work/                       [created|present]
   docs/work/README.md              [created|present]
   ```

7. **Brownfield detection** — detect whether existing codebase, and if so, suggest generating an AI-context file:

   ```bash
   # Tier 1 (strong): version control with history
   git log --oneline -1 2>/dev/null

   # Tier 2 (strong): lockfiles
   ls package-lock.json yarn.lock pnpm-lock.yaml Cargo.lock poetry.lock go.sum Gemfile.lock composer.lock 2>/dev/null
   ```

   - **No hits → greenfield**: print "Greenfield project — no existing code to analyze." STOP.
   - **Any hit → brownfield**: check if `.github/copilot-instructions.md` (or equivalent AI-context file) exists. If exists, print "Brownfield detected. AI-context file already present." STOP. If absent, ask the user: "Brownfield detected (signals: <list>). Want me to scan the repo and generate a starter `.github/copilot-instructions.md` with project conventions, build commands, and code patterns?" If yes, do a codebase analysis pass: read README, package manifest, key source files, test setup, then write `.github/copilot-instructions.md` with a concise summary (200-400 words). If no, exit.

**Rules:**

- Never overwrite existing content in scaffold phase. If a file or directory exists, leave it untouched and mark `present`.
- Each scaffold artifact is independent — create only what's missing.
- Brownfield detection is fast (two bash calls, no file reading) so the no-op case stays quick.
- Stop after Step 7.
