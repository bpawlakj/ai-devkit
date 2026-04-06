---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go Standards

## Style

- **gofmt** and **goimports** are mandatory — no style debates
- Accept interfaces, return structs
- Keep interfaces small (1-3 methods)

## Error Handling

Always wrap errors with context:

```go
if err != nil {
    return fmt.Errorf("failed to create user: %w", err)
}
```

- Use `errors.Is(err, target)` / `errors.As` — never compare with `==`
- Return errors, don't `panic()` for recoverable conditions
- Error messages: lowercase, no punctuation

## Patterns

**Functional options:**

```go
type Option func(*Server)

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func NewServer(opts ...Option) *Server {
    s := &Server{port: 8080}
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

**Dependency injection via constructors:**

```go
func NewUserService(repo UserRepository, logger Logger) *UserService {
    return &UserService{repo: repo, logger: logger}
}
```

- Define interfaces where they are used, not where they are implemented
- `context.Context` as first parameter — always propagate

## Concurrency

- Always use `context.Context` for timeout control
- Guard shared state with `sync.Mutex` or `sync.RWMutex`, always `defer mu.Unlock()`
- Use `errgroup` for coordinated goroutine work
- Prevent goroutine leaks — every goroutine must have a cancellation path

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
```

## Security

- Load secrets from environment variables or secret managers — never hardcode
- Run `gosec ./...` for static security analysis
- Validate and sanitize all external input
- Use `filepath.Clean` + prefix check for user-controlled file paths

## Testing

- **Table-driven tests** as the standard pattern:

```go
tests := []struct {
    name    string
    input   string
    want    int
    wantErr bool
}{
    {"valid", "42", 42, false},
    {"empty", "", 0, true},
}

for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got, err := Parse(tt.input)
        if (err != nil) != tt.wantErr {
            t.Errorf("Parse(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
        }
        if got != tt.want {
            t.Errorf("Parse(%q) = %v, want %v", tt.input, got, tt.want)
        }
    })
}
```

- Always run with race detector: `go test -race ./...`
- Coverage: `go test -cover ./...`
- Target **80%+ coverage**
- Use `t.Helper()` for test helper functions
- Use `t.Cleanup()` for teardown

## Code Quality

- Functions under 50 lines
- No deep nesting (>4 levels) — use early returns
- No package-level mutable state
- Pre-allocate slices when size is known: `make([]T, 0, cap)`
- Use `strings.Builder` for string concatenation in loops
