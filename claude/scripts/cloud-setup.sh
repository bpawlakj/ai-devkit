#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Cloud Setup Wizard
# Interactive configuration for /aws and /k8s commands.
# Creates or updates ~/.claude/cloud-config.json
# ============================================================================

CLOUD_CONFIG="${CLOUD_CONFIG:-$HOME/.claude/cloud-config.json}"
SCRIPTS_DIR="$HOME/.claude/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}▸${NC} $1"; }
ok()      { echo -e "${GREEN}✔${NC} $1"; }
warn()    { echo -e "${YELLOW}△${NC} $1"; }
err()     { echo -e "${RED}✖${NC} $1" >&2; }
header()  { echo -e "\n${BOLD}$1${NC}"; }
dim()     { echo -e "${DIM}$1${NC}"; }

ask() {
    local prompt="$1" default="${2:-}" var_name="$3"
    if [ -n "$default" ]; then
        echo -ne "  ${prompt} ${DIM}(${default})${NC}: "
    else
        echo -ne "  ${prompt}: "
    fi
    read -r input
    eval "$var_name=\"${input:-$default}\""
}

ask_yn() {
    local prompt="$1" default="${2:-n}"
    local hint="y/N"
    [[ "$default" == "y" ]] && hint="Y/n"
    echo -ne "  ${prompt} ${DIM}(${hint})${NC}: "
    read -r input
    input="${input:-$default}"
    [[ "$input" =~ ^[Yy] ]]
}

choose() {
    local prompt="$1" var_name="$2"
    shift 2
    local options=("$@")
    echo -e "  ${prompt}"
    for i in "${!options[@]}"; do
        echo -e "    ${BOLD}$((i+1))${NC}  ${options[$i]}"
    done
    echo -ne "  Pick: "
    read -r pick
    pick=$((pick - 1))
    if (( pick >= 0 && pick < ${#options[@]} )); then
        eval "$var_name=\"${options[$pick]}\""
    else
        eval "$var_name=\"${options[0]}\""
    fi
}

# ============================================================================
# Check dependencies
# ============================================================================

if ! command -v jq &>/dev/null; then
    err "jq is required. Install: brew install jq / apt install jq"
    exit 1
fi

# ============================================================================
# Existing config?
# ============================================================================

echo ""
echo -e "${BOLD}  Cloud Setup Wizard${NC}"
echo -e "  ─────────────────────────────────"

if [ -f "$CLOUD_CONFIG" ]; then
    header "  Current Configuration"

    aws_path=$(jq -r '.aws.config_path // "—"' "$CLOUD_CONFIG")
    mfa=$(jq -r '.aws.mfa_serial // "—"' "$CLOUD_CONFIG")
    mfa_masked="—"
    [ "$mfa" != "—" ] && mfa_masked="...${mfa: -12}"
    profile_count=$(jq '.aws.profiles | length' "$CLOUD_CONFIG")
    default_proj=$(jq -r '.aws.default_project // "—"' "$CLOUD_CONFIG")
    k8s_enabled=$(jq -r '.k8s.enabled // false' "$CLOUD_CONFIG")
    k8s_cluster=$(jq -r '.k8s.cluster_name // "—"' "$CLOUD_CONFIG")

    echo ""
    echo -e "    AWS config:  ${aws_path}"
    echo -e "    MFA:         ${mfa_masked}"
    echo -e "    Profiles:    ${profile_count}"
    echo -e "    Default:     ${default_proj}"
    if [ "$k8s_enabled" = "true" ]; then
        echo -e "    K8s:         enabled (${k8s_cluster})"
    else
        echo -e "    K8s:         disabled"
    fi
    echo ""

    echo -e "  What to change?"
    echo -e "    ${BOLD}1${NC}  AWS config path"
    echo -e "    ${BOLD}2${NC}  Re-discover profiles"
    echo -e "    ${BOLD}3${NC}  MFA settings"
    echo -e "    ${BOLD}4${NC}  Kubernetes settings"
    echo -e "    ${BOLD}5${NC}  Script paths"
    echo -e "    ${BOLD}6${NC}  Reset (start fresh)"
    echo -e "    ${BOLD}7${NC}  Show full config"
    echo -e "    ${BOLD}0${NC}  Exit"
    echo -ne "  Pick: "
    read -r action

    case "$action" in
        6)
            if ask_yn "Delete config and start fresh?" "n"; then
                rm -f "$CLOUD_CONFIG"
                ok "Config deleted. Re-running setup..."
                exec "$0"
            else
                info "Cancelled."
                exit 0
            fi
            ;;
        7)
            echo ""
            jq '
                if .aws.mfa_serial then
                    .aws.mfa_serial = ("..." + .aws.mfa_serial[-12:])
                else . end
            ' "$CLOUD_CONFIG"
            exit 0
            ;;
        0)
            exit 0
            ;;
        1|2|3|4|5)
            warn "Partial update — running full setup with existing values as defaults."
            ;;
        *)
            err "Invalid option."
            exit 1
            ;;
    esac
