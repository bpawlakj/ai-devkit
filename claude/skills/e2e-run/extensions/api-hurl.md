# Hurl API runner — Rules

Opt-in API runner for plain-text `.hurl` specs. Enabled per project in
`tests/e2e/extensions.md`. `/e2e-run` never installs Hurl or heals a failing run.

## Detect

Any `tests/e2e/api/*.hurl` file in the resolved scope. (Hurl files are authored by
hand or by `/scenario` when the user prefers declarative HTTP over the Playwright
`request` fixture — Playwright remains the default.)

## Install (surface, do not auto-run)

Hurl is a single binary:
- macOS: `brew install hurl`
- Linux: download from `https://github.com/Orange-OpenSource/hurl/releases` or `cargo install hurl`
Verify: `hurl --version`. If absent, STOP and print the command for the user.

## Run (scoped)

```bash
# scoped to the resolved .hurl file set; --test = test mode (assertions, exit code)
hurl --test [--variable base_url=$E2E_BASE_URL] <file1.hurl> <file2.hurl> ...
```

- Base URL and secrets come from `--variable` / `--variables-file` / env — never
  hardcoded in the `.hurl` file (mirrors SEC-01).
- Stateful flows use Hurl's `[Captures]` to thread tokens/ids between requests.
- `--report-junit <path>` / `--report-html <dir>` for artifacts if the user wants them.

## Report

Hurl exits non-zero on any failed assertion and prints per-request results.
`/e2e-run` folds Hurl results into the API row of its combined report (passed/total)
and lists failing `.hurl` files with the first failed assertion line. Path-type
tags (`@optimistic`/`@pessimistic`) are not native to Hurl — group by filename
convention (`*-optimistic.hurl` / `*-pessimistic.hurl`) if the user adopts it.
