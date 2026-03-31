---
applyTo: "**/*.ts,**/*.tsx,**/*.js,**/*.jsx"
---

# TypeScript/JavaScript Standards

## Type Safety
- Explicit types on public APIs. `unknown` over `any`. Type narrowing with `instanceof`.
- `interface` for extensible objects, `type` for unions/intersections.

## Immutability
- Spread operators for updates, `readonly` props, `as const` assertions.

## Error Handling
- try-catch with `unknown` error narrowing. Never bare `catch(e)`.

## Validation
- Zod schemas for runtime safety with type inference.

## Naming
- PascalCase components/interfaces, camelCase functions/variables, UPPER_SNAKE_CASE constants.

## Logging
- Proper logger (never `console.log` in production).

## Testing
- Vitest/Jest for unit tests, Playwright for E2E. Arrange-Act-Assert pattern.
