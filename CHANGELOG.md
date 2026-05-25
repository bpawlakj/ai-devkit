# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`docs/work/ROADMAP.md`** — auto-generated cross-initiative overview, categorised as Active / Backlog / Done / Obsoleted with task progress (`done/total`) and mtimes. Maintained by a new shell script `claude/scripts/regenerate-roadmap.sh` (installs to `~/.claude/scripts/`). Pure bash, no external deps, portable across macOS BSD and Linux GNU coreutils. Idempotent — safe to invoke from any skill.
- `/save-plan`, `/atomize`, `/implement`, `/kickoff` skills now call `regenerate-roadmap.sh` at the end of their write paths so the roadmap always reflects current state. `/kickoff` seeds an initial empty ROADMAP.md placeholder.
- **`/save-plan` detects roadmap-shape plans** (top-down sequencing with foundations + slices) and offers to land them at `docs/foundation/roadmap.md` instead of `docs/work/NNN-<slug>/plan.md`. Heuristic: top heading matches `# Roadmap`, OR body has `## Slices`, OR body has both `## Foundations` and a slice-equivalent heading. User confirms classification via AskUserQuestion — never auto-routes silently. Two ROADMAP files coexist by design: `docs/foundation/roadmap.md` (top-down planning artifact, edited in place) and `docs/work/ROADMAP.md` (bottom-up derived rollup). New reference doc `claude/skills/save-plan/references/roadmap-shape.md` covers the contract: when to use each shape, minimal 4-section template (`## Foundations / ## Slices / ## Open Questions / ## Done`), Foundation `Unlocks:` rule, vertical-first guidance, anti-patterns. Rationale: top-down roadmap planning was the missing link in `/product-spec → /save-plan → /atomize → /implement` — without it users ad-hoc decide "what first" with no artifact. Minimum viable addition; no new skill, no parallel sub-agent repo audit, no readiness gate — those are ceremony when the user can read their own PRD.

### Changed
- **`/save-plan` auto-picks the most recent plan from `~/.claude/plans/`** instead of prompting. Claude Code's `/plan` mode + `ExitPlanMode` persists approved plans there as Markdown — the newest file is almost always "the plan I just approved" (which is why the user invoked `/save-plan`). New priority order: inline file arg → `~/.claude/plans/` newest → conversation context → paste. Only asks for source selection in the rare ambiguity case (two plans mtimed within the same minute). `--paste` flag still overrides.
- **`setup.sh` is now the single entry point for both install and update.** Re-running `./setup.sh` fetches `origin/main`, prints the changelog diff, fast-forwards the clone (offering to stash local mods first), then runs the install. Two new flags inherited from the old `update.sh`: `--check` (show update status, do not install) and `--no-pull` (install from working copy as-is, skip the upstream fetch).
- README "Updating" section rewritten around `./setup.sh`; project-structure tree updated.

### Removed
- **`update.sh`** — folded into `setup.sh`. Anyone who scripted `./update.sh` should switch to `./setup.sh` (same flags: `--check`, `--claude`, `--copilot`, `--permissions`). Rationale: two entry points with overlapping logic was clutter — install and update are the same operation against a different starting state.

## [1.8.1] - 2026-05-24

### Changed
- **Replaced `/init-permissions` slash command (introduced in v1.8.0, never pushed to a release tag) with a shell script at `claude/scripts/init-project-permissions.sh`** — per-project `.claude/settings.json` is **environment configuration**: it has to exist on disk before the agent starts the session it controls. A slash command lives inside the agent's session, so writing the policy from there is chicken-and-egg (the agent writes its own pre-conditions). A shell script runs outside the agent — the file lands first, then you start Claude Code in that directory. Same artifact, correct lifecycle. The `/init-permissions` markdown file at `claude/commands/init-permissions.md` is removed
- Surface change: instead of typing `/init-permissions` inside Claude, run `./setup.sh --permissions` or `./update.sh --permissions` (or call the script directly: `bash ~/.claude/scripts/init-project-permissions.sh`)

