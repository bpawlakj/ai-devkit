---
description: Fix Go build errors, go vet warnings, and linter issues incrementally. Invokes the go-build-resolver agent for minimal, surgical fixes.
---

# Go Build and Fix

This command invokes the **go-build-resolver** agent to incrementally fix Go build errors with minimal changes.

## What This Command Does

1. **Run Diagnostics**: Execute `go build`, `go vet`, `staticcheck`
2. **Parse Errors**: Group by file and sort by severity
3. **Fix Incrementally**: One error at a time
4. **Verify Each Fix**: Re-run build after each change
5. **Report Summary**: Show what was fixed and what remains

## Diagnostic Commands

```bash
go build ./...
go vet ./...
staticcheck ./... 2>/dev/null || true
golangci-lint run 2>/dev/null || true
go mod verify
go mod tidy -v
```

## Fix Strategy

1. **Build errors first** — code must compile
2. **Vet warnings second** — fix suspicious constructs
3. **Lint warnings third** — style and best practices
4. **One fix at a time** — verify each change
5. **Minimal changes** — don't refactor, just fix

## Common Errors Fixed

| Error | Typical Fix |
|-------|-------------|
| `undefined: X` | Add import or fix typo |
| `cannot use X as Y` | Type conversion or fix assignment |
| `missing return` | Add return statement |
| `X does not implement Y` | Add missing method |
| `import cycle` | Restructure packages |
| `declared but not used` | Remove or use variable |
| `cannot find package` | `go get` or `go mod tidy` |

## Stop Conditions

The agent will stop and report if:
- Same error persists after 3 attempts
- Fix introduces more errors
- Requires architectural changes
- Missing external dependencies
