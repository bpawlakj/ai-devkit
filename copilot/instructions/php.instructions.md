---
applyTo: "**/*.php,**/composer.json,**/composer.lock"
---

# PHP Standards

## Style
- PSR-12, `declare(strict_types=1)`, scalar type hints + return types everywhere. PHP-CS-Fixer or Laravel Pint for formatting. PHPStan or Psalm for static analysis.

## Immutability
- Immutable DTOs and value objects with `readonly` properties. Arrays for simple maps, explicit classes for business structures.

## Patterns
- Thin controllers (transport only), business logic in services. DTOs over associative arrays. Constructor injection, interface contracts. Wrap third-party SDKs behind adapters.

## Error Handling
- Exceptions for exceptional states, not `false`/`null`. Validate input into DTOs before domain logic. No `var_dump`/`dd`/`dump`/`die()` in committed code.

## Security
- Validate at framework boundary (FormRequest, Symfony Validator). Prepared statements only (PDO, Eloquent). Whitelist mass-assignment fields. `password_hash()`/`password_verify()`. CSRF on state-changing requests. `composer audit` in CI.

## Testing
- PHPUnit (or Pest if configured). Separate unit/integration tests. Factory builders for fixtures. `--coverage-text`, target 80%+.
