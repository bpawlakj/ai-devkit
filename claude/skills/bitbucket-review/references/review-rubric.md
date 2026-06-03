# Review rubric — bitbucket-review

This is the brief handed to each review subagent. It defines **what to look for**, **how to rate
severity**, and **the exact output schema** the skill consumes. Mirror the dimensions of the
toolkit's `/code-review` so output feels consistent.

## Inputs the subagent receives

- Absolute path to the unified diff file (`pr-<id>.diff`).
- Optionally `--repo <path>`: a local clone the agent MAY read for full-file context.
- The PR title + destination branch (intent context).

## What to review

**Always (correctness + quality):**
- **Correctness / bugs**: logic errors, off-by-one, null/undefined, wrong conditionals, broken
  error handling, race conditions, resource leaks, incorrect API usage.
- **Reuse / simplification**: duplicated logic that an existing helper covers, over-complex code that
  a standard-library or existing-utility call would simplify, dead code.
- **Efficiency**: needless O(n²), N+1 queries, repeated work in loops, unbounded growth.
- **Consistency**: violates a pattern visible elsewhere in the diff; naming/idiom mismatch.

**Only with `--security`:**
- Auth/authorization gaps, unvalidated input, injection (SQL/command/template), secrets in code,
  unsafe deserialization, missing output encoding, broken access control, sensitive data in logs.

## Severity scale

- `blocker` — must fix before merge (data loss, security hole, crash, broken core behavior).
- `high` — likely bug or real risk; fix before merge.
- `medium` — should fix; correctness/maintainability concern with a workaround.
- `low` — minor; style/clarity/micro-optimization.
- `note` — informational; no action required.

## Confidence under diff-only context

Without `--repo`, you see only changed hunks. If a finding's validity depends on code you cannot
see (a caller, a type definition, an existing helper), say so in the `body` and prefer a lower
severity. Do not assert a bug you cannot confirm from the visible context.

## Line numbers

`new_line` MUST be a line in the **new** version of the file — i.e. an added (`+`) or context line
within a diff hunk. It is what the Bitbucket inline comment anchors to (`inline.to`). For a finding
about a **deleted** line (no new-file line), omit `new_line` (it becomes a summary/file-level note).
Never invent a number that isn't in the diff.

## Output schema (return EXACTLY this — a JSON array, nothing else)

```json
[
  {
    "path": "src/payments/charge.ts",
    "new_line": 84,
    "severity": "high",
    "title": "Unhandled rejection on refund path",
    "body": "`await refund()` is not wrapped; a network failure here leaves the order in PAID with no compensation. Wrap in try/catch and roll back, or move under the existing transaction at line 60.",
    "suggestion": "try {\n  await refund(orderId);\n} catch (e) {\n  await markRefundFailed(orderId, e);\n}"
  }
]
```

Field rules:
- `path` — new-file path as it appears after `+++ b/` in the diff.
- `new_line` — integer; omit for deleted-line / file-level findings.
- `severity` — one of the scale values above.
- `title` — one line, imperative.
- `body` — markdown; explain the problem and the fix. Reference other diff lines by number where useful.
- `suggestion` — optional; raw replacement code for a Bitbucket ```suggestion``` block. Only include
  when you can produce a concrete, correct replacement for the anchored line(s).

Return an empty array `[]` if nothing is worth raising. Do not include prose outside the JSON array.
