# AI code-review recipes (canonical reference for /ci-setup)

Two ways to add automated PR review. The user picks one per project. Both post a
review as a PR comment; both are **opt-in** and **same-repo-only** by construction.

## Choosing

| | **kukuvaia (self-hosted)** | **Claude Code Action (hosted)** |
|---|---|---|
| LLM path | internal gateway (`/api/chat`) | Anthropic API |
| Infra | a **self-hosted runner** that can reach the gateway | none (GitHub-hosted) |
| Secret | none (gateway is local) | `ANTHROPIC_API_KEY` |
| Fits rule | "reuse internal infra / don't call Anthropic directly" (AGENTS.md) | projects with no such rule |
| Cost | runner upkeep; machine must be online | per-token Anthropic |

**Rule of thumb**: if AGENTS.md mandates an internal LLM gateway, recommend
kukuvaia and flag the tension if the user still wants the Claude action. Else the
Claude action is the lower-friction default.

---

## Recipe A — kukuvaia on a self-hosted runner

The gateway (e.g. `localhost:8080`) is unreachable from GitHub-hosted runners, so
review runs on a self-hosted runner registered on a machine that can reach it.

### `.github/workflows/pr-review.yml`

```yaml
name: PR review (kukuvaia)

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write

jobs:
  ai-review:
    # Dormant until opt-in: set repo variable SELF_HOSTED_CI=true once a
    # self-hosted runner is registered and the gateway is up. Same-repo only —
    # never run untrusted fork code on a self-hosted machine.
    if: >-
      ${{ vars.SELF_HOSTED_CI == 'true' &&
          (github.event_name == 'workflow_dispatch' ||
           github.event.pull_request.head.repo.full_name == github.repository) }}
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Generate review
        env:
          KUKUVAIA_URL: http://localhost:8080      # the internal gateway
          GITHUB_BASE_REF: ${{ github.base_ref }}
        run: python3 scripts/ai_review.py --out review.md
      - name: Post review comment
        if: ${{ github.event_name == 'pull_request' }}
        env: { GH_TOKEN: ${{ github.token }} }
        run: gh pr comment ${{ github.event.pull_request.number }} --body-file review.md
```

### `scripts/ai_review.py`

Stdlib-only (no deps; runs under plain `python3`). The SSE parsing below matches a
gateway that streams `data: {"content": "...", "style": "..."}` blocks — **adapt
`_parse` to the actual gateway protocol** if it differs.

```python
"""AI code review via an internal LLM gateway (reuse-internal-infra; never call
Anthropic directly). Reads the PR diff vs the base branch, asks the gateway for a
concise review, writes it to --out (default review.md). Stdlib only."""
from __future__ import annotations
import argparse, json, os, subprocess, sys, urllib.request, uuid

MAX_DIFF = 60_000

def get_diff(base: str) -> str:
    subprocess.run(["git", "fetch", "origin", base, "--depth=50"], check=False)
    return subprocess.run(["git", "diff", f"origin/{base}...HEAD"],
                          capture_output=True, text=True).stdout

def review(diff: str, url: str) -> str:
    if len(diff) > MAX_DIFF:
        diff = diff[:MAX_DIFF] + "\n…(diff truncated)…"
    prompt = ("You are a senior code reviewer. Review this pull-request diff. "
              "Be concise and specific: correctness bugs, security issues, clear "
              "simplifications, grouped by severity with file paths. If nothing "
              "material, say so.\n\nDIFF:\n" + diff)
    payload = json.dumps({"sessionId": str(uuid.uuid4()), "message": prompt,
                          "persona": None}).encode()
    req = urllib.request.Request(f"{url}/api/chat", data=payload,
        headers={"Content-Type": "application/json", "Accept": "text/event-stream"})
    parts: list[str] = []
    with urllib.request.urlopen(req, timeout=180) as resp:
        for raw in resp:                      # _parse: gateway-specific SSE
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            p = line[5:].strip()
            if not p:
                continue
            try:
                block = json.loads(p)
            except json.JSONDecodeError:
                continue
            if "content" in block and "style" in block and "spanId" not in block:
                if block.get("style") == "error":
                    print(f"gateway error: {block.get('content')}", file=sys.stderr)
                    sys.exit(1)
                if block.get("content"):
                    parts.append(block["content"])
    return "".join(parts).strip()

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=os.environ.get("GITHUB_BASE_REF") or "main")
    ap.add_argument("--url", default=os.environ.get("KUKUVAIA_URL") or "http://localhost:8080")
    ap.add_argument("--out", default="review.md")
    a = ap.parse_args()
    diff = get_diff(a.base)
    body = ("_No diff against base — nothing to review._" if not diff.strip()
            else "## 🤖 AI code review\n\n" + (review(diff, a.url) or "_(empty)_")
                 + "\n\n---\n_Automated — verify before acting._")
    open(a.out, "w", encoding="utf-8").write(body)
    print(body)

if __name__ == "__main__":
    main()
```

### Enabling (hand-off TODO for the user)

1. Register a self-hosted runner on the machine running the gateway (repo Settings
   → Actions → Runners → New self-hosted runner). Ensure `python3` + `gh` present.
2. Keep the gateway up (`localhost:8080`) whenever review may fire.
3. Set repo variable `SELF_HOSTED_CI=true` (Settings → Secrets and variables →
   Actions → Variables). Until then the job is **skipped** (green, not pending).

---

## Recipe B — Claude Code Action (Anthropic-hosted)

Zero infra; runs on GitHub-hosted runners. Needs an `ANTHROPIC_API_KEY` secret.

### `.github/workflows/pr-review.yml`

```yaml
name: PR review (Claude)

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write

jobs:
  claude-review:
    # Same-repo only: don't expose the API key to fork PRs.
    if: ${{ github.event_name == 'workflow_dispatch' || github.event.pull_request.head.repo.full_name == github.repository }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Claude code review
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          # Review the diff and post findings as a PR comment. Consult the action's
          # current README for the exact input names/version before generating —
          # pin the major you verified.
          prompt: >-
            Review this pull request for correctness bugs, security issues, and
            clear simplifications. Be concise; group by severity; cite file paths.
```

> The action's inputs evolve — when generating, confirm the latest input
> schema/version (the claude-code-guide agent or the action README) and pin the
> verified major. Don't emit input names you haven't checked.

### Enabling (hand-off TODO)

- Add repo secret `ANTHROPIC_API_KEY` (Settings → Secrets and variables → Actions).
- That's it — runs on hosted runners, same-repo PRs.
- ⚠️ If AGENTS.md says "route LLM calls through <internal gateway>", this recipe
  calls Anthropic directly — surface that tension before generating.

---

## Security model (both recipes)

- **Same-repo guard** (`head.repo.full_name == repository`) on every reviewer job:
  fork PRs never trigger a job that holds a secret or runs on a self-hosted machine.
- **Secrets via `${{ secrets.* }}` only** — never inline a key or gateway
  credential (`security.md`).
- **Least privilege**: `permissions: { contents: read, pull-requests: write }` —
  enough to read the diff and comment, nothing more.
- **`none`**: if the user declines a reviewer, generate no `pr-review.yml` and no
  review script.
