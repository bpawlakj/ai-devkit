#!/usr/bin/env bats

load test_helper

setup() {
    setup_temp
    create_mock_aws_config
}

teardown() {
    teardown_temp
}

# ── Profile discovery ──

@test "cloud-discover: finds all profiles from aws config" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | jq '.discovered_profiles | length')
    [ "$count" -eq 6 ]
}

@test "cloud-discover: identifies base profiles" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local base_count
    base_count=$(echo "$output" | jq '[.discovered_profiles[] | select(.is_base == true)] | length')
    [ "$base_count" -eq 1 ]
}

@test "cloud-discover: base profile is core-users" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local base_name
    base_name=$(echo "$output" | jq -r '.discovered_profiles[] | select(.is_base == true) | .name')
    [ "$base_name" = "core-users" ]
}

# ── Environment auto-detection ──

@test "cloud-discover: auto-detects dev environment" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local env
    env=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "myapp-dev") | .auto_env')
    [ "$env" = "dev" ]
}

@test "cloud-discover: auto-detects stg environment" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local env
    env=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "myapp-stg") | .auto_env')
    [ "$env" = "stg" ]
}

@test "cloud-discover: auto-detects prd environment" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local env
    env=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "myapp-prd") | .auto_env')
    [ "$env" = "prd" ]
}

@test "cloud-discover: no env for base profile" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local env
    env=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "core-users") | .auto_env')
    [ "$env" = "" ]
}

# ── Project auto-detection ──

@test "cloud-discover: auto-detects project from profile name" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local project
    project=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "myapp-dev") | .auto_project')
    [ "$project" = "myapp" ]
}

@test "cloud-discover: strips env suffix for project name" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local project
    project=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "myapp-prd") | .auto_project')
    [ "$project" = "myapp" ]
}

# ── Access level inference ──

@test "cloud-discover: detects PowerUser from role ARN" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local access
    access=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "myapp-dev") | .auto_access')
    [ "$access" = "PowerUser" ]
}

@test "cloud-discover: detects ReadOnly from role ARN" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local access
    access=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "myapp-stg") | .auto_access')
    [ "$access" = "ReadOnly" ]
}

@test "cloud-discover: detects Tunnel from role ARN" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local access
    access=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "tunnel-dev") | .auto_access')
    [ "$access" = "Tunnel" ]
}

@test "cloud-discover: detects Admin from role ARN" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local access
    access=$(echo "$output" | jq -r '.discovered_profiles[] | select(.name == "admin-dev") | .auto_access')
    [ "$access" = "Admin" ]
}

# ── Account ID masking ──

@test "cloud-discover: masks account IDs in role ARNs" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    # Should not contain raw account IDs
    [[ "$output" != *"123456789012"* ]]
    [[ "$output" != *"987654321098"* ]]
    # Should contain masked versions
    [[ "$output" == *"***"* ]]
}

# ── Existing config detection ──

@test "cloud-discover: reports null when no existing config" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local existing
    existing=$(echo "$output" | jq '.existing_config')
    [ "$existing" = "null" ]
}

@test "cloud-discover: includes existing config when present" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local existing
    existing=$(echo "$output" | jq '.existing_config.version')
    [ "$existing" = "1" ]
}

# ── JSON output schema ──

@test "cloud-discover: output is valid JSON" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    echo "$output" | jq . >/dev/null 2>&1
    [ $? -eq 0 ]
}

@test "cloud-discover: output has required top-level keys" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local keys
    keys=$(echo "$output" | jq -r 'keys[]' | sort | tr '\n' ',')
    [[ "$keys" == *"aws_config_exists"* ]]
    [[ "$keys" == *"aws_path"* ]]
    [[ "$keys" == *"discovered_profiles"* ]]
    [[ "$keys" == *"existing_config"* ]]
    [[ "$keys" == *"scripts"* ]]
}

# ── Missing aws config ──

@test "cloud-discover: handles missing aws config gracefully" {
    rm -rf "$TEST_DIR/.aws"
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local exists
    exists=$(echo "$output" | jq '.aws_config_exists')
    [ "$exists" = "false" ]
    local count
    count=$(echo "$output" | jq '.discovered_profiles | length')
    [ "$count" -eq 0 ]
}

# ── Wrapper script detection ──

@test "cloud-discover: reports wrapper scripts not found" {
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local aws_exists
    aws_exists=$(echo "$output" | jq '.scripts.aws_wrapper_exists')
    [ "$aws_exists" = "false" ]
}

@test "cloud-discover: reports wrapper scripts found when present" {
    touch "$TEST_DIR/.claude/scripts/awscmd.sh"
    chmod +x "$TEST_DIR/.claude/scripts/awscmd.sh"
    run bash "$SCRIPTS_DIR/cloud-discover.sh" "$TEST_DIR/.aws"
    [ "$status" -eq 0 ]
    local aws_exists
    aws_exists=$(echo "$output" | jq '.scripts.aws_wrapper_exists')
    [ "$aws_exists" = "true" ]
}
