# /implement Extensions — Authoring Contract

Extensions add **opt-in quality gates** to the `/implement` loop. Each extension is a
set of identified, verifiable rules (e.g. `SEC-01`) that the skill checks against the
task diff before commit. The pattern is borrowed from AWS AI-DLC's extension mechanism:
lightweight descriptors are always loaded; full rules load only when the user opts in
(deferred loading — opting out costs zero context).

## File layout

Each extension is a flat pair in this directory:

```
<name>.opt-in.md    # lightweight descriptor — ALWAYS loaded at the opt-in gate
<name>.md           # full rules — loaded ONLY when the user opts in
```

Users may drop their own extension pairs into this directory; `/implement` discovers
them by globbing `*.opt-in.md` — no registration step.

## Descriptor format (`<name>.opt-in.md`)

```yaml
---
name: <kebab-case id, matches filename>
title: <human-readable title>
rules_file: <name>.md
partial_rules: [<RULE-IDs enforced in Partial mode>]
---
```

Body: 2–4 sentences describing what the extension checks and when it is worth enabling.
This is the ONLY content shown to the user at the opt-in gate — keep it short.

## Rules format (`<name>.md`)

Each rule follows this shape:

```markdown
### <PREFIX>-NN — <short title>

**Rule**: one-sentence statement of the constraint.

**Verify**: bullet list of concrete checks against the task diff. Plain bullets,
not checkboxes — these are evaluation criteria, not a to-do list.
```

Rule IDs are stable — never renumber existing rules; append new ones at the end.

## Enforcement semantics

The user picks one mode per extension, per initiative (recorded in the initiative's
`extensions.md`):

- **Full** — every rule is blocking.
- **Partial** — only the rules in `partial_rules` are blocking; the rest are advisory.
- **Off** — the rules file is never loaded.

A **blocking finding** means:

1. The finding is listed before the commit ask in Step 6, with its rule ID.
2. The commit does not proceed until the finding is resolved OR the user explicitly
   downgrades it for this task ("Downgrade to advisory — recorded").
3. Downgrades are appended to the initiative's `extensions.md` under `overrides:`
   with the rule ID, task ID, and one-line rationale — overrides are deliberate
   and auditable, never silent.

An **advisory finding** is printed with its rule ID but does not block.

## Scope of evaluation

Rules are evaluated against the **task diff** (files touched in the current task),
not the whole repository. Extensions gate new work; they are not a repo-wide audit —
use `/security-review` or `/threat-model` for that.
