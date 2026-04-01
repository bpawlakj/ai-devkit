A UserPromptSubmit hook has already run and injected the AWS dashboard output into your context above this message. Display that dashboard output to the user EXACTLY as provided — do not summarize, do not rephrase, do not ask questions first.

## MFA Handling (CRITICAL)

After displaying the dashboard, check the MFA status line in the output:

- If `MFA: ✖ expired` — IMMEDIATELY ask the user for their 6-digit MFA token BEFORE anything else. Say: "MFA session expired. Enter your 6-digit MFA token:". Once received, authenticate using the default project's dev profile:
  ```
  echo '<token>' | AWS_MFA_TOKEN=$(cat) <aws_wrapper> <profile> aws sts get-caller-identity
  ```
  Then proceed normally.
- If `MFA: ✔ active` — proceed without asking for MFA.
- If no MFA line — MFA is not configured, proceed normally.

## After dashboard (and MFA if needed)

- If $ARGUMENTS contains an environment (e.g., "dev", "ETSL dev") — resolve the profile, run `<aws_wrapper> <profile> aws sts get-caller-identity` to connect, show the identity, then re-display the operations menu.
- If $ARGUMENTS contains a command request — resolve profile and execute.
- If $ARGUMENTS is empty — wait for user to pick a number or type a request.
- If a number is picked — execute the corresponding command from the menu using the active profile.

Every AWS command MUST go through the wrapper: `<aws_wrapper> <profile> aws <subcommand...>`

Read wrapper path from: `jq -r '.scripts.aws_wrapper' ~/.claude/cloud-config.json`

If any command fails with AccessDenied, ask the user for MFA token and retry with:
```
echo '<token>' | AWS_MFA_TOKEN=$(cat) <aws_wrapper> <profile> aws <subcommand...>
```

Safety: NEVER modify/delete prd resources without confirmation. Always confirm destructive ops.

$ARGUMENTS
