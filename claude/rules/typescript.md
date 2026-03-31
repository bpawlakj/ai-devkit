---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---
# TypeScript/JavaScript Standards

## Type Safety

- Explicit types on exported functions, public methods, and shared utilities
- Let TypeScript infer obvious local variable types
- **Never use `any`** — use `unknown` with proper type narrowing for external input
- Narrow errors with `instanceof` before accessing properties

```typescript
// GOOD — unknown with narrowing
catch (error: unknown) {
    if (error instanceof Error) {
        logger.error(error.message);
    }
}

// BAD — loses all type safety
catch (error: any) {
    logger.error(error.message);
}
```

## Interface vs Type

- `interface` for extensible object shapes (can be extended/merged)
- `type` for unions, intersections, and utility types
- Prefer string literal unions over enums unless interoperability requires otherwise

```typescript
// Interface for objects
interface UserProfile {
    id: string;
    name: string;
    email: string;
}

// Type for unions/utilities
type Status = "active" | "suspended" | "closed";
type Nullable<T> = T | null;
```

## Immutability

- Spread operators for object/array updates — never direct mutation
- `readonly` for props that should not change
- `as const` for literal assertions

## Validation

Use **Zod** for runtime validation with type inference:

```typescript
import { z } from "zod";

const UserSchema = z.object({
    name: z.string().min(1),
    email: z.string().email(),
    age: z.number().int().positive().optional(),
});

type User = z.infer<typeof UserSchema>;
```

## Naming

- `PascalCase` — components, interfaces, types, classes
- `camelCase` — functions, variables, methods
- `UPPER_SNAKE_CASE` — constants
- Files: `kebab-case.ts` or `PascalCase.tsx` for components

## Logging

Never use `console.log` in production code. Use a proper logging library (Winston, Pino, or framework-specific logger).

## Testing

- **Vitest** or **Jest** for unit tests
- **Playwright** for E2E tests
- Test files: `*.test.ts` or `*.spec.ts`
- Arrange-Act-Assert pattern
