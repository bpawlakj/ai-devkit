# Model-per-skill convention (token economy)

Closes SL AiDLC `SKILL-04`/`SKILL-05`: optimize cost and quality by matching the
model tier to the task — guidance and defaults only, no machinery. The override
mechanism already exists everywhere it's needed: skill frontmatter accepts
`model:`, and `Agent`/subagent calls accept a `model` option.

## The default rule

**Omit the override.** A skill or subagent without a `model:` hint inherits the
session model, which is almost always correct. Set a tier only when the task
archetype below makes it obvious — when unsure, omit.

## Archetype → tier table

| Archetype | Examples | Tier | Why |
|---|---|---|---|
| Mechanical / plumbing | `/save-plan` (copy + slug), `/e2e-run` (runner orchestration), `regenerate-status.sh` callers, file scaffolding | **cheap** (Haiku-class) | Deterministic transforms; output is verified downstream (tests, schema checks) |
| Signal gathering | `/repo-map` signal subagents, read-and-report Explore agents | **cheap** | They collect and summarize evidence; the synthesis step does the thinking |
| Schema-locked generation | `/atomize`, `/product-spec`, `/scenario` spec generation | **session default** | Needs competence and schema discipline, not top-tier reasoning |
| Design / judgment / synthesis | `/discover`, `/research`, `/repo-map` synthesis, plan authoring | **capable** (Sonnet/Opus-class) | Open-ended reasoning; errors here cascade into every downstream artifact |
| Review / verification / judge | `/eval` rubric judge, code-review subagents, `security-reviewer`, fresh verification | **capable** — and see rule 2 | A weak judge rubber-stamps; verification is where quality is enforced |

## Rules

1. **Omit by default.** The session model is the user's choice; respect it.
2. **The judge is never weaker than the producer.** A rubric judge, verifier, or
   reviewer running on a cheaper model than the one that produced the output
   inverts the quality gate (`/eval`'s fresh-judge, `/implement` Step 5 agents).
3. **Cheap tier only where output is deterministically verifiable downstream**
   (tests, schema validation, diff review). If a human is the only check, don't
   economize.
4. **Hints live in this table and in skill frontmatter — never hardcoded model
   IDs in skill bodies.** Skills stay model-agnostic (P10 durability: the
   toolkit must survive model generations); tiers are named by class
   (cheap/default/capable), and the mapping of class → current model id is the
   session/harness concern.

## Where this is consumed

- `/eval` — the rubric judge note cites rule 2.
- `Agent`-spawning skills (`/research`, `/repo-map`, `/discover`) — subagent
  briefs may pass `model` per the table; default is to inherit.
