# Runner Detection (canonical reference for /e2e-run)

How `/e2e-run` maps an artifact under `tests/e2e/` to the command that runs it.
Playwright is the default and needs no opt-in; dedicated API tools are opt-in
extensions (see `../extensions/`).

## Artifact → tool

| Artifact | Tool | Command (scoped) | Opt-in? |
|---|---|---|---|
| `tests/e2e/web/*.spec.ts`, `tests/e2e/api/*.api.spec.ts` | Playwright | `npx playwright test [files] [--grep @tag] [--headed]` | No (default) |
| `tests/e2e/api/*.hurl` | Hurl | `hurl --test [files]` | Yes — `api-hurl` |
| OpenAPI spec (`openapi.{yaml,json}`, `swagger.*`) + opt-in | Schemathesis | `schemathesis run <spec> --url <base>` | Yes — `api-schemathesis` |

## Playwright presence + bootstrap

Walk up from `tests/e2e/` (or cwd) to find a Playwright install:

```bash
# config marker
ls playwright.config.* 2>/dev/null
# dependency marker
node -e "require.resolve('@playwright/test')" 2>/dev/null && echo "present" || echo "absent"
```

- **Config + dep present** → run directly with `npx playwright test`.
- **Dep present, no config** → still runs (Playwright has defaults); offer to write
  a minimal `tests/e2e/playwright.config.ts` (testDir, `baseURL` from env, trace
  on-first-retry).
- **Dep absent** → STOP and offer the install command; do not silently install:
  `npm i -D @playwright/test && npx playwright install` (or pnpm/yarn per lockfile).
  Browsers must be installed once (`npx playwright install`). Surface this — a
  missing browser is the most common first-run failure.

Package-manager pick mirrors `/implement` Step 2.4: `pnpm-lock.yaml` → `pnpm`,
`yarn.lock` → `yarn`, else `npm`.

## Scoping

`/e2e-run` resolves a file set before running. Sources of scope:

- **scenario `.md`** → read its `generated:` frontmatter list; run exactly those.
- **initiative folder** (`docs/work/<NNN>-<slug>/`) → every scenario whose
  `initiative:` frontmatter matches; union their `generated:` lists.
- **`T-NNN`** → every scenario whose `depends_on` contains that id.
- **`--grep @optimistic|@pessimistic`** → Playwright tag filter, applied on top.
- **`--layer web|api`** → restrict to that subdirectory.
- **`all` / `tests/e2e`** → the whole tree.

Always print the resolved file set before executing.

## Result artifacts

Playwright writes traces/screenshots/HTML report under `test-results/` and
`playwright-report/` by default. `/e2e-run` surfaces those paths in its report;
it does not move or commit them. Add both to the project `.gitignore`.
