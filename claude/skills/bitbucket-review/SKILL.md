---
name: bitbucket-review
description: >
  Automated Claude code review for a Bitbucket Cloud pull request, driven by
  the Bitbucket REST API. Fetches PR metadata + the unified diff over the API
  (no local clone required), runs a structured Claude review (correctness +
  reuse/simplification/efficiency, optional security pass), prints findings in
  chat, and — opt-in — posts them back to the PR as inline or summary comments.
  Auth is via API token (App Passwords are deprecated/disabled 2026-06-09).
  Bridges the gap that /code-review --comment only covers GitHub: this is the
  Bitbucket equivalent. Posting defaults to OFF so a run never silently writes
  to a shared PR. Trigger phrases: "review this Bitbucket PR", "bitbucket pull
  request review", "review PR <url>", "/bitbucket-review <url>".
---

# /bitbucket-review — Claude code review for Bitbucket PRs

`/code-review --comment` posts inline review comments, **but only for GitHub PRs**.
Bitbucket Cloud has no equivalent in the toolkit. This skill is that equivalent: it
pulls a PR's diff over the Bitbucket REST API, has Claude review it, and (when asked)
posts the findings back to the PR.

The split of labour is deliberate:
- **Claude** does the reasoning — reads the diff, finds bugs, judges severity.
- **`scripts/bb_review.py`** (Python stdlib, no pip) does the deterministic plumbing —
  API calls, the `/diff` redirect, pagination, 429 backoff, and unified-diff line mapping
  (so inline comment anchors are always valid).

## When to use, when to skip

**Use when**:
- You want a Claude review of a Bitbucket Cloud PR without cloning + checking out branches by hand.
- You want findings posted back to the PR (inline or as one summary comment).

**Skip when**:
- The PR is on GitHub → use `/code-review <PR#> --comment` (native support).
- You want Bitbucket's own AI review (Atlassian's model, acceptance-criteria checks) → enable
  **Rovo Dev code review** in the repo instead; this skill is the Claude alternative, not a wrapper for it.
- You only need to read the PR page (description, discussion, CI) → use `/open-web`.

## Invocation

```
/bitbucket-review <PR-url | workspace/repo PR-id> [flags]
```

Both forms resolve to the same `workspace`, `repo`, `pr_id`:
- `https://bitbucket.org/sl-technology/sl-etsl-authorsuite/pull-requests/2651`
- `sl-technology/sl-etsl-authorsuite 2651`

Flags:
- `--comment` — post each finding as an **inline** comment on the diff. **Opt-in.**
- `--summary-comment` — post **one** aggregated markdown comment instead of inline.
- `--security` — add a security-focused review pass (auth, input handling, secrets, injection).
- `--effort low|med|high|max` — review depth. Default `high`.
- `--repo <path>` — path to a local clone; lets review agents read **full files** for context the raw diff lacks.

Default (no `--comment`/`--summary-comment`) = **preview in chat only**.

## Process

### Step 0: Preflight

Check the helper is reachable and credentials exist. Credentials live in
`~/.claude/bitbucket-review.env` (written by `./setup.sh --bitbucket-creds`); source it if present:

```bash
SKILL_DIR="$HOME/.claude/skills/bitbucket-review"   # installed location
BB="$SKILL_DIR/scripts/bb_review.py"
command -v python3 >/dev/null || { echo "python3 required"; exit 1; }
[ -f "$HOME/.claude/bitbucket-review.env" ] && . "$HOME/.claude/bitbucket-review.env"
test -n "$BITBUCKET_EMAIL" && test -n "$BITBUCKET_API_TOKEN" || echo "MISSING_CREDS"
```

(`bb_review.py` also loads that env file itself as a fallback, so the helper works even when invoked
directly. You do not need to edit your shell profile.)

If `MISSING_CREDS`, print this and **STOP** — do not proceed:

```
Bitbucket credentials not set. This skill authenticates with an API token
(App Passwords are deprecated — disabled 2026-06-09).

  Quickest:  ./setup.sh --bitbucket-creds
             (prompts for email + token, writes ~/.claude/bitbucket-review.env, chmod 600)

  Manual:    1. Atlassian account → Settings → Security → API tokens → Create
             2. Scopes: "read repository" + "read & write pull request"
             3. export BITBUCKET_EMAIL="you@example.com"
                export BITBUCKET_API_TOKEN="<token>"
  Then re-run /bitbucket-review.
```

(When running from this repo during development, point `BB` at
`claude/skills/bitbucket-review/scripts/bb_review.py` instead.)

### Step 1: Parse arguments

Extract `workspace`, `repo`, `pr_id` from the URL or short form. Parse the flags listed above.
The script takes the repo as a single `workspace/repo` argument.

### Step 2: Fetch PR metadata

```bash
python3 "$BB" meta "$WORKSPACE/$REPO" "$PR_ID"
```

Read `state`, `source`, `destination`, `title`, `author`, `url`. If `state` is not `OPEN`,
warn the user ("PR is <state> — review anyway?") and let them decide before continuing.

### Step 3: Fetch the diff + changed-file overview

