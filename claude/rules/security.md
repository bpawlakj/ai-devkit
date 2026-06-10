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
- New personal-data fields have a lawful basis and a retention path (see Privacy / GDPR)

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
- **Never swallow exceptions:** a `catch` that logs and returns a 2xx hides failures from clients and monitoring alike (OWASP 2025 **A10: Mishandling of Exceptional Conditions**). Propagate the error or map it to a non-2xx status — see `node.md` § Error Handling.

## Privacy / GDPR (Privacy by Design)

Applies whenever code collects, stores, or processes personal data (anything identifying a person: name, email, IP, device id, location, behavioral traces).

- **Data minimisation:** collect and persist only the fields the feature actually uses. A "might need it later" column is a liability, not an asset — add it when the need is real.
- **Lawful basis:** every new collection of personal data names its basis (consent / contract / legitimate interest) in the spec or PR description. Consent-based data requires a working revocation path.
- **Pseudonymisation:** logs, analytics events, and test fixtures reference opaque user IDs or hashes — never names, emails, or raw identifiers.

```typescript
// BAD — PII in logs
logger.info(`Login failed for ${user.email} from ${req.ip}`);

// GOOD — pseudonymous, still debuggable
logger.info(`Login failed`, { userId: user.id, ipHash: hash(req.ip) });
```

- **Retention:** personal data gets a TTL or a documented deletion path. "Keep forever" is a decision that must be made explicitly — never the default of a forgotten table.
- **Right to erasure:** account deletion deletes or irreversibly anonymizes the person's data, including in backups' restore procedures and downstream copies (analytics, search indexes).
- **Data subject rights:** features storing personal data must not structurally block export (access/portability) or deletion — e.g. don't bake PII into immutable event payloads without a crypto-shredding or anonymization strategy.

Org- or domain-specific compliance (e.g. minors / education regulations) lives in the project's `AGENTS.md` or foundation docs — this rule covers the generic GDPR baseline only.

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
