#!/usr/bin/env bash
# ============================================================================
# UserPromptSubmit hook for /aws and /k8s commands
# Runs the dashboard script and injects output as additionalContext.
# ============================================================================

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || echo "$INPUT")

DASHBOARD=""
case "$PROMPT" in
    /aws*)
        DASHBOARD=$(bash ~/.claude/scripts/aws-dashboard.sh 2>&1)
        ;;
    /k8s*)
        DASHBOARD=$(bash ~/.claude/scripts/k8s-dashboard.sh 2>&1)
        ;;
    /cloud-setup*)
        DASHBOARD=$(bash ~/.claude/scripts/cloud-discover.sh 2>&1)
        ;;
esac

if [ -n "$DASHBOARD" ]; then
    # Output as plain text — becomes additionalContext for Claude
    echo "$DASHBOARD"
fi

exit 0
