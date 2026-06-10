# ai-devkit

Portable configuration for **Claude Code** and **GitHub Copilot CLI**. One repo, one script — sets up rules, commands, agents, hooks, and plugins on any machine.

## Quick Start

```bash
git clone <this-repo> ~/ai-devkit
cd ~/ai-devkit

# Install everything (Claude Code + Copilot CLI)
./setup.sh

# Or pick one
./setup.sh --claude
./setup.sh --copilot
```

Restart your tool after running.

### Updating

`setup.sh` is the single entry point for both install and upgrades. Re-running it fetches `origin/main`, shows the changelog diff, fast-forwards your clone (after offering to stash local mods), then re-installs:

```bash
cd ~/ai-devkit
./setup.sh
```

Options:
```bash
./setup.sh --check     # Show update status (version / changelog diff), don't install
./setup.sh --no-pull   # Install from working copy as-is, skip the upstream fetch
./setup.sh --claude    # Install/update Claude Code config only
./setup.sh --copilot   # Install/update Copilot CLI config only
```

### Per-project permission policy (`--permissions`)

Drop a canonical `.claude/settings.json` into any project so Claude Code stops asking about every routine command but never gets a blanket waiver on dangerous ones.

```bash
# From inside your project:
~/ai-devkit/setup.sh --permissions

# Or point at a specific dir:
~/ai-devkit/setup.sh --permissions /path/to/project

# Forward flags to the underlying script:
~/ai-devkit/setup.sh --permissions --minimal     # base only (no docker/ssh/cloud/db extras in ask)
~/ai-devkit/setup.sh --permissions --force       # overwrite without prompting
~/ai-devkit/setup.sh --permissions --dry-run     # print policy, do not write
~/ai-devkit/setup.sh --permissions --yes         # answer yes to all prompts
```

Calling `setup.sh` with `--permissions` shortcuts straight into `claude/scripts/init-project-permissions.sh` (also installed to `~/.claude/scripts/` so you can call it directly: `bash ~/.claude/scripts/init-project-permissions.sh`).

Policy follows M1L3 of 10xDevs 3.0 ("AI-Powered Bootstrap"):

- **allow**: routine local operations — package managers (pnpm/npm/yarn/pip/poetry/uv/cargo/composer/bundle/mix), runtimes (node/python/go/swift/dotnet/rustc), `mvn`/`gradle`, local git operations (`add`/`commit`/`diff`/`log`/`status`/`branch`/`checkout`/`stash`), Claude Code's `Read`/`Edit`/`Write` primitives.
- **ask**: network egress (`curl`, `wget`), `git push`, and (unless `--minimal`) docker, ssh/scp/rsync, cloud CLIs (aws/gcloud/az/kubectl/helm/terraform), database CLIs (psql/mysql/redis-cli/mongosh).
- **deny**: recursive force-delete unconditionally.

Evaluation order: `deny → ask → allow`, first match wins.

Existing `.claude/settings.json` is backed up (`.bak-YYYYMMDD-HHMMSS`) before overwrite — set `--force` to skip the prompt. `.claude/settings.local.json` (per-machine override) is untouched; the script offers to add it to `.gitignore` if a `.gitignore` exists.

Why a script and not a slash command: per-project permissions are environment configuration — they must exist on disk before the agent starts the session they control. A slash command would be chicken-and-egg (the agent writing its own pre-conditions). Copilot CLI / Codex / Cursor equivalents (different file formats, similar semantics) are documented in `copilot/prompts/init-permissions.md`.

---

## What's Inside

### Language support — where the per-language knowledge lives

ai-devkit splits language-specific knowledge from workflow tooling on purpose:

| Layer | Per-language? | Why |
|---|---|---|
| **Rules** (`~/.claude/rules/*.md`) | **Yes** — `go.md`, `java.md`, `python.md`, `typescript.md`, … | Idioms differ per language (Go error wrapping, Python type hints, TS `unknown` over `any`). Auto-active when matching files are edited. |
| **Hooks** (formatters) | **Yes** — `gofmt`/`goimports`, `ruff`, `prettier`, `php-cs-fixer`, `swiftformat`, `google-java-format`, `dotnet format` | Formatters are language-specific by definition. |
| **Commands / Agents / Skills** | **No** — `build-resolver`, `security-reviewer`, `/implement`, `/atomize`, … | Workflow shape is the same across languages. Runner / build tool / test command auto-detected from `package.json` / `pyproject.toml` / `go.mod` / `pom.xml` / `Cargo.toml` / `composer.json` / `Package.swift` / etc. |

Practical consequence: there is no `/go-build` or `/python-test` slash command. To get the same outcome, edit a `.go` file (Rules auto-activate Go idioms), invoke `/implement` (auto-detects `go test` via `go.mod`), or invoke `build-resolver` agent (has a Go section in its multi-language body). Same for any other language with a Rule and a lockfile.

---

### Rules — Coding Standards (14 files)

Auto-activate based on file type. Enforce language/framework best practices without manual setup.

| Rule | Activates On | What It Enforces |
|---|---|---|
| **security** | `*.java`, `*.py`, `*.swift`, `*.ts`, `*.js`, `*.yml`, `.env*` | OWASP checklist, STRIDE threat model, secrets management, injection prevention, dependency scanning, Privacy/GDPR by design (data minimisation, lawful basis, pseudonymised logs, retention, right to erasure) |
| **java** | `*.java` | Records, sealed classes, Optional usage, immutability (`final`, `List.copyOf()`), modern Java 17+ patterns, JUnit 5 + AssertJ + Mockito + Testcontainers |
| **spring-boot** | `*.java`, `application*.yml`, `pom.xml`, `build.gradle*` | Layered architecture, constructor injection, record DTOs with Bean Validation, `@ControllerAdvice`, Spring Security (JWT, CSRF, CORS), Testcontainers |
| **python** | `*.py`, `*.pyi` | PEP 8, type annotations, `Protocol` duck typing, frozen dataclasses, ruff, pytest with marks, 80% coverage |
| **typescript** | `*.ts`, `*.tsx`, `*.js`, `*.jsx` | `unknown` over `any`, Zod validation, interface vs type, error narrowing, Vitest/Playwright |
| **react** | `*.tsx`, `*.jsx` | Custom hooks, composition patterns, `useMemo`/`useCallback`, error boundaries, accessibility (ARIA, focus), key stability |
| **angular** | `*.ts`, `*.html`, `angular.json` | Standalone components, OnPush, signals, RxJS (`async` pipe, `takeUntilDestroyed`), reactive forms, TestBed |
| **node** | `*.ts`, `*.js`, `package.json` | REST API design, N+1 prevention, Redis caching, Bull queues, rate limiting, structured logging, Zod/Joi validation |
| **go** | `*.go`, `go.mod`, `go.sum` | gofmt/goimports, error wrapping (`%w`), functional options, table-driven tests, race detection, `context.Context`, goroutine safety, gosec |
| **php** | `*.php`, `composer.json` | PSR-12, `strict_types`, typed properties, immutable DTOs, PHPUnit/Pest, PHP-CS-Fixer/Pint, PHPStan/Psalm, prepared statements, CSRF |
| **swift-ios** | `*.swift`, `Package.swift` | Swift 6 concurrency (`Sendable`, actors), protocol-oriented design, typed throws, Keychain, SwiftFormat, Swift Testing |
| **dotnet** | `*.cs`, `*.csproj` | Nullable reference types, records + modern C# 12+, async all the way (`CancellationToken`, no `.Result`), constructor DI, xUnit + FluentAssertions + Testcontainers, NetAnalyzers, 80% coverage |
| **e2e-testing** | `*.e2e.ts`, `e2e/**`, `playwright.config.*` | When E2E vs unit, role-based selectors, test independence, wait-for-state, `storageState` reuse, the five anti-patterns, deliberate-breakage verify |
| **accessibility** | `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.html`, `*.component.ts/html` | WCAG 2.2 AA: native semantics over ARIA, landmarks + heading order, programmatic labels, keyboard operability + visible focus, contrast, no meaning-by-color-alone, `aria-live` for async, a11y in the definition of done |

