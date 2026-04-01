# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
