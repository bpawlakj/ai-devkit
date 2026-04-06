---
paths:
  - "**/*.php"
  - "**/composer.json"
  - "**/composer.lock"
---
# PHP Standards

## Style

- Follow **PSR-12** formatting and naming conventions
- `declare(strict_types=1);` in all application code
- Scalar type hints, return types, and typed properties everywhere
- **PHP-CS-Fixer** or **Laravel Pint** for formatting
- **PHPStan** or **Psalm** for static analysis
- Add `use` statements for all referenced classes — avoid global namespace

## Immutability

- Prefer immutable DTOs and value objects for data crossing service boundaries
- Use `readonly` properties or immutable constructors for request/response payloads
- Keep arrays for simple maps; promote business-critical structures into explicit classes

## Patterns

**Thin controllers, explicit services:**

- Controllers handle transport: auth, validation, serialization, status codes
- Business rules go into application/domain services testable without HTTP bootstrapping

**DTOs and value objects:**

- Replace associative arrays with DTOs for requests, commands, and API payloads
- Use value objects for money, identifiers, date ranges, and constrained concepts

**Dependency injection:**

- Depend on interfaces or narrow service contracts, not framework globals
- Pass collaborators through constructors — no service-locator lookups
- Wrap third-party SDKs behind small adapters

## Error Handling

- Throw exceptions for exceptional states — avoid returning `false`/`null` as hidden error channels
- Convert framework/request input into validated DTOs before it reaches domain logic
- Never use `var_dump`, `dd`, `dump`, or `die()` in committed code

## Security

- Validate request input at framework boundary (`FormRequest`, Symfony Validator, or explicit DTO validation)
- Escape output in templates by default — raw HTML must be justified
- Use prepared statements (`PDO`, Doctrine, Eloquent query builder) — never string-build SQL
- Scope ORM mass-assignment carefully — whitelist writable fields
- Load secrets from environment variables or secret managers, never from committed config
- Run `composer audit` in CI — review new package trust before adding dependencies
- Use `password_hash()` / `password_verify()` for password storage
- Regenerate session IDs after authentication and privilege changes
- Enforce CSRF protection on state-changing web requests

## Testing

- **PHPUnit** as default framework. If **Pest** is configured, prefer Pest for new tests
- Separate fast unit tests from framework/database integration tests
- Use factory/builders for fixtures — not large hand-written arrays
- HTTP tests focused on transport and validation; business logic in service-level tests

```bash
vendor/bin/phpunit --coverage-text
# or
vendor/bin/pest --coverage
```

- Prefer **pcov** or **Xdebug** for coverage in CI
- Target **80%+ coverage**

## Code Quality

- Functions under 50 lines
- No deep nesting (>4 levels)
- No hardcoded values — use config/constants
- Validate at system boundaries (user input, API responses, external data)
