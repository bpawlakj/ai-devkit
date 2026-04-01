#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Cloud Discovery Script
# Reads ~/.aws/config and discovers profiles, roles, regions.
# Outputs JSON for Claude to use in the setup conversation.
# ============================================================================

CLOUD_CONFIG="${CLOUD_CONFIG:-$HOME/.claude/cloud-config.json}"
AWS_PATH="${1:-$HOME/.aws}"
AWS_CONFIG="$AWS_PATH/config"

if ! command -v jq &>/dev/null; then
    echo '{"error": "jq is required. Install: brew install jq / apt install jq"}' >&2
    exit 1
fi

# ── Existing config ──
existing="null"
if [ -f "$CLOUD_CONFIG" ]; then
    existing=$(jq '.' "$CLOUD_CONFIG")
fi

# ── Discover profiles ──
profiles_json="[]"

if [ -f "$AWS_CONFIG" ]; then
    while IFS= read -r profile_name; do
        role_arn=$(AWS_CONFIG_FILE="$AWS_CONFIG" aws configure get role_arn --profile "$profile_name" 2>/dev/null || echo "")
        source_profile=$(AWS_CONFIG_FILE="$AWS_CONFIG" aws configure get source_profile --profile "$profile_name" 2>/dev/null || echo "")
        region=$(AWS_CONFIG_FILE="$AWS_CONFIG" aws configure get region --profile "$profile_name" 2>/dev/null || echo "")

        # Auto-detect env from name
        auto_env=""
        case "$profile_name" in
            *-dev|*-dev-*) auto_env="dev" ;;
            *-stg|*-stg-*|*-staging|*-staging-*) auto_env="stg" ;;
            *-prd|*-prd-*|*-prod|*-prod-*|*-production*) auto_env="prd" ;;
        esac

        # Auto-detect project: strip env suffix
        auto_project=$(echo "$profile_name" | sed -E 's/-(dev|stg|staging|prd|prod|production)(-.*)?$//')

        # Auto-detect access from role ARN
        auto_access="PowerUser"
        if echo "$role_arn" | grep -qi "readonly\|read-only"; then auto_access="ReadOnly"; fi
        if echo "$role_arn" | grep -qi "admin"; then auto_access="Admin"; fi
        if echo "$role_arn" | grep -qi "tunnel"; then auto_access="Tunnel"; fi

        # Mask account ID
        masked_role=""
        if [ -n "$role_arn" ]; then
            masked_role=$(echo "$role_arn" | sed 's/:[0-9]\{12\}:/:***:/')
        fi

        is_base=false
        [ -z "$role_arn" ] && is_base=true

        profiles_json=$(echo "$profiles_json" | jq \
            --arg name "$profile_name" \
            --arg role "$masked_role" \
            --arg source "$source_profile" \
            --arg region "$region" \
            --arg auto_env "$auto_env" \
            --arg auto_project "$auto_project" \
            --arg auto_access "$auto_access" \
            --argjson is_base "$is_base" \
            '. + [{
                name: $name,
                role: $role,
                source_profile: $source,
                region: $region,
                auto_env: $auto_env,
                auto_project: $auto_project,
                auto_access: $auto_access,
                is_base: $is_base
            }]')

    done < <(grep '^\[profile ' "$AWS_CONFIG" | sed 's/\[profile //;s/\]//')
fi

# ── Check wrapper scripts ──
aws_wrapper="$HOME/.claude/scripts/awscmd.sh"
k8s_wrapper="$HOME/.claude/scripts/kubecmd.sh"
aws_wrapper_exists=false
k8s_wrapper_exists=false
[ -x "$aws_wrapper" ] && aws_wrapper_exists=true
[ -x "$k8s_wrapper" ] && k8s_wrapper_exists=true

# ── Output ──
jq -n \
    --arg aws_path "$AWS_PATH" \
    --arg aws_config "$AWS_CONFIG" \
    --argjson aws_config_exists "$([ -f "$AWS_CONFIG" ] && echo true || echo false)" \
    --argjson profiles "$profiles_json" \
    --argjson existing "$existing" \
    --arg aws_wrapper "$aws_wrapper" \
    --arg k8s_wrapper "$k8s_wrapper" \
    --argjson aws_wrapper_exists "$aws_wrapper_exists" \
    --argjson k8s_wrapper_exists "$k8s_wrapper_exists" \
    '{
        aws_path: $aws_path,
        aws_config_exists: $aws_config_exists,
        discovered_profiles: $profiles,
        existing_config: $existing,
        scripts: {
            aws_wrapper: $aws_wrapper,
            aws_wrapper_exists: $aws_wrapper_exists,
            k8s_wrapper: $k8s_wrapper,
            k8s_wrapper_exists: $k8s_wrapper_exists
        }
    }'
