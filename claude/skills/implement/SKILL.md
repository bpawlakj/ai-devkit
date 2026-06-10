---
name: implement
description: >
  Execute atomic task files (T-NNN-<slug>.md) or a standalone plan.md with
  disciplined pre/per/post gates and write status back to frontmatter, closing
  the loop with /atomize so reconciliation works without manual edits. Detects
  the project's test runner from package.json / pyproject.toml / go.mod /
  pom.xml / Cargo.toml / composer.json. Respects depends_on between tasks,
  picks the next unblocked task on resume, and offers to capture lessons when
  a task is abandoned mid-flight. Modes: single task (T-NNN), whole initiative
  folder (docs/work/<NNN>-<slug>/), or a plan.md that was never atomized.
  Trigger phrases: "implement T-001", "implement this initiative", "execute
  the plan", "work on docs/work/NNN-slug", "resume implementation", "continue
  the initiative".
argument-hint: "<T-NNN-file | initiative-folder | plan.md>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - Skill
---

# /implement — Execute Tasks with Phased Gates and Frontmatter Writeback

This skill takes one atomic task, an initiative folder, or a standalone plan and drives execution through three gates per task: **pre-execution** (dependencies, clean state, runner detected), **in-execution** (write code → test → review), **post-execution** (commit + frontmatter writeback). It closes the loop with `/atomize`: when a task finishes, `status: done`, `commit: <SHA>`, and `completed: YYYY-MM-DD` land in the T-NNN-*.md frontmatter automatically, so `/atomize` reconciliation works without you hand-editing files.

The skill is **disciplined**, not autonomous. Each task pauses for confirmation at the commit boundary by default. Configurable via the `--auto-commit` flag.

The contract for task and index file shapes lives at `../atomize/references/task-schema.md`. Read it once before the first writeback per session.

## When to use, when to skip

**Use when**:
- You have `T-NNN-*.md` files in `docs/work/<NNN>-<slug>/` (produced by `/atomize`) and want them implemented with consistent gates and frontmatter writeback.
- You have a standalone `plan.md` you'd rather execute end-to-end than atomize first (small initiatives, < 5 tasks worth of work).
- You stopped mid-initiative and want to resume from the first unblocked pending task.

**Skip when**:
- The change is a one-off bug fix or rename — just edit + commit; no initiative is needed.
- You haven't planned yet (use Claude Code's `/plan` mode → `/save-plan` → `/atomize` first).
- You want to verify status without changing anything (read `index.md` in the initiative folder).

## Relationship to other skills

- `/atomize` — produces the T-NNN-*.md files this skill consumes; reads back the frontmatter this skill writes. The two skills round-trip the initiative through implementation without conflict: `/atomize` plans, `/implement` executes, `/atomize` reconciles later if the plan changes.
- `/save-plan` — upstream of `/atomize`. If you skipped `/atomize` and want to implement a `plan.md` directly, this skill detects that and offers to atomize first.
- `/research` — orthogonal. Research conclusions referenced from `docs/analyzes/<slug>.md` may already be cited in `plan.md`; this skill leaves those references untouched.
- `~/.claude/rules/*.md` — auto-active language rules (`typescript.md`, `python.md`, `go.md`, etc.). This skill does NOT re-enforce them — it trusts ai-devkit's existing layer.
- `security-reviewer`, `performance-analyzer` agents — invoked optionally in Step 5 (post-task review) when the user opts in.
- `/scenario` + `/e2e-run` — downstream E2E layer. After implementing a task, `/scenario` authors committed end-to-end scenarios (optimistic + pessimistic paths) linked to it via `depends_on: [T-NNN]`, and `/e2e-run` runs them. Natural flow: `/implement` → `/scenario` → `/e2e-run`. They share this skill's assertion-oracle rule (assert against acceptance criteria, never observed output) and modify-in-place discipline.
- `extensions/` (next to this SKILL.md) — opt-in quality gates with identified blocking rules (e.g. `security-baseline` → SEC-01..10), checked against the task diff before commit. Discovered via `*.opt-in.md` descriptors at Step 2 gate 6; full rules load only on opt-in. Enablement is per-initiative, recorded in `docs/work/<NNN>-<slug>/extensions.md`. Authoring contract: `extensions/README.md`.
- `docs/reference/lessons.md` — if the user abandons a task mid-flight, the skill offers to append an observation here.

