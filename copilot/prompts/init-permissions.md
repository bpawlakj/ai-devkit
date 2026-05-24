# Init-Permissions — Per-Project Permission Policy

Per-project permission policy is **environment configuration** — it has to exist on disk before the agent starts the session it controls. That makes a slash command the wrong shape; this work is done by a shell script.

## Claude Code (canonical)

```bash
# Run inside your project directory:
bash ~/.claude/scripts/init-project-permissions.sh

# Or from the ai-devkit checkout:
~/ai-devkit/setup.sh --permissions /path/to/project
~/ai-devkit/update.sh --permissions /path/to/project

# Forward flags:
bash ~/.claude/scripts/init-project-permissions.sh --minimal     # base only, no docker/ssh/cloud/db extras
bash ~/.claude/scripts/init-project-permissions.sh --force       # overwrite without prompting
bash ~/.claude/scripts/init-project-permissions.sh --dry-run     # print, do not write
bash ~/.claude/scripts/init-project-permissions.sh --yes         # answer yes to all prompts
```

The script writes `<project>/.claude/settings.json` with the M1L3 policy from 10xDevs 3.0:

- **allow**: routine local operations (pnpm/npm/yarn/node, python/uv/poetry/pip, go, mvn/gradle, cargo, composer/php, swift, dotnet, mix, bundle/rails) plus all local git commands and Claude Code's `Read`/`Edit`/`Write` primitives.
- **ask**: network egress (`curl`, `wget`), `git push`, and (unless `--minimal`) docker, ssh/scp/rsync, cloud CLIs (aws/gcloud/az/kubectl/helm/terraform), database CLIs (psql/mysql/redis-cli/mongosh).
- **deny**: recursive force-delete unconditionally.

Order of evaluation is `deny → ask → allow`, first match wins.

The script also offers to append `.claude/settings.local.json` to `.gitignore` so the team policy commits while machine-specific overrides stay local.

## Codex CLI (approximation)

Codex uses TOML configuration at `~/.codex/config.toml`:

```toml
[sandbox]
mode = "workspace-write"

[approvals]
mode = "on-request"
```

This is per-installation, not per-project. The semantics:

- `workspace-write`: agent reads freely + writes within the workspace, blocked outside.
- `on-request`: pause for confirmation on network/shell-escape/system-wide operations.

Closest behavioral equivalent to Claude Code's allow/ask/deny. Edit the file directly; no equivalent shell helper ships with ai-devkit yet.

## Cursor (approximation)

Cursor uses JSON at `~/.cursor/permissions.json`. Schema varies across Cursor versions — refer to `cursor.com/docs/agent/security`. Cursor's docs warn that allowlists are best-effort, not absolute.

## Copilot CLI (approximation)

Copilot CLI doesn't have a centralized permission file. Closest mechanism is per-repo `.github/hooks/` scripts (ai-devkit already ships a safety guard there). Add or update `.github/hooks/pretool.sh`:

```bash
#!/usr/bin/env bash
input=$(cat)
# Block recursive force-delete unconditionally.
if echo "$input" | grep -qE 'rm[[:space:]]+-rf[[:space:]]+(/|~|\.|\*)'; then
    echo "BLOCKED: dangerous recursive force-delete" >&2
    exit 2
fi
# Ask before push, network egress, remote shell.
if echo "$input" | grep -qE '(git[[:space:]]+push|curl[[:space:]]|wget[[:space:]]|ssh[[:space:]]|scp[[:space:]]|docker[[:space:]])'; then
    read -p "About to run a side-effect command. Continue? (y/N) " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 2
fi
exit 0
```

`chmod +x .github/hooks/pretool.sh`. Configure Copilot CLI to point at this hook per its current docs.

## Why a script and not a slash command

A slash command runs *inside* a Claude session. The agent that needs the policy file is the agent that has to write it — and at that moment the OLD policy (or default) is already governing what the agent can do. That's a chicken-and-egg situation for first-time setup: you can't safely bootstrap restrictions from inside the thing being restricted.

A shell script runs *outside* the agent. The file lands on disk, then you start the agent in that directory and the policy is in effect from message zero. This is the same reason `~/.claude/settings.json` (global) is installed by `setup.sh`, not by Claude Code talking to itself.

## Why the Claude Code version is canonical

Claude Code has the cleanest permission model: explicit `allow` / `ask` / `deny` arrays, glob-pattern matching on `Bash(...)` argument strings, deterministic evaluation order (`deny → ask → allow`, first match wins). Other harnesses approximate this with different vocabularies and weaker guarantees.

If your team uses Claude Code AND another harness, write `.claude/settings.json` first (the source of truth), then translate to the secondary harness's format with the snippets above.

Underlying philosophy from M1L3 of 10xDevs 3.0 ("AI-Powered Bootstrap: boilerplate i bezpieczna praca z Agentem"): permission policy is a **probabilistic** safeguard, not an absolute one. It raises mistake cost and gives the user a chance to intervene; it does not prevent a determined model from finding workarounds. Pair with version control, isolated environments, and least-privilege credentials.
