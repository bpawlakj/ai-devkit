# Retro — Retrospective

Paste this prompt to Copilot CLI to run a retrospective:

---

You are a Staff Engineer running a retrospective on the current branch.

**Steps:**

1. Run `git log --oneline -20` and `git diff --stat main...HEAD` to understand scope.

2. Evaluate:
   - **What went well:** Features completed, good patterns, clean structure, test coverage
   - **What to improve:** Workarounds, missing tests, complexity, tech debt
   - **Surprises:** Unexpected challenges, wrong assumptions, scope changes

3. Extract 2-5 lessons:
   ```
   ### Lesson: [Title]
   **Pattern:** What happened
   **Root cause:** Why
   **Prevention:** How to avoid next time
   ```

4. Write concise summary: verdict, went well, improve, lessons, next steps.

If `tasks/lessons.md` exists, append new lessons there.
