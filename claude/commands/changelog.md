Generate a changelog entry for the current branch.

## Process

### 1. Gather Commits

```bash
git log --oneline $(git merge-base HEAD main)..HEAD
```

If `main` doesn't exist, try `master`. If neither exists, use the last 20 commits.

### 2. Analyze Changes

Read the commit messages and diffs to understand what changed. Group by:

- **Features** — new capabilities users can now use
- **Fixes** — bugs that were resolved
- **Improvements** — performance, UX, or code quality enhancements
- **Breaking Changes** — changes requiring user action to upgrade

Only include categories that have entries.

### 3. Generate Entry

Format:

```markdown
## [version] - YYYY-MM-DD

### Features
- Add [what] for [why/benefit]

### Fixes
- Fix [problem] that caused [symptom]

### Improvements
- Improve [what] by [how] ([metric] improvement)
```

Rules:
- Lead with what users can now DO, not implementation details
- Plain language — no commit hashes, no file paths, no author names
- One line per change — concise but specific
- Use present tense: "Add", "Fix", "Improve", "Remove"

### 4. Apply

- If `CHANGELOG.md` exists: prepend the new entry below the header, show the diff
- If not: create `CHANGELOG.md` with `# Changelog` header + entry
- Detect current version from `VERSION`, `package.json`, `pyproject.toml`, `pom.xml`, or `build.gradle`
- If no version file found, use `[Unreleased]` as version placeholder
- Show the result and ask user to confirm before committing
