# Test of Inclusion (canonical reference)

Every candidate rule must pass one question before entering `AGENTS.md`:

> **Could the agent know this without this file**, given (a) the auto-active rules in `~/.claude/rules/`, and (b) the public docs and code already in the repository?

If yes → drop. If no → keep, and write the reason next to the rule.

## Decision matrix

| Candidate rule | Likely answer | Why |
|---|---|---|
| "Use `unknown` over `any` in TypeScript." | YES → drop | Covered by `~/.claude/rules/typescript.md` |
| "Wrap errors with `%w` in Go." | YES → drop | Covered by `~/.claude/rules/go.md` |
| "Always use prepared statements for SQL." | YES → drop | Covered by `~/.claude/rules/security.md` (auto-active on `.py`, `.ts`, `.java`, `.go`, etc.) and language-specific rules |
| "Mutations to `attendance` table must check `trainer_of_record = current_user`." | NO → keep | Local business rule; not in any auto-active file. Anchor: `docs/architecture/auth.md` |
| "All UI copy is in Polish." | NO → keep | Project decision; not derivable from code. Anchor: `docs/product-spec.md § Localization` |
| "Use Tailwind classes via `clsx`, not inline." | YES → drop | Conventional React + Tailwind pattern, derivable from `~/.claude/rules/react.md` + reading 2 existing components |
| "We're stuck on Express 4 because the org plugin only works there." | NO → keep | Embarrassing constraint — agent would otherwise upgrade and break things. Anchor: `docs/reference/lessons.md` |
| "Tests live in `__tests__/` adjacent to the file under test." | NO → keep | Convention not derivable from a single file. Anchor: a sample `__tests__/` directory shown in the codebase. |
| "Use 2-space indentation." | YES → drop | `.editorconfig` / `.prettierrc` enforce this. AGENTS.md is for non-trivial. |
| "Write clean, readable code." | YES → drop | Empty intention. Not a rule. |
| "Cron jobs in this repo are wrapped in `withLock()` to prevent concurrent runs (incident IR-2024-13)." | NO → keep | Incident-derived. Anchor: incident ticket or lessons.md entry. |
| "The auth middleware reads JWT from `Authorization: Bearer`, NOT cookies (legal/compliance)." | NO → keep | Constraint-derived. Anchor: `docs/architecture/auth.md`. |

## Reasons the answer is usually "yes → drop"

1. **Language-level conventions** — covered by `~/.claude/rules/*.md`.
2. **Framework defaults** — covered by the framework's docs the model already knows.
3. **Tool config enforces it** — covered by `.eslintrc`, `tsconfig`, `pyproject.toml`, etc.
4. **Repo grep would surface it** — three example components, three matching SQL files, three `__tests__/` dirs all make the convention discoverable in seconds.

## Reasons the answer is usually "no → keep"

1. **Constraints from incidents** — invisible without a person telling the agent.
2. **Domain business rules** — derivable only from product-spec / architecture docs, not from code shape.
3. **Legal / compliance constraints** — same as above; never inferable.
4. **"Embarrassing" workarounds** — keep using the broken-but-stable thing because the alternative made prod worse last quarter. Invisible from code.
5. **Cross-cutting workflows** — "all PRs must include a `docs/work/*` task ref" — workflow rule, not a code rule.

## What the test does NOT decide

- It does not decide if the rule is well-written. (That's `/rule-review`.)
- It does not decide if the rule belongs at root vs in `<area>/AGENTS.md`. (That's the size-budget step + scope analysis.)
- It does not decide order. (U-shaped attention: highest-priority at the top of the final file.)

## Saying "I don't know" is legal

If the user can't honestly answer yes/no, that itself is a signal: the rule is probably under-specified. Either:

- **Anchor it more concretely** ("we do X because of incident IR-..." vs "we do X"). Then re-ask the test.
- **Drop and let it surface again** — if the agent really does keep making the mistake, it'll come back into focus via `/lesson` later. Don't over-engineer up front.
