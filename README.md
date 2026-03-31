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

---

## What's Inside

### Rules — Coding Standards (9 files)

Auto-activate based on file type. Enforce language/framework best practices without manual setup.

| Rule | Activates On | What It Enforces |
|---|---|---|
| **security** | `*.java`, `*.py`, `*.swift`, `*.ts`, `*.js`, `*.yml`, `.env*` | OWASP checklist, STRIDE threat model, secrets management, injection prevention, dependency scanning |
| **java** | `*.java` | Records, sealed classes, Optional usage, immutability (`final`, `List.copyOf()`), modern Java 17+ patterns, JUnit 5 + AssertJ + Mockito + Testcontainers |
| **spring-boot** | `*.java`, `application*.yml`, `pom.xml`, `build.gradle*` | Layered architecture, constructor injection, record DTOs with Bean Validation, `@ControllerAdvice`, Spring Security (JWT, CSRF, CORS), Testcontainers |
| **python** | `*.py`, `*.pyi` | PEP 8, type annotations, `Protocol` duck typing, frozen dataclasses, ruff, pytest with marks, 80% coverage |
| **typescript** | `*.ts`, `*.tsx`, `*.js`, `*.jsx` | `unknown` over `any`, Zod validation, interface vs type, error narrowing, Vitest/Playwright |
| **react** | `*.tsx`, `*.jsx` | Custom hooks, composition patterns, `useMemo`/`useCallback`, error boundaries, accessibility (ARIA, focus), key stability |
| **angular** | `*.ts`, `*.html`, `angular.json` | Standalone components, OnPush, signals, RxJS (`async` pipe, `takeUntilDestroyed`), reactive forms, TestBed |
| **node** | `*.ts`, `*.js`, `package.json` | REST API design, N+1 prevention, Redis caching, Bull queues, rate limiting, structured logging, Zod/Joi validation |
| **swift-ios** | `*.swift`, `Package.swift` | Swift 6 concurrency (`Sendable`, actors), protocol-oriented design, typed throws, Keychain, SwiftFormat, Swift Testing |

---

### Commands — Slash Commands (4 files)

Type these directly in Claude Code. For Copilot CLI, use the prompt templates in `copilot/prompts/`.

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

### Agents — Specialized AI Roles (3 files)

Focused agents that can be invoked for specific tasks.

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

### Hooks — Auto-Triggers (5 hooks)

Run automatically after file edits or before dangerous commands.

| Hook | Trigger | Action |
|---|---|---|
| **ruff** | Edit `*.py` | Auto-lint with `ruff check --fix` |
| **google-java-format** | Edit `*.java` | Auto-format |
| **swiftformat** | Edit `*.swift` | Auto-format |
| **prettier** | Edit `*.ts`/`*.tsx`/`*.js`/`*.jsx` | Auto-format |
| **safety guard** | Any shell command | Blocks `--no-verify`, `push --force` (allows `--force-with-lease`), `reset --hard`, dangerous `rm -rf` |

All formatter hooks use `command -v` guards — silently skip if the tool isn't installed.

---

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
| Agents | `~/.claude/agents/` (global) | `~/.copilot/agents/` (global) |
| Hooks | `~/.claude/settings.json` (global) | `.github/hooks/` (per-repo) |
| MCP | `~/.claude/settings.json` (global) | `~/.copilot/mcp-config.json` (global) |

### Installing Instructions Into a Repo

```bash
# All languages + security
./copilot/install-to-repo.sh /path/to/project

# Only specific languages (security always included)
./copilot/install-to-repo.sh /path/to/project --languages java,python

# Available: java, spring-boot, python, typescript, react, angular, node, swift-ios
```

This copies `.instructions.md` files to `.github/instructions/` and hooks to `.github/hooks/`. Commit them to share with your team, or add to `.gitignore` for personal use.

### Using Prompts (Slash Command Replacement)

Copilot CLI doesn't support custom slash commands yet. Copy-paste from `copilot/prompts/`:

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
brew install gh                      # GitHub CLI (for /ship)
apt install jq                       # JSON merge in setup script
```

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
├── setup.sh                         # Unified setup (--claude | --copilot | --all)
├── uninstall.sh                     # Unified uninstall (same flags)
├── CLAUDE.md                        # Shared global instructions (both tools)
├── LICENSE                          # MIT
│
├── claude/                          # Claude Code specific
│   ├── settings.template.json       # Hooks, plugins, MCP servers
│   ├── rules/                       # 9 coding standard files
│   ├── commands/                    # 4 slash commands
│   └── agents/                      # 3 specialized agents
│
└── copilot/                         # Copilot CLI specific
    ├── install-to-repo.sh           # Install instructions into a repo
    ├── mcp-config.json              # MCP server config
    ├── agents/                      # 3 agents (Copilot format)
    ├── hooks/                       # hooks.json (per-repo)
    ├── instructions/                # 9 instruction files (per-repo)
    └── prompts/                     # 4 prompt templates (copy-paste)
```
