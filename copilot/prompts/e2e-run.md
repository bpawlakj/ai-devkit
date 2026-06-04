# E2E-Run — Run E2E scenarios with the right tool

Paste this prompt to Copilot CLI (or any agent) to discover and run the tests authored by the scenario
prompt, scoped to what you ask for, with the right tool per artifact. Reports failures — never heals them.

> Default runner: Playwright (`npx playwright test`) for web `.spec.ts` + API `.api.spec.ts`. Opt-in API
> runners: **Hurl** for `.hurl` specs, **Schemathesis** for OpenAPI specs — enabled per project, recorded
> in `tests/e2e/extensions.md`. Never auto-install a tool; never regenerate a failing test.

---

You are an E2E test runner. Given a scope (`tests/e2e/scenarios/<slug>.md`, an initiative folder, a
`T-NNN`, `tests/e2e`, or `all`) plus optional flags (`--grep @optimistic|@pessimistic`, `--layer web|api`,
`--headed`, `--dir tests/e2e`), do this:

1. **Discover + detect runner**: glob `tests/e2e/` for `*.spec.ts` / `*.hurl` and `scenarios/*.md`.
   `.spec.ts` → Playwright (confirm `@playwright/test` resolves; if absent, STOP and print
   `npm i -D @playwright/test && npx playwright install` — do not auto-install). `.hurl`/OpenAPI → extension.
2. **Resolve scope** (print the file set before running):
   - scenario `.md` → its `generated:` list; initiative → all scenarios whose `initiative:` matches;
     `T-NNN` → all scenarios whose `depends_on` contains it; `all`/`tests/e2e` → whole tree.
   - apply `--layer` (subdir) and remember `--grep` (tag filter).
3. **Extension opt-in** (only if `.hurl`/OpenAPI in scope): read/append `tests/e2e/extensions.md`; ask to
   enable Hurl / Schemathesis. Playwright needs no opt-in. Enabled-but-missing tool → STOP with install cmd.
4. **Run** the scoped command(s): `npx playwright test <files> [--grep <tag>] [--headed]`; `hurl --test
   <files>`; `schemathesis run <spec> --url <base>`. Run each once over its slice — no retry, no edits.
5. **Report**: PASS/FAIL, per-layer counts (web optimistic/pessimistic, api), failing test names + first
   failure line, artifact paths (`playwright-report/`, `test-results/.../trace.zip`). On failure, offer
   human-driven next steps (open trace / re-author via scenario prompt / fix the app) — never regenerate.
6. **Optional write-back**: if the run maps to a `T-NNN`, offer to append a dated one-line `### E2E note`
   under that task's `## Notes` (PASS/FAIL summary). Never flip task `status`.

Guardrails: report-only on failure — never auto-heal/regenerate/retry-until-green; never auto-install a
tool; print scope before running; extensions opt-in and recorded; don't touch task status.
