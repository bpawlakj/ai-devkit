---
applyTo: "**/*.swift,**/Package.swift"
---

# Swift & iOS Standards

## Style
- SwiftFormat + SwiftLint. `let` over `var`, `struct` over `class` by default.
- Apple API Design Guidelines: clarity at point of use.

## Concurrency (Swift 6)
- Strict concurrency. `Sendable` value types. Actors for shared mutable state.
- Structured concurrency (`async let`, `TaskGroup`) over unstructured `Task {}`.

## Error Handling
- Typed throws (Swift 6+). Pattern matching on error types.

## Patterns
- Protocol-oriented design. Value types with enums for state.
- DI via protocols with default parameters.

## Testing
- Swift Testing (`@Test`, `#expect`). Parameterized tests. Fresh instance per test.

## iOS-Specific
- Keychain Services for secrets (never UserDefaults). ATS enabled.
- Validate external data (deep links, pasteboard, APIs). `os.Logger` (not `print()`).
