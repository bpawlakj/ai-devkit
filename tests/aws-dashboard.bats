#!/usr/bin/env bats

load test_helper

setup() {
    setup_temp
}

teardown() {
    teardown_temp
}

# ── Not configured ──

@test "aws-dashboard: shows not configured when no config file" {
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]
    [[ "$output" == *"/cloud-setup"* ]]
}

# ── Dashboard rendering ──

@test "aws-dashboard: shows profile count" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 profiles"* ]]
}

@test "aws-dashboard: shows default project" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Default: MyApp"* ]]
}

@test "aws-dashboard: shows project grouping" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MyApp"* ]]
    [[ "$output" == *"Tunnel"* ]]
}

# ── Access level indicators ──

@test "aws-dashboard: PowerUser gets checkmark indicator" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✔ PowerUser"* ]]
}

@test "aws-dashboard: ReadOnly gets triangle indicator" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"△ ReadOnly"* ]]
}

@test "aws-dashboard: Tunnel gets circle indicator" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"◯ Tunnel"* ]]
}

# ── Operations menu ──

@test "aws-dashboard: shows operations menu" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Operations"* ]]
    [[ "$output" == *"whoami"* ]]
    [[ "$output" == *"s3 ls"* ]]
    [[ "$output" == *"ec2 ls"* ]]
    [[ "$output" == *"logs tail"* ]]
}

@test "aws-dashboard: menu has 18 numbered operations" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"18  logs tail"* ]]
}

# ── MFA status ──

@test "aws-dashboard: shows MFA expired when no cache" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MFA: ✖ expired"* ]]
}

@test "aws-dashboard: shows MFA active when cache is fresh" {
    create_mock_cloud_config
    create_mfa_cache 60
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MFA: ✔ active"* ]]
    [[ "$output" == *"remaining"* ]]
}

@test "aws-dashboard: shows MFA expired when cache is old" {
    create_mock_cloud_config
    create_mfa_cache 4000
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MFA: ✖ expired"* ]]
}

@test "aws-dashboard: no MFA line when MFA not configured" {
    create_mock_cloud_config_no_mfa
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"MFA:"* ]]
}

# ── Wrapper path ──

@test "aws-dashboard: shows wrapper path" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/aws-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Wrapper:"* ]]
    [[ "$output" == *"awscmd.sh"* ]]
}
