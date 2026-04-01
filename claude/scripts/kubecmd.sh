#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kubernetes CLI Wrapper with EKS Auth + Role Assumption
# Reads configuration from cloud-config.json or environment variables.
#
# Usage: kubecmd.sh <profile> kubectl|helm <args...>
#
# Config precedence (highest → lowest):
#   1. Environment variables (EKS_CLUSTER_NAME, EKS_CLUSTER_REGION, EKS_ROLE_NAME)
#   2. cloud-config.json
#   3. Built-in defaults
# ============================================================================

PROFILE="${1:?Usage: kubecmd.sh <profile> <command...>}"
shift

# Validate profile name — reject path traversal and unsafe characters
if [[ "$PROFILE" =~ [^a-zA-Z0-9._-] ]]; then
    echo "Error: Invalid profile name: $PROFILE (only alphanumeric, dots, underscores, hyphens allowed)" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Error: No command specified" >&2
    echo "Usage: kubecmd.sh <profile> kubectl|helm <subcommand...>" >&2
    exit 1
fi

# ── Load configuration ──
CLOUD_CONFIG="${CLOUD_CONFIG:-$HOME/.claude/cloud-config.json}"

config_get() {
    local key="$1" default="${2:-}"
    if [[ -f "$CLOUD_CONFIG" ]] && command -v jq &>/dev/null; then
        local val
        val=$(jq -r "$key // empty" "$CLOUD_CONFIG" 2>/dev/null || echo "")
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

# ── Configuration ──
CLUSTER_NAME="${EKS_CLUSTER_NAME:-$(config_get '.k8s.cluster_name')}"
CLUSTER_REGION="${EKS_CLUSTER_REGION:-$(config_get '.k8s.cluster_region' 'eu-west-1')}"
ROLE_NAME="${EKS_ROLE_NAME:-$(config_get '.k8s.eks_role_name' 'shared-eks-management-role')}"

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: EKS cluster name not configured." >&2
    echo "Set EKS_CLUSTER_NAME env var or run /cloud-setup to configure." >&2
    exit 1
fi

# ── AWS config path ──
AWS_CONFIG_PATH="$(config_get '.aws.config_path' "$HOME/.aws")"
export AWS_CONFIG_FILE="${AWS_CONFIG_PATH}/config"
export AWS_SHARED_CREDENTIALS_FILE="${AWS_CONFIG_PATH}/credentials"

CACHE_DIR="$HOME/.cache/k8s-creds"
CACHE_FILE="$CACHE_DIR/${PROFILE}.json"
CACHE_TTL=3500  # ~58 min (STS tokens last 1 hour)

mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR"

# Clean previous credentials
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN KUBECONFIG
export AWS_PROFILE="$PROFILE"

# ── Check cached credentials ──
use_cached=false
if [[ -f "$CACHE_FILE" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null) ))
    if (( cache_age < CACHE_TTL )); then
        use_cached=true
    fi
fi

if $use_cached; then
    export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId "$CACHE_FILE")
    export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey "$CACHE_FILE")
    export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken "$CACHE_FILE")
else
    echo "Connecting to EKS (profile: $PROFILE, cluster: $CLUSTER_NAME)..." >&2

    # Update kubeconfig for the cluster
    aws eks --region "$CLUSTER_REGION" update-kubeconfig --name "$CLUSTER_NAME" >/dev/null 2>&1

    # Assume EKS management role
    account_id=$(aws sts get-caller-identity --output text --query 'Account')
    kubectl_role=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/${ROLE_NAME}" \
        --role-session-name "kubectl-session")

    # Cache credentials (atomic write, 600 = owner read/write only)
    tmpfile=$(mktemp "$CACHE_DIR/.tmp.XXXXXX")
    chmod 600 "$tmpfile"
    echo "$kubectl_role" > "$tmpfile"
    mv "$tmpfile" "$CACHE_FILE"

    export AWS_ACCESS_KEY_ID=$(echo "$kubectl_role" | jq -r .Credentials.AccessKeyId)
    export AWS_SECRET_ACCESS_KEY=$(echo "$kubectl_role" | jq -r .Credentials.SecretAccessKey)
    export AWS_SESSION_TOKEN=$(echo "$kubectl_role" | jq -r .Credentials.SessionToken)

    echo "Connected." >&2
fi

# Execute the command
"$@"
