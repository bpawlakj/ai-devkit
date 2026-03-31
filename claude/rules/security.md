---
paths:
  - "**/*.java"
  - "**/*.py"
  - "**/*.swift"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.yml"
  - "**/*.yaml"
  - "**/*.properties"
  - "**/.env*"
  - "**/Dockerfile"
  - "**/docker-compose*.yml"
---
# Security Standards

## Pre-Commit Checklist

Before ANY commit, verify:
- No hardcoded secrets (API keys, passwords, tokens)
- All user inputs validated at system boundaries
- SQL injection prevention (parameterized queries only)
- XSS prevention (sanitized output)
- CSRF protection where applicable
- Authentication/authorization verified on all endpoints
- Rate limiting on public endpoints
- Error messages don't leak internals (stack traces, paths, SQL)

## Secret Management

Never hardcode credentials in source code.

```java
// Java
String apiKey = System.getenv("API_KEY");
Objects.requireNonNull(apiKey, "API_KEY must be set");
```

```python
# Python
import os
api_key = os.environ["API_KEY"]  # Raises KeyError if missing
```

```typescript
// TypeScript/Node.js
const apiKey = process.env.API_KEY;
if (!apiKey) throw new Error("API_KEY not configured");
```

```swift
// Swift — use Keychain Services for tokens/passwords, never UserDefaults
```

## Injection Prevention

- **SQL:** Always use parameterized queries (`?`, `$1`, named params). Never concatenate user input into SQL.
- **Command injection:** Never pass user input to shell commands. Use safe APIs.
- **Path traversal:** Normalize paths, reject `..` segments, validate against allowed directories.

## Error Messages

- Log detailed errors server-side with proper logging framework
- Return generic messages to clients — never expose stack traces, internal paths, or SQL errors
- Map exceptions to safe HTTP status codes at handler boundaries

## Dependency Security

- **Java:** OWASP Dependency-Check or Snyk, enable Dependabot/Renovate
- **Python:** `bandit -r src/` for static analysis
- **Node.js/TS:** `npm audit`, Snyk, enable Dependabot/Renovate
- **Swift:** Xcode dependency auditing

## Threat Modeling (STRIDE)

For security-sensitive features (auth, payments, data access, APIs), analyze threats using STRIDE:

| Threat | Question | Mitigation |
|---|---|---|
| **Spoofing** | Can an attacker impersonate a user or service? | Strong auth, token validation, mutual TLS |
| **Tampering** | Can data be modified in transit or at rest? | Input validation, checksums, signed payloads |
| **Repudiation** | Can a user deny performing an action? | Audit logs, immutable event streams |
| **Information Disclosure** | Can sensitive data leak? | Encryption, access control, sanitized errors |
| **Denial of Service** | Can the system be overwhelmed? | Rate limiting, timeouts, resource quotas |
| **Elevation of Privilege** | Can a user gain unauthorized access? | Least privilege, role checks at every layer |

Apply STRIDE when:
- Adding/modifying authentication or authorization
- Exposing new API endpoints
- Handling user-uploaded files or content
- Integrating with external services
- Processing payments or sensitive PII

## Security Response Protocol

If a security issue is found:
1. STOP current work immediately
2. Assess severity (CRITICAL/HIGH/MEDIUM/LOW)
3. Fix CRITICAL issues before continuing any other work
4. Rotate any potentially exposed secrets
5. Review codebase for similar patterns