---

### Commands — Slash Commands (7 files)

Type these directly in Claude Code. For Copilot CLI, cloud commands are available as agents (`@aws`, `@k8s`).

#### `/cloud-setup` — Cloud Access Configuration

Interactive setup wizard for AWS and Kubernetes access. Uses a `UserPromptSubmit` hook to auto-discover your AWS profiles before the conversation starts.

**How it works:**
1. Hook runs `cloud-discover.sh` → reads `~/.aws/config` → discovers profiles with role ARNs, auto-detects project/env/access
2. Claude walks you through annotation one question at a time, with smart defaults
3. Writes `~/.claude/cloud-config.json` (chmod 600)

**Steps:**
1. **AWS config path** — locates your `~/.aws` directory
2. **Profile annotation** — confirm or override auto-detected project, environment, access level per profile
3. **Default project** — which project resolves when you just say "dev"
4. **MFA setup** — configure your MFA device ARN
5. **Region** — default AWS region
6. **K8s setup** (optional) — EKS cluster name, region, management role, namespaces
7. **Script paths** — wrapper scripts for auth (installed by `setup.sh`)

**Claude Code:**
```
/cloud-setup
```

**Copilot CLI:** Run the interactive script directly:
```bash
bash ~/.claude/scripts/cloud-setup.sh
```

#### `/aws` — AWS Environment Dashboard

Deterministic dashboard + interactive command executor. A `UserPromptSubmit` hook runs `aws-dashboard.sh` before Claude processes the command — the dashboard always renders the same way for the same config.

**Features:**
- **Dashboard** — shows all environments grouped by project with access indicators (✔ PowerUser, △ ReadOnly, ◯ Tunnel)
- **MFA status** — shows `✔ active (42m remaining)` or `✖ expired` with automatic prompt for 6-digit token
- **Operations menu** — 18 numbered operations (whoami, s3, ec2, ecs, lambda, ecr, rds, dynamo, ssm, secrets, vpc, sg, logs)
- **Environment connect** — type an env name to assume role and verify identity
- **Safety** — confirms destructive ops, blocks writes on ReadOnly profiles

**Claude Code:**
```
/aws                    # Show dashboard + menu
/aws dev                # Connect to default project's dev
/aws ETSL stg           # Connect to ETSL staging
/aws show S3 buckets    # Execute directly
```

After `/aws`, pick a number from the menu or type a command:
```
> 5                     # List EC2 instances (asks which env first)
> 3                     # List S3 buckets
> ETSL dev              # Switch to ETSL dev environment
> show lambda functions # Natural language
```

**Copilot CLI** (agent, no hook — dashboard rendered by Claude, less deterministic):
```
@aws                    # Show dashboard
@aws dev                # Connect to dev
@aws show pods on stg   # Execute directly
```

#### `/k8s` — Kubernetes Environment Dashboard

Same architecture as `/aws` — deterministic hook-driven dashboard with interactive commands.

**Features:**
- **Dashboard** — K8s-enabled profiles, cluster name, region, known namespaces
- **MFA status** — same as `/aws`, prompts for token when expired
- **Operations menu** — 18 operations (pods, deployments, services, ingress, logs, describe, events, top, configmaps, secrets, hpa, nodes, namespaces, helm)
- **Namespace awareness** — suggests `-n <namespace>` from config when not specified

**Claude Code:**
```
/k8s                    # Show dashboard + menu
/k8s dev                # Connect to default project's dev cluster
/k8s MAX stg            # Connect to MAX staging
/k8s show pods on dev   # Execute directly
```

**Copilot CLI:**
```
@k8s                    # Show dashboard
@k8s dev                # Connect to dev
```

#### MFA Flow (both `/aws` and `/k8s`)

When MFA is configured and credentials are expired:

```
  MFA: ✖ expired

  MFA session expired. Enter your 6-digit MFA token:
> 123456
  ✔ Authenticated. Session valid for ~58 minutes.
```

Subsequent commands reuse cached credentials. If a command fails with `AccessDenied` mid-session, Claude will ask for a new MFA token automatically.

#### Safety Guard — Read-Only by Default

All cloud commands operate in **read-only mode**. Three layers of protection prevent accidental modifications:

1. **PreToolUse hook** (`cloud-guard.sh`) — deterministic bash script that intercepts every shell command and blocks destructive operations before they execute
2. **Command prompts** — explicit read-only instructions with blocked command lists
3. **Copilot agents** — same safety rules for `@aws` and `@k8s`

**Read operations (always allowed):**
```
/aws                          # Dashboard, menu
> 1                           # whoami — ✅ allowed
> 5                           # ec2 ls — ✅ allowed
> 17                          # logs groups — ✅ allowed
kubectl get pods -A           # ✅ allowed
kubectl describe pod my-pod   # ✅ allowed
kubectl logs my-pod           # ✅ allowed
helm list -A                  # ✅ allowed
```

**Write operations (blocked — requires explicit confirmation):**
```
> update ECS service image

⚠️  Write operation on dev
  Profile:  myapp-dev
  Command:  awscmd.sh myapp-dev aws ecs update-service --cluster my-cluster --service my-svc --force-new-deployment
  Effect:   Forces new deployment of my-svc with latest image

  Type "yes" to confirm, or anything else to cancel.

> yes
  ✔ Service updated.
```

```
> set image to v2.1

⚠️  Write operation on dev (app-ns)
  Profile:   myapp-dev
  Command:   kubecmd.sh myapp-dev kubectl set image deployment/my-app my-app=myimage:v2.1
  Current:   image: myimage:v2.0
  New:       image: myimage:v2.1

  Type "yes" to confirm, or anything else to cancel.

> yes
  ✔ Image updated.
```

**Blocked commands include:**

| AWS | Kubernetes |
|---|---|
| `ec2 terminate/stop/start/modify/delete` | `kubectl delete/apply/create/patch/edit` |
| `ecs update-service/stop-task` | `kubectl set image/env/resources` |
| `lambda update/delete/invoke` | `kubectl scale/rollout restart/drain` |
| `rds delete/modify/stop` | `kubectl exec` (except read-only: cat, ls, env) |
| `dynamodb delete/update/put-item` | `helm install/upgrade/uninstall/rollback` |
| `s3 rm/mv/cp` (upload) | |
| `ssm put-parameter`, `secretsmanager create/update/delete` | |
| All `iam` write operations, `cloudformation create/update/delete` | |

**Forbidden on production (even with confirmation):** `rds delete-db-instance`, `dynamodb delete-table`, `ec2 terminate-instances`, `cloudformation delete-stack`, `s3 rb`, `kubectl delete namespace/deployment/statefulset`, `kubectl scale --replicas=0`, `helm uninstall`.

#### `/ship` — Release Flow

Automates the full release cycle:

1. **Pre-flight** — checks for clean working tree, lists commits on branch
2. **Changelog** — generates `CHANGELOG.md` entry from commits (Features, Fixes, Improvements, Breaking Changes)
3. **Version bump** — detects `VERSION`/`package.json`/`pyproject.toml`/`pom.xml`, bumps semver with confirmation
4. **Commit + PR** — commits release metadata, pushes, creates PR via `gh` (or updates existing PR)

