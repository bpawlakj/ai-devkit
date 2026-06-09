---
name: api-hurl
title: Hurl API runner
rules_file: api-hurl.md
artifacts: ["tests/e2e/api/*.hurl"]
tool: hurl
---

Runs plain-text `.hurl` HTTP specs — request chaining, capture, and JSONPath/XPath
assertions — as a test suite. Worth enabling when you want browser-free, language-
agnostic API scenarios that diff cleanly in git and run without Node (single Rust
binary). Use over Playwright's `request` fixture when the API contract lives apart
from the web suite or the team prefers declarative HTTP files over TypeScript.
