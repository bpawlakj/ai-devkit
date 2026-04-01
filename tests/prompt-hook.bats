#!/usr/bin/env bats

load test_helper

setup() {
    setup_temp
    # Install dashboard scripts to where prompt-hook expects them
    cp "$SCRIPTS_DIR/aws-dashboard.sh" "$TEST_DIR/.claude/scripts/"
    cp "$SCRIPTS_DIR/k8s-dashboard.sh" "$TEST_DIR/.claude/scripts/"
    cp "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.claude/scripts/"
}

teardown() {
    teardown_temp
}

# ── Command routing ──

@test "prompt-hook: /aws triggers aws-dashboard" {
    create_mock_cloud_config
    run bash -c 'echo "{\"prompt\":\"/aws\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"AWS Environments"* ]]
}

@test "prompt-hook: /aws with args triggers aws-dashboard" {
    create_mock_cloud_config
    run bash -c 'echo "{\"prompt\":\"/aws dev\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"AWS Environments"* ]]
}

@test "prompt-hook: /k8s triggers k8s-dashboard" {
    create_mock_cloud_config
    run bash -c 'echo "{\"prompt\":\"/k8s\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Kubernetes Environments"* ]]
}

@test "prompt-hook: /cloud-setup triggers cloud-discover" {
    create_mock_aws_config
    run bash -c 'echo "{\"prompt\":\"/cloud-setup\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"discovered_profiles"* ]]
}

@test "prompt-hook: unrelated prompt produces no output" {
    run bash -c 'echo "{\"prompt\":\"hello world\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "prompt-hook: empty prompt produces no output" {
    run bash -c 'echo "{\"prompt\":\"\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Not configured state ──

@test "prompt-hook: /aws shows not configured when no config" {
    run bash -c 'echo "{\"prompt\":\"/aws\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]
}

@test "prompt-hook: /k8s shows not configured when no config" {
    run bash -c 'echo "{\"prompt\":\"/k8s\"}" | bash "$1"' _ "$SCRIPTS_DIR/prompt-hook.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]
}
