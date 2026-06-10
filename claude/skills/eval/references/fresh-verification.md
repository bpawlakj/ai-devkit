# Fresh-Model Verification (shared reference)

Single source of truth for the verification-by-fresh-model pattern. Consumed by
`/eval` (rubric grader), `/implement` (Step 5 review subagents), and `/scenario`
(assertion-oracle discipline). Skills cite this file instead of restating the
pattern — one place to refine it.

The pattern, in one sentence: **the agent that produced the work never grades
it; a fresh agent tries to refute it.**

## The five constraints

1. **Separate agent, fresh context.** The verifier is a different agent from the
   producer, with no access to the producing conversation. A verifier that
   shares the producer's context inherits its blind spots.
2. **Blind to reasoning.** The verifier's input is ONLY the artifact under test
   (diff, generated file, output) plus the acceptance criteria / spec — never
   the chain of reasoning, plan, or justification that produced it. Reasoning is
   persuasive; the verifier must judge the result, not the story.
3. **Refute, don't confirm.** The brief is adversarial: try to show the
   acceptance criteria are NOT met. A verifier asked "does this look right?"
   rubber-stamps; one asked "find where this fails its criteria" finds gaps.
4. **Correctness and requirement gaps only.** The verifier reports criteria
   violations and correctness defects — not style, naming, or taste. A
   gap-hunting reviewer given an open brief over-reports on style and buries
   the signal.
5. **Never weaker than the producer.** The verifier's model tier is at least
   the producer's (`docs/model-per-skill.md`, rule 2). A cheaper judge inverts
   the quality gate.

## Where each skill applies it

- **`/eval`** — `grader: rubric` delegates to a fresh `Agent` judge scoring the
  output against `## Expected`, criterion by criterion (constraints 1-5).
- **`/implement` Step 5** — review subagents (`security-reviewer`,
  `performance-analyzer`) receive the task diff + `## Acceptance`, not the
  implementation conversation (constraints 1-2), and report findings against
  named criteria (constraint 4).
- **`/scenario`** — the generated assertions encode acceptance criteria, never
  observed implementation output; the authored test is itself a standing fresh
  verifier of the implementation (constraint 2 applied to test oracles).

## Sources

Anthropic Claude Code best practices (verification subagents — a fresh model
refutes the result); convergent: GitHub Squad (rejected code is reviewed by a
different agent, never revised by its author). Adopted per
`docs/analyzes/sl-aidlc-external-repos-borrow-scan.md` Tier 1.
