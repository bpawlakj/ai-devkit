# Init-Permissions — Per-Project Permission Policy (Copilot CLI / Codex / Cursor)

Paste this prompt to Copilot CLI (or its analog) to drop a per-project permission policy in the current directory. The Claude Code-specific version (`.claude/settings.json`) is the canonical one; this prompt produces the closest equivalent for other agent harnesses.

---

You are a permission-policy initializer. The user wants their agent (Copilot CLI / Codex / Cursor) configured to allow routine local operations without asking, ask before network or remote side-effects, and unconditionally block recursive force-delete.

## Process

### Step 0: Detect harness

Read environment to determine which agent is running. Look for:

- `~/.codex/config.toml` exists → **Codex CLI**.
- `~/.cursor/permissions.json` exists or env var `CURSOR_TRACE_ID` present → **Cursor**.
- Otherwise → assume **Copilot CLI** (per-project hook scripts under `.github/hooks/`).

Print which one was detected, then proceed to the relevant section.

### Step 1A: Codex CLI

Codex policy lives in `~/.codex/config.toml`. Write or update:

```toml
[sandbox]
mode = "workspace-write"

[approvals]
mode = "on-request"
```

Translation:
- `workspace-write`: agent can read freely + write within the workspace, but not outside. Maps roughly to Claude Code's `Bash(... in cwd ...)` allow.
- `on-request`: ask before executing risky operations (network, shell escapes, system-wide writes).

If the file exists, merge — preserve other sections (`[features]`, `[memories]`, etc.). Back up to `~/.codex/config.toml.bak-<timestamp>` before edit.

### Step 1B: Cursor

Cursor permissions: `~/.cursor/permissions.json`. Skeleton:

```json
{
  "allow": [
    "pnpm:*", "npm:*", "yarn:*", "node:*",
    "python:*", "uv:*", "poetry:*",
    "go:*", "cargo:*", "mvn:*", "gradle:*",
    "composer:*", "swift:*", "dotnet:*", "mix:*", "bundle:*",
    "git:add", "git:commit", "git:diff", "git:log", "git:status",
    "git:branch", "git:checkout", "git:stash"
  ],
  "ask": [
    "curl:*", "wget:*",
    "git:push"
  ],
  "deny": [
    "shell:rm:-rf:*"
  ]
}
```

The actual JSON schema differs across Cursor versions — adjust to whatever the local install accepts. Cursor's official permissions file format is documented at `cursor.com/docs/agent/security`. Best-effort only.

### Step 1C: Copilot CLI (per-repo hooks)

Copilot CLI doesn't have a centralized permission file equivalent to Claude or Codex. The closest mechanism is per-repo `.github/hooks/` scripts (already used by ai-devkit's safety guard). Add or update `.github/hooks/pretool.sh` with:

```bash
#!/usr/bin/env bash
# Block recursive force-delete unconditionally.
input=$(cat)
if echo "$input" | grep -qE 'rm[[:space:]]+-rf[[:space:]]+(/|~|\.|\*)'; then
  echo "BLOCKED: dangerous recursive force-delete detected." >&2
  exit 2
fi

# Ask before push, network egress, remote shell.
if echo "$input" | grep -qE '(git[[:space:]]+push|curl[[:space:]]|wget[[:space:]]|ssh[[:space:]]|scp[[:space:]]|docker[[:space:]])'; then
  read -p "About to run a side-effect command. Continue? (y/N) " ans
  [[ "$ans" =~ ^[Yy]$ ]] || exit 2
fi

exit 0
```

`chmod +x .github/hooks/pretool.sh`. Configure Copilot CLI to point at this hook per its current mechanism.

### Step 2: Print summary

```
Detected harness: <name>
Written: <path>
Policy summary:
  - Local package/runtime tools allowed without asking.
  - Local git operations allowed.
  - Network egress (curl/wget) requires confirmation.
  - git push requires confirmation.
  - Recursive force-delete blocked unconditionally.

Restart your agent for the policy to take effect.
```

## Why the Claude Code version is the canonical one

Claude Code's per-project `.claude/settings.json` has the cleanest model: explicit `allow` / `ask` / `deny` arrays, glob-pattern matching on `Bash(...)` argument strings, deterministic evaluation order (`deny → ask → allow`, first match wins). Other harnesses approximate this with different vocabularies and weaker guarantees.

If your team uses Claude Code AND another harness, write `.claude/settings.json` first (the source of truth), then translate to the secondary harness's format with this prompt.

The underlying philosophy is from 10xDevs 3.0 Module 1 Lesson 3 (M1L3, "AI-Powered Bootstrap: boilerplate i bezpieczna praca z Agentem"): permission policy is a probabilistic safeguard, not an absolute one. It raises mistake cost and gives the user a chance to intervene; it does not prevent a determined model from finding workarounds. Pair with version control, isolated environments, and least-privilege credentials.
