---
paths:
  - "**/*.cs"
  - "**/*.csproj"
---
# .NET / C# Standards

## Formatting

Use **dotnet format** (or CSharpier). File-scoped namespaces, one type per file, `.editorconfig` checked in.

## Naming

- `PascalCase` — types, methods, properties, public fields, constants
- `camelCase` — locals, parameters
- `_camelCase` — private fields
- `IPascalCase` — interfaces; `TPascalCase` — generic type parameters
- Async methods end in `Async`: `GetOrderAsync`

## Nullable Reference Types

- `<Nullable>enable</Nullable>` in every csproj — non-negotiable for new code
- Never silence warnings with `!` (null-forgiving) without a comment stating why it's safe
- Validate at boundaries; prefer pattern matching over null checks

```csharp
// Pattern matching over null checks
if (order is { Customer.Email: { Length: > 0 } email })
    await _mailer.SendAsync(email, ct);
```

## Modern C# (12+)

- **Records** for DTOs and value types; `init` setters over mutable properties
- **Primary constructors** for simple dependency wiring
- **Switch expressions** with exhaustive matching
- **Collection expressions**: `int[] ids = [1, 2, 3];`

```csharp
// Immutable value type
public record OrderSummary(long Id, string CustomerName, decimal Total);

// Exhaustive switch expression
var label = result switch
{
    PaymentSuccess s => $"Paid: {s.TransactionId}",
    PaymentFailure f => $"Failed: {f.ErrorCode}",
    _ => throw new UnreachableException()
};
```

## Async / Await

- Async all the way — never `.Result`, `.Wait()`, or `GetAwaiter().GetResult()` (deadlocks)
- Accept and propagate `CancellationToken` on every async public API
- `ConfigureAwait(false)` in libraries; not needed in ASP.NET Core apps
- `ValueTask` only on measured hot paths

## Dependency Injection

- Constructor injection only — no service locator, no `IServiceProvider` passing
- Register by lifetime deliberately: `Singleton` (stateless), `Scoped` (per-request), `Transient`
- Depend on interfaces at seams you test or swap; concrete types elsewhere are fine

## Error Handling

- Specific exception types extending domain base; include context: `$"Order not found: id={id}"`
- No broad `catch (Exception)` outside top-level handlers / middleware
- Never swallow exceptions — propagate or map to a non-2xx at the handler boundary

## LINQ

- Keep pipelines short (3-4 operations); no side effects inside
- Prefer method syntax with method references where readable
- Materialize deliberately (`ToList()` once) — beware multiple enumeration

## Testing

- **xUnit** (`[Fact]`, `[Theory]` + `[InlineData]`)
- **FluentAssertions**: `result.Should().BeEquivalentTo(expected)`
- **NSubstitute** or Moq for test doubles, constructor injection
- **Testcontainers for .NET** for integration tests with real databases
- Test naming: `Method_Scenario_ExpectedBehavior`
- Target **80%+ coverage** with coverlet

```csharp
public class OrderServiceTests
{
    private readonly IOrderRepository _repository = Substitute.For<IOrderRepository>();

    [Fact]
    public async Task GetOrderAsync_MissingOrder_Throws()
    {
        _repository.FindByIdAsync(99, Arg.Any<CancellationToken>())
            .Returns((Order?)null);
        var sut = new OrderService(_repository);

        var act = () => sut.GetOrderAsync(99, CancellationToken.None);

        await act.Should().ThrowAsync<OrderNotFoundException>()
            .WithMessage("*99*");
    }
}
```

## Analyzers

- `Microsoft.CodeAnalysis.NetAnalyzers` enabled (`<AnalysisLevel>latest</AnalysisLevel>`)
- `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` on new projects
- Security: parameterized queries via EF Core/Dapper parameters — never interpolated SQL strings
