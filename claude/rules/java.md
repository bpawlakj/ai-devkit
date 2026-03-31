---
paths:
  - "**/*.java"
---
# Java Standards

## Formatting

Use **google-java-format** or Checkstyle (Google style). Member order: constants, fields, constructors, public methods, protected, private.

## Naming

- `PascalCase` — classes, interfaces, records, enums
- `camelCase` — methods, fields, parameters, locals
- `SCREAMING_SNAKE_CASE` — `static final` constants
- Packages: all lowercase, reverse domain (`com.example.app.service`)

## Immutability

- Prefer `record` for value types (Java 16+)
- Mark fields `final` by default — mutable only when required
- Return defensive copies: `List.copyOf()`, `Map.copyOf()`

```java
// Immutable value type
public record OrderSummary(Long id, String customerName, BigDecimal total) {}

// Final fields, no setters
public class Order {
    private final Long id;
    private final List<LineItem> items;

    public List<LineItem> getItems() {
        return List.copyOf(items);
    }
}
```

## Modern Java (17+)

- **Records** for DTOs and value types
- **Sealed classes** for closed type hierarchies
- **Pattern matching** with `instanceof` — no explicit cast
- **Switch expressions** with arrow syntax
- **Text blocks** for multi-line strings (SQL, JSON)

```java
// Pattern matching instanceof
if (shape instanceof Circle c) {
    return Math.PI * c.radius() * c.radius();
}

// Sealed hierarchy + exhaustive switch
public sealed interface PaymentResult permits PaymentSuccess, PaymentFailure {}
String msg = switch (result) {
    case PaymentSuccess s -> "Paid: " + s.transactionId();
    case PaymentFailure f -> "Failed: " + f.errorCode();
};
```

## Optional

- Return `Optional<T>` from finder methods that may have no result
- Use `map()`, `flatMap()`, `orElseThrow()` — never `get()` without `isPresent()`
- Never use `Optional` as a field type or method parameter

```java
return repository.findById(id)
    .map(ResponseDto::from)
    .orElseThrow(() -> new OrderNotFoundException(id));
```

## Error Handling

- Unchecked domain exceptions extending `RuntimeException`
- Include context in messages: `"Order not found: id=" + id`
- Avoid broad `catch (Exception e)` unless at top-level handlers

## Streams

- Keep pipelines short (3-4 operations max)
- Prefer method references: `.map(Order::getTotal)`
- No side effects in stream operations
- Complex logic? Use a loop instead of convoluted streams

## Testing

- **JUnit 5** (`@Test`, `@ParameterizedTest`, `@Nested`, `@DisplayName`)
- **AssertJ** for fluent assertions: `assertThat(result).isEqualTo(expected)`
- **Mockito** with `@ExtendWith(MockitoExtension.class)` and constructor injection
- **Testcontainers** for integration tests with real databases
- Test naming: `methodName_scenario_expectedBehavior()` + `@DisplayName`
- Target **80%+ coverage** with JaCoCo

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {
    @Mock private OrderRepository orderRepository;
    private OrderService orderService;

    @BeforeEach
    void setUp() {
        orderService = new OrderService(orderRepository);
    }

    @Test
    @DisplayName("findById throws when order not found")
    void findById_missingOrder_throws() {
        when(orderRepository.findById(99L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> orderService.findById(99L))
            .isInstanceOf(OrderNotFoundException.class)
            .hasMessageContaining("99");
    }
}
```
