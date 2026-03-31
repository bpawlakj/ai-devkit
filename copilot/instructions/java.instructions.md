---
applyTo: "**/*.java"
---

# Java Standards

## Formatting & Naming
- google-java-format or Checkstyle. Member order: constants, fields, constructors, public, protected, private.
- `PascalCase` classes/interfaces, `camelCase` methods/fields, `SCREAMING_SNAKE_CASE` constants.

## Immutability
- Prefer `record` for value types (Java 16+). Mark fields `final` by default.
- Return defensive copies: `List.copyOf()`, `Map.copyOf()`.

## Modern Java (17+)
- Records for DTOs, sealed classes for closed hierarchies, pattern matching `instanceof`, switch expressions, text blocks.

## Optional
- Return `Optional<T>` from finder methods. Use `map()`/`flatMap()`/`orElseThrow()`.
- Never use Optional as field type or method parameter. Never call `get()` without `isPresent()`.

## Error Handling
- Unchecked domain exceptions extending `RuntimeException` with context in messages.
- Avoid broad `catch (Exception e)` unless at top-level handlers.

## Streams
- Short pipelines (3-4 ops), method references, no side effects.

## Testing
- JUnit 5 + AssertJ + Mockito + Testcontainers. `@DisplayName` for readable reports.
- Naming: `methodName_scenario_expectedBehavior()`. Target 80%+ coverage with JaCoCo.
