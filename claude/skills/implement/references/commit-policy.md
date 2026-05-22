# Commit Policy (canonical reference)

`/implement` Step 6 follows the rules below when committing a finished task. The goal is one commit per atomic task, with a deterministic message format that makes `index.md` and `git log` mutually intelligible.

## Staging rules

- **Never `git add -A` or `git add .`** — these sweep up unrelated changes from concurrent work.
- Stage only files explicitly touched by the current task. Track them via the file list maintained internally during Steps 4–5.
- If an Edit / Write tool touched a file not in `## Scope`, the skill flags it BEFORE staging. The user decides: include, revert, or split into a follow-up task.
- Generated files (lockfiles, `.next/`, `dist/`, `target/`) — include only if the task's `## Scope` explicitly says so. Otherwise check `.gitignore` is doing its job; do not commit accidentally.

## Message template

```
<task-id>: <task title from frontmatter>

<one-paragraph what + why, derived from ## Scope and ## Acceptance.
Wrap at 72 cols.>

Refs: docs/work/<NNN>-<slug>/<task-file>.md
```

Examples:

```
T-003: Add OTel exporter for traces

Wires the OpenTelemetry SDK we added in T-001 to an OTLP/gRPC exporter
pointed at the collector configured in T-002. Behind feature flag
TRACING_ENABLED; off by default. Adds an integration test that asserts
spans land in an in-memory collector.

Refs: docs/work/004-observability-otel/T-003-otel-exporter.md
```

```
T-007: Refactor session repository to record-based DTOs

Replaces the bean-style SessionRow class with a record (Java 17),
removes setters and adds compact constructor validation. No behavior
change; existing tests pass unmodified.

Refs: docs/work/002-attendance/T-007-record-dtos.md
```

## What the message MUST NOT contain

- `🤖 Generated with Claude Code` / `Co-Authored-By: Claude` footers — unless the user opts in once per session.
- Markdown formatting beyond what `git log` renders sensibly (no bullets, no fenced code blocks).
- References to tickets / PRs that don't exist yet.
- The user's name unless the user wrote it.

## Amend policy

Never amend after the frontmatter has been written back (Step 7). If acceptance criteria fail after commit:

1. Do NOT `git commit --amend`.
2. Open a follow-up task: `T-NNN-followup-<id>` with `depends_on: [<original-id>]`. Restart from Step 1.

If the user explicitly asks to amend (typo in message, accidentally left a comment), allow it BEFORE Step 7's frontmatter writeback. After writeback, amending desyncs the `commit:` field from history.

## Hook handling

If a pre-commit hook fails:
- Read the hook output.
- If it's a linter / formatter that auto-fixed files (`gofmt -w`, `prettier --write`, `ruff format`), stage the changes and retry the commit once.
- If it's a check that failed without auto-fix (lint error, type error), STOP and surface the failure. Do not bypass with `--no-verify`.
- If the hook is environment-specific (e.g. `pre-commit-config.yaml` missing on this machine) and the user explicitly asks, allow `--no-verify` with a one-time confirmation.

## Branch policy

- Branch naming default: `<initiative-slug>/<task-id>` for single-task mode, `<initiative-slug>` for initiative mode.
- Branches off `main` (or the repo's default branch). The skill reads `git symbolic-ref refs/remotes/origin/HEAD` to detect; falls back to `main`.
- Branch is created at Step 2.2, NOT auto-deleted at Step 8. User decides via separate `/ship` flow or manual merge.

## Push policy

`/implement` never pushes. Push is an explicit user action or part of a `/ship` flow. This matches the M1L3 permission policy (`Bash(git push *)` in `ask`, not `allow`).
