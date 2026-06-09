#!/usr/bin/env bats

load test_helper

SKILL_DIR="$REPO_DIR/claude/skills/scenario"

# ── Skill structure ──

@test "scenario: SKILL.md exists with frontmatter name" {
    [ -f "$SKILL_DIR/SKILL.md" ]
    run head -5 "$SKILL_DIR/SKILL.md"
    [[ "$output" == *"name: scenario"* ]]
}

@test "scenario: reference schema present" {
    [ -f "$SKILL_DIR/references/scenario-schema.md" ]
}

@test "scenario: allowed-tools include the Playwright MCP (grounding tier)" {
    run grep -c "mcp__plugin_maister_playwright__browser_" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "scenario: documents optimistic and pessimistic paths" {
    run grep -qiE "optimistic" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "pessimistic" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "scenario: schema defines the depends_on back-link + generated footprint" {
    run grep -qE "depends_on" "$SKILL_DIR/references/scenario-schema.md"
    [ "$status" -eq 0 ]
    run grep -qE "generated:" "$SKILL_DIR/references/scenario-schema.md"
    [ "$status" -eq 0 ]
}

@test "scenario: enforces plan-before-code human-review gate" {
    run grep -qiE "human-review gate|before .* test code|before any test code|Plan before code" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "scenario: copilot prompt mirror exists" {
    [ -f "$REPO_DIR/copilot/prompts/scenario.md" ]
}
