---
name: repo-map
description: >
  Build an evidence-based map of an unfamiliar or large/legacy repository before
  you change it. Gathers cheap, deterministic CLI signals (git-history territory,
  a dependency graph, contributor history) OUTSIDE the model's context window, then
  has the agent interpret the evidence into one short, decision-oriented artifact —
  docs/architecture/repo-map.md (modules, entry points, dependency directions +
  cycles, coupling hotspots, sensitive areas / blast radius, who-to-ask, and
  explicit unknowns). Read-only: never modifies source. Detects the stack
  (JS/TS, Python) to pick the right dependency tool. Trigger phrases: "map this
  repo", "understand this codebase", "onboard me to this legacy project",
  "where is it risky to change", "/repo-map".
argument-hint: "[<subdir>] [--since <window>] [--out <path>] [--verify]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - Agent
  - Skill
---

# /repo-map — Wide-Scan a repo into an evidence-based project map

This skill is for the **brownfield** moment: you (or an agent) land in a large or
unfamiliar codebase and need to know *what's here, what's load-bearing, what's
active, and where a change is risky* — before touching anything. The naive move
("agent, read the whole repo and explain the architecture") fails twice: it
doesn't fit a context window, and "lots of context" is not "good understanding"
(you get a flat, priority-less summary).

The method is **Wide Scan**: run cheap, deterministic CLI tools to collect
*signals* (they reduce noise *outside* the context window), then ask the agent to
**interpret the evidence** — not to read everything. The deliverable is one short,
decision-oriented artifact, `docs/architecture/repo-map.md`.

> Inspired by the 2026 "Wide Scan" practice for AI-assisted legacy work; written
> fresh for ai-devkit. The companion "Deep Focus" (single-feature trace + test
> gaps + blast radius) is **out of v1** — see Notes.

Read `references/repo-map-schema.md` (the locked artifact shape) and
`references/signal-recipes.md` (the per-stack CLI commands) before writing the map.

## When to use, when to skip

**Use when**:
- You're onboarding to an existing/legacy repo and need a fast, honest mental model.
- You're about to refactor or add a feature and want the blast radius first.
- You want to decide where per-module `AGENTS.md` / ownership boundaries belong
  (feeds `/agents-md`).

**Skip when**:
- It's a small/greenfield project you already understand — a map is overhead.
- You need a *feature-level* deep dive (one data flow end-to-end) — that's Deep
  Focus, not v1 here; use `/research` or trace it manually.
- You want product scope/vision — that's `/discover` + `/product-spec`.

## Relationship to other skills & rules

- **`/setup`** — provides the `docs/architecture/` home the map is written to. If
  `docs/` is absent, this skill offers to delegate to `/setup` (Step 0).
- **`/implement`** — its `references/runner-detection.md` is the source of the
  stack-marker → tool mapping this skill reuses for dependency tooling.
- **`/research`** — downstream. The map's "sensitive areas / unknowns" are good
  inputs to a focused research pass; a repo-map often precedes `/research`.
- **`/agents-md`** — downstream. The map's module/ownership boundaries inform where
  a per-module `AGENTS.md` earns its place (don't split by folder count — split by
  ownership + real need).
- **`~/.claude/rules/` (read-only)** — `security.md` governs the analysis itself:
  this skill runs only **read-only** inspection commands and **never executes the
  target project's code**. Do not modify rules.

## Output language

The map and all comments are written in **English** (global policy,
`~/.claude/CLAUDE.md` §13). User-facing prompts may follow the user's language.

## Initial Response

1. **Args given** (`/repo-map src --since 18.months --verify`): capture; jump to Step 0.
2. **No args**: proceed to Step 0 and confirm scope interactively in Step 1.

## Process

### Step 0: Preconditions

```bash
git rev-parse --is-inside-work-tree 2>/dev/null   # must be a git repo (history = the signal)
ls docs/architecture/ 2>/dev/null                  # output home
```

- Not a git repo → much of the signal (territory, contributors) is unavailable;
  tell the user and STOP (or continue structure-only if they insist).
- `docs/` absent → offer to delegate to `/setup` via the `Skill` tool; continue on return.
- Detect the stack and its dependency-graph tool per `references/signal-recipes.md`.
  If the tool is missing, print the install hint and continue **without auto-installing**
  (mirrors `/e2e-run`); the structure signal degrades to import-grep, noted as a gap.

### Step 1: Scope (confirm before doing work)

Resolve and confirm: **target** (subdir or repo root), **history window**
(default 12 months), **output path** (default `docs/architecture/repo-map.md`).