## [1.8.0] - 2026-05-24

### Added
- **`claude/scripts/init-project-permissions.sh`** — writes a per-project `.claude/settings.json` with the M1L3 permission policy from 10xDevs 3.0. Polyglot allow list covers Node / Python / Go / Rust / Java / PHP / Swift / .NET / Ruby / Elixir tool families plus all local git operations and `Read`/`Edit`/`Write` primitives. Default `ask` list includes network egress (`curl`, `wget`), `git push`, plus Docker, SSH-SCP-rsync, cloud CLIs (aws, gcloud, az, kubectl, helm, terraform), and database CLIs (psql, mysql, redis-cli, mongosh). Deny list is unconditional: recursive force-delete. Flags: `--minimal` (base ask only), `--force` (no prompts), `--dry-run` (print only), `--yes` (auto-confirm), positional target dir or `--target DIR`. Backs up existing `.claude/settings.json` to `.bak-YYYYMMDD-HHMMSS` before overwrite. Offers to append `.claude/settings.local.json` to `.gitignore` when one exists. Bash-3.2 compatible (works on stock macOS bash without homebrew). Installed to `~/.claude/scripts/` by `setup.sh`
- **`setup.sh --permissions [DIR]`** — shortcut that exec's the script with forwarded flags. Run from anywhere; default target is the current working directory. Skips the whole installer flow when this flag is present
- **`update.sh --permissions [DIR]`** — same shortcut on the update side. No git pull, no reinstall — just refresh the project policy
- **Copilot CLI / Codex / Cursor docs** in `copilot/prompts/init-permissions.md` — documents how to apply the same policy on other harnesses (Codex `~/.codex/config.toml` with `sandbox = workspace-write` + `approvals = on-request`, Cursor `~/.cursor/permissions.json`, Copilot CLI per-repo `.github/hooks/pretool.sh`). Claude Code remains the canonical source of truth; other harnesses approximate

### Changed
- README Quick Start: added "Per-project permission policy" subsection right after Updating, documenting the `--permissions` flag on both `setup.sh` and `update.sh` with examples for `--minimal` / `--force` / `--dry-run` / `--yes` forwarding
- README Scripts table: 7 → 9 files (added `cloud-guard.sh` documentation row + new `init-project-permissions.sh`)
- README tree diagram: scripts count 7 → 9
- `setup.sh` summary line annotated for the init-permissions prompt as shell-script docs (not a slash command)

### Why this release exists
- Per-project permission policy was being copy-pasted by hand into every new repo discovered during the trainer-advisor cert project. M1L3 prescribes it as a foundational artifact (alongside scaffold + audit report), so it deserves first-class tooling. **The artifact is environment configuration — it must exist on disk before the agent starts the session it controls.** That makes a slash command the wrong abstraction (chicken-and-egg: the agent writing its own pre-conditions). A shell script invoked from `setup.sh --permissions` / `update.sh --permissions` is the right shape: the file lands before the agent ever reads it

## [1.7.0] - 2026-05-22

