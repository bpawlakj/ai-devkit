# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
