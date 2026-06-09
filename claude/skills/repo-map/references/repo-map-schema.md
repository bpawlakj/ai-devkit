# repo-map.md schema (canonical reference for /repo-map)

The single artifact `/repo-map` writes. Short, decision-oriented, evidence-grounded,
agent-friendly. It answers **"what is important, connected, active, and risky here?"**
— not "what files exist?". If a section can't be filled with evidence, it lists an
`unknown`, never a guess.

## Frontmatter

```yaml
---
kind: repo-map
target: <repo root | subdir>
window: <e.g. 12 months>            # git-history window the signals cover
generated: <YYYY-MM-DD>             # point-in-time stamp (re-run to refresh)
stack: <js/ts | python | mixed | …>
dep_tool: <dependency-cruiser | pydeps | tach | grep-fallback>
---
```

## Body sections (all required; "none/unknown" is a valid value)

### 1. Summary (≤5 lines)
The shape of the system in a few sentences: main modules, the one or two
load-bearing areas, and the single biggest risk to a change. A newcomer should get
the gist here before reading the tables.

### 2. Modules / territory
A table of the significant modules. For each: **role** (core / supporting /
peripheral), **activity** (active / stable / frozen — from git history), and the
**evidence** (e.g. "#changes in window, top-3 changed paths"). Distinguish a
*permanent center* (consistently changed every quarter) from a *change campaign*
(a burst then quiet).

### 3. Entry points
Where execution / requests / jobs enter (HTTP routers, CLI mains, queue consumers,
schedulers, public API surfaces). Cite the file(s).

### 4. Dependency directions + cycles
Import/dependency direction between modules (who depends on whom), and **every
cycle** found, listed explicitly with the modules involved. Note coupling
hotspots: high afferent `Ca` (many depend on it → fan-in hub, risky to change) and
`instability = Ce/(Ca+Ce)`. Evidence = the grapher output.

### 5. Sensitive areas / blast radius
Where a change is most likely to ripple: cycle members, fan-in hubs, modules that
co-change with many others, and anything touching shared state / contracts /
migrations. For each, one line on *why* and *what to check first* (tests, PR
history). This is the section a reviewer/implementer reads before editing.

### 6. Testability risks (lightweight)
Modules hard to test in isolation (heavy imports, global state, shared
utils/types) — where you'll need mocking vs an integration/e2e test. Derived from
the dependency graph; one or two lines, not a coverage report.

### 7. Who to ask (contributors)
Per area, the contributor(s) with the most history there (bots and AI-agent
commits filtered out). This is "who has tacit knowledge", not blame. Omit if no
git history.

### 8. Unknowns / needs verification
Explicit list of what the signals could NOT establish: runtime coupling (DI,
dynamic imports, feature flags, codegen, webhooks), areas with thin history,
labels that need a human to confirm. **This section is mandatory and must not be
empty in a real repo** — static analysis always has blind spots.

## Invariants

- **Evidence rule**: every classification cites its evidence (commit / import path /
  `file:line` / co-change count). A label without evidence is a guess → it belongs
  in § 8 as an `unknown`, not in §§ 2–6 as fact.
- **Short over complete**: prefer the 20% that drives decisions. A map nobody reads
  because it's an essay has failed.
- **Re-runnable, point-in-time**: the `generated` date + `window` bound the claims;
  re-running refreshes them. Don't present stale history as current truth.
- **No source mutation**: producing the map never edits the analyzed code.