## Output language

All persisted artifacts — commit messages, T-NNN-*.md frontmatter writeback, `## Notes` appendings, `docs/reference/lessons.md` entries — are written in **English**, regardless of the user's chat language. This matches the global policy in `~/.claude/CLAUDE.md` §13. User-facing prompts during the session may follow the user's working language; the disk content is always English so the repo is portable across teams and time.

## What this skill does not do

- It does not write the code for you in zero shots. It runs **one task at a time**, you steer per task.
- It does not push to remote. Push is your explicit step after the initiative is done (or part of a separate `/ship` flow).
- It does not modify already-done tasks. If `status: done` is in frontmatter, the skill skips that file entirely (matching `/atomize`'s never-edit-done invariant).
- It does not invent tests. If `## Acceptance` in the task says nothing about tests, the skill asks what would prove completion before any code is written.

## Initial Response

When invoked:

1. **Path given** (`/implement <path>`): resolve as either a file or folder; jump to Step 1.
2. **No path**: scan `docs/work/` for initiative folders with at least one `T-*.md status: pending`. If exactly one such folder exists, propose it. Otherwise list them:

```
Which target?

  - docs/work/001-auth/                [T-*: 6 files, 4 done, 2 pending]
  - docs/work/002-attendance/          [T-*: 3 files, 0 done, 3 pending]
  - docs/work/003-monthly-summary/     [plan.md only, no T-*]

Pass: /implement <path>
```

Then STOP.

## Process

### Step 0: Verify workspace

```bash
test -d docs/work
```

If missing, ask whether to delegate to `/setup`. STOP if declined.

### Step 1: Resolve target and mode

| Argument | Mode | Behavior |
|---|---|---|
| `docs/work/NNN-slug/T-003-*.md` | **single-task** | Implement just this task. |
| `docs/work/NNN-slug/` | **initiative** | Implement next unblocked pending task; offer to chain to the next one on completion. |
| `docs/work/NNN-slug/plan.md` (no T-*) | **standalone-plan** | Ask: atomize first (recommended) or execute plan inline phase-by-phase? |
| Anything else | reject and re-prompt | — |

Print the resolved mode in one line. Print which T-NNN will be touched.

### Step 2: Pre-execution gates

Before opening any source file:

1. **Clean working tree**. `git status --porcelain` must be empty. If not, ask:
   - "Stash and continue" → `git stash push -u -m "implement-gate-<task-id>"`
   - "Commit current changes first" → STOP; user handles it.
   - "Override (risky)" → continue without stashing.

2. **Branch check**. If on `main` / `master` / `trunk`, offer to create a branch named `<initiative-slug>/<task-id>` (or `<initiative-slug>` for standalone-plan). Default: yes.

3. **Dependency check** (initiative mode). Read the target task frontmatter `depends_on:`. For each id, open the file and confirm `status: done`. If any dependency is not done, STOP and print which one(s) — offer to switch target.

4. **Runner detection**. Walk up from cwd looking for one of:

| Marker | Test command (default) |
|---|---|
| `package.json` (has `test` script) | `npm test` (or `pnpm test`, `yarn test` based on lockfile) |
| `package.json` (vitest in devDeps) | `npx vitest run` |
| `package.json` (jest in devDeps) | `npx jest` |
| `pyproject.toml` / `setup.py` / `pytest.ini` | `pytest` |
| `go.mod` | `go test ./...` |
| `pom.xml` | `mvn -B test` |
| `build.gradle` / `build.gradle.kts` | `./gradlew test` |
| `Cargo.toml` | `cargo test` |
| `composer.json` (phpunit in require-dev) | `./vendor/bin/phpunit` |
| `Package.swift` | `swift test` |
| (none) | ask user once; cache for the session |

Print the detected runner. Offer one-line override.

5. **Baseline test run**. Run the detected command once; expect green. If red, STOP — do not start a task on a red baseline. Print the failing test names and ask:
   - "Stop and let me fix the baseline."
   - "Override (the failures are unrelated and I'll fix them in this task)."

6. **Extension opt-in** (once per initiative). Extensions are opt-in quality gates checked against the task diff before commit — see `extensions/README.md` (relative to this SKILL.md) for the contract.

   - If `docs/work/<NNN>-<slug>/extensions.md` exists, read it — enablement is locked from a prior session. Print one line: "Extensions: security-baseline=partial (recorded <date>)." Load the full rules file for each enabled extension. Done.
   - Otherwise, glob `extensions/*.opt-in.md` (relative to this SKILL.md). If none exist, skip silently.
   - For each descriptor found, read it (descriptors are deliberately lightweight) and ask via AskUserQuestion:
     - question: "Enable the <title> extension for this initiative? It gates every task's diff before commit."
       header: "<name>"
       options:
       - label: "Partial — core rules block, rest advisory (Recommended)"
         description: "Rules <partial_rules> are blocking; remaining rules print as advisory findings."
       - label: "Full — all rules block"
         description: "Every rule is a blocking finding. For security-critical or production-bound work."
       - label: "Off"
         description: "The rules file is never loaded. Zero context cost."
       multiSelect: false
   - Record the choices in `docs/work/<NNN>-<slug>/extensions.md`:

   ```yaml
   ---
   extensions:
     security-baseline: partial   # full | partial | off
   recorded: <YYYY-MM-DD>
   overrides: []                  # appended by Step 6 downgrades
   ---
   ```

   - **Deferred loading**: read the full rules file (`extensions/<name>.md`) ONLY for extensions enabled `full` or `partial`. Extensions set to `off` cost nothing.

### Step 3: Read the task

Read the target T-NNN-*.md FULLY. Extract:
- `## Scope` (what files/areas this touches)
- `## Approach` (how to implement)
- `## Acceptance` (what proves done)

If `## Acceptance` is missing or vague (e.g. "it works"), ask: "What observable change or test result proves this task is done?" before writing code.

### Step 4: Execute (red → green → refactor, or write-then-test)

Branch by task shape:

- **Test-first** if `## Acceptance` names a test case or behavior that can be expressed as a test: write the failing test first, run the runner, confirm red, then implement, run the runner, confirm green.
- **Implement-then-verify** for refactors, config changes, scaffolding tasks where a test-first cadence is artificial.

In both branches:
- Run only the **affected** test selector when possible (`vitest run path/to/spec`, `pytest path/to/test_x.py::test_y`, `go test ./pkg/...`, etc.). Full-suite run is reserved for Step 6.
- **The assertion's expected value must come from `## Acceptance` / the spec / requirements — never read off the implementation.** A test whose oracle is the code only cements current behavior, bugs included (the *oracle problem*). Assert observable behavior or persisted state (e.g. the DB row that was written), not the function's own return value echoed back. Confirm the test fails *for the right reason*: red before the implementation exists (test-first), or — for implement-then-verify — break the behavior once, confirm red, then revert (never commit the break).
- Edit only files listed in `## Scope` or files reasonably implied by them. If a substantial edit lands outside scope, surface it to the user: "This required touching `<file>` not in scope — confirm?"
- **Modify in place — never fork files.** When a task changes an existing file, edit that file directly. NEVER create sibling copies as a way to "preserve" the original (`UserService_new.ts`, `auth_v2.py`, `Component.modified.tsx`, `routes.bak`, `Copy of X`) — git preserves history; duplicates rot into dead code that confuses every later task. New files are reserved for genuinely new modules named or implied by `## Scope`.
- **Accessibility is part of done for UI work.** When the task touches user-facing UI, an increment is not done until it meets the accessibility bar (P11 / `rules/accessibility.md`): keyboard-operable, programmatic labels, visible focus, sufficient contrast, no meaning-by-color-alone. Treat a missing label or unreachable control as a failing acceptance criterion, not a follow-up ticket — verify with the keyboard and an automated check (axe / Lighthouse) before commit.

### Step 5: Optional review

After tests pass, ask once per task:

```
Run code review before commit?
  - Yes — security + correctness (agents: security-reviewer, performance-analyzer)
  - No — proceed to commit
  - Just security
  - Just performance
```

If yes / partial yes: delegate via the `Agent` tool to the relevant subagent(s). The review brief follows fresh-model verification (`../eval/references/fresh-verification.md`): the subagent gets the task diff + `## Acceptance` — never the implementation reasoning — and reports correctness/requirement gaps only. Print their findings. Loop: if the user wants to apply suggested fixes, jump back to Step 4 with the suggestions as the new scope addendum.

### Step 6: Full suite + commit

Before committing:
1. **Duplicate-file check.** Scan `git status --porcelain` for added/untracked files whose names suggest a forked copy of an existing file (`*_new.*`, `*_v2.*`, `*_modified.*`, `*.bak`, `* copy.*`, `Copy of *`). If any match, STOP — fold the changes back into the original file before committing (see the modify-in-place rule in Step 4).
2. **Extension rules check** (only if Step 2 gate 6 enabled any extension). Evaluate the task diff against each loaded rules file. For every rule report one state: `pass`, `N/A` (with one-line justification), `advisory finding`, or `blocking finding` — each finding cites its rule ID and the offending file:line. Print the findings table. If blocking findings exist, the commit does NOT proceed; ask per finding:
   - "Fix now (Recommended)" → jump back to Step 4 with the finding as scope addendum, then re-run this check.
   - "Downgrade to advisory for this task — recorded" → append to `overrides:` in the initiative's `extensions.md`: `{rule: SEC-NN, task: T-NNN, reason: <user's one-liner>, date: <YYYY-MM-DD>}`. Deliberate and auditable, never silent.
   - "Stop here" → STOP without committing.
   Advisory findings are printed but don't block.
3. Run the **full** detected runner once. Must be green.
4. Show the diff (`git diff --stat` then `git diff` if user wants details).
5. Compose commit message. Default template:

```
<task-id>: <task title from frontmatter>

