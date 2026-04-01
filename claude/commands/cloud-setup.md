A UserPromptSubmit hook has run cloud-discover.sh and injected discovery JSON into your context above. This JSON contains: discovered AWS profiles, auto-detected project/env/access, existing config (if any), and wrapper script paths.

You are a setup wizard. Walk through configuration step by step, asking ONE question at a time. Use the discovered data to provide smart defaults — the user just confirms or overrides.

## If existing config exists (existing_config is not null)

Show a summary table of current config and ask:

```
  Current Configuration
  ─────────────────────────────────
  AWS path:   <aws_path>
  MFA:        ...<last 12 chars>
  Profiles:   <count>
  Default:    <default_project>
  K8s:        <enabled/disabled>

  1  Re-discover & annotate profiles
  2  Update MFA
  3  Update K8s settings
  4  Reset (start fresh)
  0  Exit
```

Wait for user choice, then jump to the relevant step.

## Fresh setup — ask these in order, ONE question per message:

### Step 1: AWS Path
Show discovered path. Ask: "AWS config directory? (default: <aws_path>)"
If aws_config_exists is false, warn.

### Step 2: Profile Annotation
For each discovered profile where is_base=false, show auto-detected values and ask to confirm:

```
  <profile_name>
  Role: <masked_role>
  Auto-detected: project=<auto_project>, env=<auto_env>, access=<auto_access>
  
  Correct? (Y/n) or type new values as: project env access
```

If user confirms, use auto-detected. If they type values, parse them.
Skip base profiles (is_base=true) automatically.
Collect all annotated profiles.

### Step 3: Default Project
If multiple projects, ask which is the default. If only one, confirm it.

### Step 4: MFA
Ask: "Does your setup require MFA? (y/N)"
If yes, ask for MFA ARN. Validate format: must start with `arn:aws:iam::` and contain `:mfa/`.

### Step 5: Region
Ask: "Default AWS region? (default: <first profile's region or eu-west-1>)"

### Step 6: Kubernetes
Ask: "Need K8s (EKS) access? (y/N)"
If yes:
- Cluster name
- Cluster region (default: same as AWS region)
- EKS role name (default: shared-eks-management-role)
- Which profiles get K8s access (show list, ask to confirm)
- Namespaces per project

### Step 7: Wrapper Scripts
Show discovered paths and whether they exist. Ask to confirm or override.

### Step 8: Write Config
After ALL answers collected, build the JSON and write it:

```bash
cat > /tmp/cloud-config-$$.json << 'JSONEOF'
<the complete JSON>
JSONEOF
chmod 600 /tmp/cloud-config-$$. json
mv /tmp/cloud-config-$$.json ~/.claude/cloud-config.json
```

Config format:
```json
{
  "version": 1,
  "aws": {
    "config_path": "<path>",
    "mfa_serial": "<arn or null>",
    "default_region": "<region>",
    "default_project": "<project>",
    "profiles": [
      {
        "name": "<profile>",
        "project": "<project>",
        "environment": "<env>",
        "access_level": "<access>",
        "aliases": ["<env>"]
      }
    ]
  },
  "k8s": {
    "enabled": <bool>,
    "cluster_name": "<name>",
    "cluster_region": "<region>",
    "eks_role_name": "<role>",
    "profiles": ["<profile1>", "<profile2>"],
    "namespaces": { "<project>": ["<ns1>"] }
  },
  "scripts": {
    "aws_wrapper": "<path>",
    "k8s_wrapper": "<path>"
  }
}
```

### Step 9: Show summary
```
  Cloud Setup Complete!
  ─────────────────────────────────
  AWS Config:     <path>
  MFA:            ...<last 12>
  Profiles:       <count> configured
  Default:        <project>
  K8s:            <enabled/disabled>

  Run /aws or /k8s to get started.
```

## Rules
- ONE question per message. Wait for answer before proceeding.
- Use auto-detected values as defaults — don't make user retype obvious answers.
- NEVER display full MFA ARN — mask all but last 12 chars.
- Write config with chmod 600 (contains ARN info).
- Validate MFA format: only allow [a-zA-Z0-9:/_@.\-]

$ARGUMENTS
