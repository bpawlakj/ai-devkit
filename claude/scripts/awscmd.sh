#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# AWS CLI Wrapper with MFA + Role Assumption
# Reads configuration from cloud-config.json or environment variables.
#
# Usage: awscmd.sh <profile> aws <subcommand...>
#
# Config precedence (highest → lowest):
#   1. Environment variables (AWS_MFA_SERIAL, AWS_CACHE_DIR)
#   2. cloud-config.json
#   3. Built-in defaults
# ============================================================================

PROFILE="${1:?Usage: awscmd.sh <profile> <command...>}"
shift

# Validate profile name — reject path traversal and unsafe characters
if [[ "$PROFILE" =~ [^a-zA-Z0-9._-] ]]; then
    echo "Error: Invalid profile name: $PROFILE (only alphanumeric, dots, underscores, hyphens allowed)" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Error: No command specified" >&2
    echo "Usage: awscmd.sh <profile> aws <subcommand...>" >&2
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

# ── MFA Configuration ──
MFA_SERIAL="${AWS_MFA_SERIAL:-$(config_get '.aws.mfa_serial')}"
CACHE_DIR="${AWS_CACHE_DIR:-$HOME/.cache/aws-mfa}"
CACHE_FILE="$CACHE_DIR/${PROFILE}.json"
CACHE_TTL=3500  # ~58 min (role tokens last 1h)

mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR"

# ── Resolve role_arn from ~/.aws/config ──
AWS_CONFIG_PATH="$(config_get '.aws.config_path' "$HOME/.aws")"
export AWS_CONFIG_FILE="${AWS_CONFIG_PATH}/config"
export AWS_SHARED_CREDENTIALS_FILE="${AWS_CONFIG_PATH}/credentials"

resolve_role_arn() {
    local profile="$1"
    aws configure get role_arn --profile "$profile" 2>/dev/null || echo ""
}

ROLE_ARN=$(resolve_role_arn "$PROFILE")

# ── If profile has no role_arn, just pass through (no MFA needed) ──
if [[ -z "$ROLE_ARN" ]]; then
    export AWS_PROFILE="$PROFILE"
    "$@"
    exit $?
fi

# ── Resolve source_profile ──
SOURCE_PROFILE=$(aws configure get source_profile --profile "$PROFILE" 2>/dev/null || echo "default")

# ── Check cached credentials ──
use_cached=false
if [[ -f "$CACHE_FILE" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null) ))
    if (( cache_age < CACHE_TTL )); then
        export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId "$CACHE_FILE")
        export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey "$CACHE_FILE")
        export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken "$CACHE_FILE")
        if aws sts get-caller-identity >/dev/null 2>&1; then
            use_cached=true
        else
            unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        fi
    fi
fi

if $use_cached; then
    "$@"
    exit $?
fi

# ── Need fresh credentials: MFA → assume-role ──
echo "Session expired for profile: $PROFILE" >&2

if [[ -z "$MFA_SERIAL" ]]; then
    echo "Error: MFA serial not configured." >&2
    echo "Set AWS_MFA_SERIAL env var or run /cloud-setup to configure." >&2
    exit 1
fi

# Step 1: Get MFA session token using source profile
MFA_TOKEN="${AWS_MFA_TOKEN:-}"
if [[ -z "$MFA_TOKEN" ]]; then
    read -rp "MFA token for $MFA_SERIAL: " MFA_TOKEN </dev/tty
fi

MFA_CACHE="$CACHE_DIR/_mfa_session.json"
MFA_CACHE_TTL=3500

# Check if we have a valid MFA session already
mfa_cached=false
if [[ -f "$MFA_CACHE" ]]; then
    mfa_age=$(( $(date +%s) - $(stat -f %m "$MFA_CACHE" 2>/dev/null || stat -c %Y "$MFA_CACHE" 2>/dev/null) ))
    if (( mfa_age < MFA_CACHE_TTL )); then
        mfa_cached=true
    fi
fi

if ! $mfa_cached; then
    echo "Authenticating with MFA..." >&2
    mfa_result=$(AWS_PROFILE="$SOURCE_PROFILE" aws sts get-session-token \
        --serial-number "$MFA_SERIAL" \
        --token-code "$MFA_TOKEN" \
        --duration-seconds 43200)

    tmpfile=$(mktemp "$CACHE_DIR/.tmp.XXXXXX")
    chmod 600 "$tmpfile"
    echo "$mfa_result" > "$tmpfile"
    mv "$tmpfile" "$MFA_CACHE"
fi

# Step 2: Assume role using MFA session credentials
export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId "$MFA_CACHE")
export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey "$MFA_CACHE")
export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken "$MFA_CACHE")

REGION=$(config_get '.aws.default_region' 'eu-west-1')

echo "Assuming role: $ROLE_ARN" >&2
role_result=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "awscmd-session" \
    --region "$REGION")

# Cache the assumed-role credentials (atomic write)
tmpfile=$(mktemp "$CACHE_DIR/.tmp.XXXXXX")
chmod 600 "$tmpfile"
echo "$role_result" > "$tmpfile"
mv "$tmpfile" "$CACHE_FILE"

export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId <<< "$role_result")
export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey <<< "$role_result")
export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken <<< "$role_result")

echo "Connected as: $(aws sts get-caller-identity --query Arn --output text)" >&2

# Execute the command
"$@"
