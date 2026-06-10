---
applyTo: "**/*.cs"
---

# .NET / C# Standards

## Formatting & Naming

- **dotnet format** (or CSharpier); file-scoped namespaces; `.editorconfig` checked in
- `PascalCase` types/methods/properties; `camelCase` locals/params; `_camelCase` private fields; `IPascalCase` interfaces; async methods end in `Async`

## Nullable Reference Types

- `<Nullable>enable</Nullable>` in every csproj
- Never use `!` (null-forgiving) without a comment stating why it's safe
- Prefer pattern matching over null checks

## Modern C# (12+)

- Records for DTOs/value types; `init` setters; primary constructors
- Switch expressions with exhaustive matching; collection expressions

## Async / Await

- Async all the way — never `.Result`, `.Wait()`, or `GetAwaiter().GetResult()`
- Accept and propagate `CancellationToken` on every async public API
- `ConfigureAwait(false)` in libraries

## Dependency Injection

- Constructor injection only — no service locator
- Deliberate lifetimes: Singleton (stateless), Scoped (per-request), Transient

## Error Handling

- Specific exception types with context in messages
- No broad `catch (Exception)` outside top-level handlers; never swallow exceptions

## Testing

- xUnit (`[Fact]`, `[Theory]`), FluentAssertions, NSubstitute/Moq, Testcontainers for .NET
- Test naming: `Method_Scenario_ExpectedBehavior`
- Target 80%+ coverage with coverlet

## Analyzers & Security

- `Microsoft.CodeAnalysis.NetAnalyzers` + `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`
- Parameterized queries via EF Core/Dapper — never interpolated SQL strings