<one-paragraph what + why, derived from ## Scope and ## Acceptance>

Refs: docs/work/<NNN>-<slug>/T-NNN-<slug>.md
```

   If the task implements a decision recorded in `docs/architecture/decisions/` (an ADR written by
   `/research`), add that `D-NNN` to the `Refs:` line too — it ties the implementing commit back to
   the durable verdict that motivated it.

6. Ask:
   - "Commit with this message" (default)
   - "Edit message"
   - "Show full diff first"
   - "Don't commit yet"

On commit: `git add <files-touched-in-this-task>` then `git commit`. Never `git add -A` / `git add .`.

### Step 7: Frontmatter writeback

After a successful commit, capture the SHA: `git rev-parse HEAD`. Edit the T-NNN-*.md frontmatter:

```yaml
status: done
completed: <YYYY-MM-DD from `date +%Y-%m-%d`>
commit: <short SHA from `git rev-parse --short HEAD`>
```

Other frontmatter fields untouched. Body untouched. If a `## Notes` section exists, append a `### Implementation note` subsection with a one-line summary (timestamp + what changed). If `## Notes` is absent, do nothing — don't invent sections.

### Step 7.5: Regenerate docs/work/STATUS.md

The task just flipped from `pending` / `in-progress` to `done` — refresh the cross-initiative status board so the new state is reflected:

