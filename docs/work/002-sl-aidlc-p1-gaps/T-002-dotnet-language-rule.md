---
id: T-002
title: .NET / C# language rule (dotnet.md + mirror + formatter hook)
status: pending
plan: ../plan.md
created: 2026-06-10
completed: null
commit: null
depends_on: []
blocks: []
plan_anchor: P1-2
---

## Scope

- `claude/rules/dotnet.md` — new auto-active language rule (14th)
- `copilot/instructions/dotnet.instructions.md` — mirror
- PostToolUse formatter hook — add `dotnet format` (same mechanism as
  `goimports`/`prettier`)
- Both installers (`setup.sh` claude path, `copilot/install-to-repo.sh`)
- `README.md` — rules table 13 → 14

## Approach

Follow the exact shape of the existing per-language rules (e.g. `java.md`,
`go.md`): idioms, nullable reference types, async/await discipline, DI
(constructor injection), testing with xUnit/NUnit + Testcontainers, analyzers
(`Microsoft.CodeAnalysis.NetAnalyzers`), 80%+ coverage line. Gate to `*.cs`,
`*.csproj`, `*.sln` globs. Closes MOD-08 (SL stack explicitly includes .NET).

## Acceptance

- `claude/rules/dotnet.md` exists, matches the per-language rule shape, and is
  glob-gated to C# files.
- Copilot mirror installed by `copilot/install-to-repo.sh` when dotnet is among
  selected languages.
- Editing a `.cs` file triggers the rule; editing a `.py` file does not.
- If `dotnet` CLI is absent, then the formatter hook degrades silently (no error
  spam), consistent with how other formatter hooks behave.
- README rules table lists 14 rules including dotnet.
- Bats test covering rule presence + hook wiring passes.
