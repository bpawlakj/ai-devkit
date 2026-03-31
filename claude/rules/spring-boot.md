---
paths:
  - "**/*.java"
  - "**/application*.yml"
  - "**/application*.properties"
  - "**/pom.xml"
  - "**/build.gradle"
  - "**/build.gradle.kts"
---
# Spring Boot Standards

## Layered Architecture

Controller (thin, validation) -> Service (business logic) -> Repository (data access).

**Constructor injection only** — never field injection with `@Autowired`:

```java
// GOOD
public class OrderService {
    private final OrderRepository orderRepository;
    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }
}

// BAD — untestable without reflection
public class OrderService {
    @Autowired private OrderRepository orderRepository;
}
```

## REST API

```java
@RestController
@RequestMapping("/api/v1/orders")
@Validated
public class OrderController {
    @GetMapping
    public ResponseEntity<Page<OrderResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(orderService.findAll(PageRequest.of(page, size)));
    }
}
```

## DTOs with Validation

Use records with Bean Validation:

```java
public record CreateOrderRequest(
    @NotBlank String customerName,
    @NotNull @Positive BigDecimal amount,
    @Size(min = 1) List<@Valid LineItemRequest> items
) {}
```

Always use `@Valid` on controller parameters to trigger validation.

## Exception Handling

Centralized via `@ControllerAdvice`:

```java
@ControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(OrderNotFoundException.class)
    public ResponseEntity<ProblemDetail> handleNotFound(OrderNotFoundException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(problem);
    }
}
```

Never expose stack traces or internal details in API responses.

## Transactions

- `@Transactional` on service methods that modify data
- `@Transactional(readOnly = true)` for read-only queries (optimizes connection)
- Keep transactions short — no external API calls inside transactions

## Spring Security

- Stateless JWT with `OncePerRequestFilter` for API-only services
- `@EnableMethodSecurity` + `@PreAuthorize("hasRole('ADMIN')")` for method-level authorization
- CSRF: disable for stateless Bearer token APIs, enable for browser sessions
- CORS: explicit allowed origins — never `*` in production
- Secrets via `${ENV_VAR}` placeholders in `application.yml`, never hardcoded

## Production Defaults

- `spring.mvc.problemdetails.enabled=true` — RFC 9457 error responses
- HikariCP pool: `maximum-pool-size` based on `connections = cores * 2 + disk_spindles`
- Structured JSON logging (Logback + logstash-encoder or similar)
- Micrometer + Actuator for metrics (`/actuator/health`, `/actuator/prometheus`)

## Testing

- **`@WebMvcTest`** + MockMvc for controller isolation (no full context)
- **`@SpringBootTest`** + Testcontainers for integration tests with real DB
- **`@DataJpaTest`** for repository layer isolation
- Follow Arrange-Act-Assert pattern
