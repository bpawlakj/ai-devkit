#!/usr/bin/env bats

load test_helper

setup() {
    setup_temp
}

teardown() {
    teardown_temp
}

# ── Profile name validation (security) ──

@test "awscmd: rejects profile with path traversal" {
    run bash "$SCRIPTS_DIR/awscmd.sh" "../../../etc/passwd" aws sts get-caller-identity
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid profile name"* ]]
}

@test "awscmd: rejects profile with spaces" {
    run bash "$SCRIPTS_DIR/awscmd.sh" "my profile" aws sts get-caller-identity
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid profile name"* ]]
}

@test "awscmd: rejects profile with semicolons" {
    run bash "$SCRIPTS_DIR/awscmd.sh" "profile;rm -rf /" aws sts get-caller-identity
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid profile name"* ]]
}

@test "awscmd: rejects profile with backticks" {
    run bash "$SCRIPTS_DIR/awscmd.sh" 'profile`whoami`' aws sts get-caller-identity
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid profile name"* ]]
}

@test "awscmd: rejects profile with dollar sign" {
    run bash "$SCRIPTS_DIR/awscmd.sh" 'profile$HOME' aws sts get-caller-identity
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid profile name"* ]]
}

@test "awscmd: accepts valid profile with alphanumeric" {
    # Will fail on missing aws config, but shouldn't fail on validation
    run bash "$SCRIPTS_DIR/awscmd.sh" "myapp-dev" aws sts get-caller-identity
    [[ "$output" != *"Invalid profile name"* ]]
}

@test "awscmd: accepts profile with dots and underscores" {
    run bash "$SCRIPTS_DIR/awscmd.sh" "my_app.dev" aws sts get-caller-identity
    [[ "$output" != *"Invalid profile name"* ]]
}

# ── Missing arguments ──

@test "awscmd: fails without profile argument" {
    run bash "$SCRIPTS_DIR/awscmd.sh"
    [ "$status" -ne 0 ]
}

@test "awscmd: fails without command argument" {
    run bash "$SCRIPTS_DIR/awscmd.sh" "myprofile"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No command specified"* ]]
}

# ── Cache directory ──

@test "awscmd: creates cache directory" {
    create_mock_aws_config
    export AWS_CONFIG_FILE="$TEST_DIR/.aws/config"
    export AWS_SHARED_CREDENTIALS_FILE="$TEST_DIR/.aws/credentials"
    # Will fail on aws call but cache dir should be created
    run bash "$SCRIPTS_DIR/awscmd.sh" "core-users" aws sts get-caller-identity 2>&1
    [ -d "$TEST_DIR/.cache/aws-mfa" ]
}
