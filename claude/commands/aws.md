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

## Safety Guard (CRITICAL — READ-ONLY BY DEFAULT)

You are a READ-ONLY tool. You may ONLY execute commands that read/list/describe/get resources. You MUST NEVER execute any command that creates, modifies, updates, or deletes resources unless the user provides EXPLICIT confirmation.

### BLOCKED commands — NEVER execute without confirmation:

**Always blocked (all environments):**
- `aws s3 rm`, `aws s3 mv`, `aws s3 cp` (upload direction)
- `aws ec2 terminate-instances`, `aws ec2 stop-instances`, `aws ec2 start-instances`
- `aws ec2 modify-*`, `aws ec2 create-*`, `aws ec2 delete-*`
- `aws ecs update-service`, `aws ecs stop-task`, `aws ecs delete-*`
- `aws lambda update-function-*`, `aws lambda delete-*`, `aws lambda invoke`
- `aws rds delete-*`, `aws rds modify-*`, `aws rds stop-*`, `aws rds reboot-*`
- `aws dynamodb delete-*`, `aws dynamodb update-*`, `aws dynamodb put-item`
- `aws ssm put-parameter`, `aws ssm delete-*`
- `aws secretsmanager create-*`, `aws secretsmanager update-*`, `aws secretsmanager delete-*`
- `aws iam *` (all IAM write operations)
- `aws cloudformation create-*`, `aws cloudformation update-*`, `aws cloudformation delete-*`
- Any command with `--force`, `--yes`, `--no-confirm`

**Absolutely forbidden on prd (even with confirmation):**
- `aws rds delete-db-instance`
- `aws dynamodb delete-table`
- `aws ec2 terminate-instances`
- `aws cloudformation delete-stack`
- `aws s3 rb` (remove bucket)

### Confirmation flow for write operations:

If the user explicitly requests a write operation (e.g., "update the ECS service image"), you MUST:

1. Show the EXACT command you would run
2. Show which environment and profile it targets
3. Show what will change (before → after if possible)
4. Ask for explicit confirmation with this format:

```
⚠️  Write operation on <ENV>
  Profile:  <profile-name>
  Command:  <full aws command>
  Effect:   <what this will change>

  Type "yes" to confirm, or anything else to cancel.
```

5. Only execute if the user responds with exactly "yes"
6. On ReadOnly profiles — refuse immediately, do not even show the confirmation

$ARGUMENTS
