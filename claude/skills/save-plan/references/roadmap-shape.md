# Roadmap-shape plans

A "roadmap" plan is a **top-down sequencing artifact** that lives once per project and answers "what next, what blocks what, what's parallel" across multiple initiatives. It is NOT the same as a per-initiative `plan.md` — that one lives inside `docs/work/<NNN>-<slug>/` and describes one coherent change-set.

`/save-plan` detects roadmap-shape automatically (heuristic in Step 1.5) and lands it at `docs/roadmap.md` instead of inside `docs/work/`. The user can always override the auto-classification at the prompt.

## When to write a roadmap

- You have a PRD (e.g. `docs/product-spec.md`) and you don't yet know which slice to plan first.
- You need to make foundation work (e.g. auth, infra bootstrap) explicit before user-visible slices and prove it actually unlocks something.
- You want one canonical place that records cross-slice dependencies — "S-02 needs F-01", "S-04 can run in parallel with S-03".

If you're already past that point and you're planning a single change-set, write an initiative-level plan and let `/save-plan` land it under `docs/work/<NNN>-<slug>/` as usual.

## Framing questions to consider before writing

A roadmap that doesn't answer these three questions will sequence slices by gut feel — and that's how foundations get planned with nothing to unlock, slice priorities flip on every weekly review, and "blocked" turns into a permanent category. Sit with these for two minutes before invoking `/plan` to draft the roadmap. They don't go into the document itself; they live in your head while you write it.

### Q1 — `main_goal`: what dimension drives sequencing?

When two slices look equally valuable, which axis breaks the tie?

- **Time-to-launch** — ship-anything-as-fast-as-possible. Scope cuts aggressive; anything non-critical parks.
- **Market feedback** — get-real-users-on-it. Slices that surface usage signal (retention, churn, analytics) come earlier.
- **Quality / polish** — get-it-right. Error-rate reduction, edge-case coverage, UX hardening come earlier.
- **Availability / reliability** — get-it-stable. Infra, monitoring, backups, error handling come earlier.
- **Learning** — find-out-if-the-bet-works. Slices that test the riskiest product assumption come first.

There's no wrong answer; there is a wrong answer of *not having one* and letting the sequence drift across weekly reviews.

### Q2 — `north_star`: what's the smallest working flow that proves the product thesis?

Pick the user story whose successful completion would most convince a skeptic that the product is worth building. That story dictates which slice is S-01.

The north star isn't "MVP" (too broad). It's a specific end-to-end interaction — one user, one task, completed successfully. Everything in the roadmap before it is foundation; everything after it is expansion.

### Q3 — `top_blocker`: what's the most likely reason this project stalls?

Honest answer here changes which slices get parked aggressively, and what shows up in `## Open Roadmap Questions` vs in `## Slices` with `status: blocked`:

- **Decisions** — too many open questions to commit. Surface them as `## Open Roadmap Questions`; mark dependent slices `blocked` until resolved.
- **Time** — limited capacity. Park anything not on the north-star path; foundations that don't unlock S-01..S-03 wait.
- **Availability** — depending on someone else (designer, stakeholder, external API access). Isolate work that can proceed without them; mark dependent slices `blocked: on <person/thing>`.
- **External factors** — vendor approval, legal review, hardware delivery. Park dependent slices; surface the dependency as a roadmap-level open question.
- **Knowledge** — uncertain how to do something. Add a foundation labelled "spike: investigate <X>" before slices that depend on the knowledge.
- **Motivation** — risk of losing interest. Front-load the most visible wins (slices that produce something demoable) over correctness work.
- **None / unsure** — fine, but revisit this question after the first slice ships.

These three answers determine which slice is `ready` vs `blocked`, which foundation is `Unlocks: S-01` vs `Unlocks: nothing` (the latter being a code smell — see Rules § 2), and which open question is parking-lot vs hard blocker.

## Detection heuristic (what `/save-plan` looks for)

A plan is treated as roadmap-shape if **any** of these match:

