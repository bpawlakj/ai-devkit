# Security Baseline — Rules

Evaluated against the **task diff** before commit (Step 6 of `/implement`). Each rule
is blocking in Full mode; in Partial mode only SEC-01..05 block (the rest are advisory).
Rules that don't apply to the diff (e.g. SEC-10 in a backend-only change) are marked
`N/A` with a one-line justification — N/A is a finding state, not a silent skip.

### SEC-01 — No hardcoded secrets

**Rule**: No credentials, API keys, tokens, or private keys appear in code, config, or test fixtures added by this task.

**Verify**:
- Scan the diff for assignment patterns (`password=`, `api_key=`, `token=`, `secret=`, `Bearer `, `-----BEGIN`) with literal values.
- New config files reference secrets via environment variables or a secrets manager, never literals.
- Test fixtures use obviously-fake placeholder values (`test-key-not-real`), not real-looking credentials.

### SEC-02 — Input validation at trust boundaries

**Rule**: Every new input crossing a trust boundary (HTTP params, request bodies, file uploads, CLI args from untrusted sources, queue messages) is validated before use.

**Verify**:
- New endpoints / handlers validate type, length, range, or schema of inputs before business logic runs.
- Validation failures return a controlled error, not an unhandled exception.
- Deserialization of external data uses safe parsers (no `eval`, no unsafe YAML/pickle load).

### SEC-03 — Parameterized queries

**Rule**: No database query added by this task builds SQL (or NoSQL filter expressions) via string concatenation or interpolation of external input.

**Verify**:
- New queries use parameter binding, prepared statements, or the ORM's query builder.
- Dynamic identifiers (table/column names from input) are allowlisted, not interpolated.

### SEC-04 — No sensitive data in logs

**Rule**: No log statement added by this task writes passwords, tokens, session ids, full payment data, or unmasked PII.

**Verify**:
- New log lines that include request/response objects mask or omit sensitive fields.
- Error logs don't echo raw user input that may contain credentials.

### SEC-05 — Authorization on new operations

**Rule**: Every new endpoint, mutation, or privileged operation checks that the caller is allowed to perform it — authentication alone is not authorization.

**Verify**:
- New routes/handlers carry the same authz middleware/guard pattern as existing ones (or document why the operation is public).
- Object-level access is checked (caller can only reach their own resources) — not just role-level.

### SEC-06 — Controlled error surfaces

**Rule**: Errors returned to users by code in this task expose no stack traces, internal paths, query text, or dependency versions.

**Verify**:
- New catch/except blocks map internal errors to generic user-facing messages.
- Detailed diagnostics go to logs (subject to SEC-04), not to the response body.

### SEC-07 — Dependency hygiene

**Rule**: Dependencies added by this task are pinned, sourced from the official registry, and not known-vulnerable versions.

**Verify**:
- New entries in the manifest specify a version (no floating `latest`).
- The package name matches the intended library (typosquatting check — one-character diffs from popular names are suspect).
- If a lockfile audit tool is configured in the project (`npm audit`, `pip-audit`, `cargo audit`), it reports no new high/critical findings.

### SEC-08 — No weak or homegrown crypto

**Rule**: Code added by this task uses platform/stdlib or well-known library crypto primitives — never custom implementations — and avoids MD5/SHA-1 for security purposes.

**Verify**:
- Hashing of passwords uses a purpose-built KDF (bcrypt/scrypt/argon2), not a general hash.
- Random values used for security (tokens, ids) come from a CSPRNG, not `Math.random()`/`random.random()`.

### SEC-09 — Path and file safety

**Rule**: File paths derived from external input in this task cannot escape their intended directory.

**Verify**:
- User-supplied filenames are sanitized or mapped to generated names before filesystem use.
- Path joins resolve and verify the result is inside the allowed base directory.

### SEC-10 — Output encoding

**Rule**: User-controlled data rendered by code in this task is encoded for its output context (HTML, attribute, JS, URL).

**Verify**:
- Templating uses the framework's auto-escaping (no `dangerouslySetInnerHTML` / `| safe` / `v-html` on user data without sanitization).
- Data placed into URLs or headers is encoded/validated for that context.
