# Changelog — Generate Entry

Paste this prompt to Copilot CLI:

---

Generate a changelog entry for the current branch.

1. Run `git log --oneline $(git merge-base HEAD main)..HEAD`
2. Group changes: Features, Fixes, Improvements, Breaking Changes (only include non-empty categories)
3. Format: `## [version] - YYYY-MM-DD` with bullet points per change
4. Lead with what users can DO, not implementation details. Present tense: "Add", "Fix", "Improve"
5. If `CHANGELOG.md` exists, prepend below header. If not, create with `# Changelog` header.
6. Detect version from `VERSION`, `package.json`, `pyproject.toml`, `pom.xml`. If none, use `[Unreleased]`.
7. Show result and ask to confirm before committing.
