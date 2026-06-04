# Schemathesis (OpenAPI) runner — Rules

Opt-in runner that generates property-based + stateful API tests from an
OpenAPI/Swagger spec. Enabled per project in `tests/e2e/extensions.md`.
`/e2e-run` never installs it or heals a failing run.

## Detect

An OpenAPI/Swagger document in the repo (`openapi.{yaml,yml,json}`, `swagger.*`),
or a path the user points at. Unlike the other artifacts this is not under
`tests/e2e/` — confirm the spec path with the user when ambiguous.

## Install (surface, do not auto-run)

```bash
# Python tool — prefer an isolated install
uv tool install schemathesis    # or: pipx install schemathesis  / pip install schemathesis
```
Verify: `schemathesis --version` (or `st --version`). If absent, STOP and print
the command for the user.

## Run (scoped)

```bash
schemathesis run <spec-path-or-url> \
  --url "$E2E_BASE_URL" \
  --checks all \
  [--include-path /the/endpoints/in/scope]
```

- `--url` is the live base URL (env, never hardcoded). Auth via
  `--header "Authorization: Bearer $TOKEN"` from env.
- Stateful sequences: Schemathesis follows OpenAPI `links` automatically — this is
  its advantage over single-request tools.
- Scope to the endpoints the run cares about with `--include-path` /
  `--include-tag` so a broad spec doesn't fuzz everything every run; **log what was
  scoped out** so coverage isn't silently narrowed.

## Report

Schemathesis exits non-zero on any failing check and prints failing cases with the
minimal reproducing example. `/e2e-run` folds the pass/fail count into the API row
of its combined report and lists failing operations (method + path) with the first
failure line. Because cases are generated, note in the report that counts vary run
to run unless a seed is fixed (`--hypothesis-seed`).
