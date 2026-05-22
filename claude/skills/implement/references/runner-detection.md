# Test Runner Detection (canonical reference)

`/implement` Step 2.4 uses this matrix to pick the test command without asking the user. Walks up from cwd; closest matching marker wins.

## Detection matrix

| Marker file | Additional signal | Command | Notes |
|---|---|---|---|
| `package.json` | `scripts.test` present | `npm test` | If `pnpm-lock.yaml` exists, use `pnpm test`; if `yarn.lock`, use `yarn test`. |
| `package.json` | `vitest` in devDependencies | `npx vitest run` | Watch mode (`npx vitest`) for inner-loop only — full suite uses `run`. |
| `package.json` | `jest` in devDependencies | `npx jest` | If `--testPathPattern` is supported, use for affected-only runs. |
| `package.json` | `playwright` in devDependencies | `npx playwright test` | E2E only — usually paired with unit runner; ask which to run when ambiguous. |
| `pyproject.toml` | `[tool.pytest]` section OR `pytest` in dependencies | `pytest` | If `uv.lock` exists, prefer `uv run pytest`; if `poetry.lock`, `poetry run pytest`. |
| `setup.py` / `setup.cfg` | `pytest.ini` present | `pytest` | Same dependency-manager heuristic as above. |
| `go.mod` | always | `go test ./...` | For affected: `go test ./pkg/...`. With `-race` on if rule `go.md` is active and CI uses it. |
| `pom.xml` | always | `mvn -B test` | `-B` for non-interactive output. |
| `build.gradle` / `build.gradle.kts` | `gradlew` script in repo root | `./gradlew test` | Fallback to `gradle test` if no wrapper. |
| `Cargo.toml` | always | `cargo test` | |
| `composer.json` | `phpunit` in `require-dev` | `./vendor/bin/phpunit` | Fallback to `vendor/bin/pest` if Pest detected (`pestphp/pest` in `require-dev`). |
| `Package.swift` | always | `swift test` | |
| `mix.exs` | always | `mix test` | Elixir / Phoenix. |
| `Gemfile` | `rspec` in Gemfile | `bundle exec rspec` | Fallback to `bundle exec rake test` if `Rakefile` exists. |
| `.csproj` / `.sln` | always | `dotnet test` | |
| (no marker) | — | ask user | Cache for the session in `~/.claude/cache/runner-<repo-hash>.txt`. |

## Affected-only test selectors

When possible, `/implement` runs only tests for the area touched in the current task:

- **vitest**: `npx vitest run <glob>` — accepts file globs.
- **jest**: `npx jest <regex>` or `--testPathPattern <regex>`.
- **pytest**: `pytest path/to/test_module.py::test_name` for a single test, or `pytest path/to/` for a directory.
- **go**: `go test ./path/to/pkg/...`.
- **mvn**: `mvn -Dtest=ClassName test`.
- **gradle**: `./gradlew test --tests "com.example.MyTest"`.
- **cargo**: `cargo test <substring>` matches test names.

Full-suite is reserved for Step 6 (pre-commit). Affected-only is the inner loop.

## Override flow

If the detection matrix picks the wrong command (e.g. monorepo with workspace tests), the user can override once per session:

```
/implement --runner "npm run test:integration"
```

The override is in-memory only; not written to disk.

## What NOT to detect

- **Linters / formatters** (`eslint`, `ruff`, `prettier`, `gofmt`, etc.) — these are PostToolUse hooks in `settings.template.json`, not gates for `/implement`. They run automatically on edited files.
- **Type checks** (`tsc`, `mypy`, `pyright`) — same reasoning; if they fail, the test runner will surface it via compilation errors.
- **Build commands** (`tsc -b`, `mvn package`, `cargo build`) — only run if `## Acceptance` explicitly requires the build artifact; otherwise test command implies build for compiled languages.

## Caching

The first detection per repo (per session) is cached in memory. Subsequent invocations skip detection unless `--runner` override is passed.

For long-lived sessions across reboots, the cache lives at `~/.claude/cache/runner-<sha256-of-repo-root>.txt` — one line, the detected command. Delete the file to force re-detection.
