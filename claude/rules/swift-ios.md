---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift & iOS Standards

## Style

- **SwiftFormat** for auto-formatting, **SwiftLint** for style enforcement
- `let` over `var` — default to immutable, only use `var` when compiler requires it
- `struct` over `class` — use class only when identity or reference semantics are needed
- Follow [Apple API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/): clarity at point of use

## Concurrency (Swift 6)

Enable strict concurrency checking. Prefer:

- `Sendable` value types for data crossing isolation boundaries
- **Actors** for shared mutable state (not locks or DispatchQueue)
- Structured concurrency (`async let`, `TaskGroup`) over unstructured `Task {}`

```swift
actor Cache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: Value] = [:]

    func get(_ key: Key) -> Value? { storage[key] }
    func set(_ key: Key, value: Value) { storage[key] = value }
}
```

## Error Handling

Use typed throws (Swift 6+) and pattern matching:

```swift
func load(id: String) throws(LoadError) -> Item {
    guard let data = try? read(from: path) else {
        throw .fileNotFound(id)
    }
    return try decode(data)
}
```

## Patterns

**Protocol-oriented design** — small, focused protocols with default extensions:

```swift
protocol Repository: Sendable {
    associatedtype Item: Identifiable & Sendable
    func find(by id: Item.ID) async throws -> Item?
    func save(_ item: Item) async throws
}
```

**Value types with enums for state:**

```swift
enum LoadState<T: Sendable>: Sendable {
    case idle, loading, loaded(T), failed(Error)
}
```

**Dependency injection** via protocols with default parameters:

```swift
struct UserService {
    private let repository: any UserRepository
    init(repository: any UserRepository = DefaultUserRepository()) {
        self.repository = repository
    }
}
```

## Testing

Use **Swift Testing** framework (`import Testing`):

```swift
@Test("User creation validates email")
func userCreationValidatesEmail() throws {
    #expect(throws: ValidationError.invalidEmail) {
        try User(email: "not-an-email")
    }
}

@Test("Validates formats", arguments: ["json", "xml", "csv"])
func validatesFormat(format: String) throws {
    let parser = try Parser(format: format)
    #expect(parser.isValid)
}
```

Each test gets a fresh instance. No shared mutable state between tests.

## iOS-Specific

- **Keychain Services** for sensitive data (tokens, passwords, keys) — never `UserDefaults`
- **App Transport Security** stays enabled — do not add ATS exceptions without justification
- Certificate pinning for critical endpoints
- Validate all external data (deep links, pasteboard, API responses) before use
- Use `os.Logger` for production logging — never `print()`
