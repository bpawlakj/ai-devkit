# /e2e-run Extensions — Authoring Contract

Extensions add **opt-in API runners** to `/e2e-run` for artifacts Playwright's
`request` fixture doesn't cover — plain-text HTTP specs and OpenAPI-derived
property/stateful testing. The pattern mirrors `/implement`'s extension
mechanism: lightweight descriptors are always discoverable; full rules load only
when the user opts in (deferred loading — opting out costs zero context).

Playwright (web `.spec.ts` + API `.api.spec.ts`) is the **default** runner and is
NOT an extension — it always runs without opt-in.

## File layout

```
<name>.opt-in.md    # lightweight descriptor — read at the opt-in gate
<name>.md           # full rules: detection, install, run command, scoping
```

`/e2e-run` discovers extensions by globbing `*.opt-in.md`. Users may drop their
own pairs here — no registration step.

## Descriptor format (`<name>.opt-in.md`)

```yaml
---
name: <kebab-case id, matches filename>
title: <human-readable title>
rules_file: <name>.md
artifacts: [<glob or marker that triggers this extension>]
tool: <cli binary required>
---
```

Body: 2–4 sentences — what the runner does, what artifacts trigger it, when it's
worth enabling over plain Playwright. This is the only content shown at the gate.

## Rules format (`<name>.md`)

Cover, concretely:
- **Detect** — which files/markers in `tests/e2e/` (or the repo) trigger it.
- **Install** — the exact command to surface if the tool is absent (never
  auto-installed by `/e2e-run`).
- **Run** — the scoped command, including how to pass the resolved file set, base
  URL, and any auth/env.
- **Report** — what the tool emits and how `/e2e-run` should fold it into the
  combined per-layer report.

## Enablement semantics

Per project, recorded in `tests/e2e/extensions.md` (`enabled` | `off`, with a
`recorded:` date). An enabled extension whose tool is not installed makes
`/e2e-run` STOP with the install command — it never installs silently and never
auto-heals a failing run.
