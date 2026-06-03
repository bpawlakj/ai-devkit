# Bitbucket Cloud REST API — reference for bitbucket-review

Base: `https://api.bitbucket.org/2.0`. PR endpoints live under
`/repositories/{workspace}/{repo_slug}/pullrequests/{id}`.
Official reference: <https://developer.atlassian.com/cloud/bitbucket/rest/api-group-pullrequests/>

All of this is implemented in `scripts/bb_review.py`; this file documents the contract and the
gotchas so the behavior can be audited without reading the code.

## Authentication — API tokens (NOT app passwords)

App Passwords are deprecated: none issued after 2025-09-09, all disabled **2026-06-09**. Migrate to
API tokens. ([Atlassian blog](https://www.atlassian.com/blog/bitbucket/bitbucket-cloud-transitions-to-api-tokens-enhancing-security-with-app-password-deprecation))

- **API token (used here):** Basic auth with the **account email** (not username) and the token:
  `Authorization: Basic base64(email:token)`. Create at Atlassian account → Settings → Security →
  **API tokens**, with scopes **read repository** + **read & write pull request**.
  ([Using API tokens](https://support.atlassian.com/bitbucket-cloud/docs/using-api-tokens/))

Env vars consumed: `BITBUCKET_EMAIL`, `BITBUCKET_API_TOKEN`.

## Endpoints used

| Purpose | Method + path |
|---|---|
| PR metadata | `GET .../pullrequests/{id}` → `source.branch.name`, `destination.branch.name`, `title`, `state`, `author`, `links.html.href` |
| Raw unified diff | `GET .../pullrequests/{id}/diff` — returns `text/plain`; **302 redirect to a signed temp URL** (urllib follows it automatically) |
| Changed files | `GET .../pullrequests/{id}/diffstat` — paginated JSON; each entry has `status`, `old.path`, `new.path`, `lines_added/removed` |
| Post comment | `POST .../pullrequests/{id}/comments` body `{"content":{"raw":"…"}}` |

`PR state` values: `OPEN`, `MERGED`, `DECLINED`, `SUPERSEDED`.

## Comments — general, inline, threaded

```bash
# general comment
-d '{"content":{"raw":"text"}}'

# inline comment on a NEW-file line
-d '{"content":{"raw":"text"},"inline":{"path":"src/App.java","to":42}}'

# threaded reply
-d '{"content":{"raw":"text"},"parent":{"id":12345}}'
```

**`inline.to` vs `inline.from`:** `to` = line in the **new** (added/destination) file; `from` = line
in the **old** (removed/source) file. Comment on added/current code with `to`; on deleted code with
`from`. **Send exactly one.** A
[community report](https://community.developer.atlassian.com/t/api-post-endpoint-for-inline-pull-request-comments/60452)
notes the API may drop `to` if `from` is also present — so the script sends only `to`.

## Rate limits & pagination

- Authenticated repository-data calls: ~1,000/hr (up to ~10,000/hr on larger paid plans), rolling
  1-hour window per user. Anonymous ~60/hr.
  ([API request limits](https://support.atlassian.com/bitbucket-cloud/docs/api-request-limits/))
- The script backs off on HTTP 429 (honors `Retry-After`) and throttles inline posts with `--delay`.
- Collections return `{values, page, pagelen, next}`; follow `next` until absent (`pagelen` max 100).
  ([REST intro](https://developer.atlassian.com/cloud/bitbucket/rest/intro/))

## Idempotency

Every comment body is prefixed with `<!-- bitbucket-review (ai-devkit) -->`. The script does not
auto-delete prior comments, but the marker makes re-runs and cleanup recognizable.

## Verified empirically against PR sl-technology/sl-etsl-authorsuite #2651
Confirm before bulk runs: the `/diff` redirect behavior and that `inline.to` anchors land on the
intended line (line numbering can drift if the PR is updated between fetch and post).