fi

# ============================================================================
# Step 1: AWS Configuration Path
# ============================================================================

header "  Step 1: AWS Configuration"

existing_aws_path=""
[ -f "$CLOUD_CONFIG" ] && existing_aws_path=$(jq -r '.aws.config_path // ""' "$CLOUD_CONFIG")

ask "AWS config directory" "${existing_aws_path:-$HOME/.aws}" aws_path

# Expand ~
aws_path="${aws_path/#\~/$HOME}"

if [ ! -f "$aws_path/config" ]; then
    err "No config file at $aws_path/config"
    if ! ask_yn "Continue anyway?" "n"; then
        exit 1
    fi
fi

ok "AWS path: $aws_path"

# ============================================================================
# Step 2: Discover Profiles
# ============================================================================

header "  Step 2: Discover Profiles"

profiles=()
if [ -f "$aws_path/config" ]; then
    while IFS= read -r line; do
        profiles+=("$line")
    done < <(grep '^\[profile ' "$aws_path/config" | sed 's/\[profile //;s/\]//')
fi

if [ ${#profiles[@]} -eq 0 ]; then
    warn "No profiles found in $aws_path/config"
    echo -ne "  Enter profile names manually (comma-separated): "
    read -r manual_profiles
    IFS=',' read -ra profiles <<< "$manual_profiles"
fi

echo ""
echo -e "  Found ${BOLD}${#profiles[@]}${NC} profiles:"
echo ""

# Show profiles with role info
declare -A profile_roles
for i in "${!profiles[@]}"; do
    p="${profiles[$i]}"
    role=$(AWS_CONFIG_FILE="$aws_path/config" aws configure get role_arn --profile "$p" 2>/dev/null || echo "")
    region=$(AWS_CONFIG_FILE="$aws_path/config" aws configure get region --profile "$p" 2>/dev/null || echo "—")
    profile_roles["$p"]="$role"

    if [ -n "$role" ]; then
        # Mask account ID in role ARN
        masked_role=$(echo "$role" | sed 's/:[0-9]\{12\}:/:***:/')
        echo -e "    ${BOLD}$((i+1))${NC}  $p  ${DIM}$masked_role  $region${NC}"
    else
        echo -e "    ${BOLD}$((i+1))${NC}  $p  ${DIM}(base profile)  $region${NC}"
    fi
done

# ============================================================================
# Step 3: Annotate Profiles
# ============================================================================

header "  Step 3: Annotate Profiles"
info "For each profile with a role, provide project/env/access info."
info "Press Enter to accept auto-detected values. Type 'skip' to skip a profile."
echo ""

json_profiles="[]"

for p in "${profiles[@]}"; do
    role="${profile_roles[$p]}"

    # Skip base profiles
    if [ -z "$role" ]; then
        dim "  Skipping $p (base profile)"
        continue
    fi

    echo -e "  ${BOLD}$p${NC}"

    # Auto-detect from profile name
    auto_env=""
    auto_project=""
    if [[ "$p" =~ -dev$ ]]; then auto_env="dev"; fi
    if [[ "$p" =~ -stg$ ]]; then auto_env="stg"; fi
    if [[ "$p" =~ -staging$ ]]; then auto_env="stg"; fi
    if [[ "$p" =~ -prd$ ]]; then auto_env="prd"; fi
    if [[ "$p" =~ -prod$ ]]; then auto_env="prd"; fi
    if [[ "$p" =~ -production$ ]]; then auto_env="prd"; fi

    # Extract project name: everything before the last -env segment
    auto_project=$(echo "$p" | sed -E 's/-(dev|stg|staging|prd|prod|production)$//')

    # Auto-detect access level from role ARN
    auto_access="PowerUser"
    if echo "$role" | grep -qi "readonly\|read-only"; then auto_access="ReadOnly"; fi
    if echo "$role" | grep -qi "admin"; then auto_access="Admin"; fi
    if echo "$role" | grep -qi "tunnel"; then auto_access="Tunnel"; fi

    ask "    Project" "$auto_project" proj
    [ "$proj" = "skip" ] && { dim "    Skipped."; echo ""; continue; }

    ask "    Environment (dev/stg/prd)" "$auto_env" env

    choose "    Access level:" access "PowerUser" "ReadOnly" "Admin" "Tunnel"

    ask "    Aliases (comma-separated)" "$env" aliases

    # Build JSON for this profile
    aliases_json=$(echo "$aliases" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";""))')
    json_profiles=$(echo "$json_profiles" | jq \
        --arg name "$p" \
        --arg project "$proj" \
        --arg env "$env" \
        --arg access "$access" \
        --argjson aliases "$aliases_json" \
        '. + [{name: $name, project: $project, environment: $env, access_level: $access, aliases: $aliases}]')

    ok "  $p → $proj / $env / $access"
    echo ""
done

# ============================================================================
# Step 4: Default Project
# ============================================================================

header "  Step 4: Default Project"

projects=($(echo "$json_profiles" | jq -r '.[].project' | sort -u))

if [ ${#projects[@]} -eq 0 ]; then
    warn "No profiles annotated."
    default_project=""
elif [ ${#projects[@]} -eq 1 ]; then
    default_project="${projects[0]}"
    ok "Default project: $default_project (only one)"
else
    choose "Default project:" default_project "${projects[@]}"
    ok "Default project: $default_project"
fi

# ============================================================================
# Step 5: MFA Configuration
# ============================================================================

header "  Step 5: MFA Configuration"

existing_mfa=""
[ -f "$CLOUD_CONFIG" ] && existing_mfa=$(jq -r '.aws.mfa_serial // ""' "$CLOUD_CONFIG")

if ask_yn "Does your AWS setup require MFA?" "${existing_mfa:+y}"; then
    ask "MFA device ARN" "$existing_mfa" mfa_serial

    # Validate format
    if [[ ! "$mfa_serial" =~ ^arn:aws:iam::[0-9]+:mfa/ ]]; then
        warn "MFA ARN format looks unusual (expected arn:aws:iam::<account>:mfa/<user>)"
        if ! ask_yn "Continue anyway?" "n"; then
            exit 1
        fi
    fi
    # Reject dangerous characters
    if [[ "$mfa_serial" =~ [^a-zA-Z0-9:/_@.\-] ]]; then
        err "MFA ARN contains invalid characters."
        exit 1
    fi
    ok "MFA: ...${mfa_serial: -12}"
else
    mfa_serial=""
    ok "MFA: disabled"
fi

# ============================================================================
# Step 6: Default Region
# ============================================================================

header "  Step 6: Default Region"

existing_region=""
[ -f "$CLOUD_CONFIG" ] && existing_region=$(jq -r '.aws.default_region // ""' "$CLOUD_CONFIG")

ask "Default AWS region" "${existing_region:-eu-west-1}" default_region
ok "Region: $default_region"

# ============================================================================
# Step 7: Kubernetes Configuration
# ============================================================================

header "  Step 7: Kubernetes (EKS)"

k8s_enabled=false
k8s_cluster=""
k8s_region=""
k8s_role=""
k8s_profiles_json="[]"
k8s_namespaces_json="{}"

existing_k8s="n"
[ -f "$CLOUD_CONFIG" ] && [ "$(jq -r '.k8s.enabled // false' "$CLOUD_CONFIG")" = "true" ] && existing_k8s="y"

if ask_yn "Do you need Kubernetes (EKS) access?" "$existing_k8s"; then
    k8s_enabled=true

    existing_cluster=""
    [ -f "$CLOUD_CONFIG" ] && existing_cluster=$(jq -r '.k8s.cluster_name // ""' "$CLOUD_CONFIG")
    ask "EKS cluster name" "$existing_cluster" k8s_cluster

    ask "Cluster region" "${default_region}" k8s_region

    existing_role=""
    [ -f "$CLOUD_CONFIG" ] && existing_role=$(jq -r '.k8s.eks_role_name // ""' "$CLOUD_CONFIG")
    ask "EKS IAM role name" "${existing_role:-shared-eks-management-role}" k8s_role

    # Select which profiles get K8s access
    echo ""
    info "Which profiles should have K8s access?"
    annotated=($(echo "$json_profiles" | jq -r '.[].name'))
    k8s_selected=()

    for p in "${annotated[@]}"; do
        if ask_yn "    $p?" "y"; then
            k8s_selected+=("$p")
        fi
    done

    k8s_profiles_json=$(printf '%s\n' "${k8s_selected[@]}" | jq -R . | jq -s .)

    # Namespaces per project
    echo ""
    info "Known namespaces per project (optional):"
    k8s_namespaces_json="{}"
    for proj in "${projects[@]}"; do
        ask "    Namespaces for $proj (comma-separated, or skip)" "" ns
        if [ -n "$ns" ]; then
            ns_json=$(echo "$ns" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";""))')
            k8s_namespaces_json=$(echo "$k8s_namespaces_json" | jq --arg p "$proj" --argjson ns "$ns_json" '. + {($p): $ns}')
        fi
    done

    ok "K8s: enabled ($k8s_cluster)"
else
    ok "K8s: disabled"
fi

# ============================================================================
# Step 8: Script Paths
# ============================================================================

header "  Step 8: Wrapper Scripts"

default_aws_wrapper="$SCRIPTS_DIR/awscmd.sh"
default_k8s_wrapper="$SCRIPTS_DIR/kubecmd.sh"

existing_aws_wrapper=""
existing_k8s_wrapper=""
if [ -f "$CLOUD_CONFIG" ]; then
    existing_aws_wrapper=$(jq -r '.scripts.aws_wrapper // ""' "$CLOUD_CONFIG")
    existing_k8s_wrapper=$(jq -r '.scripts.k8s_wrapper // ""' "$CLOUD_CONFIG")
fi

ask "AWS wrapper script" "${existing_aws_wrapper:-$default_aws_wrapper}" aws_wrapper
aws_wrapper="${aws_wrapper/#\~/$HOME}"

if [ ! -x "$aws_wrapper" ]; then
    warn "$aws_wrapper not found or not executable"
fi

if $k8s_enabled; then
    ask "K8s wrapper script" "${existing_k8s_wrapper:-$default_k8s_wrapper}" k8s_wrapper
    k8s_wrapper="${k8s_wrapper/#\~/$HOME}"

    if [ ! -x "$k8s_wrapper" ]; then
        warn "$k8s_wrapper not found or not executable"
    fi
else
    k8s_wrapper="${existing_k8s_wrapper:-$default_k8s_wrapper}"
fi

# ============================================================================
# Step 9: Write Config
# ============================================================================

header "  Writing Configuration"

mfa_json="null"
[ -n "$mfa_serial" ] && mfa_json="\"$mfa_serial\""

config=$(jq -n \
    --arg aws_path "$aws_path" \
    --argjson mfa "$mfa_json" \
    --arg region "$default_region" \
    --arg default_project "$default_project" \
    --argjson profiles "$json_profiles" \
    --argjson k8s_enabled "$k8s_enabled" \
    --arg k8s_cluster "$k8s_cluster" \
    --arg k8s_region "$k8s_region" \
    --arg k8s_role "$k8s_role" \
    --argjson k8s_profiles "$k8s_profiles_json" \
    --argjson k8s_namespaces "$k8s_namespaces_json" \
    --arg aws_wrapper "$aws_wrapper" \
    --arg k8s_wrapper "$k8s_wrapper" \
    '{
        version: 1,
        aws: {
            config_path: $aws_path,
            mfa_serial: $mfa,
            default_region: $region,
            default_project: $default_project,
            profiles: $profiles
        },
        k8s: {
            enabled: $k8s_enabled,
            cluster_name: $k8s_cluster,
            cluster_region: $k8s_region,
            eks_role_name: $k8s_role,
            profiles: $k8s_profiles,
            namespaces: $k8s_namespaces
        },
        scripts: {
            aws_wrapper: $aws_wrapper,
            k8s_wrapper: $k8s_wrapper
        }
    }')

# Atomic write with secure permissions
mkdir -p "$(dirname "$CLOUD_CONFIG")"
tmpfile=$(mktemp "$(dirname "$CLOUD_CONFIG")/.cloud-config.XXXXXX")
chmod 600 "$tmpfile"
echo "$config" > "$tmpfile"
mv "$tmpfile" "$CLOUD_CONFIG"

ok "Config written to $CLOUD_CONFIG (chmod 600)"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BOLD}  Cloud Setup Complete!${NC}"
echo -e "  ─────────────────────────────────"
echo -e "    AWS Config:     $aws_path"
if [ -n "$mfa_serial" ]; then
    echo -e "    MFA:            ...${mfa_serial: -12}"
else
    echo -e "    MFA:            disabled"
fi
echo -e "    Region:         $default_region"
echo -e "    Profiles:       $(echo "$json_profiles" | jq length) configured"
echo -e "    Default:        $default_project"
if $k8s_enabled; then
    echo -e "    K8s:            enabled ($k8s_cluster)"
else
    echo -e "    K8s:            disabled"
fi
echo ""
echo -e "  Run ${BOLD}/aws${NC} or ${BOLD}/k8s${NC} to get started."
echo ""
