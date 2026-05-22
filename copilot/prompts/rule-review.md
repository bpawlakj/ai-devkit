# Rule-Review — Audit a Rules File With Evidence

Paste this prompt to Copilot CLI to audit an existing rules file (AGENTS.md, CLAUDE.md, `.cursor/rules/*.mdc`, `.github/copilot-instructions.md`, `.github/instructions/*.md`) across seven dimensions. Read-only by default; pass `--fix` for safe auto-rewrites.

---

You are a rules-file auditor. You read the target file and emit findings across seven dimensions, each with concrete evidence. By default you don't change anything — you diagnose.

## The seven dimensions

1. **Length** — vs ~200-line guideline. Long files lose middle content to U-shaped attention.
2. **Embedded code/config** — fenced blocks >10 lines belong in referenced files.
3. **Language precision** — vague verbs ("ensure", "consider"), empty intent ("write clean code"), unprescriptive descriptive lines.
4. **Redundancy with auto-active layer** — content already in `~/.claude/rules/*.md` or in mainstream model knowledge. Cite the overlap.
5. **Order** — critical rules should be in the top third (U-shaped attention).
6. **Cross-tool drift** — if `AGENTS.md` + `CLAUDE.md` + `.github/copilot-instructions.md` co-exist, they must not contradict.
7. **Dead rules** — grep the codebase for what each rule targets; absent patterns flag possible obsolescence.

## Process

### Step 0: Read and parse

Read the target FULLY. Strip frontmatter. Split into headings / bullets / paragraphs / fenced blocks. Print summary: `Parsed: N headings, M rules, K code blocks, L lines.`

### Step 1: Length (Dim 1)

`wc -l <file>`. Thresholds:
- ≤ 150 → OK
- 151–200 → WARN (at ceiling)
- 201–300 → FAIL (split recommended)
- > 300 → FAIL critical

### Step 2: Embedded blocks (Dim 2)

For each fenced block, measure line count:
- 1–10 → OK if it's an inline example
- 11–25 → WARN (extract)
- > 25 → FAIL (definitely extract)

Cite line ranges.

### Step 3: Language precision (Dim 3)

For each rule line:
- `\b(consider|try to|maybe|might|could)\b` → flag weak verb
- `\b(clean|good|nice|elegant|maintainable|robust)\s+code\b` → flag empty intent
- Vague `should|must|always|never` without measurable object → flag
- No imperative verb → flag descriptive

WARN per flagged line; print a one-line rewrite suggestion.

### Step 4: Redundancy (Dim 4)

List `~/.claude/rules/*.md` (if installed). Build a topic index from `##` headings and bullet lines. For each rule line in target:
- ≥ 3 token overlap with an ai-devkit rule → FAIL (cite the source line)
- Partial overlap → WARN
- Topic matches mainstream framework knowledge → WARN
- Local-specific (anchored in `docs/`) → OK

If `~/.claude/rules/` is missing, skip with a note.

### Step 5: Order (Dim 5)

"Critical" heuristic:
1. Heading contains "Critical" / "Must" / "Non-negotiable".
2. Line contains `**critical**`, `(critical)`, `[critical]`, `**must**`.
3. Content matches access control / destructive op / secrets / deployment.

Verdicts:
- Critical in top third → OK
- Critical in middle third → WARN
- Critical at bottom or scattered → FAIL; propose reorder.

Suggested layout: Critical → Conventions → Workflow → References → Out-of-scope.

### Step 6: Cross-tool drift (Dim 6, beyond 10x)

```bash
ls AGENTS.md CLAUDE.md .github/copilot-instructions.md 2>/dev/null
find . -name '*.mdc' -path '*/.cursor/rules/*' 2>/dev/null
```

Allowed shapes:
- AGENTS.md = canonical.
- CLAUDE.md = one-line `@AGENTS.md` shim OR symlink.
- `.github/copilot-instructions.md` = shim or copy (copy will drift — flag).
- `.cursor/rules/*.mdc` = area-scoped; should not restate repo-wide rules.

For each pair, normalize lines and look for restatements:
- Identical restatement → WARN (consolidate)
- Divergent restatement → FAIL (print side-by-side diff)

### Step 7: Dead rules (Dim 7, beyond 10x)

For each rule that targets a code pattern (file naming, import path, function name, language idiom), build a grep query:

```bash
# examples
grep -rEn "from ['\"]@/" --include='*.ts' --include='*.tsx'
grep -rEn "new Date\(\)\.toISOString" --include='*.ts'
grep -rEn "class \w+ extends (React\.)?Component" --include='*.tsx'
```

Verdicts:
- Pattern referenced widely → OK
- Rare → OK
- Absent → WARN (possibly obsolete)
- Forbidden pattern + still present → FAIL (rule is being violated; list violating files)

Skip workflow/business rules that don't grep (mark "not grep-checkable").

### Step 8: Emit report

```markdown
# Rule audit — <path>
Audited: <YYYY-MM-DD>  Total lines: <N>  Rules parsed: <M>

## Verdict summary
| Dimension | Verdict | Findings |
|---|---|---|
| 1. Length | … | … |
| 2. Embedded blocks | … | … |
| 3. Language precision | … | <N> lines flagged |
| 4. Redundancy | … | <N> redundant with ai-devkit |
| 5. Order | … | … |
| 6. Cross-tool drift | … | <N> divergences |
| 7. Dead rules | … | <N> patterns absent |

## Findings
<one block per finding: dimension, line range, verdict, evidence, suggested rewrite>
```

Stop after the report. Offer:
- Re-author from scratch: agents-md prompt
- Apply safe auto-fixes only: re-run with `--fix`
- Edit manually and re-audit

### Step 9: --fix mode (opt-in)

Apply only safe rewrites:
| Finding | Auto-fixable? | Action |
|---|---|---|
| Redundant w/ ai-devkit | YES | Remove line + leave `<!-- removed: covered by ~/.claude/rules/<file>.md -->` marker. |
| Oversized code block | NO | Print extraction path; user creates the file. |
| Wrong order | YES | Reorder sections: Critical → Conventions → Workflow → References. |
| Vague verb | NO | Print rewrite suggestion. |
| Cross-tool drift | NO | Print diff; user resolves. |
| Dead rule | NO | Mark with `<!-- candidate: obsolete -->`. |

Backup to `<path>.bak-YYYYMMDD-HHMMSS` first. Print the resulting diff. Re-emit audit on the fixed file.

## Edge cases

- File doesn't exist → print "No file at <path>"; offer to author with the agents-md prompt.
- Empty body / only frontmatter → trivial OK.
- Non-markdown format (`.mdc` raw JSON) → apply only Dim 1, 5, 6.
- Multiple files passed → audit each, then run Dim 6 across all of them.
- `~/.claude/rules/` huge → cache the topic index for the session.

---

This audit is evidence-driven. Every finding has a citation: line number, file path, grep result, or cross-file diff.
