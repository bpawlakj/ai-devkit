#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# AWS Environment Dashboard
# Reads cloud-config.json and displays environment list + operations menu.
# Used by the /aws slash command to ensure deterministic output.
# ============================================================================

CLOUD_CONFIG="${CLOUD_CONFIG:-$HOME/.claude/cloud-config.json}"

if [[ ! -f "$CLOUD_CONFIG" ]]; then
    cat <<'EOF'

  AWS Environments
  △ not configured

  Run /cloud-setup to configure your AWS profiles, MFA, and script paths.
EOF
    exit 0
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

# ── Parse config ──
profile_count=$(jq '.aws.profiles | length' "$CLOUD_CONFIG")
default_project=$(jq -r '.aws.default_project // "—"' "$CLOUD_CONFIG")
wrapper=$(jq -r '.scripts.aws_wrapper // "—"' "$CLOUD_CONFIG")

# ── Build environment list ──
echo ""
echo "  AWS Environments"
echo "  $profile_count profiles"
echo ""

# Group profiles by project
jq -r '.aws.profiles | group_by(.project)[] | .[0].project' "$CLOUD_CONFIG" | while read -r project; do
    echo "    $project"

    jq -r --arg proj "$project" '
        .aws.profiles[]
        | select(.project == $proj)
        | "    \(.name) · \(.environment) · \(.access_level)"
    ' "$CLOUD_CONFIG" | while read -r line; do
        # Add access level indicator
        if echo "$line" | grep -qE 'PowerUser|Admin'; then
            echo "$line" | sed 's/· \(PowerUser\|Admin\)/· ✔ \1/'
        elif echo "$line" | grep -q 'ReadOnly'; then
            echo "$line" | sed 's/· ReadOnly/· △ ReadOnly/'
        else
            echo "$line" | sed 's/· \([^·]*\)$/· ◯ \1/'
        fi
    done
    echo ""
done

echo "  Default: $default_project"
echo "  Wrapper: $wrapper"

# ── MFA status ──
mfa_serial=$(jq -r '.aws.mfa_serial // empty' "$CLOUD_CONFIG")
if [ -n "$mfa_serial" ]; then
    CACHE_DIR="$HOME/.cache/aws-mfa"
    MFA_CACHE="$CACHE_DIR/_mfa_session.json"
    CACHE_TTL=3500  # ~58 min

    mfa_status="✖ expired"
    if [ -f "$MFA_CACHE" ]; then
        cache_age=$(( $(date +%s) - $(stat -f %m "$MFA_CACHE" 2>/dev/null || stat -c %Y "$MFA_CACHE" 2>/dev/null) ))
        if (( cache_age < CACHE_TTL )); then
            remaining=$(( (CACHE_TTL - cache_age) / 60 ))
            mfa_status="✔ active (${remaining}m remaining)"
        fi
    fi
    echo "  MFA: $mfa_status"
fi

# ── Operations menu ──
cat <<'EOF'

  Operations
  ─────────────────────────────────
  Identity & Access
    1  whoami          Caller identity
    2  roles           Assumable roles

  Storage
    3  s3 ls           List buckets
    4  s3 browse       Browse bucket contents

  Compute
    5  ec2 ls          List EC2 instances
    6  ecs services    List ECS services
    7  ecs tasks       Running ECS tasks
    8  lambda ls       List Lambda functions

  Containers & Registry
    9  ecr repos       List ECR repositories
   10  ecr images      Images in a repo

  Database
   11  rds ls          List RDS instances
   12  dynamo ls       List DynamoDB tables

  Secrets & Config
   13  ssm params      List SSM parameters
   14  secrets ls      List SM secrets

  Networking
   15  vpc ls          List VPCs
   16  sg ls           List security groups

  Monitoring
   17  logs groups     CloudWatch log groups
   18  logs tail       Tail a log group
  ─────────────────────────────────
  Pick a number, type a profile to switch env,
  or describe what you need.

EOF