- Top heading matches `# Roadmap` (case-insensitive, optional suffix).
- Body contains a `## Slices` heading.
- Body contains both `## Foundations` and any `## Slices`-like section name (`## Vertical slices`, `## Milestones` etc.).

Detection is best-effort. `/save-plan` always asks the user to confirm classification with one AskUserQuestion — the heuristic only chooses the recommended default option.

## Minimal shape (4 sections)

This is the shape `/save-plan` will prepend a title to if the plan content has no top-level heading. Authors don't need to use all four — but if you do use this shape, follow the ID conventions.

```markdown
# Roadmap — <project>

## Foundations

Short preparatory work with no user-visible outcome. Each foundation MUST declare what it unlocks — orphan foundations are a code smell.

### F-01: <title>
- **Outcome:** <internal capability, not user-facing>
- **Unlocks:** S-01, S-02
- **Status:** proposed | ready | in-progress | done

## Slices

Vertical end-to-end work. Each slice cuts UI + data + logic and ends with something a user can verify.

### S-01: <user-facing outcome>
- **Outcome:** <what the user can do after this ships>
- **Change ID:** <kebab-case slug — becomes the `/save-plan` slug>
- **Prerequisites:** F-01, F-02
- **Parallel with:** S-02
- **Blockers:** —
- **Risk:** <one line — why this slice might fail, or what bet it represents>
- **Status:** proposed | ready | blocked | in-progress | in-review | done

## Open Questions

Things that block roadmap finalization. One bullet each, with owner.

## Done

Slices/foundations that have shipped, with link to the initiative folder.
```

## Rules

1. **One roadmap per project.** It lives at `docs/roadmap.md` (peer-level with `docs/product-spec.md` — both are top-of-funnel product artifacts). Versioned overwrites (`roadmap-v2.md`, `roadmap-v3.md`) are the only allowed shape for replacement — never delete an old roadmap.

2. **Foundations require `Unlocks:`.** A foundation that doesn't list at least one slice is suspect — either the slice is missing, or the foundation isn't actually needed.

3. **Vertical-first as default.** Horizontal slices (whole DB → whole API → whole UI) are an anti-pattern with AI agents because they hide integration risk until the end. Each slice should produce something a user can interact with.

4. **Change ID = `/save-plan` slug.** When a slice goes from `ready` to `in-progress`, the developer runs `/save-plan <change-id>` (or `/plan` then `/save-plan`) and the resulting `docs/work/<NNN>-<change-id>/plan.md` references the slice ID in its front-matter. That's how the bottom-up `docs/work/STATUS.md` (auto-generated rollup) reconnects to the top-down `docs/roadmap.md`.

5. **Two artifacts, two questions.**
   - `docs/roadmap.md` — top-down planning artifact (written by `/save-plan` when roadmap-shape detected; edited in place as the project evolves). Answers "where are we going".
   - `docs/work/STATUS.md` — bottom-up derived rollup (auto-regenerated by `regenerate-status.sh` from initiative folders + T-*.md frontmatter). Answers "where are we now".

   Don't conflate them. The roadmap is hand-edited intent; STATUS is machine-derived observation. They tell complementary stories.

6. **Roadmap is NOT atomized.** `/save-plan` does NOT offer to chain into `/atomize` for roadmap-shape plans — the roadmap itself isn't a change-set, its slices are. Each slice becomes its own `/save-plan` invocation later, and THAT plan is atomized.

## Anti-patterns

- **Treating roadmap as backlog**: dumping every idea into `## Slices` without sequencing or risk-scoring. The whole point of the artifact is sequencing — if it doesn't sequence, write a backlog file in `docs/reference/` instead.
- **Skipping foundations**: writing only slices when there's real infra prep work. The foundation/slice split makes prep work explicit so it doesn't get smuggled into "S-01 also installs auth".
- **PRD-readiness theater**: roadmap quality is bounded by PRD quality. If the PRD has gaping holes, fix the PRD first — the roadmap won't paper over them.
