#!/usr/bin/env bats

load test_helper

SKILL_DIR="$REPO_DIR/claude/skills/e2e-run"

# ── Skill structure ──

@test "e2e-run: SKILL.md exists with frontmatter name" {
    [ -f "$SKILL_DIR/SKILL.md" ]
    run head -5 "$SKILL_DIR/SKILL.md"
    [[ "$output" == *"name: e2e-run"* ]]
}

@test "e2e-run: runner-detection reference present" {
    [ -f "$SKILL_DIR/references/runner-detection.md" ]
}

@test "e2e-run: does NOT wire the browser MCP (runs the real runner, not a live browser)" {
    # allowed-tools must not include the browser MCP; prose mentions are fine,
    # but the frontmatter allowed-tools block should contain none.
    frontmatter="$(sed -n '/^allowed-tools:/,/^---/p' "$SKILL_DIR/SKILL.md")"
    [[ "$frontmatter" != *"mcp__plugin_maister_playwright__browser_"* ]]
}

@test "e2e-run: extension pairs present (hurl + schemathesis)" {
    [ -f "$SKILL_DIR/extensions/README.md" ]
    [ -f "$SKILL_DIR/extensions/api-hurl.opt-in.md" ]
    [ -f "$SKILL_DIR/extensions/api-hurl.md" ]
    [ -f "$SKILL_DIR/extensions/api-schemathesis.opt-in.md" ]
    [ -f "$SKILL_DIR/extensions/api-schemathesis.md" ]
}

@test "e2e-run: every opt-in descriptor names its rules_file" {
    for d in "$SKILL_DIR"/extensions/*.opt-in.md; do
        run grep -qE "^rules_file:" "$d"
        [ "$status" -eq 0 ]
    done
}

@test "e2e-run: enforces report-only / no auto-heal discipline" {
    run grep -qiE "never (auto-heal|regenerat)|report-only|no auto-heal" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "e2e-run: never auto-installs tools" {
    run grep -qiE "never auto-install|do not auto-install|don't auto-install|do not (silently )?install" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "e2e-run: scopes by depends_on / initiative / tag" {
    run grep -qE "depends_on" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "@optimistic|@pessimistic|--grep" "$SKILL_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "e2e-run: copilot prompt mirror exists" {
    [ -f "$REPO_DIR/copilot/prompts/e2e-run.md" ]
}
