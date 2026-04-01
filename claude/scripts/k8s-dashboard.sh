#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kubernetes Environment Dashboard
# Reads cloud-config.json and displays environment list + operations menu.
# Used by the /k8s slash command to ensure deterministic output.
# ============================================================================

CLOUD_CONFIG="${CLOUD_CONFIG:-$HOME/.claude/cloud-config.json}"

if [[ ! -f "$CLOUD_CONFIG" ]]; then
    cat <<'EOF'

  Kubernetes Environments
  △ not configured

  Run /cloud-setup to configure your EKS cluster, AWS profiles, and script paths.
EOF
    exit 0
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

# ── Check if K8s is enabled ──
k8s_enabled=$(jq -r '.k8s.enabled // false' "$CLOUD_CONFIG")
if [[ "$k8s_enabled" != "true" ]]; then
    cat <<'EOF'

  Kubernetes Environments
  ◯ disabled

  K8s is not enabled in your cloud config. Run /cloud-setup and enable Kubernetes.
EOF
    exit 0
fi

# ── Parse config ──
cluster_name=$(jq -r '.k8s.cluster_name // "—"' "$CLOUD_CONFIG")
cluster_region=$(jq -r '.k8s.cluster_region // "—"' "$CLOUD_CONFIG")
eks_role=$(jq -r '.k8s.eks_role_name // "—"' "$CLOUD_CONFIG")
wrapper=$(jq -r '.scripts.k8s_wrapper // "—"' "$CLOUD_CONFIG")
default_project=$(jq -r '.aws.default_project // "—"' "$CLOUD_CONFIG")

# Get K8s-enabled profiles
k8s_profiles=$(jq -r '.k8s.profiles[]' "$CLOUD_CONFIG" 2>/dev/null)
profile_count=$(jq '.k8s.profiles | length' "$CLOUD_CONFIG")

echo ""
echo "  Kubernetes Environments"
echo "  $profile_count profiles · $cluster_name ($cluster_region)"
echo ""

# Group K8s profiles by project
jq -r --argjson k8s_profiles "$(jq '.k8s.profiles' "$CLOUD_CONFIG")" '
    .aws.profiles
    | map(select(.name as $n | $k8s_profiles | index($n)))
    | group_by(.project)[]
    | .[0].project
' "$CLOUD_CONFIG" | while read -r project; do
    echo "    $project"

    jq -r --arg proj "$project" --argjson k8s_profiles "$(jq '.k8s.profiles' "$CLOUD_CONFIG")" '
        .aws.profiles[]
        | select(.project == $proj)
        | select(.name as $n | $k8s_profiles | index($n))
        | if .access_level == "PowerUser" or .access_level == "Admin" then
            "    \(.name) · \(.environment) · ✔ \(.access_level)"
          elif .access_level == "ReadOnly" then
            "    \(.name) · \(.environment) · △ \(.access_level)"
          else
            "    \(.name) · \(.environment) · ◯ \(.access_level)"
          end
    ' "$CLOUD_CONFIG"
    echo ""
done

# Show namespaces
ns_count=$(jq '.k8s.namespaces | length' "$CLOUD_CONFIG" 2>/dev/null || echo 0)
if [[ "$ns_count" -gt 0 ]]; then
    echo "  Known namespaces:"
    jq -r '.k8s.namespaces | to_entries[] | "    \(.key): \(.value | join(", "))"' "$CLOUD_CONFIG"
    echo ""
fi

echo "  Default: $default_project"
echo "  Wrapper: $wrapper"
echo "  EKS role: $eks_role"

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
  Workloads
    1  pods            List pods (all ns)
    2  pods ns         List pods in namespace
    3  deployments     List deployments
    4  services        List services
    5  ingress         List ingresses

  Debugging
    6  logs            Tail pod logs
    7  describe        Describe a resource
    8  events          Recent events
    9  top pods        Pod resource usage
   10  top nodes       Node resource usage

  Configuration
   11  configmaps      List ConfigMaps
   12  secrets         List Secrets (names)
   13  hpa             List autoscalers

  Cluster
   14  nodes           List nodes
   15  namespaces      List namespaces
   16  contexts        Current context

  Helm
   17  releases        List Helm releases
   18  history         Release history
  ─────────────────────────────────
  Pick a number, type a profile to switch env,
  or describe what you need.

EOF
