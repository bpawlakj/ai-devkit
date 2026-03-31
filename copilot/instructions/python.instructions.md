---
applyTo: "**/*.py,**/*.pyi"
---

# Python Standards

## Style
- PEP 8, type annotations on all function signatures, ruff for linting+formatting.

## Immutability
- `@dataclass(frozen=True)`, `NamedTuple`. Never mutate function arguments.

## Patterns
- `Protocol` for duck typing, dataclasses as DTOs, context managers for resources, generators for lazy iteration.

## Organization
- 200-400 lines typical, 800 max. Functions under 50 lines, nesting under 4 levels.

## Error Handling
- Explicit handling, `logging` module (never `print()`), fail fast at boundaries with context.

## Testing
- pytest with `pytest.mark` categorization (unit/integration). `pytest --cov`, target 80%+.
