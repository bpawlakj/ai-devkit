#!/usr/bin/env bats

load test_helper

SKILL_DIR="$REPO_DIR/claude/skills/eval"

# ── Skill structure ──

@test "eval: SKILL.md exists with frontmatter name" {
    [ -f "$SKILL_DIR/SKILL.md" ]
    run head -5 "$SKILL_DIR/SKILL.md"
    [[ "$output" == *"name: eval"* ]]
}

@test "eval: reference schema present" {
    [ -f "$SKILL_DIR/references/eval-schema.md" ]
}

@test "eval: documents golden tasks, baseline, and thresholds" {
    run grep -qiE "golden task" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "baseline" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "threshold" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "eval: schema defines golden task + baseline + thresholds shapes" {
    run grep -qE "G-NNN|G-001" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qE "baseline.json" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qE "thresholds.yml" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
}

@test "eval: enforces the oracle rule (expected outcome, not observed output)" {
    run grep -qiE "oracle" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "never .* observed output|not .* observed output|never .* implementation" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "eval: checks for regression on model/harness upgrade" {
    run grep -qiE "regression" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "model.*harness|harness.*upgrade|model/harness" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "eval: copilot prompt mirror exists" {
    [ -f "$REPO_DIR/copilot/prompts/eval.md" ]
}

# ── P1-5 refinements: pattern taxonomy, expectations checklists, triggers fixture ──

@test "eval: schema defines the pattern taxonomy (A/B/C)" {
    run grep -qE "pattern:" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qiE "process-discipline" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qiE "config-compliance" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
}

@test "eval: rubric grading is per-expectation (fraction met)" {
    run grep -qiE "fraction met" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "each expectation independently" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "eval: triggers.json documented in schema and SKILL.md" {
    run grep -qE "triggers.json" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qE "triggers.json" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "should_trigger.*false.*failure|failure, not a warning" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "eval: baseline carries gen_ai usage keys with the no-content privacy rule" {
    run grep -qE "gen_ai\.usage\.input_tokens" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qE "gen_ai\.usage\.output_tokens" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qE "cost_usd" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qiE "never prompt.*text|never.*completion text" "$SKILL_DIR/references/eval-schema.md"
    [ "$status" -eq 0 ]
    run grep -qiE "never prompt or completion text" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "eval: cost deltas are informational, not pass/fail" {
    run grep -qiE "informational" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "quality thresholds decide|never part of the pass/fail" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "eval: repo triggers fixture is valid JSON with adversarial negatives per skill" {
    [ -f "$REPO_DIR/evals/triggers.json" ]
    run jq empty "$REPO_DIR/evals/triggers.json"
    [ "$status" -eq 0 ]
    # every covered skill has at least one should_trigger:false case
    run jq -e '.skills | to_entries | all(.value.cases | map(select(.should_trigger == false)) | length >= 1)' "$REPO_DIR/evals/triggers.json"
    [ "$status" -eq 0 ]
    # every case has query + should_trigger
    run jq -e '[.skills[].cases[]] | all(has("query") and has("should_trigger"))' "$REPO_DIR/evals/triggers.json"
    [ "$status" -eq 0 ]
}