Never force-pushes. Never merges — only creates the PR. Idempotent (safe to run twice).

#### `/retro` — Retrospective

Runs a structured retrospective on the current branch:
- Analyzes all commits and diffs against main
- Evaluates: what went well, what to improve, surprises
- Extracts 2-5 actionable lessons with pattern/root cause/prevention
- Appends to `tasks/lessons.md` if it exists

#### `/changelog` — Generate Changelog Entry

Standalone changelog generation (also included in `/ship`):
- Groups commits by type (Features, Fixes, Improvements)
- Plain language, user-focused ("Add X" not "Refactored Y")
- Creates or prepends to `CHANGELOG.md`
- Detects version from project files or uses `[Unreleased]`

#### `/threat-model` — STRIDE Security Analysis

Full threat modeling for a specified component:
- Maps data flows and trust boundaries
- Analyzes all 6 STRIDE categories (Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation of Privilege)
- Rates findings: Likelihood x Impact = Priority
- Outputs structured report with concrete mitigations

---

### Agents — Specialized AI Roles

Focused agents that can be invoked for specific tasks.

| Agent | Claude Code | Copilot CLI |
|---|---|---|
| security-reviewer | Auto-available as subagent | `@security-reviewer` |
| build-resolver | Auto-available as subagent | `@build-resolver` |
| performance-analyzer | Auto-available as subagent | `@performance-analyzer` |
| aws | Via `/aws` slash command (hook-driven) | `@aws` |
| k8s | Via `/k8s` slash command (hook-driven) | `@k8s` |

#### `security-reviewer`

Scans code for vulnerabilities following OWASP Top 10:
- Hardcoded secrets, SQL injection, XSS, CSRF, broken auth
- Flags patterns like `innerHTML` with user data, plaintext passwords, missing rate limiting
- Outputs findings by severity (CRITICAL/HIGH/MEDIUM) with exact file:line and fix

**Claude Code:** Auto-available as subagent.
**Copilot CLI:** `copilot --agent=security-reviewer`

#### `build-resolver`

Diagnoses and fixes compilation/build/dependency errors:
- Java: Maven/Gradle conflicts, annotation processors, Spring Boot wiring
- Python: import errors, virtualenv, async issues
- TypeScript: tsconfig, module resolution, monorepo references
- Swift: SPM resolution, deployment targets

Applies minimal surgical fixes. Stops after 3 failed attempts and escalates.

#### `performance-analyzer`

Static code analysis for performance bottlenecks:
- Database: N+1 queries, missing indexes, `SELECT *`, unbounded queries
- Algorithmic: O(n^2) loops, missing memoization
- I/O: blocking calls in async, sequential when parallel possible, missing timeouts
- Memory: unbounded caches, event listener leaks, large object retention

---

### Skills — Discovery → Plan → Execute → Test → Audit Workflow (16 skills)

Five complementary workflows: (1) idea → product spec, (2) per-decision research, (3) plan → atomic tasks, (4) execute tasks → audit rules, (5) author E2E scenarios → run them. Plus two integration skills — `/open-web` (browser bridge for content `WebFetch` can't read) and `/bitbucket-review` (Claude code review for Bitbucket PRs over the REST API) — an eval harness (`/eval`) that scores AI output against golden tasks to catch regressions when the model or harness changes, and two engineering-infra skills: `/repo-map` (evidence-based map of an unfamiliar repo before you change it) and `/ci-setup` (CI pipeline with coverage gate + optional AI review). Skills live in `~/.claude/skills/` as subfolders with their own `references/` for locked schemas. Model tiers per skill archetype (token economy — when to run a subagent on a cheap vs capable model, and why a judge is never weaker than the producer) are documented in [`docs/model-per-skill.md`](docs/model-per-skill.md).

How the phases and artifacts fit together:

```
                       ┌────────────────────────────────────────────────┐
                       │  /setup — scaffold docs/ + tests/e2e/          │
                       │  + docs/architecture/decisions/ (D-NNN log)    │
                       └─────────────────────┬──────────────────────────┘
                                             ▼
┌────────────────────────────── DISCOVERY ──────────────────────────────┐
│                                                                       │
│  brownfield?  /repo-map ──► docs/architecture/repo-map.md             │
│               (evidence map: territory, cycles, blast radius)         │
│                                                                       │
│  /discover ──► discover-notes.md ──► /product-spec ──► product-spec   │
│                                                                       │
│  technical decision?  /research ──► docs/analyzes/<slug>.md           │
│                           │                                           │
│                           └──► D-NNN record (living decision log)     │
└─────────────────────────────────┬─────────────────────────────────────┘
                                  ▼
┌────────────────────────────────  PLAN  ───────────────────────────────┐
│                                                                       │
│  plan mode ──► /save-plan ──► docs/work/NNN-slug/plan.md              │
│                (roadmap-shape plans ► docs/roadmap.md)                │
│                                                                       │
│  /atomize ──► T-001…T-NNN (depends_on, ## Acceptance with             │
│               "If <trigger>, then <expected>" failure-path criteria)  │
│               + derived index.md                                      │
└─────────────────────────────────┬─────────────────────────────────────┘
                                  ▼
┌──────────────────────────────  EXECUTE  ──────────────────────────────┐
│                                                                       │
│  /implement (loop per task):                                          │
│    pre gates  ─ clean tree, branch, deps, runner, green baseline      │
│    execute    ─ red→green→refactor, oracle = ## Acceptance            │
│    review     ─ fresh-model verification (reviewer sees ONLY the      │
│                 diff + acceptance criteria, never the reasoning)      │
│    post gates ─ opt-in security-baseline on the diff, full suite,     │
│                 commit "T-NNN … Refs: D-NNN"                          │
│    writeback  ─ status/commit/completed → frontmatter → STATUS.md     │
└─────────────────────────────────┬─────────────────────────────────────┘
                                  ▼
┌────────────────────────────────  TEST  ───────────────────────────────┐
│                                                                       │
│  /scenario ──► scenario plan (human gate) ──► committed .spec.ts      │
│                @optimistic/@pessimistic ──► /e2e-run (report-only)    │
└─────────────────────────────────┬─────────────────────────────────────┘
                                  ▼
┌────────────────────────────────  AUDIT  ──────────────────────────────┐
│                                                                       │
│  /eval ── golden tasks ► baseline.json (model+harness stamp +         │
│           gen_ai.* cost/token telemetry) ► fail on any regression     │
│           pattern: A/B/C taxonomy · triggers.json routing check       │
│                                                                       │
│  /code-review · /bitbucket-review · /rule-review · /agents-md         │
│  /ci-setup ──► GitHub Actions (lint + test + coverage gate + AI       │
│                review)                                                │
└────────────────────────────────────────────────────────────────────────┘

═══════════════ RUNTIME LAYER (always active, underneath) ═══════════════
  14 auto-active language rules (security+GDPR, accessibility, dotnet…)
  9 hooks: formatters · safety guard (force-push, hard-reset, force-
  clean, branch -D, checkout .) · cloud-guard (AWS/kubectl/helm) ·
  M1L3 permission policy
═════════════════════════════════════════════════════════════════════════
```

Two feedback loops the vertical arrows don't show: **plan changed → `/atomize` reconciliation** revises tasks without touching `done` ones, and **`/research` → D-NNN → `/implement` `Refs:`** ties every decision from its reasoning snapshot through the durable verdict to the commit that implements it. Cross-run memory lives in `docs/work/STATUS.md` (where we are) and `docs/roadmap.md` (where we're going).

