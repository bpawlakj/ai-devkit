---
name: atomize
description: >
  Decompose a plan.md into atomic task files (T-NNN-<slug>.md) inside an
  initiative folder under docs/work/. Auto-detects mode: INITIAL (no T-*.md
  present — propose tasks from plan, write T-*.md + index.md) or RECONCILIATION
  (T-*.md exist — diff plan against current tasks, propose new/revised/obsoleted
  tasks; verify status:done claims against git log + file existence; never edit
  already-done tasks — write follow-up tasks instead).
  Trigger phrases: "atomize the plan", "decompose into tasks", "break down the
  plan", "create tasks from plan", "reconcile tasks", "the plan changed",
  "what tasks need updating".
argument-hint: "<path-to-initiative-folder-or-plan.md>"
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
---

# /atomize — Plan → Tasks Decomposition + Reconciliation

This skill turns a `plan.md` (typically the output of Claude Code's `/plan` mode, manually copied into an initiative folder) into atomic, status-tracked task files. It auto-detects whether this is the initial decomposition or a re-run after the plan changed.

The contract for task and index file shapes lives at `references/task-schema.md` (relative to this SKILL.md). Read it before producing any artifact and re-check against it at every write.

## Two modes, one skill

| Mode | Trigger | Behavior |
|---|---|---|
| **Initial atomization** | No `T-*.md` files in target folder | Read `plan.md`, propose T-001 ... T-NNN, user confirms per task, write T-*.md + initial `index.md`. |
| **Reconciliation** | `T-*.md` files already exist | Read plan + all T-*.md + `index.md`. Verify `status: done` claims (git log + file presence + ask). Diff plan ↔ tasks. Propose changes: new T-*.md for new requirements, mark obsolete for removed, follow-up tasks for changes to already-done work. |

## When to use, when to skip

**Use when**: you have a `plan.md` in `docs/work/<NNN>-<slug>/` that needs to be decomposed; OR the plan changed and you want to reconcile existing tasks against it; OR you want to verify whether `status: done` claims actually match the code.

**Skip when**: you have raw notes, not a plan (use Claude Code's `/plan` first, copy approved output into `docs/work/<NNN>-<slug>/plan.md`); OR you just want to see status (read `index.md` directly).

## Relationship to other skills

- `/kickoff` — scaffolds `docs/work/`. `/atomize` requires the folder structure exists; if missing, delegates to `/kickoff` via the `Skill` tool.
- Claude Code's built-in `/plan` mode — upstream of `/atomize`. User runs `/plan`, approves output, manually copies plan content into `docs/work/<NNN>-<slug>/plan.md`, then invokes `/atomize`.

## Initial Response

When this skill is invoked:

1. **If a folder path was provided** (e.g. `/atomize docs/work/004-observability-otel/`), use that as the target. Proceed to Step 1.
2. **If a plan.md path was provided** (e.g. `/atomize docs/work/004-observability-otel/plan.md`), use its parent dir as target. Proceed to Step 1.
3. **If nothing was provided**, scan `docs/work/` for folders containing `plan.md`. If exactly one is missing `T-*.md` files, propose it as the target. Otherwise ask:

```
Which initiative do you want to atomize? Available folders in docs/work/:

  - 001-foo               [T-*: 3 files, 2 done, 1 pending]    → reconciliation
  - 002-bar               [no T-*]                              → initial
  - 003-baz               [T-*: 5 files, all done]              → reconciliation

Pass the folder path: /atomize docs/work/<NNN>-<slug>/
```

Then STOP.

## Process

### Step 0: Verify target structure

```bash
test -d "<target-folder>" && test -f "<target-folder>/plan.md"
```

If folder is missing: ask whether to run `/kickoff` first (then re-invoke). If `plan.md` is missing: tell the user to copy the `/plan` output into `<target-folder>/plan.md` and re-invoke. STOP either way.

If the folder exists but isn't under `docs/work/`, warn but allow (user may have a custom location). Print: "Target folder is outside docs/work/ — proceeding, but this isn't the conventional location."

### Step 0.5: Detect mode

```bash
ls "<target-folder>"/T-*.md 2>/dev/null | head -1
```

- **No matches** → INITIAL mode. Proceed to Step 1.
- **At least one match** → RECONCILIATION mode. Proceed to Step 10.

Announce the detected mode:

```
Mode: INITIAL atomization (no T-*.md found)
or
Mode: RECONCILIATION (found N T-*.md files)
```

---

## INITIAL mode

### Step 1: Read the plan

Read `<target-folder>/plan.md` FULLY (no `limit`/`offset`). Extract:

- Top-level heading (used as initiative title in `index.md`)
- Section structure (`##` headings — often map to logical task boundaries)
- Any explicit "task list" / "implementation steps" / "scope" enumeration
- Any explicit dependency hints ("after X is done, do Y")

### Step 2: Propose task decomposition

Based on the plan structure, propose a list of atomic tasks. Each should be:

- **Atomic** — one PR's worth of work, single coherent change
- **Verifiable** — has clear "done" criteria
- **Independently mergeable** where possible — minimize forced dependencies

Print the proposed list:

```
Proposed task decomposition (N tasks):

  T-001  Add OTel SDK dependencies
         Scope: pom.xml + Spring AutoConfig wiring
         Depends on: (none)
         Blocks: T-002, T-003

  T-002  Wire tracing config to ChatClient
         Scope: TracingAdvisor, MDC propagation
         Depends on: T-001
         Blocks: T-004

  T-003  Bridge Micrometer to OTel
         Scope: MeterRegistry config, custom timers
         Depends on: T-001
         Blocks: T-004

  T-004  Wire to dashboard (Grafana)
         Scope: docker-compose addition, dashboard JSON
         Depends on: T-002, T-003
         Blocks: (none)
```

Then ask, per task, with AskUserQuestion:

```
T-001: Add OTel SDK dependencies. Confirm?
- Confirm (Recommended)              — write as proposed
- Edit                               — I'll re-prompt for title/scope/deps
- Merge into next task               — fold into T-002 (combines if too granular)
- Skip                               — drop this task entirely
```

After all confirms, summarize the final list and ask one global confirm before writing.

### Step 3: Write task files

For each confirmed task, write `<target-folder>/T-NNN-<slug>.md` with:

**Frontmatter** (per `references/task-schema.md`):

```yaml
---
id: T-NNN
title: <title>
status: pending
plan: ../plan.md
created: <today YYYY-MM-DD>
completed: null
commit: null
depends_on: [<list>]
blocks: [<list>]
plan_anchor: <heading slug or null>
---
```

**Body** with sections `## Scope`, `## Approach`, `## Acceptance`. Populate from the plan content where possible; leave skeleton placeholders otherwise (user fills in during implementation).

### Step 4: Write initial `index.md`

Generate `<target-folder>/index.md` per the schema reference. All tasks land in the `## Pending` table with their `depends_on`. Empty `## Done`, `## In flight`, `## Obsoleted` sections still present (preserves shape).

Add a `## Verification log` entry recording the initial creation date.

### Step 4.5: Regenerate docs/work/ROADMAP.md

Tasks just landed in this initiative — refresh the cross-initiative roadmap:

```bash
bash ~/.claude/scripts/regenerate-roadmap.sh
```

The script reads every `docs/work/<NNN>-<slug>/` and rewrites `docs/work/ROADMAP.md` with categorised tables (Active / Backlog / Done / Obsoleted). After this initial atomization the initiative typically stays in Backlog (all tasks `pending`) — it will move to Active when `/implement` flips the first task to `in-progress` or `done`.

If `~/.claude/scripts/regenerate-roadmap.sh` is missing, print a soft warning and continue — the roadmap is a derived artifact, not a hard dependency.

### Step 5: Hand off

Print summary:

```
═══════════════════════════════════════════════════════════
  ATOMIZATION COMPLETE — INITIAL
═══════════════════════════════════════════════════════════

  Initiative:       <slug from folder>
  Plan:             <target-folder>/plan.md
  Tasks created:    N
  All pending; none in flight or done yet.

  ► Index:  <target-folder>/index.md
  ► Tasks:  <target-folder>/T-001-*.md ... T-NNN-*.md

  Next:
    - Pick a task with no unmet deps (depends_on resolved)
    - Update status to in-progress when you start
    - Update status to done + commit SHA when finished
    - Re-run /atomize <target-folder> when plan changes
═══════════════════════════════════════════════════════════
```

STOP.

---

## RECONCILIATION mode

### Step 10: Inventory current state

Read:

1. `<target-folder>/plan.md` (current plan)
2. All `<target-folder>/T-*.md` files (current tasks with frontmatter)
3. `<target-folder>/index.md` if present (last known derived view)

Build an in-memory map: `{ T-NNN → { title, status, depends_on, blocks, commit, completed } }`.

### Step 11: Verify status:done claims (3-layer heuristic)

For each task with `status: done`, run verification:

**Layer 1 — Git log check**:

```bash
# If task has commit SHA in frontmatter:
git cat-file -e <sha>^{commit} 2>/dev/null && echo "commit exists"

# Always: search for task ID mentions in commit messages
git log --all --oneline --grep "T-NNN" -- 2>/dev/null

# And: log of files mentioned in ## Scope (extract file paths via regex)
git log --all --oneline -- <extracted-file-1> <extracted-file-2> 2>/dev/null
```

**Layer 2 — File presence check**:

Extract file paths from the task's `## Scope` section (heuristic: lines with `/` or recognizable extensions like `.java`, `.py`, `.yml`). For each, `test -f "<path>"`. Missing files → flag as unverified.

**Layer 3 — User assertion (if Layers 1+2 ambiguous)**:

If git log has no matching commit AND file presence is mixed/missing, ask:

```
T-NNN ('<title>') claims status: done but I can't auto-verify:
  - No commit matched in git log
  - X of Y scope files exist; Z are missing

Confirm completion?
- Yes, it's done (auto-verified failure is OK — keep status)
- Revert to in-progress (it's not really done)
- Mark obsolete (it was done but is no longer relevant)
```

Record each verification result in memory; will be written to `index.md`'s `## Verification log` at the end.

### Step 12: Diff plan ↔ tasks

Compare the current plan against the existing task set. Classify each finding into one of four categories:

**A. New requirement in plan** — plan has a discrete piece of work not covered by any existing T-*.md.
- Action: propose new T-NNN with `status: pending`.
- **Special case**: if the new requirement modifies behavior of an already-DONE task, frame it explicitly as a follow-up: `T-NNN-<slug>` body opens with `Follow-up to T-MMM. Plan revision requires modifying the existing implementation.` Include `depends_on: [T-MMM]` even though MMM is already done — preserves traceability.

**B. Requirement removed from plan** — plan no longer mentions work that an existing T-*.md covers.
- Action: propose flipping that task's `status` to `obsolete`.
- **Never delete the file** — preserves history and traceability.
- Add a body note: `## Obsoleted on <YYYY-MM-DD>: removed from plan. <reason if known>`

**C. Requirement changed in plan** — plan still has the work, but scope/approach/acceptance differs from the corresponding T-*.md.
- **If task is `pending` or `in-progress`**: propose editing the task in place (update scope/approach body sections; keep frontmatter except `title` if necessary).
- **If task is `done`**: NEVER edit in place. Propose a NEW follow-up task (see category A special case). The original `done` task stays as historical record of what was actually shipped.

**D. No change** — plan requirement matches an existing task. No action.

### Step 13: Present diff for user confirm

Print the proposed changes grouped by category:

```
═══════════════════════════════════════════════════════════
  RECONCILIATION DIFF
═══════════════════════════════════════════════════════════

  Verification of status:done claims (N tasks):
    ✓ T-001 — verified via commit abc1234 + file presence
    ✓ T-002 — verified via commit def5678 + file presence
    ⚠ T-003 — user-confirmed (auto-verification ambiguous)

  Proposed changes:

  [A] New tasks (N):
    + T-005  Add OTel exporter for AWS X-Ray
              (new requirement: plan section "Cloud export")
              depends_on: T-001 (done)
    + T-006  Follow-up to T-002: switch from MDC to W3C TraceContext
              (plan revision: trace propagation now W3C-spec-compliant)
              depends_on: T-002 (done) — preserves traceability

  [B] Obsoleted (N):
    ~ T-004  Wire to Prometheus dashboard
              (removed from plan: "switching to Grafana via OTel-native")
              status: pending → obsolete

  [C] Edit-in-place (N):
    Δ T-003  Bridge Micrometer to OTel
              (scope expanded: now includes histogram buckets config)
              status: pending — body ## Scope updated

  [D] No change (N):
    = T-001, T-002

═══════════════════════════════════════════════════════════
```

Ask:

AskUserQuestion:
- question: "Apply all proposed changes?"
  header: "Apply diff?"
  options:
  - label: "Apply all (Recommended)"
    description: "Write all changes shown above. Index.md regenerated."
  - label: "Per-change confirm"
    description: "Walk through each change individually for approval."
  - label: "Cancel"
    description: "Exit without writes. The plan changes will not be reflected in tasks."
  multiSelect: false

On "Per-change confirm": iterate each change with its own AskUserQuestion (confirm / edit / skip).

On "Cancel": STOP.

### Step 14: Apply changes

For each approved change:

- **Category A**: write new `T-NNN-<slug>.md` with `status: pending` (or `obsolete` if user marked it so during confirm). For follow-ups to done work, body opens with the `Follow-up to T-MMM.` framing.
- **Category B**: edit existing `T-*.md` — flip `status` to `obsolete`, append `## Obsoleted on <YYYY-MM-DD>` body section with reason.
- **Category C**: edit existing `T-*.md` — update `## Scope` / `## Approach` / `## Acceptance` body sections per the plan change. **Preserve user-added sections and comments.** Touch frontmatter only if `title` changed.

Pick task IDs for new tasks by scanning for the highest existing `T-NNN`, incrementing.

### Step 15: Regenerate `index.md`

Rebuild `index.md` FROM SCRATCH based on the now-current T-*.md frontmatter. Sections: Done, In flight, Pending, Obsoleted (each populated from frontmatter `status`).

Append a new `## Verification log` entry recording this reconciliation run:

```
### Reconciliation YYYY-MM-DD HH:MM
- T-001 status=done — verified via commit abc1234 + file presence ✓
- T-002 status=done — verified via commit def5678 + file presence ✓
- T-003 status=done — user-confirmed (auto-verification ambiguous) ⚠
- Plan diff: +2 new, ~1 obsoleted, Δ1 edit-in-place
```

Preserve prior `## Verification log` entries — this is an append-only audit trail.

### Step 15.5: Regenerate docs/work/ROADMAP.md

Statuses changed (new tasks, obsoletes, follow-ups) — refresh the cross-initiative roadmap:

```bash
bash ~/.claude/scripts/regenerate-roadmap.sh
```

Same idempotent regeneration as Step 4.5 — rewrites `docs/work/ROADMAP.md` from current `plan.md` + `T-*.md` frontmatter across all folders. Newly-obsoleted initiatives may flip to the Obsoleted section; reconciled initiatives may move between Active / Backlog / Done based on the new task mix.

### Step 16: Hand off

Print summary:

```
═══════════════════════════════════════════════════════════
  RECONCILIATION COMPLETE
═══════════════════════════════════════════════════════════

  Initiative:       <slug>
  Tasks before:     N (M done, P pending, Q in-progress)
  Tasks after:      N' (M' done, P' pending, Q' in-progress, R obsoleted)

  Changes applied:
    + N new (incl. K follow-ups to done work)
    ~ M obsoleted
    Δ P edited in place
    ✓ Q done verified
    ⚠ R done user-confirmed (auto-verification ambiguous)

  ► Index:  <target-folder>/index.md (regenerated)

  Next:
    - Pick a new pending task with resolved deps
    - Investigate ⚠ tasks if auto-verification was unexpected
    - Re-run /atomize when plan changes again
═══════════════════════════════════════════════════════════
```

STOP.

---

## Critical guardrails

1. **Never edit `done` tasks.** Once a task is marked `done`, its content is a historical record of what was actually shipped. Changes to that scope = NEW follow-up task with `depends_on: [<original>]`. This rule preserves traceability between plan revisions and implementation reality.

2. **Never delete task files.** Obsoletion is a status flip, not a deletion. Preserves history. If a task was a mistake from the start, the body can record that — but the file stays.

3. **Verification is layered, not absolute.** Git log + file presence + user assertion. None alone is sufficient; together they cover most cases. When all three are ambiguous, default to trusting the user's `status` field — the human is the authority.

4. **Index.md is derived, not source.** T-*.md frontmatter is the truth. `/atomize` regenerates `index.md` from scratch on every run (preserving only the append-only `## Verification log`). Manual edits to index.md will be overwritten — this is intentional.

5. **Preserve user-added content.** Reconciliation edits ONLY schema-controlled fields and the standard body sections (`## Scope`, `## Approach`, `## Acceptance`, `## Obsoleted on ...`). Any custom sections, comments, debug notes the user added to a task body MUST survive a reconciliation pass.

6. **Plan is the master.** When in doubt about what work needs doing, the plan wins over tasks. Reconciliation aligns tasks TO the plan, not the other way around. (User edits to the plan are intentional; tasks are derived artifacts.)

7. **Schema is the contract.** `references/task-schema.md` defines frontmatter keys and section names. Re-check at every write. If the schema changes mid-implementation, update this skill body to match.

## Notes

- This skill is intentionally **reconciliation-heavy** because the most common real-world pattern is "plan changed; what do I do about the tasks?". Initial decomposition is the easier path; the value lives in the reconciliation logic.
- The verification heuristic intentionally fails open (defaults to trusting `status: done`). Auto-verification is best-effort — we'd rather flag suspicions than overwrite correct human judgment.
- Folder discovery in Step 0 deliberately avoids globbing across the whole repo. The convention is `docs/work/<NNN>-<slug>/` — if the user has tasks elsewhere, they need to pass the path explicitly.
- `/atomize` does not push tasks to external trackers (Linear, Jira, GitHub Issues). It's a local-Markdown tracking system. Bridging to external trackers is out of scope.
