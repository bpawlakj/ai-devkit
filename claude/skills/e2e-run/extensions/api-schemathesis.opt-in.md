---
name: api-schemathesis
title: Schemathesis (OpenAPI) runner
rules_file: api-schemathesis.md
artifacts: ["openapi.yaml", "openapi.json", "openapi.yml", "swagger.json", "swagger.yaml"]
tool: schemathesis
---

Auto-derives property-based and stateful API tests from an OpenAPI/Swagger spec
and runs them against a live base URL — covering edge cases and request sequences
hand-written tests usually miss. Worth enabling when the project has an OpenAPI
document and you want broad, generated coverage Playwright's request fixture can't
produce (fuzzing, schema conformance, stateful link-following). Complements, does
not replace, the hand-authored happy/edge scenarios.
