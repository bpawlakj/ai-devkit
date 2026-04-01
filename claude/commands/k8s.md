A UserPromptSubmit hook has already run and injected the K8s dashboard output into your context above this message. Display that dashboard output to the user EXACTLY as provided — do not summarize, do not rephrase, do not ask questions first.

## MFA Handling (CRITICAL)

After displaying the dashboard, check the MFA status line in the output:

- If `MFA: ✖ expired` — IMMEDIATELY ask the user for their 6-digit MFA token BEFORE anything else. Say: "MFA session expired. Enter your 6-digit MFA token:". Once received, authenticate using the AWS wrapper:
  ```
  echo '<token>' | AWS_MFA_TOKEN=$(cat) <aws_wrapper> <profile> aws sts get-caller-identity
  ```
  Read aws_wrapper from: `jq -r '.scripts.aws_wrapper' ~/.claude/cloud-config.json`
  Then proceed normally.
- If `MFA: ✔ active` — proceed without asking for MFA.
- If no MFA line — MFA is not configured, proceed normally.

## After dashboard (and MFA if needed)

- If $ARGUMENTS contains an environment (e.g., "dev", "MAX dev") — resolve the profile, run `<k8s_wrapper> <profile> kubectl get nodes` to connect, show the result, then re-display the operations menu.
- If $ARGUMENTS contains a command request — resolve profile and execute.
- If $ARGUMENTS is empty — wait for user to pick a number or type a request.
- If a number is picked — execute the corresponding command from the menu using the active profile.

Every K8s command MUST go through the wrapper: `<k8s_wrapper> <profile> kubectl|helm <args...>`

Read wrapper path from: `jq -r '.scripts.k8s_wrapper' ~/.claude/cloud-config.json`

If any command fails with AccessDenied, ask the user for MFA token and retry with:
```
echo '<token>' | AWS_MFA_TOKEN=$(cat) <aws_wrapper> <profile> aws sts get-caller-identity
```
Then retry the original command.

## Safety Guard (CRITICAL — READ-ONLY BY DEFAULT)

You are a READ-ONLY tool. You may ONLY execute commands that read/list/describe/get resources. You MUST NEVER execute any command that creates, modifies, updates, or deletes resources unless the user provides EXPLICIT confirmation.

### BLOCKED commands — NEVER execute without confirmation:

**Always blocked (all environments):**
- `kubectl delete`, `kubectl patch`, `kubectl edit`, `kubectl apply`, `kubectl create`
- `kubectl set image`, `kubectl set env`, `kubectl set resources`
- `kubectl scale`, `kubectl autoscale`
- `kubectl rollout restart`, `kubectl rollout undo`
- `kubectl drain`, `kubectl cordon`, `kubectl uncordon`
- `kubectl taint`, `kubectl label` (write), `kubectl annotate` (write)
- `kubectl exec` (except read-only inspection like `cat`, `ls`, `env`, `printenv`)
- `kubectl cp` (upload direction)
- `helm install`, `helm upgrade`, `helm uninstall`, `helm rollback`

**Absolutely forbidden on prd (even with confirmation):**
- `kubectl delete namespace`
- `kubectl delete deployment`
- `kubectl delete statefulset`
- `kubectl scale --replicas=0`
- `kubectl drain`
- `helm uninstall`

### Confirmation flow for write operations:

If the user explicitly requests a write operation (e.g., "update the image to v2.1", "restart the pods", "scale to 3 replicas"), you MUST:

1. Show the EXACT command you would run
2. Show which environment, profile, and namespace it targets
3. Show what will change (current state → new state if possible)
4. Ask for explicit confirmation with this format:

```
⚠️  Write operation on <ENV> (<namespace>)
  Profile:   <profile-name>
  Command:   <full kubectl/helm command>
  Effect:    <what this will change>
  Current:   <current state, e.g., image: myapp:v2.0, replicas: 2>
  New:       <new state, e.g., image: myapp:v2.1, replicas: 3>

  Type "yes" to confirm, or anything else to cancel.
```

5. Only execute if the user responds with exactly "yes"
6. On ReadOnly profiles — refuse immediately, do not even show the confirmation

$ARGUMENTS