```bash
bash ~/.claude/scripts/regenerate-status.sh
```

This rewrites `docs/work/STATUS.md` from current state across all initiatives. A done-counter bump moves the initiative's row in the **Active** table (e.g. `3/12 → 4/12`); finishing the last pending task may promote the initiative from **Active** to **Done**.

If `~/.claude/scripts/regenerate-status.sh` is absent (user hasn't installed ai-devkit's scripts layer), print a soft warning and continue. STATUS.md is a derived artifact — its absence doesn't block the implement loop.

### Step 8: Next task or close

| Mode | Behavior |
|---|---|
| `single-task` | Print: "T-NNN done. Commit: `<SHA>`. Frontmatter updated." STOP. |
| `initiative` | Identify next unblocked pending task. Ask: "Continue with `T-NNN <title>`?" Default yes → loop to Step 2. Default no → STOP after printing remaining queue. |
| `standalone-plan` | Identify next major section in `plan.md` not yet implemented (heuristic: look for `<!-- implemented: SHA -->` markers near each `##`). Same loop. If finished, ask: "Atomize the now-implemented plan to leave a paper trail in `T-*.md`?" |

### Step 9: Abandon path (any step)

If the user says "stop", "abandon", "give up on this task" mid-stream:

1. **Don't commit partial work** unless the user explicitly says so.
2. Offer: "Stash, drop, or leave dirty?" — execute their choice.
3. Offer to append a lesson to `docs/reference/lessons.md`. Format:

