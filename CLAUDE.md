# Admin Instructions for Claude

## Sudo Password
When sudo password is required, use: ask user about it

## Workflow Orchestration

### 1. Plan Before Acting
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Delegate Smart
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- Use the right personnel for focused specialized tasks

### 3. Self-Improvement Loop
- After each correction from the user update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same outcome
- Habitually iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Quality Gates
- Never mark a task complete without proving it works
- TEST between milestones and test your changes when relevant
- Ask yourself "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Honest Diagnosis (Balanced)
- When stuck, say "I'm stuck on X because Y" and ask "Is there a more elegant way?"
- If a fix feels hacky, "knowing everything I know now, implement the most elegant solution"
- Don't over-engineer or add unnecessary complexity
- Challenge your own work before presenting it

### 6. Communication
- When given a bug report: just fix it. Don't ask for hand-holding
- When given a feature request: plan it, then build it
- Use context matching required from the user
- Do 75-85% of tasks without being told how

### 7. Task Management
- **offTask**: Write plan to `tasks/instructions` with checklist items
- **milestoneTask**: Complete multiple tasks towards a milestone
- **Track Progress**: Mark items complete as you go
- **onTask Updates**: Add review sections to task docs
- **inProgress**: Create task items for any work underway
- **reEvaluation Readiness**: Add review sections to `tasks/instructions`

### 8. Core Principles
- **Stability First**: Make every change as simple as possible. Impact minimal code.
- **Safe Transitions**: Test and commit so bugs stay "in frames". Incremental.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

### 9. Never Auto-Rollback
- **NEVER** automatically rollback or revert code changes without user confirmation
- When something fails: **STOP → Analyze root cause → Check for easy fix → Ask user**
- Many failures are simple config/setup issues with easy 1-line fixes
- Automatic rollback discards potentially valid work and hides root causes
- Use `AskUserQuestion` with options: "Try suggested fix" / "Rollback changes" / "Let me investigate"

### 10. Feature Completeness Thinking
- When building features involving data or UI, verify the **full lifecycle**: Create → Read → Update → Delete
- **Backend ≠ User Operability**: An API endpoint alone doesn't mean users can actually use the feature
- Detect **orphaned displays** (shows data with no way to input it) and **orphaned inputs** (captures data with nowhere to view/use it)
- Ask: Can users **discover** the feature? **Input** data? **View** it? **Edit/delete** it?
- For safety-critical domains (healthcare, finance, legal): heightened analysis for missing touchpoints

### 11. Incremental Testing Strategy
- **During implementation**: Run only affected/relevant tests after each change — not the full suite every time
- **Before declaring work complete**: Run the full test suite to catch regressions
- This avoids wasting time on unrelated test runs mid-work while still ensuring correctness at the end

### 12. Root Cause Over Retry
- When a test, build, or API call fails — **don't retry blindly** or work around it
- Diagnose the actual cause first. Often it's config, setup, or environment — not logic
- Don't stack workarounds on top of workarounds. Fix the real problem.
- If stuck after diagnosis, say so and ask — don't silently loop