### Added
- **`/implement` skill** — execute one `T-NNN-*.md` task, an initiative folder (picks next unblocked pending task), or a standalone `plan.md` through three gates: pre-execution (clean tree, branch off main, dependency check via `depends_on:`, runner detection, baseline green) → in-execution (red/green/refactor or write-then-test, affected-only test selectors, scope-respecting edits) → post-execution (full suite, one commit per task with deterministic message template, frontmatter writeback `status: done` + `commit:` + `completed:`). Closes the loop with `/atomize` reconciliation. Multi-language runner auto-detection from `package.json` / `pyproject.toml` / `go.mod` / `pom.xml` / `build.gradle*` / `Cargo.toml` / `composer.json` / `Package.swift` / `mix.exs` / `Gemfile` / `.csproj`. Optional `security-reviewer` + `performance-analyzer` Agent invocation before commit. Lesson capture on abandon (append to `docs/reference/lessons.md`). Never `git add -A`, never pushes
- `claude/skills/implement/references/runner-detection.md` — canonical detection matrix per ecosystem + affected-only selectors + override flow
- `claude/skills/implement/references/commit-policy.md` — staging rules (never `-A`/`.`), message template, amend policy, hook handling, branch policy, push policy
- **`/agents-md` skill** — author `AGENTS.md` as the canonical project-rules file with a thin `CLAUDE.md` import shim (`@AGENTS.md`) and an optional `.github/copilot-instructions.md` shim. Anti-duplication: inventories `~/.claude/rules/*.md` and refuses to propose rules already auto-active there. Test-of-inclusion gate enforced up front — every candidate rule must answer "could the agent know this without this file?" with a documented "no" plus an anchor citation (`docs/product-spec.md` § …, `docs/architecture/*.md` decision, `docs/reference/lessons.md` entry, incident reference). U-shaped attention layout (Critical → Conventions → Workflow → References → Out-of-scope). Size budget: ≤150 OK, 151–200 WARN, 201–250 split, >250 strong split push. Scope-aware: can target root `AGENTS.md` or area-specific `<area>/AGENTS.md`
- `claude/skills/agents-md/references/test-of-inclusion.md` — decision matrix with worked examples for "drop" vs "keep" rules
- **`/rule-review` skill** — audit a rules file (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*.mdc`, `.github/copilot-instructions.md`, `.github/instructions/*.md`) across **7 dimensions**: (1) length vs ~200-line ceiling, (2) embedded code/config blocks, (3) language precision via regex on weak verbs / empty intent, (4) redundancy vs `~/.claude/rules/` auto-active layer with cited overlap, (5) order (critical rules in top third via U-shaped attention), **(6) cross-tool drift** when AGENTS.md / CLAUDE.md / copilot-instructions co-exist (side-by-side diffs of divergent rules), **(7) dead rules** via codebase grep for the patterns each rule targets (absent → WARN, forbidden + still present → FAIL with violating files). Read-only by default; `--fix` applies safe rewrites only (redundancy removal, section reorder, dead-rule marking) with backup to `<path>.bak-YYYYMMDD-HHMMSS`
- `claude/skills/rule-review/references/dimensions.md` — canonical thresholds, triggers, and verdicts per dimension
- Copilot CLI parity prompts in `copilot/prompts/implement.md`, `agents-md.md`, `rule-review.md`
- Closed-loop integration: `/atomize` writes T-*.md → `/implement` reads + writes back frontmatter → `/atomize` reconciliation reads the same fields. No manual frontmatter edits needed for the happy path

### Changed
- README sections rewritten to reflect the four-workflow model (discover → research → plan → execute/audit) with cycle-position table covering all 9 skills
- `setup.sh` summary: 9 skills, 13 prompt templates (was 6 / 10)
- `uninstall.sh` skill removal list extended to include `/implement`, `/agents-md`, `/rule-review`

### Why this release exists
- Designed against 10xDevs 3.0 Module 1 (`/10x-agents-md`, `/10x-rule-review`) and Module 2 (`/10x-implement`) skills, but intentionally NOT clones. Key value-adds: (a) frontmatter writeback closes `/atomize` ↔ `/implement` loop without manual edits, (b) multi-language test runner detection across 11 ecosystems instead of JS/TS-first, (c) anti-duplication against ai-devkit's auto-active `~/.claude/rules/` layer, (d) 7 audit dimensions vs 5 — adds cross-tool drift and dead-rule grep, (e) evidence-cited findings (line numbers, file paths, grep results) instead of opinions, (f) `--fix` safe-rewrite mode with backup

## [1.6.0] - 2026-05-20

### Added
- **`/save-plan` skill** — bridges Claude Code's built-in `/plan` mode (which only displays a plan) to the `docs/work/` convention (where plans need to live as files). Captures plan from one of three sources in priority order (inline file arg → most recent plan in conversation context → user paste), derives slug from first heading (first 5 meaningful words, kebab-case), computes next NNN by scanning `docs/work/`, writes `plan.md` verbatim, then offers to chain into `/atomize`
- Plan content is sacred — written to disk verbatim, never reformatted or "improved". Only mechanical change: prepend `# <Title>` heading derived from slug if plan starts headingless
- Collision handling: pick different slug (recommended) / overwrite / save as `plan-v2.md` sibling / cancel
- Auto-chain to `/atomize` opt-in via AskUserQuestion (default Yes) — decomposes the just-saved plan into T-NNN tasks in one flow
- Copilot CLI version in `copilot/prompts/save-plan.md`

### Changed
- Workflow now has explicit bridge from `/plan` mode → `docs/work/` → `/atomize` without manual `mkdir` + paste. Full chain: Claude `/plan` → user approves → `/save-plan` (captures from context) → `/atomize` (auto-chained) = tracked initiative with tasks in 3 commands
- Setup summary: 6 skills, 10 prompt templates

## [1.5.0] - 2026-05-20

### Added
- **`/research` skill** — per-decision research: produces a single point-in-time artifact at `docs/analyzes/<slug>.md` capturing context, findings, alternatives, anti-bias cross-check, and decision for a specific technical question (vendor selection, library comparison, technology evaluation, integration investigation). Distinct from `/discover` (product-level) — `/research` is the per-decision research that accretes throughout a project's lifetime
- Three classification types: `decision` (pick between alternatives), `technology-evaluation` (assess single option), `investigation` (understand existing mechanic)
- Three execution modes: **interview** (user provides facts, skill structures), **investigation** (skill spawns 2-4 parallel research subagents — official docs / third-party comparisons / code context / pricing), **mixed** (interview first, investigate gaps)
- Heuristic context gathering from `docs/reference/` via slug-overlap matching; user confirms which files to read as context
- Mandatory anti-bias cross-check (devil's advocate + pre-mortem) on the leading conclusion before write — user can loop back to revisit findings or switch to alternative
- Collision handling for existing research docs: read existing first / write follow-up (`<slug>-followup.md` with `Supersedes:` link) / overwrite / cancel
- Copilot CLI version in `copilot/prompts/research.md`

### Changed
- Setup summary string updated to list 5 skills; prompts string updated to list 9 templates

## [1.4.0] - 2026-05-20

### Added
- **Brownfield onboarding in `/kickoff`** — Step 7 detects brownfield (git history + lockfiles), and if `CLAUDE.md` is absent, offers to invoke Claude Code's built-in `/init` via the Skill tool. Greenfield projects and projects with existing `CLAUDE.md` skip silently. Scaffolding (Steps 1-6) remains independent and idempotent regardless of Step 7 outcome
- Copilot CLI version of brownfield detection in `copilot/prompts/kickoff.md` — suggests generating `.github/copilot-instructions.md` instead (Copilot has no built-in /init equivalent)
- **`/atomize` skill** — decomposes `plan.md` into atomic `T-NNN-<slug>.md` task files inside `docs/work/<NNN>-<slug>/` initiative folders. Auto-detects mode: INITIAL (no T-*.md present — propose tasks, write files + initial index.md) or RECONCILIATION (T-*.md exist — diff plan against tasks, verify status:done claims via git log + file presence + user assertion, propose new/revised/obsoleted tasks)
- `claude/skills/atomize/references/task-schema.md` — canonical schema for T-*.md frontmatter + derived index.md format
- Reconciliation engine with hard rules: never edit `done` tasks (changes → new follow-up with `depends_on: [<original>]`), never delete task files (obsoletion = status flip), index.md is DERIVED view regenerated from frontmatter (with append-only `## Verification log`), preserve user-added body content
- 3-layer status:done verification: git log search (commit SHA + task ID + scope files), file presence check (file paths extracted from `## Scope`), user assertion fallback
- Copilot CLI prompt — `copilot/prompts/atomize.md` for parity

### Changed
- **Workspace structure overhauled** — `/kickoff` now scaffolds `docs/{architecture,analyzes,reference,work}/` instead of `context/{changes,archive,foundation}/`. Inspired by mature engineering projects (kukuvaia-style): docs accreted by *type* (architecture, research, reference, work) rather than by *change-id*. Includes folder-per-initiative pattern under `docs/work/NNN-<slug>/` for plan + tasks.
- `/discover` output path: `context/foundation/discover-notes.md` → `docs/discover-notes.md`
- `/product-spec` output path: `context/foundation/product-spec.md` → `docs/product-spec.md`. Versioned saves: `docs/product-spec-vN.md`
- `product-spec-schema.md` path references updated
- README, setup.sh summary, uninstall.sh updated for the new structure and `/atomize` skill

## [1.3.0] - 2026-05-19

### Added
- **Product discovery skills** — three new Claude Code skills that turn an idea into a structured product spec, adapted from the 10xDevs workflow
- `/kickoff` — scaffolds the `/context` directory skeleton (`changes/`, `archive/`, `foundation/`) with canonical READMEs. Idempotent; never overwrites
- `/discover` — facilitates a structured discovery conversation (6 phases: Vision, Access, MVP, FRs, Business Logic, Framing). Auto-detects greenfield vs brownfield from cwd. Produces `context/foundation/discover-notes.md`. Includes empty-CRUD anti-pattern detection, MVP-too-big scope-cost surfacing, Socratic challenge round per FR, soft-gate quality cross-check, and resume-from-checkpoint
- `/product-spec` — generates `context/foundation/product-spec.md` from discover-notes (or raw notes) against a locked schema. 10 sections for greenfield, 11 for brownfield. Includes thin-input heuristic, technical-leak content lint (7 categories: vendors, schema notation, runtime, mechanism, UI, transport, impl verbs), and versioned-save collision handling
- `claude/skills/discover/references/product-spec-schema.md` — canonical schema for both skills (frontmatter keys, section order, discover-notes checkpoint format)
- Copilot CLI parity — `copilot/prompts/kickoff.md`, `discover.md`, `product-spec.md` for users on Copilot
- `setup.sh` now installs `claude/skills/*` (subfolders with `references/`) into `~/.claude/skills/`
- `uninstall.sh` removes the three skills

### Changed
- Setup summary shows skills count alongside rules/commands/agents

## [1.2.0] - 2026-04-06

### Added
- **Go language support** — rule (`go.md`), 3 slash commands (`/go-build`, `/go-review`, `/go-test`), 2 agents (`go-build-resolver`, `go-reviewer`), Copilot instruction, goimports/gofmt auto-format hook
- **PHP language support** — rule (`php.md`), Copilot instruction, Pint/PHP-CS-Fixer auto-format hook
- Go rule enforces: gofmt/goimports, error wrapping (`%w`), functional options, table-driven tests, race detection, `context.Context` propagation, goroutine safety, gosec
- PHP rule enforces: PSR-12, `strict_types`, typed properties, immutable DTOs, PHPUnit/Pest, prepared statements, CSRF, `composer audit`
- `/go-build` command — incremental build error resolution via go-build-resolver agent
- `/go-review` command — comprehensive Go code review (security, concurrency, idioms) via go-reviewer agent
- `/go-test` command — TDD workflow with table-driven tests, race detection, 80%+ coverage
- PostToolUse hook for Go: auto-format with goimports (fallback to gofmt)
- PostToolUse hook for PHP: auto-format with Pint (fallback to PHP-CS-Fixer)
- Go and PHP sections added to build-resolver agent
- Tool checks for `gofmt`, `goimports`, `php-cs-fixer` in setup.sh

### Changed
- Total rules: 9 → 11
- Total commands: 7 → 10
- Total agents: 3 → 5
- Total hooks: 6 → 8
- Copilot instructions: 9 → 11
- `install-to-repo.sh` now supports `go` and `php` language flags

## [1.1.0] - 2026-04-01

### Added
- **Hook-driven cloud dashboards** — `/aws` and `/k8s` now use `UserPromptSubmit` hook to inject deterministic bash output before Claude processes the command, solving non-deterministic prompt rendering
- `prompt-hook.sh` — detects `/aws`, `/k8s`, `/cloud-setup` slash commands and runs corresponding dashboard scripts
- `aws-dashboard.sh` — reads `cloud-config.json`, renders environment list, MFA status, and 18-operation numbered menu
- `k8s-dashboard.sh` — same for Kubernetes environments with cluster info and namespaces
- `cloud-discover.sh` — discovers AWS profiles from `~/.aws/config`, outputs JSON with auto-detected project/env/access
- `cloud-setup.sh` — standalone interactive terminal wizard for creating `cloud-config.json` (usable outside Claude Code)
- **MFA status in dashboards** — shows `✔ active (Xm remaining)` or `✖ expired` with automatic prompt for 6-digit token
- **Environment connect flow** — selecting an environment immediately assumes role and verifies identity instead of asking what to do
- Copilot CLI agents: `@aws` and `@k8s` — same functionality as Claude Code commands but agent-based (no hook support in Copilot)

### Changed
- `/aws` command rewritten — minimal prompt that references hook-injected dashboard context
- `/k8s` command rewritten — same approach as `/aws`
- `/cloud-setup` command rewritten — hybrid approach: deterministic discovery via hook, conversational annotation via Claude
- `settings.template.json` — added `UserPromptSubmit` hook for cloud dashboard injection
- README fully updated with cloud command examples (Claude Code + Copilot CLI), MFA flow, scripts table, hook architecture

### Architecture
- Cloud commands now follow a **hook + script + prompt** pattern: deterministic bash scripts handle data/formatting, hooks inject output as context, prompts handle only user interaction
- This replaces the previous prompt-only approach where Claude would ignore formatting instructions

## [1.0.1] - 2026-04-01

### Added
- `/cloud-setup` command — interactive wizard for AWS and Kubernetes access configuration
- `/aws` command — natural language AWS CLI with profile selection and MFA handling
- `/k8s` command — natural language kubectl/helm with EKS auth chain
- Cloud wrapper scripts (`awscmd.sh`, `kubecmd.sh`) installed to `~/.claude/scripts/`
- `update.sh` — check for and install newer versions
- `release.sh` — automated release flow (version bump, changelog, tag, GitHub Release)
- Version display in setup.sh header and summary
- Auto-update check in setup.sh (non-blocking remote version comparison)
- Scripts section in setup summary output

### Changed
- setup.sh installs cloud scripts and checks for `cloud-config.json`
- setup.sh checks for `aws`, `kubectl`, `helm` in optional dependencies
- README updated with cloud commands docs, update instructions, and revised project tree

## [1.0.0] - 2026-04-01

### Added
- 9 coding standard rules: security, java, spring-boot, python, typescript, react, angular, node, swift-ios
- 4 slash commands: /ship, /retro, /changelog, /threat-model
- 3 specialized agents: security-reviewer, build-resolver, performance-analyzer
- 5 auto-formatting and safety hooks (ruff, google-java-format, swiftformat, prettier, safety guard)
- Maister plugin integration for Claude Code
- Unified setup.sh and uninstall.sh with --claude / --copilot / --all flags
- Smart JSON config merging with jq (preserves existing user settings)
- Copilot CLI per-repo installation via install-to-repo.sh
- Automatic backup of existing configs before overwriting