```markdown
## <Short rule in imperative>

- **Context**: T-NNN, initiative `<NNN>-<slug>` (abandoned <YYYY-MM-DD>).
- **Problem**: <what blocked us — friction, surprise, missing precondition>.
- **Rule**: <what we'd do differently next time>.
- **Applies to**: plan | research | implement | impl-review | all
```

Append-only; never reorganize prior entries. If the file doesn't exist, create it with a `# Lessons Learned` heading. STOP after writing.

## Edge cases

- **No git repo**: skip git checks; ask "no git detected — continue without commits? lessons writeback still works." Default yes.
- **`status: done` already on the target task**: print "T-NNN is already done (commit `<SHA>` on `<date>`). Re-implementing would orphan history. Confirm overwrite (rare) or pick another task."
- **Plan.md edited mid-implementation**: not detected automatically — surface periodically: "plan.md mtime is newer than session start; you may want to `/atomize` for reconciliation before continuing."
- **Acceptance criteria fail after commit**: do NOT amend. Open a follow-up task (`T-NNN-followup-<id>` with `depends_on: [<original-id>]`) and start it from Step 1.
- **Test runner is slow** (> 60s baseline): warn once; suggest watch mode (`vitest --watch`, `pytest --watch`, etc.) for inner loop, full suite only at Step 6.
- **Monorepo**: runner detection walks up from cwd, not repo root. If cwd is `apps/web/`, the closest `package.json` wins. Print resolved cwd for clarity.
- **Extensions dir absent or empty**: skip the opt-in gate silently — extensions are optional infrastructure, not a precondition.
- **`extensions.md` vs `/atomize`**: the per-initiative `extensions.md` is owned by this skill; it is NOT part of the task schema and `/atomize` ignores it on reconciliation.
- **Extension check vs Step 5 review**: they don't replace each other. The extension check (Step 6) is a deterministic rules gate against named criteria; Step 5's `security-reviewer` agent is an open-ended review. Enabling `security-baseline` does not make Step 5's security option redundant — but skipping Step 5 is more defensible when the baseline gate is on.

## Output summary at session end

When the user STOPs the skill (Step 8 or Step 9 close), print:

```
Initiative: docs/work/<NNN>-<slug>/
Session: <start time>–<end time>
Tasks completed: T-NNN, T-NNN
Tasks pending: T-NNN, T-NNN
Commits: <short SHA list>
Branch: <branch name>
Next: `gh pr create` / `/implement docs/work/<NNN>-<slug>/` to resume / `/atomize` to reconcile
```
