#!/usr/bin/env python3
"""bb_review.py — Bitbucket Cloud REST plumbing for the /bitbucket-review skill.

Deterministic mechanics only: API I/O + unified-diff line mapping. The review
*reasoning* lives in the skill (Claude); this script never judges code.

Auth: API token via Basic auth (email:token). App Passwords are deprecated and
disabled 2026-06-09 — do NOT use them. Set:
    BITBUCKET_EMAIL       Atlassian account email
    BITBUCKET_API_TOKEN   API token (account Settings > Security > API tokens)

Subcommands:
    meta         WS/REPO PR            -> JSON {title,state,source,destination,author,links}
    diff         WS/REPO PR [--out F]  -> unified diff (stdout or file)
    diffstat     WS/REPO PR            -> JSON list of {status, old, new}
    map          --diff F              -> JSON {path: [valid_new_lines...]}  (added+context)
    post-inline  WS/REPO PR --findings F   -> post one inline comment per finding
    post-summary WS/REPO PR --body F        -> post one aggregated comment

Findings file (for post-inline) is a JSON list of:
    {"path": "...", "new_line": 42, "title": "...", "body": "...", "severity": "..."}

All comment bodies are prefixed with a marker so re-runs are recognizable.
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.bitbucket.org/2.0"
MARKER = "<!-- bitbucket-review (ai-devkit) -->"
CREDS_FILE = os.path.join(os.path.expanduser("~"), ".claude", "bitbucket-review.env")


# ---------------------------------------------------------------- auth / http

def _load_creds_file():
    """Fallback: load BITBUCKET_* from ~/.claude/bitbucket-review.env if not
    already in the environment. Lets the tool work whether invoked by the skill
    (which sources the file) or directly, without editing the shell profile.
    Written by `./setup.sh --bitbucket-creds`."""
    if not os.path.exists(CREDS_FILE):
        return
    with open(CREDS_FILE) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export "):]
            if "=" not in line:
                continue
            key, val = line.split("=", 1)
            os.environ.setdefault(key.strip(), val.strip().strip('"').strip("'"))


def _auth_header():
    _load_creds_file()
    email = os.environ.get("BITBUCKET_EMAIL")
    token = os.environ.get("BITBUCKET_API_TOKEN")
    if not email or not token:
        sys.exit(
            "ERROR: BITBUCKET_EMAIL and BITBUCKET_API_TOKEN must be set.\n"
            "Quickest fix: run  ./setup.sh --bitbucket-creds  (prompts, writes "
            f"{CREDS_FILE}).\n"
            "Or mint a token at: Atlassian account > Settings > Security > API tokens\n"
            "Scopes: read repository + read & write pull request.\n"
            "App Passwords are deprecated (disabled 2026-06-09) — use an API token."
        )
    raw = f"{email}:{token}".encode()
    return "Basic " + base64.b64encode(raw).decode()


def _request(method, url, body=None, accept="application/json"):
    """One HTTP call with 429 backoff. Returns (status, headers, bytes)."""
    data = None
    headers = {"Authorization": _auth_header(), "Accept": accept}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    for attempt in range(5):
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                return resp.status, dict(resp.headers), resp.read()
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 4:
                wait = int(e.headers.get("Retry-After", 2 ** attempt))
                sys.stderr.write(f"429 rate-limited; sleeping {wait}s...\n")
                time.sleep(wait)
                continue
            detail = e.read().decode(errors="replace")
            sys.exit(f"ERROR: HTTP {e.code} {method} {url}\n{detail}")
        except urllib.error.URLError as e:
            sys.exit(f"ERROR: network failure {method} {url}: {e.reason}")
    sys.exit("ERROR: exhausted retries (429).")


def _get_json(url):
    _, _, raw = _request("GET", url)
    return json.loads(raw)


def _paginate(url):
    """Yield every value across a paginated collection."""
    while url:
        page = _get_json(url)
        for v in page.get("values", []):
            yield v
        url = page.get("next")


def _pr_base(ws, repo, pr):
    return f"{API}/repositories/{ws}/{repo}/pullrequests/{pr}"


def _split_repo(spec):
    """'workspace/repo' -> ('workspace', 'repo')."""
    if "/" not in spec:
        sys.exit(f"ERROR: expected WORKSPACE/REPO, got '{spec}'")
    ws, repo = spec.split("/", 1)
    return ws, repo


# ---------------------------------------------------------------- diff parsing

def parse_diff_newlines(diff_text):
    """Map each file to the set of NEW-file line numbers that exist in the diff
    (added '+' lines and unchanged context ' ' lines). These are the only lines
    an inline comment's `inline.to` can validly anchor to.

    Returns {new_path: sorted([line, ...])}.
    """
    result = {}
    cur_path = None
    new_ln = None
    for line in diff_text.splitlines():
        if line.startswith("+++ "):
            # "+++ b/path/to/file"  (or "+++ /dev/null" for deletions)
            target = line[4:].strip()
            if target == "/dev/null":
                cur_path = None
            else:
                cur_path = target[2:] if target.startswith(("a/", "b/")) else target
                result.setdefault(cur_path, [])
            new_ln = None
            continue
        if line.startswith("--- "):
            continue
        if line.startswith("@@"):
            # @@ -old,cnt +new,cnt @@
            try:
                plus = line.split("+", 1)[1]
                new_start = int(plus.split(",")[0].split(" ")[0])
                new_ln = new_start
            except (IndexError, ValueError):
                new_ln = None
            continue
        if cur_path is None or new_ln is None:
            continue
        if line.startswith("+"):
            result[cur_path].append(new_ln)
            new_ln += 1
        elif line.startswith("-"):
            pass  # old-file only; no new-file line consumed
        elif line.startswith("\\"):
            pass  # "\ No newline at end of file"
        else:  # context line (leading space, or empty)
            result[cur_path].append(new_ln)
            new_ln += 1
    return {p: sorted(set(v)) for p, v in result.items()}


# ---------------------------------------------------------------- subcommands

def cmd_meta(args):
    ws, repo = _split_repo(args.repo)
    pr = _get_json(_pr_base(ws, repo, args.pr))
    out = {
        "id": pr.get("id"),
        "title": pr.get("title"),
        "state": pr.get("state"),
        "author": (pr.get("author") or {}).get("display_name"),
        "source": ((pr.get("source") or {}).get("branch") or {}).get("name"),
        "destination": ((pr.get("destination") or {}).get("branch") or {}).get("name"),
        "url": ((pr.get("links") or {}).get("html") or {}).get("href"),
    }
    print(json.dumps(out, indent=2))


def cmd_diff(args):
    ws, repo = _split_repo(args.repo)
    # /diff redirects (302) to a signed URL; urllib follows redirects by default.
    _, _, raw = _request("GET", _pr_base(ws, repo, args.pr) + "/diff",
                         accept="text/plain")
    text = raw.decode(errors="replace")
    if args.out:
        with open(args.out, "w") as f:
            f.write(text)
        sys.stderr.write(f"diff written to {args.out} ({len(text)} bytes)\n")
    else:
        sys.stdout.write(text)


def cmd_diffstat(args):
    ws, repo = _split_repo(args.repo)
    files = []
    for v in _paginate(_pr_base(ws, repo, args.pr) + "/diffstat"):
        files.append({
            "status": v.get("status"),
            "old": (v.get("old") or {}).get("path"),
            "new": (v.get("new") or {}).get("path"),
            "lines_added": v.get("lines_added"),
            "lines_removed": v.get("lines_removed"),
        })
    print(json.dumps(files, indent=2))


def cmd_map(args):
    with open(args.diff) as f:
        text = f.read()
    print(json.dumps(parse_diff_newlines(text), indent=2))


def _post_comment(ws, repo, pr, raw_body, inline=None):
    body = {"content": {"raw": raw_body}}
    if inline:
        body["inline"] = inline
    status, _, resp = _request("POST", _pr_base(ws, repo, pr) + "/comments", body=body)
    return json.loads(resp)


def cmd_post_inline(args):
    ws, repo = _split_repo(args.repo)
    with open(args.findings) as f:
        findings = json.load(f)
    # Validate anchors against the diff's new-file lines.
    valid = None
    if args.diff:
        with open(args.diff) as f:
            valid = parse_diff_newlines(f.read())
    posted, skipped = 0, []
    for fd in findings:
        path, line = fd.get("path"), fd.get("new_line")
        if valid is not None and (path not in valid or line not in valid.get(path, [])):
            skipped.append({"path": path, "new_line": line, "reason": "line not in diff"})
            continue
        sev = fd.get("severity", "note").upper()
        raw = f"{MARKER}\n**[{sev}] {fd.get('title','').strip()}**\n\n{fd.get('body','').strip()}"
        if fd.get("suggestion"):
            raw += f"\n\n```suggestion\n{fd['suggestion']}\n```"
        _post_comment(ws, repo, args.pr, raw, inline={"path": path, "to": line})
        posted += 1
        time.sleep(args.delay)
    print(json.dumps({"posted": posted, "skipped": skipped}, indent=2))


def cmd_post_summary(args):
    ws, repo = _split_repo(args.repo)
    with open(args.body) as f:
        raw = f.read()
    if MARKER not in raw:
        raw = f"{MARKER}\n{raw}"
    res = _post_comment(ws, repo, args.pr, raw)
    print(json.dumps({"id": res.get("id"), "url": ((res.get("links") or {}).get("html") or {}).get("href")}, indent=2))


# ---------------------------------------------------------------- cli

def main():
    p = argparse.ArgumentParser(description="Bitbucket PR review plumbing")
    sub = p.add_subparsers(dest="cmd", required=True)

    def add_pr(sp):
        sp.add_argument("repo", help="workspace/repo")
        sp.add_argument("pr", help="pull request id")

    add_pr(sub.add_parser("meta"))

    sp = sub.add_parser("diff"); add_pr(sp); sp.add_argument("--out")
    add_pr(sub.add_parser("diffstat"))

    sp = sub.add_parser("map"); sp.add_argument("--diff", required=True)

    sp = sub.add_parser("post-inline"); add_pr(sp)
    sp.add_argument("--findings", required=True)
    sp.add_argument("--diff", help="validate anchors against this diff")
    sp.add_argument("--delay", type=float, default=0.5)

    sp = sub.add_parser("post-summary"); add_pr(sp)
    sp.add_argument("--body", required=True)

    args = p.parse_args()
    {
        "meta": cmd_meta, "diff": cmd_diff, "diffstat": cmd_diffstat,
        "map": cmd_map, "post-inline": cmd_post_inline, "post-summary": cmd_post_summary,
    }[args.cmd](args)


if __name__ == "__main__":
    main()
