#!/usr/bin/env bash
# Common test helper — sets up temp dirs, mock configs, and cleanup.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/claude/scripts"

setup_temp() {
    TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR"
    export CLOUD_CONFIG="$TEST_DIR/.claude/cloud-config.json"
    mkdir -p "$TEST_DIR/.claude/scripts"
    mkdir -p "$TEST_DIR/.aws"
    mkdir -p "$TEST_DIR/.cache/aws-mfa"
}

teardown_temp() {
    [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# Create a mock ~/.aws/config with test profiles
create_mock_aws_config() {
    cat > "$TEST_DIR/.aws/config" <<'EOF'
[profile core-users]
region = eu-west-1

[profile myapp-dev]
role_arn = arn:aws:iam::123456789012:role/users-poweruser-role
source_profile = core-users
region = eu-west-1

[profile myapp-stg]
role_arn = arn:aws:iam::987654321098:role/users-readonly-role
source_profile = core-users
region = eu-west-1

[profile myapp-prd]
role_arn = arn:aws:iam::111222333444:role/users-readonly-role
source_profile = core-users
region = eu-west-1

[profile tunnel-dev]
role_arn = arn:aws:iam::123456789012:role/mongo-tunnel-role
source_profile = core-users
region = eu-west-1

[profile admin-dev]
role_arn = arn:aws:iam::123456789012:role/admin-role
source_profile = core-users
region = eu-west-1
EOF
}

# Create a mock cloud-config.json
create_mock_cloud_config() {
    mkdir -p "$(dirname "$CLOUD_CONFIG")"
    cat > "$CLOUD_CONFIG" <<EOF
{
  "version": 1,
  "aws": {
    "config_path": "$TEST_DIR/.aws",
    "mfa_serial": "arn:aws:iam::123456789012:mfa/user@example.com",
    "default_region": "eu-west-1",
    "default_project": "MyApp",
    "profiles": [
      {
        "name": "myapp-dev",
        "project": "MyApp",
        "environment": "dev",
        "access_level": "PowerUser",
        "aliases": ["dev"]
      },
      {
        "name": "myapp-stg",
        "project": "MyApp",
        "environment": "stg",
        "access_level": "ReadOnly",
        "aliases": ["stg"]
      },
      {
        "name": "myapp-prd",
        "project": "MyApp",
        "environment": "prd",
        "access_level": "ReadOnly",
        "aliases": ["prd"]
      },
      {
        "name": "tunnel-dev",
        "project": "Tunnel",
        "environment": "dev",
        "access_level": "Tunnel",
        "aliases": ["tunnel"]
      }
    ]
  },
  "k8s": {
    "enabled": true,
    "cluster_name": "test-cluster",
    "cluster_region": "eu-west-1",
    "eks_role_name": "shared-eks-management-role",
    "profiles": ["myapp-dev", "myapp-stg", "myapp-prd"],
    "namespaces": {
      "MyApp": ["app-ns", "cache-ns"]
    }
  },
  "scripts": {
    "aws_wrapper": "$TEST_DIR/.claude/scripts/awscmd.sh",
    "k8s_wrapper": "$TEST_DIR/.claude/scripts/kubecmd.sh"
  }
}
EOF
}

# Create a mock cloud-config without MFA
create_mock_cloud_config_no_mfa() {
    mkdir -p "$(dirname "$CLOUD_CONFIG")"
    cat > "$CLOUD_CONFIG" <<EOF
{
  "version": 1,
  "aws": {
    "config_path": "$TEST_DIR/.aws",
    "mfa_serial": null,
    "default_region": "eu-west-1",
    "default_project": "MyApp",
    "profiles": [
      {
        "name": "myapp-dev",
        "project": "MyApp",
        "environment": "dev",
        "access_level": "PowerUser",
        "aliases": ["dev"]
      }
    ]
  },
  "k8s": {
    "enabled": false,
    "cluster_name": "",
    "cluster_region": "",
    "eks_role_name": "",
    "profiles": [],
    "namespaces": {}
  },
  "scripts": {
    "aws_wrapper": "$TEST_DIR/.claude/scripts/awscmd.sh",
    "k8s_wrapper": "$TEST_DIR/.claude/scripts/kubecmd.sh"
  }
}
EOF
}

# Create a fake MFA cache file with given age in seconds
create_mfa_cache() {
    local age_seconds="${1:-0}"
    local cache_file="$TEST_DIR/.cache/aws-mfa/_mfa_session.json"
    mkdir -p "$(dirname "$cache_file")"
    echo '{"Credentials":{"AccessKeyId":"FAKE","SecretAccessKey":"FAKE","SessionToken":"FAKE"}}' > "$cache_file"
    if [ "$age_seconds" -gt 0 ]; then
        touch -t "$(date -v-${age_seconds}S +%Y%m%d%H%M.%S 2>/dev/null || date -d "-${age_seconds} seconds" +%Y%m%d%H%M.%S)" "$cache_file"
    fi
}
