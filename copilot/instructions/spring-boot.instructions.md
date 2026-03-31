---
applyTo: "**/*.java,**/application*.yml,**/application*.properties,**/pom.xml,**/build.gradle*"
---

# Spring Boot Standards

## Architecture
Controller (thin) -> Service (business logic) -> Repository (data access). Constructor injection only — never `@Autowired` on fields.

## REST API
`@RestController` with `@Validated`, pagination via `Pageable`, return `ResponseEntity<T>`.

## DTOs & Validation
Record DTOs with Bean Validation: `@NotBlank`, `@Size`, `@Valid` on controller params.

## Exception Handling
`@ControllerAdvice` with `GlobalExceptionHandler`. Use `ProblemDetail` (RFC 9457). Never expose stack traces.

## Transactions
`@Transactional` on service methods. `@Transactional(readOnly = true)` for queries. Keep transactions short.

## Spring Security
- Stateless JWT with `OncePerRequestFilter` for APIs
- `@EnableMethodSecurity` + `@PreAuthorize` for authorization
- CSRF: disable for stateless APIs, enable for browser sessions
- CORS: explicit origins, never `*` in production
- Secrets via `${ENV_VAR}` in application.yml

## Production
- `spring.mvc.problemdetails.enabled=true`
- Structured JSON logging, Micrometer + Actuator metrics

## Testing
- `@WebMvcTest` + MockMvc for controllers
- `@SpringBootTest` + Testcontainers for integration
- `@DataJpaTest` for repository layer
