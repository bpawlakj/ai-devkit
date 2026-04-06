---
applyTo: "**/*.go,**/go.mod,**/go.sum"
---

# Go Standards

## Style
- gofmt and goimports mandatory. Accept interfaces, return structs. Keep interfaces small (1-3 methods).

## Error Handling
- Wrap errors with context: `fmt.Errorf("context: %w", err)`. Use `errors.Is`/`errors.As`, never `==`. Return errors, don't panic.

## Patterns
- Functional options for constructors. Constructor injection for dependencies. Define interfaces where used, not implemented. `context.Context` as first parameter.

## Concurrency
- `context.Context` for timeouts. `sync.Mutex`/`sync.RWMutex` with `defer Unlock()`. `errgroup` for coordinated goroutines. Every goroutine needs a cancellation path.

## Security
- Secrets from env vars only. `gosec ./...` for scanning. `filepath.Clean` + prefix check for user paths.

## Testing
- Table-driven tests, `go test -race ./...`, `go test -cover ./...`, target 80%+. Use `t.Helper()` and `t.Cleanup()`.

## Quality
- Functions under 50 lines, nesting under 4 levels. No package-level mutable state. Pre-allocate slices, `strings.Builder` in loops.
