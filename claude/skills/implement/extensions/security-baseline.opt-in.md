---
name: security-baseline
title: Security Baseline
rules_file: security-baseline.md
partial_rules: [SEC-01, SEC-02, SEC-03, SEC-04, SEC-05]
---

Checks every task diff against 10 baseline security rules before commit: hardcoded
secrets, input validation at trust boundaries, query parameterization, sensitive data
in logs, authorization on new operations, error-detail leaks, dependency hygiene,
weak crypto, path traversal, and output encoding. Worth enabling for any code that
handles user input, auth, external data, or runs in production. Partial mode enforces
the five highest-value rules (SEC-01..05) and treats the rest as advisory.
