---
paths:
  - "**/*.py"
  - "**/*.pyi"
---
# Python Standards

## Style

- Follow **PEP 8** conventions
- **Type annotations** on all function signatures
- **ruff** for linting and formatting

## Immutability

Prefer immutable data structures:

```python
from dataclasses import dataclass
from typing import NamedTuple

@dataclass(frozen=True)
class User:
    name: str
    email: str

class Point(NamedTuple):
    x: float
    y: float
```

Never mutate function arguments — return new objects.

## Patterns

**Protocol for duck typing:**

```python
from typing import Protocol

class Repository(Protocol):
    def find_by_id(self, id: str) -> dict | None: ...
    def save(self, item: dict) -> None: ...
```

- Use `@dataclass` for DTOs and structured data
- Use `with` statements (context managers) for resource management
- Use generators for memory-efficient iteration over large datasets

## File Organization

- 200-400 lines typical, 800 max per file
- Organize by feature/domain, not by layer
- Extract utilities when modules grow large

## Error Handling

- Handle errors explicitly — never silently swallow exceptions
- Use `logging` module — never `print()` in production
- Fail fast with clear error messages at system boundaries
- Include context: `raise ValueError(f"Invalid order: id={order_id}")`

## Testing

- **pytest** as the test framework
- Use `pytest.mark` for categorization:

```python
import pytest

@pytest.mark.unit
def test_calculate_total():
    assert calculate_total([10, 20]) == 30

@pytest.mark.integration
def test_database_connection():
    ...
```

- Coverage: `pytest --cov=src --cov-report=term-missing`
- Target **80%+ coverage**

## Code Quality

- Functions under 50 lines
- No deep nesting (>4 levels)
- No hardcoded values — use config/constants
- Validate at system boundaries (user input, API responses, external data)
