#!/usr/bin/env bash
# ============================================================================
# Cloud Safety Guard — PreToolUse hook for Bash commands
# Blocks destructive AWS/K8s operations. Exit 2 = block, exit 0 = allow.
# ============================================================================

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null || echo "$INPUT")

# ── AWS destructive commands ──
if echo "$CMD" | grep -qE 'aws\s+(ec2\s+(terminate|stop|start|modify|create|delete)|ecs\s+(update-service|stop-task|delete)|lambda\s+(update-function|delete|invoke)|rds\s+(delete|modify|stop|reboot)|dynamodb\s+(delete|update|put-item)|s3\s+(rm|mv)|s3api\s+delete|ssm\s+(put-parameter|delete)|secretsmanager\s+(create|update|delete)|iam\s+(create|delete|update|attach|detach|put)|cloudformation\s+(create|update|delete))'; then
    echo "BLOCKED: Destructive AWS command detected. This is a read-only session. Show the command to the user and ask for explicit confirmation before executing." >&2
    exit 2
fi

# ── AWS S3 upload (cp to s3://) ──
if echo "$CMD" | grep -qE 'aws\s+s3\s+cp\s+[^s].*\s+s3://'; then
    echo "BLOCKED: S3 upload detected. Show the command to the user and ask for explicit confirmation." >&2
    exit 2
fi

# ── kubectl write commands ──
if echo "$CMD" | grep -qE 'kubectl\s+(delete|patch|edit|apply|create|replace|set\s+(image|env|resources)|scale|autoscale|rollout\s+(restart|undo)|drain|cordon|uncordon|taint|cp)'; then
    echo "BLOCKED: Destructive kubectl command detected. This is a read-only session. Show the command to the user and ask for explicit confirmation before executing." >&2
    exit 2
fi

# ── kubectl label/annotate write (without --list or -l) ──
if echo "$CMD" | grep -qE 'kubectl\s+(label|annotate)' && ! echo "$CMD" | grep -qE '\-\-list|\-l\s'; then
    echo "BLOCKED: kubectl label/annotate write detected. Show the command to the user and ask for explicit confirmation." >&2
    exit 2
fi

# ── kubectl exec (allow read-only: cat, ls, env, printenv, whoami, id, df, ps) ──
if echo "$CMD" | grep -qE 'kubectl\s+exec'; then
    if ! echo "$CMD" | grep -qE -- '-- (cat|ls|env|printenv|whoami|id|df|ps|hostname|date|uname)( |$)'; then
        echo "BLOCKED: kubectl exec with potentially destructive command. Show the command to the user and ask for explicit confirmation." >&2
        exit 2
    fi
fi

# ── helm write commands ──
if echo "$CMD" | grep -qE 'helm\s+(install|upgrade|uninstall|rollback|delete)'; then
    echo "BLOCKED: Destructive helm command detected. This is a read-only session. Show the command to the user and ask for explicit confirmation before executing." >&2
    exit 2
fi

exit 0
