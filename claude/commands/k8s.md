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

Safety: NEVER execute destructive commands in prd without confirmation. Always confirm delete/scale/drain/uninstall.

$ARGUMENTS
