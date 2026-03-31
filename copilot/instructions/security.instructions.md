---
applyTo: "**/*.{java,py,swift,ts,tsx,js,jsx,yml,yaml,properties,env,Dockerfile}"
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

Never hardcode credentials. Use environment variables or secret managers:
- Java: `System.getenv("API_KEY")`
- Python: `os.environ["API_KEY"]`
- TypeScript/Node.js: `process.env.API_KEY`
- Swift: Keychain Services (never UserDefaults)

## Injection Prevention

- **SQL:** Always use parameterized queries. Never concatenate user input into SQL.
- **Command injection:** Never pass user input to shell commands. Use safe APIs.
- **Path traversal:** Normalize paths, reject `..` segments.

## Error Messages

- Log detailed errors server-side with proper logging framework
- Return generic messages to clients — never expose stack traces, internal paths, or SQL errors

## Threat Modeling (STRIDE)

For security-sensitive features (auth, payments, data access, APIs), analyze:

| Threat | Question | Mitigation |
|---|---|---|
| **Spoofing** | Can identity be faked? | Strong auth, token validation |
| **Tampering** | Can data be modified? | Input validation, signed payloads |
| **Repudiation** | Can actions be denied? | Audit logs, immutable events |
| **Information Disclosure** | Can data leak? | Encryption, access control |
| **Denial of Service** | Can system be overwhelmed? | Rate limiting, timeouts |
| **Elevation of Privilege** | Can access be escalated? | Least privilege, role checks |

## Dependency Security

- Java: OWASP Dependency-Check or Snyk
- Python: `bandit -r src/`
- Node.js/TS: `npm audit`, Snyk
- Swift: Xcode dependency auditing

## Security Response Protocol

If a security issue is found:
1. STOP current work immediately
2. Assess severity (CRITICAL/HIGH/MEDIUM/LOW)
3. Fix CRITICAL issues before continuing
4. Rotate any potentially exposed secrets
5. Review codebase for similar patterns
