# Audit Dimensions (canonical reference)

`/rule-review` evaluates a rule file across the seven dimensions below. Each dimension has explicit signals, thresholds, and at least one cited piece of evidence per finding.

## Dimension 1 — Length

**Signal**: total line count of the canonical rules file (frontmatter + body).

**Thresholds**:
- ≤ 150 lines — OK.
- 151–200 — WARN. "At the recommended ceiling — consider splitting area-specific content into nested `<area>/AGENTS.md`."
- 201–300 — FAIL. "Over guidance. Identify the largest sections and split."
- > 300 — FAIL (critical). "Middle of file is in low-attention zone; rules in the bottom half rarely fire."

**Why**: Lulla et al. eval showed monolithic / oversized rules files lose efficiency. Liu et al. ("Lost in the Middle") shows U-shaped attention — long contexts are best attended at start and end, weakest in the middle.

## Dimension 2 — Embedded code or config blocks

**Signal**: fenced code block lines, per block.

**Thresholds**:
- 1–10 lines per block — OK.
- 11–25 — WARN. "Extract to a referenced file; leave a pointer."
- > 25 — FAIL. "Inline blob is a context tax; rules file should reference, not duplicate."

**Why**: rules files are read every session. Pasted config repeats the cost of content the agent could fetch on demand.

## Dimension 3 — Language precision

**Signal**: regex on each rule line.

**Triggers**:
- Weak verbs: `\b(consider|try to|maybe|might|could)\b` — rewrite imperatively.
- Empty intent: `\b(clean|good|quality|nice|elegant|maintainable|robust)\s+code\b` — rewrite as observable behavior.
- Vague directive: rules with `should|must|always|never` but no measurable object → rewrite or drop.
- Descriptive instead of prescriptive: no imperative verb → rewrite.

**Verdict**: WARN per flagged line. Always print a one-line rewrite suggestion.

**Why**: ambiguous rules don't change agent behavior. Cursor's own rules doc: "Rules should be focused, executable, scoped."

## Dimension 4 — Redundancy with auto-active layer

**Signal**: keyword overlap between each rule and the topic index of `~/.claude/rules/*.md`.

**Build the index** (per session, in memory):
```bash
for f in ~/.claude/rules/*.md; do
  grep -E '^(##|-)\s' "$f" | head -50
done
```

**Per rule**:
- Tokenize the rule line (drop stopwords).
- Match against ai-devkit rule files (`typescript.md`, `python.md`, `go.md`, `react.md`, `node.md`, `security.md`, …).
- ≥ 3 token overlap with a specific rule line → likely covered.

**Verdicts**:
- Exact / near-exact coverage → FAIL. Cite `~/.claude/rules/<file>.md` line.
- Partial overlap → WARN; ask user.
- No match, but topic matches mainstream framework knowledge (React hooks, REST conventions) → WARN.
- Local-specific (anchored in `docs/`) → OK.

**Why**: Gloaguen et al. showed redundancy with already-known content costs +20–23%.

**Graceful degradation**: if `~/.claude/rules/` is missing, skip Dimension 4 with a note.

## Dimension 5 — Order

**Signal**: position of critical rules within the file.

**"Critical" heuristic** (in priority order):
1. Rule appears under a heading containing "Critical", "Must", "Non-negotiable", "Critical rules".
2. Rule line contains explicit tags: `**critical**`, `(critical)`, `[critical]`, `**must**`.
3. Rule content matches a sensitive domain: access control, destructive operation, irreversible action, secrets, deployment.

**Verdicts**:
- All critical rules in the top third of the file → OK.
- Critical rules in middle third → WARN. "U-shaped attention puts middle in low-attention zone."
- Critical rules at the bottom or scattered → FAIL.

**Suggested layout** (when reordering):
```
Critical → Conventions → Workflow → References → Out-of-scope footer
```

**Why**: same as Dimension 1 — U-shaped attention.

## Dimension 6 — Cross-tool drift (beyond 10x)

**Signal**: multiple rule files for the same scope.

**Detection**:
```bash
# at the directory level of the target file
ls AGENTS.md CLAUDE.md .github/copilot-instructions.md 2>/dev/null
find . -name '*.mdc' -path '*/.cursor/rules/*' 2>/dev/null
```

**Allowed shapes**:
- `AGENTS.md` is canonical.
- `CLAUDE.md` is a one-line import shim (`@AGENTS.md`) OR a symlink to `AGENTS.md`.
- `.github/copilot-instructions.md` is either a shim (link) or a copy (will drift over time — flag as known risk).
- `.cursor/rules/*.mdc` are area-scoped (have globs in their frontmatter); should not restate repo-wide rules from `AGENTS.md`.

**Drift detection**:
- For each pair of canonical-ish files, normalize lines (strip whitespace, lowercase) and look for rule lines that exist in both but differ.
- Report side-by-side diffs with line refs.

**Verdicts**:
- Shim-only siblings → OK.
- Restating, but identical → WARN. Consolidate into one source of truth.
- Restating, divergent → FAIL. Print conflict pairs.

**Why**: agents pick one or the other unpredictably. Drift is a hidden coin flip.

## Dimension 7 — Dead rules (beyond 10x)

**Signal**: grep the codebase for each rule's targeted pattern.

**Construction**:
- Parse each rule for a code pattern (file glob, language token, import path, function name, file naming convention).
- Build a grep query: `grep -rEn '<pattern>' --include='<lang-glob>' <repo>`.

**Verdicts**:
- Pattern is referenced widely → OK (rule is alive).
- Pattern is rare → OK.
- Pattern is absent → WARN. "No code matches what this rule targets. Possibly obsolete."
- **Forbidden** pattern still present → FAIL. "Rule is being violated. Files: …"

**Skip**: rules that don't grep — workflow rules ("PRs must have a docs/work/ ref"), business rules ("attendance mutations require trainer-of-record"). Note them as "not grep-checkable".

**Why**: rule files accrete. Frameworks evolve. The class-vs-hooks rule from 2020 is dead weight in a 2026 hooks-only repo. Surfacing dead rules keeps the file lean.

## Combined verdict

| Dimensions failing | Overall |
|---|---|
| 0 | PASS — file is in good shape. |
| 1–2 (WARN only) | PASS with notes. Apply incremental fixes. |
| 1–2 (one FAIL) | NEEDS-FIX. Run `--fix` or address manually. |
| 3+ or any critical | REWRITE. Strongly recommend `/agents-md` re-author from scratch. |
