#!/usr/bin/env bats

load test_helper

setup() {
    setup_temp
}

teardown() {
    teardown_temp
}

# ── Not configured ──

@test "k8s-dashboard: shows not configured when no config file" {
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]
    [[ "$output" == *"/cloud-setup"* ]]
}

# ── K8s disabled ──

@test "k8s-dashboard: shows disabled when k8s not enabled" {
    create_mock_cloud_config_no_mfa
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"disabled"* ]]
}

# ── Dashboard rendering ──

@test "k8s-dashboard: shows cluster name and region" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-cluster"* ]]
    [[ "$output" == *"eu-west-1"* ]]
}

@test "k8s-dashboard: shows only k8s-enabled profiles" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    # myapp profiles are k8s-enabled
    [[ "$output" == *"myapp-dev"* ]]
    [[ "$output" == *"myapp-stg"* ]]
    # tunnel-dev is NOT k8s-enabled
    [[ "$output" != *"tunnel-dev"* ]]
}

@test "k8s-dashboard: shows k8s profile count" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 profiles"* ]]
}

# ── Namespaces ──

@test "k8s-dashboard: shows known namespaces" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Known namespaces"* ]]
    [[ "$output" == *"app-ns"* ]]
    [[ "$output" == *"cache-ns"* ]]
}

# ── Access indicators ──

@test "k8s-dashboard: PowerUser gets checkmark" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✔ PowerUser"* ]]
}

@test "k8s-dashboard: ReadOnly gets triangle" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"△ ReadOnly"* ]]
}

# ── EKS role ──

@test "k8s-dashboard: shows EKS role name" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EKS role: shared-eks-management-role"* ]]
}

# ── Operations menu ──

@test "k8s-dashboard: shows operations menu" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Operations"* ]]
    [[ "$output" == *"pods"* ]]
    [[ "$output" == *"deployments"* ]]
    [[ "$output" == *"logs"* ]]
    [[ "$output" == *"releases"* ]]
}

# ── MFA status ──

@test "k8s-dashboard: shows MFA expired when no cache" {
    create_mock_cloud_config
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MFA: ✖ expired"* ]]
}

@test "k8s-dashboard: shows MFA active when cache is fresh" {
    create_mock_cloud_config
    create_mfa_cache 60
    run bash "$SCRIPTS_DIR/k8s-dashboard.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MFA: ✔ active"* ]]
}
