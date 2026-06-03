---
name: research
description: >
  Per-decision research skill: gather facts and reasoning around a specific
  technology choice, vendor selection, or technical investigation, and write
  the findings to docs/analyzes/<slug>.md as a point-in-time research snapshot.
  Two modes (auto-selected via user choice): INTERVIEW — facilitator asks
  structured questions, user provides facts; INVESTIGATION — spawns research
  subagents (web + code) and synthesizes. Reads docs/reference/ for project-
  specific context — any file type (PDFs, DOCs, link collections, curated
  bibliographies), with sibling .md indexes for binaries. Closes with anti-bias
  cross-check (devil's advocate + pre-mortem). Use BEFORE making a significant
  technical choice, NOT for product-level discovery (use /discover for that).
  Trigger phrases: "should we adopt X", "research <topic>", "evaluate <option>",
  "vendor selection", "<lib A> vs <lib B>", "investigate <technology>",
  "what should I know about <topic>".
argument-hint: "<topic — what to research>"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - Agent
  - WebSearch
  - WebFetch
  - TaskCreate
  - TaskUpdate
---

# /research — Per-Decision Research → docs/analyzes/

This skill produces a single research artifact (`docs/analyzes/<slug>.md`) for a specific technical question — a vendor evaluation, a library comparison, an integration investigation, an "is X worth adopting?" decision. It is **not** product-level discovery (`/discover` handles that); it is the per-decision research that accretes throughout a project's lifetime.

The output is a **point-in-time snapshot**. It records what was known and decided at one moment. It is NOT edited retroactively when reality changes — instead, write a follow-up research doc that supersedes it.

## When to use, when to skip

**Use when**:
- Choosing between alternatives (vendor A vs B, library X vs Y, approach 1 vs 2)
- Evaluating adoption ("should we add Koog AI as a dependency?")
- Investigating an unknown ("how does our existing OAuth flow handle refresh tokens?")
- Pre-decision research where you want the reasoning captured before committing

**Skip when**:
- The decision is product-level (what to build, for whom) — use `/discover`
- The investigation is a single fact lookup (just grep / ask Claude directly; doesn't need an artifact)
- You're already deep in implementation and just need to remember a detail (use a code comment, not a research doc)
- A research doc on this topic already exists at `docs/analyzes/<slug>.md` and the findings are still valid — read it, don't regenerate

## Relationship to other skills

- `/kickoff` — scaffolds `docs/`. `/research` requires `docs/analyzes/` to exist; delegates to `/kickoff` via the `Skill` tool if missing.
- `/discover` — product-level discovery; orthogonal to `/research`. Both can run on the same project at different cadences (discover: once or rarely; research: many times).
- `/atomize` — downstream consumer in spirit: a research conclusion may seed a `plan.md` in `docs/work/<NNN>-<slug>/`, which `/atomize` then decomposes into tasks.
- `docs/reference/` — input material of any file type (`.md`, `.pdf`, `.docx`, `.xlsx`, link-collection `.md`, vendor specs, etc.). Step 4 scans this directory for items relevant to the research topic. Binaries are read via their sibling `.md` index per the `docs/reference/README.md` convention. Selected items are cited in Findings using `> Ref: docs/reference/<file> — <claim>` blockquotes.

## Output schema (inline)

Each research artifact lives at `docs/analyzes/<slug>.md` with this shape:

```yaml
---
title: <human-readable title>          # e.g. "Vector database choice for embeddings"
date: <YYYY-MM-DD>                     # day the research concluded
type: <enum>                           # technology-evaluation | decision | investigation
status: <enum>                         # decided | open | superseded
decision: <one-line or null>           # e.g. "pgvector — keeps Postgres as single store"
related: [<path/to/related-doc.md>]    # other docs/analyzes/ or docs/reference/ files cited
---

# <Title>

## Context

Why this research was needed. What triggered it. 1-3 paragraphs.

## Question

The specific question being researched, phrased precisely. One paragraph.

## Findings

What was discovered. Facts, evidence, links. Cite sources (URLs, code paths, docs).
This is the substance of the document — most of the body length lives here.

## Alternatives considered

For decision/evaluation types, list each option with pros, cons, and a one-line
verdict. For investigation type, this section can be `(N/A — investigation, not
selection)` or omitted.

- **Option A — <name>**
  - Pros: ...
  - Cons: ...
  - Verdict: ...
- **Option B — <name>**
  - ...

## Anti-bias cross-check

### Devil's advocate
Strongest argument AGAINST the leading option (or against the framing of the
question itself). What's the best case for not doing this / picking differently?

### Pre-mortem
Imagine it's 6 months later and this decision turned out to be wrong. What broke?
What did we miss? What signals should we have seen?

## Decision (if any)

The choice + 1-2 sentence rationale. `null` if research concluded open.

## Open questions

Things still unresolved. Each should name an owner (if known) and a tentative
resolution path (read code / ask vendor / wait for v1.2 / etc.).
```

## Process

### Step 0: Verify workspace

```bash
test -d docs/analyzes
```

If missing, ask:

AskUserQuestion:
- question: "docs/analyzes/ is missing. Run /kickoff to scaffold the docs/ structure?"
  header: "Init?"
  options:
  - label: "Yes — run /kickoff (Recommended)"
    description: "Scaffolds docs/ + subdirs, then continues research."
  - label: "Create docs/analyzes/ only"
    description: "Quick mkdir without full /kickoff. You can run /kickoff later."
  - label: "Cancel"
    description: "Exit without changes."
  multiSelect: false

On "Yes — run /kickoff": delegate to `kickoff` via the `Skill` tool. When it returns, re-check and continue.
On "Create only": `mkdir -p docs/analyzes` and continue.
On "Cancel": STOP.

### Step 1: Capture topic

If a topic was passed as argument (e.g. `/research vector database for embeddings`), capture it verbatim. Print:

```
Topic: <topic>
```

If no argument was passed, ask: "What do you want to research? Examples: 'should we adopt Koog AI', 'vector database for embeddings', 'how OAuth refresh tokens work in our existing flow', 'evaluate Auth0 vs Supabase vs Clerk'."

Then wait.

### Step 2: Generate slug + collision check

Derive a slug from the topic — **first 5 meaningful words, lowercased, hyphenated, no stopwords**. Examples:

- "Should we adopt Koog AI for agent orchestration" → `koog-ai-agent-orchestration-evaluation`
- "Vector database choice for embeddings" → `vector-database-choice-embeddings`
- "How OAuth refresh tokens work in our flow" → `oauth-refresh-tokens-flow-investigation`

Suffix the slug with the research type once classified in Step 3 (`-evaluation`, `-decision`, `-investigation`) IF the slug doesn't already imply it.

Check `docs/analyzes/<slug>.md`:

```bash
test -f docs/analyzes/<slug>.md
```

If exists, ask:

AskUserQuestion:
- question: "docs/analyzes/<slug>.md already exists. How to proceed?"
  header: "Collision"
  options:
  - label: "Read existing first (Recommended)"
    description: "Show me the existing doc; I'll decide whether to write a follow-up or stop."
  - label: "Write follow-up <slug>-followup.md"
    description: "Treat existing as superseded; write a new doc that references it."
  - label: "Overwrite existing"
    description: "Replace. Prior research is lost (unless committed)."
  - label: "Cancel"
    description: "Exit without writes."
  multiSelect: false

Handle each option accordingly. "Read existing" → print existing doc body, then STOP (user can re-invoke later). "Follow-up" → use `<slug>-followup.md` as target path, plan to add `Supersedes: docs/analyzes/<slug>.md` in the new doc's `related:` frontmatter.

### Step 3: Classify research type

Ask via AskUserQuestion:

- question: "What kind of research is this?"
  header: "Type"
  options:
  - label: "Decision — pick between alternatives (Recommended for vendor/library choices)"
    description: "Multiple options on the table. Output: structured comparison + decision."
  - label: "Technology evaluation — assess single thing"
    description: "Specific tool/library/approach under scrutiny. Output: evaluation against criteria."
  - label: "Investigation — understand how something works"
    description: "Build understanding of existing system or external mechanic. Output: factual synthesis."
  multiSelect: false

Map answer to frontmatter `type:` field (`decision` / `technology-evaluation` / `investigation`).

### Step 4: Gather project-specific context

Scan `docs/reference/` for **any file type** the user may have placed there as input material — not just `.md`. The reference directory is the user-curated input pool; reading from it is the difference between research that knows the project and research that reinvents context.

```bash
test -d docs/reference && find docs/reference -maxdepth 2 -type f \
  ! -name 'README.md' \
  -printf '%p\t%s\t%TY-%Tm-%Td\n' 2>/dev/null \
  | sort
```

Group results into two buckets:

- **Text/markdown** (`.md`, `.txt`, `.json`, `.yaml`, `.csv`) — readable directly.
- **Binary** (`.pdf`, `.docx`, `.xlsx`, `.png`, `.drawio`) — read via the sibling `.md` index per `docs/reference/README.md` convention. Detect by stripping the binary's extension and looking for `<basename>.md`.

Relevance match (heuristic, not strict):

- Slug overlap — topic words appearing in filename.
- Topic-word substring match against the file's first heading (for `.md`) or its sibling `.md` index summary (for binaries).
- **Always include**: files tagged as `external-link-index` or `api-contract` or `operational-spec` in any sibling `.md` index — these are likely topic-adjacent for technical research regardless of filename match.

Print a numbered table of matches with type and source-of-context (the file itself, or its sibling index for binaries):

```
Found potentially relevant material in docs/reference/:

  [#]  [path]                              [type]  [reads via]                    [headline]
  1    auth-and-providers.md               md      self                           "LLM Authentication & Providers"
  2    smartgate-models.md                 md      self                           "SmartGate Available Models"
  3    vendor-pricing-2026-q1.pdf          pdf     vendor-pricing-2026-q1.md      "Q1 2026 vendor pricing snapshot — pgvector/Pinecone/Weaviate"
  4    links-vector-databases.md           md      self (link index)              "Curated links: vector DB benchmarks & docs"
  5    client-data-schema.xlsx             xlsx    (no sibling .md found)         (binary — sibling index missing)
```

If a binary has no sibling `.md` index, flag it inline (`(no sibling .md found)`). Do NOT skip silently — the user may want to add an index before proceeding, or accept reading without one.

AskUserQuestion (multiSelect: true) with options:

- One entry per file found (label: filename, description: headline + type)
- "Include none"
- "Read all in-scope (Recommended)" — selects all items whose binaries have a sibling index; skips orphaned binaries
- For orphaned binaries specifically, append a sub-option: "Pause — let me add a sibling .md index first"

For each selected file:
- **Text/markdown** → Read FULLY into context.
- **Binary with sibling index** → Read the sibling `.md` index FULLY. Record the binary path as the underlying source (cited as such), but the readable surface is the index.
- **Binary without sibling index** (if user opted to read blindly) → use Read with a soft warning; for `.pdf`, pass a `pages:` range if needed; for unreadable formats (`.xlsx`, `.docx` without a sibling), surface "I can't extract this — captured as `Source: <path> (not directly read; user-attested context only)`" and let the user paste relevant excerpts.

**Link-collection files** (`.md` files that are mostly bullet lists of URLs with annotations) deserve special treatment: do not just read them — also extract the URLs and consider them candidate WebFetch targets for Step 6B (Investigation mode). Print: "Found link index with N URLs. Want me to fetch any of these directly during investigation?" and capture the user's picks for later.

Selected items become:
- Evidence for the `## Findings` section, cited inline as `> Ref: docs/reference/<file> — <claim>` blockquotes.
- Entries in the `related:` frontmatter array of the final research doc (write the canonical path — for binaries, cite the binary AND its sibling index).

Also ask once: "Any other files in the repo (outside `docs/reference/`) you want me to read as context? (paste paths, or skip)". Wait. If user provides paths, read them. Otherwise continue.

### Step 5: Mode selection

Ask via AskUserQuestion:

- question: "How would you like to conduct the research?"
  header: "Mode"
  options:
  - label: "Interview — I provide facts, you structure them"
    description: "You already know most of what's needed. Skill asks targeted questions; you supply the findings; skill assembles the document. Faster, no web research."
  - label: "Investigation — spawn research subagents (Recommended for new topics)"
    description: "Skill dispatches parallel subagents to web-search, fetch official docs, and inspect related code. Synthesizes a draft for your review. Slower, deeper."
  - label: "Mixed — interview first, investigate gaps"
    description: "Start with interview; for gaps you can't answer, spawn a focused subagent. Combines speed + depth."
  multiSelect: false

Store the choice. Different Step 6 branches per mode.

### Step 6A: Interview mode

Walk the user through structured questions matching the `type`:

**Decision type:**
1. "What alternatives are on the table? List 2-5 options."
2. "What are the **must-haves** — properties an alternative MUST satisfy to qualify?"
3. "What are the **nice-to-haves** — properties that score points but aren't blockers?"
4. For each alternative: "What do you currently know about <option>? Strengths, weaknesses, gotchas?" (free-form per option)
5. "Is there a leading option in your mind? Why?"
6. "What is the constraint forcing this decision now — budget cycle, scaling limit, security audit, deadline?"

**Technology evaluation type:**
1. "What is the technology — name + one-line of what it does?"
2. "What problem in our system would adopting it solve?"
3. "What's the alternative (status quo — do nothing — or a different solution we already use)?"
4. "What do you know about it — features, maturity, community, license?"
5. "What's the integration cost — what would change in our codebase?"
6. "Is there a deal-breaker that would force a 'no' regardless?"

**Investigation type:**
1. "What is the thing you want to understand?"
2. "Why does it need to be understood now — what depends on it?"
3. "What do you already know? (so we don't re-derive it)"
4. "What's the boundary — where does the investigation stop?"

Capture answers verbatim where possible — do NOT rephrase or "improve" the user's words. Treat them as evidence to transcribe into Findings / Alternatives sections.

**Ambiguity analysis (mandatory before leaving interview):** scan the captured answers for hedging language — "depends", "maybe", "probably", "not sure", "mix of", "somewhere between" (or their equivalents in the user's working language). For each flagged answer, ask ONE targeted follow-up that names the ambiguity: "You said the integration cost 'depends' — on what? Which case applies to this project?" If the user cannot resolve it, route the point to `## Open Questions` (in Mixed mode, it also becomes a candidate gap for a focused subagent) — do NOT carry a hedged answer into `## Findings` as if it were a fact.

### Step 6B: Investigation mode

Spawn 2-4 research subagents via the `Agent` tool. Each gets a focused brief:

- **Subagent 1 — Official docs / vendor pages**: WebFetch the canonical sources. Report: GA/beta status, key feature list, pricing tier, license.
- **Subagent 2 — Comparisons / third-party reviews**: WebSearch for "<topic> vs <alternative>" / "<topic> review". Report: independent perspectives, common criticisms, real-world adoption.
- **Subagent 3 — Code/repo context** (only if relevant to investigation): Read related files in the codebase. Report: how the current system handles the area being investigated.
- **Subagent 4 — Pricing / scaling concerns** (only for paid services): Fetch pricing pages, search forum / Reddit / HN discussions for reports on scaling limits, cost cliffs, and operational issues at higher volumes.

**Seed each subagent's brief with relevant reference material** from Step 4. Specifically:
- Pass the contents of any `external-link-index` references as a starter URL list to Subagents 1, 2, and 4 — these are URLs the user has pre-vetted as on-topic.
- Pass any `api-contract` or `operational-spec` reference contents to Subagent 3 — they constrain what the codebase context means.
- Cite reference paths in the subagent prompt: "Per docs/reference/<file>, the user flagged the following starter URLs/constraints: [...]. Use these as primary sources where they overlap your scope."

Each subagent's prompt: self-contained brief + "report findings in under 300 words with cited URLs (web) AND `> Ref:` blockquotes for any reference-material claims you used". Run in parallel (single message, multiple Agent calls).

Synthesize results into the Findings section. Cite every claim with a URL, codepath, or `> Ref: docs/reference/<file>` blockquote where the source came from. Distinguish between web-sourced facts and user-reference-sourced facts visually — the latter are higher-trust because the user curated them.

### Step 6C: Mixed mode

Run Step 6A first. After interview, identify gaps: questions the user answered with "not sure" / "no idea" / left blank. For each gap, spawn ONE focused Agent subagent with a precise brief. Synthesize subagent output into the corresponding section.

### Step 7: Anti-bias cross-check

Regardless of mode, run two cross-check passes on the leading conclusion (or, for investigation type, on the dominant interpretation):

**Devil's advocate**: spend 2-3 paragraphs writing the strongest possible argument AGAINST the leading option. Don't strawman — find the actual best case for the opposing position. If you can't generate a strong counter-argument, that's a signal: either the decision is genuinely one-sided, or the framing missed something.

**Pre-mortem**: write a 1-paragraph scenario where the decision turns out to be wrong 6 months later. Imagine reading a post-mortem about it. What broke? What signals existed at decision time that we ignored?

After writing both, ask the user:

AskUserQuestion:
- question: "Cross-check raised concerns. How do you want to proceed?"
  header: "Anti-bias"
  options:
  - label: "Keep the leading option (Recommended if devil's advocate failed)"
    description: "Cross-check considered; concerns logged in doc; decision stands."
  - label: "Revisit Findings / Alternatives"
    description: "Go back and dig deeper into specific concerns raised."
  - label: "Switch to alternative"
    description: "Cross-check surfaced a real issue. The runner-up becomes the new leading option; re-run cross-check on it."
  - label: "Mark decision as 'open'"
    description: "Don't commit yet. Doc captures the research with status: open."
  multiSelect: false

Loop on "Revisit" or "Switch" (re-cross-check on new leader). Continue when user picks "Keep" or "Mark open".

### Step 8: Write artifact

Assemble the document per the inline schema. Frontmatter from captured fields. Body sections in this exact order:

1. `## Context`
2. `## Question`
3. `## Findings` (longest section — substance lives here)
4. `## Alternatives considered` (or omit / mark N/A for investigation)
5. `## Anti-bias cross-check` with `### Devil's advocate` + `### Pre-mortem` subsections
6. `## Decision (if any)` — null if open
7. `## Open questions`

**Citation discipline** (applies primarily to `## Findings`, `## Alternatives`, and `## Decision`):

- Every factual claim has an inline citation. Three citation forms are valid:
  - **Web source**: `[<source name>](<URL>)` — e.g. `[pgvector docs](https://github.com/pgvector/pgvector)`
  - **Code source**: `path/to/file.ext:line` — e.g. `src/db/embeddings.ts:42`
  - **Reference material**: `> Ref: docs/reference/<file> — <claim>` blockquote, placed immediately after the sentence that drew from it
- Reference-material citations always include the verbatim claim being made (or a tight paraphrase) so a reader doesn't need to open the file to know what was sourced from it.
- For binaries cited via their sibling `.md` index, cite the **binary** as the source of truth (`docs/reference/vendor-pricing-2026-q1.pdf`) and note in parentheses that the index was the readable surface: `(read via vendor-pricing-2026-q1.md)`.

Populate `related:` frontmatter with every `docs/reference/` and `docs/analyzes/` path that was consulted, in citation order. Binaries and their sibling indexes are listed together as a pair when both were used.

Write to `docs/analyzes/<slug>.md` (or `<slug>-followup.md` if Step 2 chose follow-up).

### Step 9: Hand off

Print summary:

```
═══════════════════════════════════════════════════════════
  RESEARCH COMPLETE
═══════════════════════════════════════════════════════════

  Topic:        <topic>
  Type:         <decision | technology-evaluation | investigation>
  Status:       <decided | open>
  Decision:     <one-liner or "(open)">
  Mode:         <interview | investigation | mixed>
  Subagents:    <N spawned>  (investigation/mixed modes only)
  Sources:      <count cited — web: X, code: Y, reference: Z>
  References:   <list of docs/reference/ files consulted, with sibling-index notes>
  Related docs: <list of docs/analyzes/ files cross-linked>

  ► Doc:  docs/analyzes/<slug>.md
═══════════════════════════════════════════════════════════
```

STOP. Do not chain into other skills automatically — the research is the artifact; what comes next (a `plan.md` derived from the decision, a `/research` follow-up on an unresolved sub-question) is the user's call.

## Critical guardrails

1. **Point-in-time snapshot, not a living doc.** Once written, `docs/analyzes/<slug>.md` records what was known on `date:`. If reality changes, write a follow-up research doc that supersedes it (mark old with `status: superseded` and `related: [<new-doc>]`). NEVER edit a research doc retroactively — that destroys the audit trail of why a decision was made.

2. **Cite sources or it didn't happen.** Every claim in Findings should have a citation: a URL, a code path with line number, a doc reference. Uncited claims are conjecture; flag them as `(uncited)` or move them to Open Questions.

3. **Anti-bias is not optional.** Skipping Step 7 makes the doc indistinguishable from confirmation bias. The devil's advocate and pre-mortem are the difference between research and rationalization.

4. **Reference context is read, not authored.** `/research` reads `docs/reference/` files; it never writes to them. If research findings need to land in reference (e.g. discovered vendor limits), the user creates that doc separately. Any file type is welcome in `docs/reference/` — `.md`, `.pdf`, `.docx`, `.xlsx`, `.png`, link-collection markdown, etc. Binaries MUST have a sibling `.md` index per the `docs/reference/README.md` convention; reading a binary without an index is opt-in (the user is told the limitation and chooses to proceed anyway).

5. **Slug stability.** Don't rename research docs after they're written — other docs (including future `related:` references in follow-ups) cite them by path. If the title changes, leave the slug; only update the `title:` frontmatter.

6. **One topic per doc.** Resist scope expansion within a single research run. If the user starts asking about adjacent decisions, suggest spawning a separate `/research` for each. Multi-topic docs are unsearchable and decay fast.

7. **User-curated references outrank web sources, but not silently.** When a `docs/reference/` item contradicts a web-sourced claim, surface the conflict explicitly in `## Findings` rather than picking a winner. Format: "Sources disagree: [web source] claims X; `docs/reference/<file>` (user-curated, dated YYYY-MM-DD) claims Y. Resolution: [user decides, or open question]." Don't bury the conflict — it's the most useful kind of finding.

8. **Professional tone; adapt to the user's working language.** Research docs are read by engineering decision-makers and audit reviewers, not pitch audiences. Avoid startup vocabulary: no "pain", "burning need", "killer feature", "growth hack", "ship it", "scope creep". Prefer **problem / constraint / limitation / friction point / scaling limit / operational cost / scope expansion / release**. When the user writes in a non-English language, render prompts and section labels idiomatically — DO NOT translate literally. Polish equivalents: `problem` → "problem" (NOT "ból"); `constraint` → "ograniczenie"; `friction point` → "punkt tarcia"; `release` → "wdrożenie" / "wydanie".

## Notes

- The "type" classification (decision / technology-evaluation / investigation) is partly cosmetic but mostly load-bearing for downstream filtering: a maintainer can grep `type: decision` to find decision docs only.
- Slug generation is best-effort. If the auto-generated slug is ugly, the user can override in Step 2 before the file is written.
- Subagent spawning in Investigation mode is parallel by default (single message with multiple Agent calls). This is the right call for independent research streams. Don't sequentialize unless one subagent's output is required input for another.
- Mixed mode is the recommended default for most real-world research: interview catches the user's existing knowledge cheaply; investigation fills the gaps with web/code research where the user genuinely doesn't know.
- **Reference-material workflow** (Step 4 detail): drop any file into `docs/reference/` before invoking `/research` — `.md`, `.pdf`, `.docx`, `.xlsx`, link-collection markdown, screenshots, exported diagrams. Binaries pair with a sibling `.md` index (`<basename>.md` next to the binary). Link-collection `.md` files double as starter URL lists for Investigation-mode subagents. Citations land in Findings as `> Ref:` blockquotes and in the doc's `related:` frontmatter. The skill never modifies `docs/reference/` — it only reads.
