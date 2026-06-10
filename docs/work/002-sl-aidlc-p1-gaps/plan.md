# SL AiDLC P1 gaps + Tier 1 borrow leftovers — finish the "adopt now" set

Sources: `docs/analyzes/sl-aidlc-requirements-gap.md` (Bucket A, P1 roadmap) and
`docs/analyzes/sl-aidlc-external-repos-borrow-scan.md` (Tier 1 — "adopt now,
near-zero new surface").

Initiative `001-sl-aidlc-p0-gaps` closed the three v1-MUSTs (EVAL harness, A11Y,
decision log). This initiative finishes the remaining items both analyses marked
for immediate adoption: the three P1 gaps (A4, A5, A7) and the four Tier 1 borrow
items still open (verified open on 2026-06-10 — no GDPR section, no dotnet rule,
no model-per-skill doc, no fresh-verification reference, no eval
taxonomy/triggers, no git patterns in cloud-guard, no cost fields in baseline).
Everything here is conventions, rules, and refinements — **no new skills** (Tier 2
skills each require a test-of-inclusion first and are explicitly out of scope).

## P1-1 — GDPR / privacy-by-design section in `rules/security.md` (A4 · SEC-06 · S)

Extend `claude/rules/security.md` with a Privacy / GDPR section: data
minimisation, pseudonymisation, lawful-basis routing, retention limits. Generic
GDPR only — minors-specific compliance (MIN) stays in the SL foundation layer
(Bucket B). Mirror the addition to `copilot/instructions/security.instructions.md`.
Reuse: the existing security rule's structure and tone; this is a section, not a
new file.

## P1-2 — `.NET / C#` language rule (A5 · MOD-08 · M)

New `claude/rules/dotnet.md` following the exact shape of the 13 existing
per-language rules: idioms, nullable reference types, async/await, DI,
xUnit/NUnit + Testcontainers, analyzers, 80%+ coverage line. Copilot mirror
`copilot/instructions/dotnet.instructions.md`. Add the `dotnet format` formatter
to the PostToolUse hook pattern (same mechanism as `goimports`/`prettier`).
Wire into both installers and the README rules table (13 → 14).

## P1-3 — Model-per-skill convention + reference table (A7 · SKILL-04/05 · S)

Document a per-skill `model:` hint convention and a recommended "model per task"
table: cheap model for mechanical/extraction skills (e.g. `/save-plan`,
`/e2e-run` plumbing), capable model for design/review/eval skills (`/research`,
`/eval` rubric judge, `/discover`). Guidance + defaults only — the
skill/`Agent` model-override mechanism already exists; build no machinery.
Landing spot: a short `docs/` or skill-reference page linked from README.

## P1-4 — Shared `references/fresh-verification.md` (borrow Tier 1.2 · S)

Extract the verification-by-fresh-model pattern (the verifier sees only the diff
+ acceptance criteria, never the reasoning that produced them; flag
correctness/requirement gaps only) into one shared reference, and cite it from
`/implement` Step 5 and `/scenario`. `/eval`'s rubric judge already implements
it — point it at the same file instead of restating. The cheapest high-leverage
borrow in the scan.

## P1-5 — `/eval` refinements: pattern taxonomy + assertion checklists + triggers fixture (borrow Tier 1.3 · M)

Three refinements to the shipped harness, from BMAD prior art:
(1) a `pattern:` dimension on golden tasks — A artifact-correctness, B
process-discipline (inspects side-artifacts like the decision log), C
config-compliance; (2) prefer granular NL `expectations[]` checklists (judge
checks assertions one-by-one) over one holistic rubric — grades more
deterministically; (3) a `triggers.json` discrimination fixture
(`{query, should_trigger}` with adversarial negatives) testing skill
routing/dispatch separately from output quality — ai-devkit has many overlapping
trigger phrases and no test that they fire correctly. Keep `baseline.json` +
thresholds as-is (already ahead of the prior art).

## P1-6 — Git guardrails folded into `cloud-guard.sh` (borrow Tier 1.4 · S)

Add the dangerous-git patterns (`git push --force`, `reset --hard`,
`clean -fd`, `branch -D`, `checkout .`) to the existing PreToolUse
`claude/scripts/cloud-guard.sh` block-list — one more pattern block in the hook
that already covers AWS/kubectl/helm. No second hook. Extend the hook's bats
tests with the new patterns.

## P1-7 — Cost/token fields in `/eval` baseline (borrow Tier 1.5 · EVAL-02 · M)

Record per-run cost and token counts in `baseline.json` using the OTel
`gen_ai.*` semantic-convention keys (`gen_ai.usage.input_tokens`,
`gen_ai.usage.output_tokens`, a `cost_usd` field) with a `skill.name` attribute,
so model/harness upgrades are comparable on cost as well as quality. Privacy
rule reused from open-gitagent: telemetry never contains prompt/completion text.
Depends on P1-5 only insofar as both touch the eval schema — sequence after it
to avoid schema churn.

## Out of scope (explicit)

- **A6 safe-output/scoped-apply reference** (P2) and **A9 Jira/Slack/Confluence
  integrations** (P3) — per the gap-analysis roadmap, after P1 lands.
- **CTX-03 MCP semantic retrieval** — deferred `extensions/` work, demand-driven.
- **Tier 2 skills** (`/grill`, `/handoff`, `/architecture-review`,
  `/quickstart`) — each requires a test-of-inclusion vs the existing skill it
  resembles before any code; separate initiative if any clear the gate.
- **Tier 3 / Bucket B & C** — SL foundation and process-layer items belong to
  sl-aidlc, not here.