AskUserQuestion:
- question: "Map <target> over <window> → <out>?"
  header: "Map scope"
  options:
  - label: "Yes (Recommended)"
    description: "Wide-scan <target> over the last <window>; write <out>."
  - label: "Change scope"
    description: "Adjust target subdir / history window / output path."
  - label: "Cancel"
    description: "Exit without analysis."
  multiSelect: false

### Step 2: Gather signals (3 read-only subagents, in parallel)

Spawn **one `Agent` per signal in a single message** (keeps bulky tool output out
of the main context — each returns structured findings only). Commands per
`references/signal-recipes.md`:

- **territory** — git-history: top-N most-changed dirs/files over the window
  (filter lockfiles / generated / snapshots), quarterly breakdown (permanent
  center vs change-campaign), co-change pairs (hidden coupling).
- **structure** — the stack's dependency grapher: entry points, layers, import
  direction, **cycles**, coupling metrics (afferent `Ca`, efferent `Ce`,
  `instability = Ce/(Ca+Ce)`). Output to markdown/JSON first, not images.
- **contributors** — git-history grouped by area, **bot/AI-agent commits filtered**
  → who carries knowledge of each area (who to ask before a change).

### Step 3: Synthesize — interpret evidence, don't dump it

Combine the three signal sets into the map per `references/repo-map-schema.md`.
**Every claim cites its evidence** (a commit, an import path, a `file:line`, a
co-change count). Record uncertainty explicitly as `unknown` / `needs
verification` — static signals can't see runtime coupling (DI, dynamic imports,
feature flags, codegen, webhooks).

If `--verify`: confirm the **load-bearing** structural claims (e.g. "only here",
"always via X", call-site counts) with `ast-grep`, and **confirm every ast-grep
zero with a plain `grep`** (a wrong pattern returns a misleading zero). Reserve
this for the few claims a decision will rest on — it's not a full pass.

### Step 4: Write the map

Write `repo-map.md` to the confirmed path. Collision handling (never clobber
silently): overwrite / write `-v2` sibling / skip. **Never modify source files** —
this skill only reads.

### Step 5: Hand off

```
═══════════════════════════════════════════════════════════
  REPO MAPPED
═══════════════════════════════════════════════════════════
  Target:    <subdir | repo root>   ·   window: <N months>
  Stack:     <js/ts | python | …>   ·   dep tool: <name | grep-fallback>
  Signals:   territory · structure · contributors
  Map:       docs/architecture/repo-map.md
  Unknowns:  <count> open (need verification)

  ► Next: feed the map into /research (a flagged risk), /implement (blast radius),
    or /agents-md (where a per-module AGENTS.md earns its place).
═══════════════════════════════════════════════════════════
```

STOP. Do not start refactoring or modify any source.

## Critical guardrails

1. **Read-only — never execute or modify the target code.** Only inspection
   commands (`git log`, dependency graphers in report mode, `rg`, `ast-grep`).
   The map is the sole written artifact.
2. **Evidence over guess.** "A label without evidence is a guess." Every
   classification (core / load-bearing / volatile / sensitive) cites its evidence;
   what you can't prove is an explicit `unknown`, never a confident assertion.
3. **Reduce noise, then interpret.** CLI tools run *outside* the context window and
   return condensed results; the agent interprets the smaller, better data — it
   does not "read the whole repo".
4. **Confirm scope before working.** Step 1 is a gate — no large analysis before
   the user confirms target / window / output.
5. **Never auto-install.** A missing dependency-graph tool → print the install
   hint and degrade gracefully (import-grep), noting the gap. Don't install.
6. **The map is short and decision-oriented.** Not an essay, not a chat dump — it
   answers "what's important, connected, active, and risky?", with unknowns named.

## Notes

- **Why three signals.** Territory (git) shows where work *actually* happens;
  structure (graph) shows how modules depend and where cycles/hubs are; contributors
  (git) shows who holds tacit knowledge. A folder tree answers "what's here?"; the
  map answers "what's important, connected, active, and risky?".
- **Deep Focus is v1-excluded.** Tracing one feature end-to-end (data flow + test
  gaps + blast radius → a research doc) is a separate, heavier mode — a future
  `/repo-map --deep` or a `/research` code-mode, to avoid overlap.
- **Extensibility.** v1 dependency tooling covers JS/TS + Python; a new stack is a
  recipe block in `references/signal-recipes.md` (grapher + flags + output format) —
  the Process is unchanged.
- **Output location.** Default `docs/architecture/repo-map.md` (living — refine as
  understanding grows). Point it elsewhere with `--out` if you prefer a point-in-time
  snapshot under `docs/analyzes/`.