```bash
OUT="${TMPDIR:-/tmp}/bb-review"; mkdir -p "$OUT"
python3 "$BB" diff "$WORKSPACE/$REPO" "$PR_ID" --out "$OUT/pr-$PR_ID.diff"
python3 "$BB" diffstat "$WORKSPACE/$REPO" "$PR_ID" > "$OUT/pr-$PR_ID.diffstat.json"
```

Print the changed-file overview (path, status, +/- counts) so the user sees scope before review.
If the diff is empty, STOP and report it.

### Step 4: Review

Spawn review subagent(s) via the `Agent` tool, each handed `references/review-rubric.md` and the
diff file path. Run them in a single message when there is more than one (parallel):

- **Always**: a correctness + reuse/simplification/efficiency reviewer.
- **`--security`**: an additional security reviewer.
- For large diffs, partition by file across multiple correctness reviewers.

Each subagent MUST return findings as a JSON array matching the schema in the rubric:
`{path, new_line, severity, title, body, suggestion?}`. `new_line` is the line number in the
**new** version of the file (what an inline `inline.to` anchors to). Scale the number of findings
and the agents' thoroughness to `--effort`.

If `--repo <path>` was given, tell each subagent it may read full files under that path for context.
Otherwise, instruct them to flag findings whose certainty is limited by diff-only context as lower
confidence (the raw diff lacks surrounding code).

Collect the JSON arrays, merge them, and write to `$OUT/findings.json`.

### Step 5: Validate inline anchors

```bash
python3 "$BB" map --diff "$OUT/pr-$PR_ID.diff" > "$OUT/valid-lines.json"
```

This lists, per file, the new-file line numbers that exist in the diff (added + context lines) —
the only lines an inline comment can anchor to. Drop or down-grade findings whose `(path, new_line)`
is not in that set (the `post-inline` command also enforces this with `--diff`, but checking here
lets you re-anchor a finding to a nearby valid line before posting).

### Step 6: Output in chat (always)

Print findings grouped per file, severity-sorted (blocker → high → medium → low → note), each as:

```
<path>:<new_line>  [SEVERITY]  <title>
   <body>
   suggestion: <…>            # if present
```

End with a count summary. This is the full deliverable when no post flag is set.

### Step 7: Post back (only if a post flag is set)

- `--comment` (inline):
  ```bash
  python3 "$BB" post-inline "$WORKSPACE/$REPO" "$PR_ID" \
      --findings "$OUT/findings.json" --diff "$OUT/pr-$PR_ID.diff"
  ```
  Posts one comment per finding, anchored to its line, throttled with 429 backoff. Each body is
  prefixed with a marker so re-runs are recognizable. Reports posted vs skipped (with reasons).

- `--summary-comment`:
  ```bash
  # render findings into one markdown body first, then:
  python3 "$BB" post-summary "$WORKSPACE/$REPO" "$PR_ID" --body "$OUT/summary.md"
  ```

Before posting, if there are many findings (> ~15 inline comments), confirm with the user — posting
floods a shared PR and is hard to undo.

### Step 8: Report

```
═══════════════════════════════════════════════════════════
  BITBUCKET PR REVIEW
═══════════════════════════════════════════════════════════
  PR:         <workspace>/<repo> #<id> — <title>
  State:      <OPEN|…>   <source> → <destination>
  Files:      <N changed>
  Findings:   <blocker> blocker, <high> high, <medium> medium, <low> low
  Posted:     <inline N | summary 1 | preview only (not posted)>
  PR URL:     <url>
═══════════════════════════════════════════════════════════
```

## Critical guardrails

1. **API token only — never app passwords.** App Passwords are disabled 2026-06-09. The script
   refuses to run without `BITBUCKET_EMAIL` + `BITBUCKET_API_TOKEN` and uses Basic auth `email:token`.
2. **Posting is opt-in.** No `--comment`/`--summary-comment` → nothing is written to the PR. Never
   post without an explicit flag, and confirm before flooding a PR with many inline comments.
3. **Only valid anchors.** Inline comments must target lines that exist in the diff (added/context).
   Always validate against `map` output; the script also drops unmappable findings and reports them.
4. **Don't fabricate line numbers.** A finding's `new_line` must come from the diff, not a guess.
   When unsure, post as a summary comment instead of a wrong inline anchor.
5. **Diff-only context is a real limit.** Without `--repo`, the review sees only changed hunks.
   Flag low-confidence findings as such rather than asserting bugs you can't fully see.
6. **No secrets in output.** Never echo `BITBUCKET_API_TOKEN`. The script reads it from the env only.

## Notes

- This skill is the Bitbucket counterpart to `/code-review --comment` (GitHub-only). For Bitbucket's
  own AI review (Atlassian's model + Jira acceptance-criteria checks), enable **Rovo Dev code review**
  in the repo settings — orthogonal to this skill.
- `scripts/bb_review.py` is pure Python stdlib — no `pip install`. It handles the `/diff` 302 redirect,
  pagination, and 429 backoff so the skill body stays declarative.
- See `references/bitbucket-api.md` for endpoint detail and `references/review-rubric.md` for the
  review checklist + finding schema.