| Skill | Purpose | Output |
|---|---|---|
| `/setup` | Scaffold the `/docs` directory (`architecture/` incl. a numbered `decisions/` log, `analyzes/`, `reference/`, `work/`) with canonical READMEs. Idempotent — never overwrites. For brownfield projects (git history + lockfile detected), additionally offers to run Claude Code's built-in `/init` to generate `CLAUDE.md` from codebase analysis. | docs dirs + READMEs + `architecture/decisions/` log (+ optional `CLAUDE.md`) |
| `/discover` | Facilitate a structured discovery conversation. Auto-detects greenfield vs brownfield from cwd. 6 phases: Vision, Access Control, Scope & Timeline, FRs & User Stories, Business Logic & NFRs, Product Framing. Scans `docs/reference/` (Step 0.8) for input materials (any file type — PDF, DOCX, link indexes). **Brownfield: inherit-by-reference (Step 0.9)** — auto-scans `docs/product-spec.md`, `docs/architecture/`, latest `docs/work/*/plan.md`; inherited elements land in `## Inherited state` and each phase only asks about the delta. Empty-CRUD detection, Socratic challenge per new/modified FR, soft-gate cross-check, resumes from checkpoint. Professional vocabulary policy — no startup clichés; adapts phrasing to the user's working language. | `docs/discover-notes.md` |
| `/product-spec` | Generate a schema-conformant product spec from `discover-notes.md` (or raw notes). 10 sections for greenfield, 11 for brownfield. Thin-input heuristic, technical-leak content lint (7 categories), versioned-save collision handling. | `docs/product-spec.md` |
| `/research` | Per-decision research artifact for a specific technical question. Three modes (interview / investigation with parallel subagents / mixed), three types (decision / technology-evaluation / investigation). Reads any file type from `docs/reference/` (binaries via sibling `.md` indexes); link-collection markdown files seed Investigation-mode subagents with starter URLs. Citation discipline: web URLs, code paths, and `> Ref:` blockquotes for reference material. Mandatory anti-bias cross-check (devil's advocate + pre-mortem). On a reached decision (`status: decided`), also appends a numbered record to the living `docs/architecture/decisions/` log (`D-NNN`, linked back to the analysis). Same professional vocabulary policy as `/discover`. | `docs/analyzes/<slug>.md` (+ `docs/architecture/decisions/D-NNN-*.md` on a decision) |
| `/save-plan` | Bridge Claude Code's built-in `/plan` mode → `docs/` convention. **Auto-picks source** in priority order: inline file arg → newest file in `~/.claude/plans/` (where Claude Code persists approved `ExitPlanMode` output) → conversation context → user paste. **Roadmap-shape detection (Step 1.5)** — if the plan content looks like top-down sequencing (`# Roadmap` heading, `## Slices`, or `## Foundations` + slice-equivalent), one confirm prompt offers to land it at `docs/roadmap.md` instead of `docs/work/NNN-<slug>/plan.md`; roadmap branch skips slug derivation / NNN / `/atomize` chain. Otherwise standard branch: derive slug, compute NNN, write verbatim, regenerate `docs/work/STATUS.md`, optionally chain into `/atomize`. Reference citations from `/discover` / `/research` flow through unchanged. | `docs/work/<NNN>-<slug>/plan.md` **or** `docs/roadmap.md` |
| `/atomize` | Decompose `plan.md` into atomic `T-NNN-<slug>.md` task files. Auto-detects mode: INITIAL (no T-*.md — propose tasks, write files + index.md) or RECONCILIATION (T-*.md exist — diff plan, verify done claims via 3-layer heuristic, propose new/revised/obsoleted tasks). Regenerates `docs/work/STATUS.md` at the end of each run so the cross-initiative rollup tracks the new task mix. | `docs/work/<NNN>-<slug>/T-*.md` + `index.md` (+ refreshed `STATUS.md`) |
| `/implement` | Execute a T-NNN-*.md task, an initiative folder (picks next unblocked pending task), or a standalone `plan.md` through three gates per task: pre-execution (clean tree, branch, dependencies, runner detected, baseline green) → in-execution (red/green/refactor or write-then-test, affected-only test selectors) → post-execution (full suite, commit one task per SHA, frontmatter writeback `status: done` + `commit:` + `completed:`, regenerate `docs/work/STATUS.md`). Closes the loop with `/atomize` reconciliation. Auto-detects runner from `package.json` / `pyproject.toml` / `go.mod` / `pom.xml` / `build.gradle*` / `Cargo.toml` / `composer.json` / `Package.swift` / `mix.exs` / `Gemfile` / `.csproj`. Lesson capture on abandon. Optional `security-reviewer` + `performance-analyzer` Agent invocation before commit. Never `git add -A`, never pushes. | Commits + updated `T-*.md` frontmatter (+ refreshed `STATUS.md`) (+ optional `docs/reference/lessons.md` entry) |
| `/agents-md` | Author `AGENTS.md` as the canonical project-rules file with a thin `CLAUDE.md` import shim (`@AGENTS.md`) and optional `.github/copilot-instructions.md` shim — Claude Code, Codex, Cursor, Copilot all read the same file. Anti-duplication: inventories `~/.claude/rules/*.md` and refuses to propose rules already auto-active there. Test-of-inclusion gate per candidate rule — every rule must cite a real anchor (`docs/product-spec.md` § …, `docs/architecture/*.md` decision, `docs/reference/lessons.md` entry, incident reference). U-shaped attention layout (Critical → Conventions → Workflow → References). Size budget warning at 200 lines; auto-proposes split into `<area>/AGENTS.md` over 250. | `AGENTS.md` + `CLAUDE.md` shim (+ optional Copilot shim) |
| `/rule-review` | Audit an existing rules file (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*.mdc`, `.github/copilot-instructions.md`, `.github/instructions/*.md`) across **7 dimensions**: (1) length vs ~200-line ceiling, (2) embedded code/config blocks, (3) language precision (weak verbs, empty intent), (4) redundancy vs `~/.claude/rules/` auto-active layer with concrete citations, (5) order (critical rules in top third), **(6) cross-tool drift** when AGENTS.md / CLAUDE.md / copilot-instructions co-exist, **(7) dead rules** via codebase grep for the patterns each rule targets. Read-only by default; `--fix` flag applies safe rewrites only (redundancy removal, section reorder, dead-rule marking). Backs up to `<path>.bak-YYYYMMDD-HHMMSS` before any change. | Audit report (+ optional fixed file) |
| `/open-web` | Drive a real headed browser via the maister Playwright MCP server to load a URL, wait for it to settle, capture an accessibility snapshot + optional screenshot, and surface JS console errors. Bridges the two cases `WebFetch` can't handle: auth-walled pages (course platforms, internal dashboards, private repos — the headed browser inherits whatever session you have open) and JavaScript-rendered SPAs (WebFetch sees an empty HTML shell before JS runs). Default-leaves-tab-open so cookies/session persist across calls; `--close` to clean up, `--no-screenshot` to skip the PNG, `--timeout 15s` to override the 5s wait. Does NOT silently fall back to `WebFetch` if Playwright is unreachable — surfaces the problem instead. Does NOT auto-click through login forms. | Page snapshot + screenshot + console log |
| `/scenario` | Author E2E test scenarios from a `T-NNN` task, initiative, product-spec, or freeform idea, and generate **committed** Playwright tests into `tests/e2e/`. Enumerates **optimistic + pessimistic paths**, presents them as a human-reviewable plan (`tests/e2e/scenarios/<slug>.md`, frontmatter `depends_on: [T-NNN]` + `initiative:` back-links), and only after explicit confirmation generates tagged `.spec.ts` — web via the browser, backend via Playwright's `request` fixture. Optionally grounds web selectors against a live app via the Playwright MCP (role/test-id locators). Assertion oracle = acceptance criteria, never observed output. Does NOT run tests and never auto-heals. Pairs with the auto-active `rules/e2e-testing.md`. | `tests/e2e/scenarios/<slug>.md` + tagged `.spec.ts` (web/api) |
| `/e2e-run` | Discover and run the scenarios `/scenario` authored, with the right tool per artifact and scoped to what you ask for. Default runner is **Playwright** (`npx playwright test`); dedicated API runners — **Hurl** (`.hurl`), **Schemathesis** (OpenAPI) — are opt-in extensions (`extensions/` mechanism, recorded in `tests/e2e/extensions.md`). Resolves scope from a scenario `.md`, an initiative, a `T-NNN` (via `depends_on`), a path-type tag (`--grep @optimistic`/`@pessimistic`), or a layer. Reports pass/fail per layer + path type with trace artifacts. **Report-only on failure — never regenerates or auto-heals**; never auto-installs a tool. Optional one-line result note to the linked task's `## Notes` (never flips `status`). | Test run + structured report (+ optional task `## Notes` line) |
| `/eval` | Run a golden-task evaluation harness over AI output to catch quality regressions when the model or harness changes. Reads golden tasks (input + a known `## Expected` outcome) from an `evals/` directory, runs each against its named `target:` (a skill, prompt, agent, or product LLM feature), scores output against the **oracle** (`rubric` via a fresh judge agent / `assert` / `exact`) — never against the implementation's own echo, compares to a git-tracked `baseline.json`, and reports pass/fail per task plus a regression delta. A run fails on any drop vs baseline (`allow_regressions: false`), not just on missing a threshold; the baseline is stamped with model + harness so a drop is attributable to an upgrade — and carries per-task **cost/token telemetry** (`gen_ai.usage.*` + `cost_usd`, numbers only — never prompt/completion text; cost deltas inform, quality thresholds decide). Golden tasks declare a `pattern:` taxonomy (A artifact-correctness / B process-discipline / C config-compliance) and rubric grading is **per-expectation** (fraction met — more deterministic than one holistic score). When `evals/triggers.json` exists, Step 3.5 also runs **trigger discrimination**: `{query, should_trigger}` cases with adversarial negatives — firing on a `should_trigger: false` case is a failure (over-triggering = the skill-collision failure mode). Scaffolds a starter `evals/` on first run. Closes EVAL-07-grade concreteness; pairs with `/ci-setup` for a CI gate. | `evals/` scaffold + run report (+ accepted `baseline.json` on `--accept`) |
| `/repo-map` | Brownfield/legacy onboarding: build an evidence-based map of an unfamiliar or large repo *before* changing it. Three read-only signal subagents in parallel (`references/signal-recipes.md`): **territory** (git-history top-changed paths, noise-filtered, with an optional process/docs-churn discount), **structure** (dependency grapher → entry points, import direction, cycles, coupling), **contributors** (who-to-ask, bot/AI commits filtered). For small/solo repos runs the recipes directly instead of fanning out. Evidence rule: a label without evidence goes in `unknowns`, never asserted; optional `--verify` confirms structural claims with `ast-grep`. Read-only — never executes or modifies target code, never auto-installs a grapher. Feeds `/research`, `/implement` (blast radius), `/agents-md`. | `docs/architecture/repo-map.md` |
| `/ci-setup` | Generate a CI pipeline: GitHub Actions workflow that lints, tests, enforces a **coverage gate** (default 80%), publishes coverage to Codecov (badge + PR diff-coverage), and optionally adds **AI code review** on PRs — two recipes (`references/ai-reviewers.md`): kukuvaia on a self-hosted runner or the official Claude Code Action. Detects the stack (Python/uv, Node/npm) via `/implement`'s runner-detection. Mandatory human-review gate before writing; idempotent collisions; below-target coverage becomes a non-blocking warning, never a red-on-day-one block. Self-hosted jobs same-repo-only and dormant until `SELF_HOSTED_CI=true`. Never stores secrets, never commits/pushes. CI-only (no CD). | `.github/workflows/ci.yml` (+ reviewer wiring) |
| `/bitbucket-review` | Automated Claude code review for a Bitbucket Cloud PR, driven by the REST API — the Bitbucket counterpart to `/code-review --comment` (which is GitHub-only). Fetches PR metadata + the unified diff over the API (no local clone needed), runs a structured review (correctness + reuse/simplification/efficiency, optional `--security` pass), prints findings in chat, and **opt-in** posts them back as inline (`--comment`) or summary (`--summary-comment`) comments. A Python stdlib helper (`scripts/bb_review.py`) does the deterministic plumbing — API I/O, the `/diff` 302 redirect, pagination, 429 backoff, and unified-diff line mapping so inline anchors are always valid. Auth via **API token** (App Passwords are disabled 2026-06-09); `BITBUCKET_EMAIL` + `BITBUCKET_API_TOKEN`. Posting defaults to OFF so a run never silently writes to a shared PR. `--repo <path>` gives reviewers full-file context the raw diff lacks. | Findings in chat (+ optional PR comments) |

**Workspace layout (`/setup` creates):**

```
docs/
├── product-spec.md             # (created by /product-spec) — what the product IS
├── discover-notes.md           # (created by /discover) — transient discovery input
├── roadmap.md                  # (created by /save-plan when roadmap-shape detected)
│                               #   — TOP-DOWN sequencing, hand-edited, "where are we going"
├── architecture/               # design decisions, system docs
├── analyzes/                   # research snapshots — created by /research
├── reference/                  # input material — ANY file type (.md/.pdf/.docx/.xlsx/.png/.drawio)
│   ├── auth-and-providers.md   #   operational spec (markdown)
│   ├── client-brief.pdf        #   binary source — paired with sibling .md index
│   ├── client-brief.md         #   sibling index — readable surface for the PDF
│   └── links-otel-sdks.md      #   link-collection markdown — feeds /research subagents
└── work/                       # initiatives — folder-per-initiative
    ├── STATUS.md               # (auto-generated by regenerate-status.sh)
    │                           #   — BOTTOM-UP rollup, "where are we now"
    └── 004-observability-otel/
        ├── plan.md             # the "thinking doc" (often from /plan mode)
        ├── index.md            # DERIVED view of task status (per initiative)
        ├── T-001-otel-deps.md
        ├── T-002-tracing-config.md
        └── T-003-metrics-bridge.md
```

`docs/reference/` is the project's input pool — `/discover`, `/research`, and `/plan` all read from it. Binaries (`.pdf`, `.docx`, `.xlsx`, etc.) MUST have a sibling `.md` index per `docs/reference/README.md` convention; the index is the readable surface, the binary is the citation target.

**Two roadmap artifacts, two questions:**

| File | Direction | Authored by | Answers |
|---|---|---|---|
| `docs/roadmap.md` | top-down | `/save-plan` writes the initial file from a roadmap-shape plan; **hand-edited** thereafter (flip slice status, add follow-ups, mark blockers) | _Where are we going?_ — sequencing of foundations + vertical slices across the project's lifetime |
| `docs/work/STATUS.md` | bottom-up | **auto-regenerated** by `~/.claude/scripts/regenerate-status.sh` at the end of `/save-plan`, `/atomize`, `/implement`, `/setup`. Derived from `plan.md` `status:` + `T-*.md` `status:` frontmatter across all `docs/work/<NNN>-<slug>/` folders | _Where are we now?_ — initiatives categorised as Active / Backlog / Done / Obsoleted with task progress (`done/total`) and mtimes |

They coexist by design. The roadmap is **intent**; STATUS is **observation**. The bridge: each slice in `roadmap.md` carries a `Change ID:` field, and when a developer picks one up they run `/save-plan <change-id>` — the resulting `docs/work/NNN-<change-id>/plan.md` reconnects bottom-up STATUS to the top-down roadmap via the slug. Full contract (when to use roadmap-shape, minimal 4-section template, framing questions, anti-patterns): `claude/skills/save-plan/references/roadmap-shape.md`.

**Project bootstrap (one-time, outside the agent session):**
Before any of the four skill workflows below, drop the permission policy onto disk so Claude Code starts the project with safe defaults:

```bash
~/ai-devkit/setup.sh --permissions   # writes <project>/.claude/settings.json (M1L3 policy)
```

This is environment configuration — it has to exist before the agent runs (see [`--permissions`](#per-project-permission-policy---permissions) for details). The skill workflows below assume this is already in place.

**Four skill workflows (inside the agent session):**

- **Idea → spec** (once per project / per major change): `/setup` → `/discover` → `/product-spec`. Each skill self-bootstraps; `/discover` delegates to `/setup` if `docs/` is missing.
- **Per-decision research** (many times throughout project): `/research <topic>` — runs interview / investigation / mixed, reads relevant `docs/reference/` files (including binaries via their sibling `.md` indexes), writes a point-in-time snapshot to `docs/analyzes/<slug>.md`. Use BEFORE significant technical choices, not for product-level questions.
- **Plan → tasks**: Claude Code's `/plan` mode → `/save-plan` (auto-picks newest from `~/.claude/plans/`, detects roadmap-shape; lands either at `docs/roadmap.md` for top-down sequencing or `docs/work/<NNN>-<slug>/plan.md` for a single change-set) → `/atomize` (auto-chained for initiative plans, skipped for roadmaps). Re-run `/atomize <folder>` whenever a `plan.md` changes — it reconciles. `docs/work/STATUS.md` regenerates automatically at every write.
- **Execute → audit**: `/implement` drives `T-*.md` execution through pre/per/post gates and writes status back to frontmatter (closes the loop with `/atomize` reconciliation). `/agents-md` authors the project rules file from anchored sources; `/rule-review` audits across 7 dimensions and offers safe auto-fixes. Together they keep the agent productive on a project AND keep the rules file load-bearing instead of bloated.

**Cycle position of each layer** — what each step decides:

```
--permissions →  WHAT the agent is ALLOWED to do (settings.json)   environment layer (run via setup.sh)
/discover     →  WHAT to build (or change) and FOR WHOM            product layer
/product-spec →  WHAT, written to schema                           product layer
/research     →  WHICH option / library / approach                 decision layer
/plan         →  HOW to build it (sequencing, decomposition)       implementation layer
/save-plan    →  persist the plan to disk                          bridge to docs/
              →    roadmap-shape → docs/roadmap.md  (top-down, hand-edited thereafter)
              →    initiative    → docs/work/NNN-slug/plan.md (chains into /atomize)
/atomize      →  break the plan into atomic tasks                  implementation layer
              →    side-effect: refresh docs/work/STATUS.md (bottom-up rollup)
/implement    →  execute one task with gates + writeback           execution layer
/agents-md    →  the agent rules contract for this project         onboarding layer
/rule-review  →  audit that contract on 7 dimensions               onboarding layer
```

**Key mechanisms:**

- **Facilitator vs generator separation** (`/discover` vs `/product-spec`) — discover NEVER writes content the user didn't say; product-spec NEVER invents domain rules. Every gap routes verbatim to `## Open Questions`.
- **Reference materials are input, not output.** `docs/reference/` accepts any file type — markdown, PDFs, DOCX, XLSX, drawio diagrams, curated link indexes. `/discover` (Step 0.8) and `/research` (Step 4) scan this directory, let the user pick what is in-scope, and thread citations through with `> Ref: docs/reference/<file>` blockquotes. Binaries pair with a sibling `.md` index — the index is the readable surface, the binary is the citation target.
- **Inherit-by-reference (brownfield `/discover` Step 0.9).** Systems evolve, they do not rebuild. `/discover` automatically scans `docs/product-spec.md`, `docs/architecture/*.md`, and the latest `docs/work/*/plan.md` for already-documented elements (vision, persona, access control, business logic, FR baseline, NFRs, `product_type`, `target_scale`). Inherited elements land once in `## Inherited state`; each subsequent phase opens with the inherited value visible and asks only about the delta. Re-elicitation is opt-in for revolutionary rebuilds.
- **Stack openness** — the spec captures product-level priors only. Frameworks, vendors, runtime location, transport, enforcement mechanism are all blocked by the content lint. Brownfield's `## Current System Overview` is the only exception (describes reality, not a choice).
- **Never edit done tasks** (`/atomize` hard rule) — changes to scope of already-DONE work create NEW follow-up tasks with `depends_on: [<original>]`. Preserves traceability between plan revisions and shipped implementation.
- **3-layer status:done verification** (`/atomize` reconciliation) — git log (commit SHA + task ID + scope files) → file presence (extracted from `## Scope`) → user assertion fallback for ambiguous cases. Results logged in append-only `## Verification log` inside `index.md`.
- **Frontmatter writeback closes the loop** (`/implement` Step 7) — after a successful task commit, `status: done`, `commit: <SHA>`, `completed: <date>` land in the T-NNN-*.md frontmatter automatically. `/atomize` reconciliation reads the same fields back; the two skills round-trip without manual edits.
- **Top-down roadmap + bottom-up STATUS, derived automatically.** `docs/roadmap.md` is the hand-edited intent layer (one per project, written by `/save-plan` when roadmap-shape detected, edited in place over the project's life). `docs/work/STATUS.md` is the observation layer — regenerated by `regenerate-status.sh` from `plan.md` + `T-*.md` frontmatter on every `/save-plan` / `/atomize` / `/implement` write, no manual edits possible. The two files answer complementary questions (going vs now); each slice's `Change ID:` in the roadmap is the slug a developer passes to `/save-plan` when picking it up, which is how STATUS reconnects to roadmap.
- **Test of inclusion** (`/agents-md` Step 3) — every candidate rule must answer "could the agent know this without this file?" with a documented "no" plus a citation. Generic best-practice content is rejected up front, before it reaches the file.
- **Evidence-cited findings** (`/rule-review`) — each verdict prints line numbers, file paths, grep results, or contradicting siblings. No vague "this rule is weak" — every finding is reproducible.
- **Schema as contract** — `claude/skills/discover/references/product-spec-schema.md` (PRD shape) and `claude/skills/atomize/references/task-schema.md` (task + index shape) are single sources of truth. Skills re-read them on every invocation and re-validate before disk writes.

**Copilot CLI:** prompts in `copilot/prompts/` — copy-paste templates for `setup.md`, `discover.md`, `product-spec.md`, `research.md`, `save-plan.md`, `atomize.md`, `implement.md`, `agents-md.md`, `rule-review.md`, `scenario.md`, `e2e-run.md`, `bitbucket-review.md`.

---

### Hooks — Auto-Triggers (9 hooks)

Run automatically on specific events. Claude Code only.

| Hook | Event | Action |
|---|---|---|
| **cloud dashboard** | `UserPromptSubmit` | Injects AWS/K8s dashboard output when `/aws`, `/k8s`, or `/cloud-setup` is invoked |
| **ruff** | `PostToolUse` (Edit `*.py`) | Auto-lint with `ruff check --fix` |
| **google-java-format** | `PostToolUse` (Edit `*.java`) | Auto-format |
| **swiftformat** | `PostToolUse` (Edit `*.swift`) | Auto-format |
| **prettier** | `PostToolUse` (Edit `*.ts`/`*.tsx`/`*.js`/`*.jsx`) | Auto-format |
| **goimports/gofmt** | `PostToolUse` (Edit `*.go`) | Auto-format with goimports (fallback to gofmt) |
| **php-cs-fixer/pint** | `PostToolUse` (Edit `*.php`) | Auto-format with Pint (fallback to PHP-CS-Fixer) |
| **dotnet format** | `PostToolUse` (Edit `*.cs`) | Auto-format C# files |
| **safety guard** | `PreToolUse` (Bash) | Blocks `--no-verify`, `push --force` (allows `--force-with-lease`), `reset --hard`, dangerous `rm -rf`, `clean -f`, `branch -D`, `checkout .` |

The cloud dashboard hook is the key mechanism that makes `/aws` and `/k8s` deterministic — `prompt-hook.sh` detects the slash command and runs the corresponding dashboard script, injecting its output as context before Claude processes the prompt.

All formatter hooks use `command -v` guards — silently skip if the tool isn't installed.

---

### Scripts — Cloud Wrappers, Hooks, Project Init (10 files)

Installed to `~/.claude/scripts/` by `setup.sh`. These are deterministic bash scripts — not prompts.

| Script | Purpose |
|---|---|
| `awscmd.sh` | AWS CLI wrapper with MFA + role assumption + credential caching (~58 min TTL) |
| `kubecmd.sh` | kubectl/helm wrapper with EKS auth via AWS role assumption |
| `aws-dashboard.sh` | Reads `cloud-config.json`, renders environment list + operations menu |
| `k8s-dashboard.sh` | Same as above for Kubernetes environments |
| `cloud-discover.sh` | Discovers AWS profiles from `~/.aws/config`, outputs JSON for `/cloud-setup` wizard |
| `cloud-setup.sh` | Interactive terminal wizard for creating `cloud-config.json` (standalone, for Copilot CLI) |
| `cloud-guard.sh` | PreToolUse safety guard — blocks `--no-verify`, dangerous `rm -rf` patterns, force pushes |
| `prompt-hook.sh` | `UserPromptSubmit` hook — detects `/aws`, `/k8s`, `/cloud-setup` and injects dashboard output |
| `init-project-permissions.sh` | Writes per-project `.claude/settings.json` with the M1L3 permission policy. Invoked by `setup.sh --permissions`. Polyglot allow list + opt-in extras (Docker / SSH / cloud CLIs / DB CLIs) in `ask` |
| `regenerate-status.sh` | Rebuilds `docs/work/STATUS.md` from current `plan.md` + `T-*.md` frontmatter across all `docs/work/<NNN>-<slug>/` folders. Pure bash (no Python/yq deps), macOS + Linux portable, idempotent. Called automatically by `/save-plan`, `/atomize`, `/implement`, `/setup` after writes; can also be invoked manually: `bash ~/.claude/scripts/regenerate-status.sh [project-root]` |

### Plugin — Maister (Claude Code only)

Auto-configured in settings.json. Provides 30+ specialized workflows:
- `/maister:development` — full development orchestration
- `/maister:reviews-code` — automated code review
- `/maister:quick-plan` — planning mode with standards awareness
- `/maister:reviews-production-readiness` — deployment readiness checks

---

## Copilot CLI Details

### What's Global vs Per-Repo

| Component | Claude Code | Copilot CLI |
|---|---|---|
| CLAUDE.md | `~/.claude/` (global) | `~/.claude/` (global, reads same file) |
| Rules / Instructions | `~/.claude/rules/` (global, auto-activate) | `.github/instructions/` (per-repo) |
| Commands | `~/.claude/commands/` (global slash commands) | Not supported (use prompt templates) |
| Cloud commands | `/aws`, `/k8s` (hook-driven, deterministic) | `@aws`, `@k8s` (agent-based, best-effort) |
| Agents | `~/.claude/agents/` (global) | `~/.copilot/agents/` (global) |
| Hooks | `~/.claude/settings.json` (global, incl. `UserPromptSubmit`) | `.github/hooks/` (per-repo, tool-level only) |
| MCP | `~/.claude/settings.json` (global) | `~/.copilot/mcp-config.json` (global) |
| Scripts | `~/.claude/scripts/` (cloud wrappers, dashboards) | Same scripts, called by agents |

### Installing Instructions Into a Repo

```bash
# All languages + security
./copilot/install-to-repo.sh /path/to/project

# Only specific languages (security always included)
./copilot/install-to-repo.sh /path/to/project --languages java,python

# Available: java, spring-boot, python, typescript, react, angular, node, swift-ios, go, php
```

This copies `.instructions.md` files to `.github/instructions/` and hooks to `.github/hooks/`. Commit them to share with your team, or add to `.gitignore` for personal use.

### Cloud Commands in Copilot CLI

Copilot CLI doesn't support `UserPromptSubmit` hooks, so cloud commands use agents instead. They work the same way but the dashboard is rendered by the AI (less deterministic):

```
@aws                           # Show AWS dashboard
@aws dev                       # Connect to dev
@aws show S3 buckets on stg    # Direct command

@k8s                           # Show K8s dashboard
@k8s MAX dev                   # Connect to MAX dev cluster
@k8s show pods in app-ns       # Direct command
```

First-time setup — run the wizard directly in your terminal:
```bash
bash ~/.claude/scripts/cloud-setup.sh
```

### Using Prompts (Slash Command Replacement)

Copilot CLI doesn't support custom slash commands. Copy-paste from `copilot/prompts/`:

```bash
cat copilot/prompts/ship.md    # Then paste the prompt into Copilot CLI
```

---

## Optional Tools

Install these for auto-formatting hooks to activate:

```bash
pip install ruff                     # Python linting
brew install google-java-format      # Java formatting
brew install swiftformat             # Swift formatting
npm install -g prettier              # JS/TS formatting
go install golang.org/x/tools/cmd/goimports@latest  # Go formatting
composer global require friendsofphp/php-cs-fixer   # PHP formatting
brew install gh                      # GitHub CLI (for /ship)
apt install jq                       # JSON merge in setup script
brew install awscli                  # AWS CLI (for /aws)
brew install kubectl                 # Kubernetes CLI (for /k8s)
brew install helm                    # Helm (for /k8s helm commands)
```

## Tests

161 unit tests using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

```bash
# Install bats
brew install bats-core

# Run all tests
bats tests/

# Run a specific test file
bats tests/cloud-discover.bats

# Verbose output
bats tests/ --verbose-run
```

| Suite | Tests | Coverage |
|---|---|---|
| `aws-dashboard.bats` | 14 | Dashboard rendering, access indicators, MFA status, operations menu |
| `awscmd.bats` | 10 | Profile name validation (path traversal, injection), argument handling |
| `cloud-discover.bats` | 21 | Profile discovery, env/project/access auto-detection, account ID masking, JSON schema |
| `k8s-dashboard.bats` | 12 | K8s dashboard, cluster info, namespace display, profile filtering |
| `prompt-hook.bats` | 8 | Command routing (`/aws`, `/k8s`, `/cloud-setup`), not-configured fallback |
| `setup.bats` | 10 | Flag parsing, JSON merge, file integrity, settings validation |
| `cloud-guard.bats` | 52 | Safety guard hook: read-only cloud commands allowed, destructive ones blocked |
| `scenario.bats` | 7 | Skill structure, scenario schema, MCP grounding tier, optimistic/pessimistic paths |
| `e2e-run.bats` | 9 | Skill structure, runner detection, no-live-browser guard, Hurl/Schemathesis extensions |
| `eval.bats` | 7 | Skill structure, golden-task/baseline/thresholds schema, oracle rule |
| `decision-log.bats` | 5 | Locked D-NNN schema, `/setup` scaffolding, living-log rules |
| `bitbucket-review.bats` | 6 | Skill structure, helper compiles, credential guard, env-file fallback, unified-diff line mapping |

## Uninstall

```bash
./uninstall.sh                # Remove both
./uninstall.sh --claude       # Claude Code only
./uninstall.sh --copilot      # Copilot CLI only
```

Removes rules, commands, and agents. Does NOT touch CLAUDE.md, settings.json, or plugins (those may have manual edits). Backups are in `~/.claude/backups/`.

---

## Project Structure

```
ai-devkit/
├── setup.sh                         # Unified install + update (--claude | --copilot | --all | --check | --no-pull | --permissions)
├── release.sh                       # Cut a new release (maintainer only)
├── uninstall.sh                     # Unified uninstall (same flags)
├── VERSION                          # Current semantic version
├── CHANGELOG.md                     # Release history
├── CLAUDE.md                        # Shared global instructions (both tools)
├── LICENSE                          # MIT
│
├── claude/                          # Claude Code specific
│   ├── settings.template.json       # Hooks, plugins, MCP servers
│   ├── rules/                       # 14 coding standard files
│   ├── commands/                    # 7 slash commands
│   ├── agents/                      # 3 specialized agents
│   ├── skills/                      # 16 skills (subfolders + references)
│   │   ├── setup/SKILL.md         #   /setup — scaffold /docs + optional /init for brownfield
│   │   ├── discover/                #   /discover — structured product discovery
│   │   │   ├── SKILL.md
│   │   │   └── references/product-spec-schema.md
│   │   ├── product-spec/SKILL.md    #   /product-spec — generate spec
│   │   ├── research/SKILL.md        #   /research — per-decision research → docs/analyzes/
│   │   ├── save-plan/               #   /save-plan — bridge /plan mode → docs/ (initiative OR roadmap)
│   │   │   ├── SKILL.md
│   │   │   └── references/roadmap-shape.md  # top-down vs initiative-shape contract
│   │   ├── atomize/                 #   /atomize — plan → tasks (initial + reconciliation)
│   │   │   ├── SKILL.md
│   │   │   └── references/task-schema.md
│   │   ├── implement/               #   /implement — execute tasks with phased gates + frontmatter writeback
│   │   │   ├── SKILL.md
│   │   │   └── references/runner-detection.md + commit-policy.md
│   │   ├── agents-md/               #   /agents-md — author AGENTS.md with anchored content
│   │   │   ├── SKILL.md
│   │   │   └── references/test-of-inclusion.md
│   │   ├── rule-review/             #   /rule-review — audit rules file across 7 dimensions
│   │   │   ├── SKILL.md
│   │   │   └── references/dimensions.md
│   │   ├── open-web/SKILL.md        #   /open-web — Playwright MCP browser bridge (auth-walled / JS-rendered pages)
│   │   ├── scenario/                #   /scenario — author E2E scenarios → committed Playwright tests
│   │   │   ├── SKILL.md
│   │   │   └── references/scenario-schema.md
│   │   ├── e2e-run/                 #   /e2e-run — run scenarios with the right tool (Playwright; Hurl/Schemathesis opt-in)
│   │   │   ├── SKILL.md
│   │   │   ├── references/runner-detection.md
│   │   │   └── extensions/          #   api-hurl + api-schemathesis (opt-in API runners)
│   │   ├── bitbucket-review/        #   /bitbucket-review — Claude code review for Bitbucket PRs via REST API
│   │   │   ├── SKILL.md
│   │   │   ├── scripts/bb_review.py #     API I/O + unified-diff line mapping (stdlib only)
│   │   │   └── references/review-rubric.md + bitbucket-api.md
│   │   ├── eval/                    #   /eval — golden-task eval harness (regressions on model/harness change)
│   │   │   ├── SKILL.md
│   │   │   └── references/eval-schema.md
│   │   ├── repo-map/                #   /repo-map — evidence-based map of an unfamiliar repo (Wide Scan)
│   │   │   ├── SKILL.md
│   │   │   └── references/signal-recipes.md + repo-map-schema.md
│   │   └── ci-setup/                #   /ci-setup — CI pipeline: lint+test+coverage gate (+ optional AI review)
│   │       ├── SKILL.md
│   │       └── references/ci-recipes.md + ai-reviewers.md + coverage-codecov.md
│   └── scripts/                     # 10 scripts (wrappers, dashboards, hooks, project init, docs/work rollup)
│       ├── awscmd.sh                #   AWS CLI wrapper (MFA + role assumption)
│       ├── kubecmd.sh               #   kubectl/helm wrapper (EKS auth)
│       ├── aws-dashboard.sh         #   AWS environment dashboard
│       ├── k8s-dashboard.sh         #   K8s environment dashboard
│       ├── cloud-discover.sh        #   AWS profile discovery (JSON output)
│       ├── cloud-setup.sh           #   Interactive setup wizard (standalone)
│       ├── cloud-guard.sh           #   PreToolUse cloud guard (AWS/kubectl/helm write-ops; git/rm patterns live in the inline settings hook)
│       ├── prompt-hook.sh           #   UserPromptSubmit hook (dashboard injection)
│       ├── init-project-permissions.sh  # Per-project .claude/settings.json (M1L3 policy)
│       └── regenerate-status.sh     #   docs/work/STATUS.md rebuilder (called by save-plan/atomize/implement/setup)
│
├── evals/                           # /eval fixtures for ai-devkit itself
│   └── triggers.json                #   Skill-routing discrimination cases (adversarial negatives, /eval Step 3.5)
│
├── tests/                           # BATS unit tests (181 tests, 13 files)
│   ├── test_helper.bash             #   Shared setup: temp dirs, mock configs
│   ├── aws-dashboard.bats           #   Dashboard rendering, MFA status
│   ├── awscmd.bats                  #   Profile validation, security
│   ├── bitbucket-review.bats        #   PR review skill: creds guard, diff line mapping
│   ├── cloud-discover.bats          #   Profile discovery, auto-detection
│   ├── cloud-guard.bats             #   Cloud write-op blocking (AWS/kubectl/helm)
│   ├── decision-log.bats            #   D-NNN decision-log convention
│   ├── e2e-run.bats                 #   Scenario runner scoping
│   ├── eval.bats                    #   Eval harness: schema, oracle rule, triggers fixture
│   ├── k8s-dashboard.bats           #   K8s dashboard, namespaces
│   ├── prompt-hook.bats             #   Command routing
│   ├── safety-guard.bats            #   Inline git/rm guard: blocked + allowed pairs
│   ├── scenario.bats                #   Scenario authoring skill
│   └── setup.bats                   #   Setup integrity, JSON merge, dotnet rule wiring
│
└── copilot/                         # Copilot CLI specific
    ├── install-to-repo.sh           # Install instructions into a repo
    ├── mcp-config.json              # MCP server config
    ├── agents/                      # 5 agents (Copilot format)
    │   ├── aws.md                   #   AWS dashboard + commands
    │   ├── k8s.md                   #   K8s dashboard + commands
    │   ├── security-reviewer.md     #   Security analysis
    │   ├── build-resolver.md        #   Build error resolution
    │   └── performance-analyzer.md  #   Performance bottleneck detection
    ├── hooks/                       # hooks.json (per-repo)
    ├── instructions/                # 11 instruction files (per-repo)
    └── prompts/                     # 18 prompt templates (copy-paste): ship, retro, changelog, threat-model, init-permissions, setup, discover, product-spec, research, save-plan, atomize, implement, agents-md, rule-review, bitbucket-review, scenario, e2e-run, eval
```
