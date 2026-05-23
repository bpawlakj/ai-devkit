You are a project-permission initializer. Drop a canonical `.claude/settings.json` (per-project Claude Code permission policy, per M1L3 of 10xDevs 3.0) into the current working directory so the agent stops asking about every routine command but never gets a blanket waiver on dangerous ones.

The contract is `Claude Code permissions`: `allow` runs without asking, `ask` pauses for confirmation, `deny` blocks unconditionally. Evaluation order is **deny → ask → allow**, first match wins. Wildcards (`*`) only match within the `Bash(...)` argument string.

## What this command does NOT do

- Does NOT modify `~/.claude/settings.json` (the global one — that's installed by `ai-devkit setup.sh`).
- Does NOT write `.claude/settings.local.json` (that file is machine-specific and should stay gitignored).
- Does NOT push, deploy, or run anything destructive.
- Does NOT decide what language stack you're using — it asks once and customizes.

## Process

### Step 0: Verify cwd looks like a project root

Run `pwd` and check whether the cwd has at least one of: `.git`, `package.json`, `pyproject.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Cargo.toml`, `composer.json`, `Package.swift`, `mix.exs`, `Gemfile`, `.csproj`. If none, ask: "Current directory `<pwd>` does not look like a project root. Continue anyway?" — default: no.

### Step 1: Check for existing `.claude/settings.json`

If `<cwd>/.claude/settings.json` already exists:

AskUserQuestion:
- question: "`<cwd>/.claude/settings.json` already exists. What to do?"
  header: "Existing file"
  options:
  - label: "Backup + overwrite (Recommended)"
    description: "Save current to `.claude/settings.json.bak-YYYYMMDD-HHMMSS`, then write canonical."
  - label: "Merge"
    description: "Add missing entries to each of allow/ask/deny without overwriting existing ones."
  - label: "Show diff first"
    description: "Print canonical vs current side-by-side, then re-ask."
  - label: "Cancel"
    description: "Exit without changes."

If `<cwd>/.claude/` doesn't exist, `mkdir -p .claude/` silently.

### Step 2: Ask about stack additions (one prompt)

The base policy below covers Node.js / Python / Go / Rust / Java / PHP / Swift / .NET / Ruby / Elixir tool families + local git. Some categories are not on by default because they imply infrastructure access. Ask which to add:

AskUserQuestion (multiSelect: true):
- question: "Include these additional categories in the `ask` list?"
  header: "Extras"
  options:
  - label: "Docker"
    description: "`docker *`, `docker compose *`, `docker-compose *` — for containerized builds and deploy."
  - label: "SSH / SCP / rsync"
    description: "Remote deploy targets."
  - label: "Cloud CLIs"
    description: "`aws *`, `gcloud *`, `az *`, `kubectl *`, `helm *`, `terraform *`."
  - label: "Database CLIs"
    description: "`psql *`, `mysql *`, `redis-cli *`, `mongosh *`."

Selected categories get appended to the `ask` array.

### Step 3: Write the file

Write `<cwd>/.claude/settings.json` with this canonical content (omit categories the user didn't select):

```json
{
  "permissions": {
    "allow": [
      "Bash(pnpm *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(yarn *)",
      "Bash(node *)",
      "Bash(python *)",
      "Bash(python3 *)",
      "Bash(pip *)",
      "Bash(pip3 *)",
      "Bash(uv *)",
      "Bash(poetry *)",
      "Bash(pipx *)",
      "Bash(go *)",
      "Bash(mvn *)",
      "Bash(./gradlew *)",
      "Bash(gradle *)",
      "Bash(cargo *)",
      "Bash(rustc *)",
      "Bash(composer *)",
      "Bash(php *)",
      "Bash(./vendor/bin/* *)",
      "Bash(swift *)",
      "Bash(mix *)",
      "Bash(iex *)",
      "Bash(bundle *)",
      "Bash(rake *)",
      "Bash(rails *)",
      "Bash(dotnet *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git status *)",
      "Bash(git branch *)",
      "Bash(git checkout *)",
      "Bash(git stash *)",
      "Read",
      "Edit",
      "Write"
    ],
    "ask": [
      "Bash(curl *)",
      "Bash(wget *)",
      "Bash(git push *)",
      "Bash(git push)"
    ],
    "deny": [
      "Bash(rm -rf *)"
    ]
  }
}
```

Append to `ask` based on Step 2 selections:

- **Docker**: `Bash(docker *)`, `Bash(docker compose *)`, `Bash(docker-compose *)`.
- **SSH / SCP / rsync**: `Bash(ssh *)`, `Bash(scp *)`, `Bash(rsync *)`.
- **Cloud CLIs**: `Bash(aws *)`, `Bash(gcloud *)`, `Bash(az *)`, `Bash(kubectl *)`, `Bash(helm *)`, `Bash(terraform *)`.
- **Database CLIs**: `Bash(psql *)`, `Bash(mysql *)`, `Bash(redis-cli *)`, `Bash(mongosh *)`.

Preserve key order (`allow`, `ask`, `deny`). One entry per line, sorted within each list. Two-space indentation.

### Step 4: Suggest gitignore entry (if `.gitignore` exists)

If `<cwd>/.gitignore` exists, grep for `.claude/settings.local.json`. If absent, ask:

```
.claude/settings.json is the TEAM policy — should be committed.
.claude/settings.local.json is the PER-MACHINE override — should NOT be committed.

Add `.claude/settings.local.json` to .gitignore?
```

Default: yes. If yes, append `.claude/settings.local.json` to `.gitignore` (under a `# Claude` section if one exists, else at the end).

### Step 5: Print summary

```
Wrote .claude/settings.json (<N> allow, <M> ask, 1 deny).

Order of evaluation: deny -> ask -> allow (first match wins).
Restart Claude Code in this directory or run /reset-permissions for the file to take effect.

Tune later by editing .claude/settings.json directly:
- Add patterns to "allow" if you find yourself approving the same Bash repeatedly.
- Move patterns to "deny" when you see something you never want.
- Keep "ask" as the safety net for anything new.

Reference: M1L3 of 10xDevs 3.0 ("AI-Powered Bootstrap: boilerplate i bezpieczna praca z Agentem").
```

## Edge cases

- **Merge mode (Step 1)**: read existing file's allow/ask/deny arrays, union with canonical, write back. Preserve any keys outside `permissions` (e.g. user-added hooks).
- **Existing file is invalid JSON**: surface the error, default to backup + overwrite.
- **Project root has `.claude/settings.json` already + `.claude/settings.local.json` already**: only touch the first; the second is the user's per-machine layer, never edited by this command.
- **No `.git` in cwd**: still works; user gets the policy file without git context. Suggest `git init` in summary if appropriate.

## Why these defaults

The `allow` list covers local-only operations that never reach a remote or destroy data:
- Package managers (pnpm/npm/yarn/pip/poetry/uv/cargo/composer/bundle/mix) — install / run scripts in the project.
- Compilers / runtimes (node/python/go/swift/dotnet/rustc/iex) — execute project code.
- Local git operations — read state, stage, commit, switch branches, stash.
- Built-in file tools (`Read`, `Edit`, `Write`) — agent's primary way to touch the codebase.

The `ask` list covers operations with external effect:
- `curl` / `wget` — network egress (potential exfiltration vector).
- `git push` — publishes to a remote.
- Optional: docker (image build/run side effects), ssh/scp (remote shell), cloud CLIs (provisioning), database CLIs (data mutation).

The `deny` list is intentionally minimal: one unconditional block on recursive force-delete patterns. The agent cannot recover from `rm -rf <path>` errors, so we remove the option entirely. Add more `deny` patterns as you discover specific dangerous commands in your workflow.

This policy is **probabilistic**, not absolute (per M1L3 caveat). It raises the cost of mistakes and gives the user a chance to intervene; it does not prevent a determined model from finding workarounds. Pair with version control discipline, isolated dev environments, and limited credentials.
