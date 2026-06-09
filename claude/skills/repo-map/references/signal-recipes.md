# Signal recipes (canonical reference for /repo-map)

The cheap, deterministic, **read-only** commands each signal subagent runs. They
run *outside* the model's context window and return condensed results the agent
then interprets. None of them execute the target project's code.

`<win>` = the history window (default `12 months ago`). `<area>` = a path/subdir.

## Noise filters (apply to every git-history signal)

Exclude churny non-signal so territory/contributors reflect real work:

```
NOISE='package-lock.json|pnpm-lock.yaml|yarn.lock|uv.lock|poetry.lock|Cargo.lock|go.sum|\.min\.|/dist/|/build/|__snapshots__|\.snap$|/vendor/|node_modules/|\.generated\.'
```

## 1. Territory — git history

Top changed directories over the window (where work actually happens):

```
git log --since="<win>" --name-only --pretty=format: -- <area> \
  | grep -vE "$NOISE" | grep -v '^$' \
  | sed -E 's#/[^/]+$##' | sort | uniq -c | sort -rn | head -30
```

Permanent center vs change-campaign — compare quarters (run per quarter and diff):

```
git log --since="<q-start>" --until="<q-end>" --name-only --pretty=format: -- <area> \
  | grep -vE "$NOISE" | grep -v '^$' | sed -E 's#/[^/]+$##' | sort | uniq -c | sort -rn | head -15
```

Co-change (hidden cross-layer coupling) — directories that change in the same
commits (lightweight: top co-occurring dir pairs):

```
git log --since="<win>" --pretty='C%h' --name-only -- <area> \
  | awk '/^C/{c=1;delete d;next} NF{sub(/\/[^/]+$/,"");d[$0]=1}
         END{}' # then pair d[] per commit and tally — keep it directory-level, top ~15 pairs
```

> Co-change is *evidence within a window* and can lie (mass refactors, reformatting).
> Treat top pairs as leads to verify, not facts.

## 2. Structure — dependency graph (per stack)

Detect the stack via `/implement`'s runner-detection markers, then:

### JS / TS — `dependency-cruiser`
Install hint (don't auto-install): `npm i -D dependency-cruiser`.

```
# Coupling metrics (afferent Ca, efferent Ce, instability) — module level:
npx depcruise <src> --include-only "^<src>" --output-type metrics

# Cycles + a readable module graph (JSON to detect circular, markdown for humans):
npx depcruise <src> --include-only "^<src>" --no-config --output-type json \
  | jq '[.modules[] | select(.dependencies[]?.circular==true) | .source] | unique'
npx depcruise <src> --include-only "^<src>" --collapse "^<src>/[^/]+" --output-type markdown
```

Tame a hairball: `--collapse "^<src>/[^/]+"` (one node per top dir), `--focus "<mod>"`
(downstream), `--reaches "<mod>"` (upstream), `--exclude 'node_modules'`.

Alternatives: `madge --circular --extensions ts,tsx <src>`, `skott`.

### Python — `pydeps` / `tach`
Install hint: `pip install pydeps` (or `tach`).

```
# Module dependencies as JSON (no graphviz needed with --no-output):
pydeps <pkg> --show-deps --no-output --max-bacon 2

# Module boundaries / layering (if tach is configured):
tach report <pkg>   # or: tach check
```

### Other stacks (v1 TODO)
Emit `# TODO: add <stack> recipe` rather than guessing. Known good tools: Go —
`go mod graph`, `goda`; Java — `jdeps`; C#/.NET — `dotnet-deptree`; Kotlin/Gradle —
modules-graph-assert. Always prefer a report/markdown/JSON output over images.

### grep-fallback (no grapher installed)
Approximate import direction from import statements (note the degraded fidelity in
§ Unknowns of the map):

```
grep -rnE "^\s*(import|from|require\()" <src> | grep -vE "$NOISE" | sort | uniq -c | sort -rn | head -40
```

## 3. Contributors — git history (who to ask)

Per significant area, who has the most history (bots + AI-agent commits filtered):

```
git log --since="<win>" --format='%an' -- <area> \
  | grep -viE 'bot|\[bot\]|claude|codex|copilot|github-actions|dependabot|renovate' \
  | sort | uniq -c | sort -rn | head -5
```

This is "tacit knowledge holder", not blame. Omit the section if there's no history.

## 4. Verify load-bearing claims (`--verify` only)

For the few structural claims a decision will rest on ("only here", "always via X",
exact call-site count), confirm with AST matching, then **confirm every zero with a
plain grep** (a wrong ast-grep pattern returns a misleading zero):

```
ast-grep -p '<structural pattern>' -l <lang>     # precise count/locations
grep -rn '<symbol>' <area>                        # honest sanity check (esp. on a zero)
```

Install hint: `npm i -g @ast-grep/cli` / `brew install ast-grep`. ast-grep is for
*counting/locating* (structure); the agent still owns *meaning/behavior*.
