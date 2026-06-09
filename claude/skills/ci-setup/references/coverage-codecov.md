# Codecov wiring (canonical reference for /ci-setup)

External coverage dashboard + badge + per-PR diff-coverage comment. Free for
public repos; private repos need the token. The CI job already produces a
coverage report (see `ci-recipes.md`); this adds the upload + badge.

## Report formats the job must emit

| Stack | Reporter flag | Output file |
|---|---|---|
| Python (pytest-cov) | `--cov-report=xml` | `coverage.xml` |
| Node (vitest) | `coverage.reporter: ['text','lcov']` in `vite.config.ts` | `coverage/lcov.info` |
| Node (jest) | `--coverageReporters=lcov` | `coverage/lcov.info` |

## Upload step (per surface, after the test/coverage step)

```yaml
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage.xml            # or <dir>/coverage/lcov.info for Node
          flags: backend                   # one flag per surface: backend / frontend
          fail_ci_if_error: false          # don't fail CI on an upload hiccup
```

- **`flags`** separate surfaces so Codecov tracks backend vs frontend coverage
  independently (and shows both on the dashboard).
- **`fail_ci_if_error: false`** — a Codecov outage must not break the build; the
  coverage *gate* is enforced by the test runner (`--cov-fail-under` / thresholds),
  not by Codecov. Codecov is visualization, not the gate.
- **Token**: always `secrets.CODECOV_TOKEN`. Never inline. The user adds it under
  repo Settings → Secrets and variables → Actions. (Public repos can sometimes
  upload tokenless, but the token path is the reliable default.)

## Badge (README)

Add near the top of `README.md` (alongside any CI badge):

```markdown
[![codecov](https://codecov.io/gh/<owner>/<repo>/branch/main/graph/badge.svg)](https://codecov.io/gh/<owner>/<repo>)
```

Derive `<owner>/<repo>` from `git remote get-url origin`. If a CI badge already
exists, place the Codecov badge on the same line.

## Optional: codecov.yml

For per-surface targets + tidy PR comments, offer a repo-root `codecov.yml`:

```yaml
coverage:
  status:
    project:
      default: { target: <PCT>%, threshold: 1% }
    patch:
      default: { target: <PCT>% }      # new code must also meet the bar
flags:
  backend:  { paths: ["<pkg>/"] }
  frontend: { paths: ["<dir>/src/"] }
comment:
  layout: "diff, flags, files"
```

`patch` target is the high-value one: it holds *new* code to the bar even while
overall coverage climbs. Keep `codecov.yml` optional — the badge + upload alone
already deliver "see 80% coverage in an external tool".

## `none` (no external tool)

If the user picks `coverage-tool: none`: skip the upload step, badge, and
`codecov.yml`. The gate still works (test-runner threshold) and coverage shows in
the CI job log + step summary. The "external dashboard" is simply absent.
