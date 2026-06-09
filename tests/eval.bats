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
