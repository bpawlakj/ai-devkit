#!/usr/bin/env bats

load test_helper

setup() {
    setup_temp
    export SCRIPT_DIR="$REPO_DIR"
}

teardown() {
    teardown_temp
}

# ── Flag parsing ──

@test "setup: --help shows usage" {
    run bash "$REPO_DIR/setup.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--claude"* ]]
    [[ "$output" == *"--copilot"* ]]
}

@test "setup: invalid flag shows error" {
    run bash "$REPO_DIR/setup.sh" --invalid
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown flag"* ]]
}

# ── JSON merge logic ──

@test "setup: jq merge preserves existing keys" {
    local base='{"existing_key": "value", "hooks": {"MyHook": []}}'
    local template='{"new_key": "value2", "hooks": {"PostToolUse": []}}'
    run bash -c "echo '$base' | jq -s '.[0] * .[1]' - <(echo '$template')"
    [ "$status" -eq 0 ]
    # Template keys are added
    [[ "$(echo "$output" | jq -r '.new_key')" = "value2" ]]
    # Existing keys overridden by template (jq merge behavior)
    [[ "$(echo "$output" | jq '.hooks | keys | length')" -gt 0 ]]
}

@test "setup: jq merge adds UserPromptSubmit hook" {
    local existing='{"hooks": {"PostToolUse": [{"matcher": "custom"}]}}'
    run bash -c "echo '$existing' | jq -s '.[0] * .[1]' - '$REPO_DIR/claude/settings.template.json'"
    [ "$status" -eq 0 ]
    local has_hook
    has_hook=$(echo "$output" | jq 'has("hooks") and (.hooks | has("UserPromptSubmit"))')
    [ "$has_hook" = "true" ]
}

# ── Version file ──

@test "setup: VERSION file exists and has valid semver" {
    run cat "$REPO_DIR/VERSION"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ── Scripts are executable ──

@test "setup: all scripts in claude/scripts are executable" {
    for f in "$REPO_DIR"/claude/scripts/*.sh; do
        [ -x "$f" ] || { echo "Not executable: $f"; false; }
    done
}

# ── Required files exist ──

@test "setup: all command files exist" {
    [ -f "$REPO_DIR/claude/commands/aws.md" ]
    [ -f "$REPO_DIR/claude/commands/k8s.md" ]
    [ -f "$REPO_DIR/claude/commands/cloud-setup.md" ]
    [ -f "$REPO_DIR/claude/commands/ship.md" ]
    [ -f "$REPO_DIR/claude/commands/retro.md" ]
    [ -f "$REPO_DIR/claude/commands/changelog.md" ]
    [ -f "$REPO_DIR/claude/commands/threat-model.md" ]
}

@test "setup: all script files exist" {
    [ -f "$REPO_DIR/claude/scripts/awscmd.sh" ]
    [ -f "$REPO_DIR/claude/scripts/kubecmd.sh" ]
    [ -f "$REPO_DIR/claude/scripts/aws-dashboard.sh" ]
    [ -f "$REPO_DIR/claude/scripts/k8s-dashboard.sh" ]
    [ -f "$REPO_DIR/claude/scripts/cloud-discover.sh" ]
    [ -f "$REPO_DIR/claude/scripts/cloud-setup.sh" ]
    [ -f "$REPO_DIR/claude/scripts/prompt-hook.sh" ]
}

@test "setup: copilot agents include aws and k8s" {
    [ -f "$REPO_DIR/copilot/agents/aws.md" ]
    [ -f "$REPO_DIR/copilot/agents/k8s.md" ]
}

@test "setup: settings template has UserPromptSubmit hook" {
    run jq '.hooks.UserPromptSubmit | length' "$REPO_DIR/claude/settings.template.json"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "setup: dotnet rule exists with copilot mirror and formatter hook" {
    [ -f "$REPO_DIR/claude/rules/dotnet.md" ]
    grep -q '\*\*/\*.cs' "$REPO_DIR/claude/rules/dotnet.md"
    [ -f "$REPO_DIR/copilot/instructions/dotnet.instructions.md" ]
    grep -q 'dotnet format' "$REPO_DIR/claude/settings.template.json"
    grep -qw 'dotnet' "$REPO_DIR/copilot/install-to-repo.sh"
    # settings template stays valid JSON after the hook addition
    run jq -e '.hooks.PostToolUse | map(select(.description | test("C#"))) | length' "$REPO_DIR/claude/settings.template.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}
