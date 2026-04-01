#!/usr/bin/env bats

load test_helper

setup() {
    setup_temp
}

teardown() {
    teardown_temp
}

# Helper: test if a command is blocked (exit 2)
assert_blocked() {
    run bash -c "echo '{\"command\":\"$1\"}' | bash '$SCRIPTS_DIR/cloud-guard.sh'"
    [ "$status" -eq 2 ]
}

# Helper: test if a command is allowed (exit 0)
assert_allowed() {
    run bash -c "echo '{\"command\":\"$1\"}' | bash '$SCRIPTS_DIR/cloud-guard.sh'"
    [ "$status" -eq 0 ]
}

# ── AWS read commands (allowed) ──

@test "guard: allows aws s3 ls" {
    assert_allowed "awscmd.sh myapp-dev aws s3 ls"
}

@test "guard: allows aws ec2 describe-instances" {
    assert_allowed "awscmd.sh myapp-dev aws ec2 describe-instances"
}

@test "guard: allows aws ecs list-services" {
    assert_allowed "awscmd.sh myapp-dev aws ecs list-services"
}

@test "guard: allows aws lambda list-functions" {
    assert_allowed "awscmd.sh myapp-dev aws lambda list-functions"
}

@test "guard: allows aws rds describe-db-instances" {
    assert_allowed "awscmd.sh myapp-dev aws rds describe-db-instances"
}

@test "guard: allows aws logs describe-log-groups" {
    assert_allowed "awscmd.sh myapp-dev aws logs describe-log-groups"
}

@test "guard: allows aws sts get-caller-identity" {
    assert_allowed "awscmd.sh myapp-dev aws sts get-caller-identity"
}

@test "guard: allows aws ssm describe-parameters" {
    assert_allowed "awscmd.sh myapp-dev aws ssm describe-parameters"
}

# ── AWS write commands (blocked) ──

@test "guard: blocks aws ec2 terminate-instances" {
    assert_blocked "awscmd.sh myapp-dev aws ec2 terminate-instances --instance-ids i-123"
}

@test "guard: blocks aws ec2 stop-instances" {
    assert_blocked "awscmd.sh myapp-dev aws ec2 stop-instances --instance-ids i-123"
}

@test "guard: blocks aws ec2 delete-security-group" {
    assert_blocked "awscmd.sh myapp-dev aws ec2 delete-security-group --group-id sg-123"
}

@test "guard: blocks aws ecs update-service" {
    assert_blocked "awscmd.sh myapp-dev aws ecs update-service --cluster my-cluster --service my-svc --force-new-deployment"
}

@test "guard: blocks aws lambda update-function-code" {
    assert_blocked "awscmd.sh myapp-dev aws lambda update-function-code --function-name my-fn"
}

@test "guard: blocks aws lambda delete-function" {
    assert_blocked "awscmd.sh myapp-dev aws lambda delete-function --function-name my-fn"
}

@test "guard: blocks aws lambda invoke" {
    assert_blocked "awscmd.sh myapp-dev aws lambda invoke --function-name my-fn out.json"
}

@test "guard: blocks aws rds delete-db-instance" {
    assert_blocked "awscmd.sh myapp-prd aws rds delete-db-instance --db-instance-identifier mydb"
}

@test "guard: blocks aws rds modify-db-instance" {
    assert_blocked "awscmd.sh myapp-dev aws rds modify-db-instance --db-instance-identifier mydb"
}

@test "guard: blocks aws dynamodb delete-table" {
    assert_blocked "awscmd.sh myapp-dev aws dynamodb delete-table --table-name my-table"
}

@test "guard: blocks aws dynamodb put-item" {
    assert_blocked "awscmd.sh myapp-dev aws dynamodb put-item --table-name my-table"
}

@test "guard: blocks aws s3 rm" {
    assert_blocked "awscmd.sh myapp-dev aws s3 rm s3://my-bucket/file.txt"
}

@test "guard: blocks aws s3 cp upload" {
    assert_blocked "awscmd.sh myapp-dev aws s3 cp ./local-file.txt s3://my-bucket/"
}

@test "guard: blocks aws ssm put-parameter" {
    assert_blocked "awscmd.sh myapp-dev aws ssm put-parameter --name /my/param --value secret"
}

@test "guard: blocks aws secretsmanager delete-secret" {
    assert_blocked "awscmd.sh myapp-dev aws secretsmanager delete-secret --secret-id my-secret"
}

@test "guard: blocks aws iam create-role" {
    assert_blocked "awscmd.sh myapp-dev aws iam create-role --role-name bad-role"
}

@test "guard: blocks aws cloudformation delete-stack" {
    assert_blocked "awscmd.sh myapp-dev aws cloudformation delete-stack --stack-name my-stack"
}

# ── kubectl read commands (allowed) ──

@test "guard: allows kubectl get pods" {
    assert_allowed "kubecmd.sh myapp-dev kubectl get pods -A"
}

@test "guard: allows kubectl describe pod" {
    assert_allowed "kubecmd.sh myapp-dev kubectl describe pod my-pod -n app-ns"
}

@test "guard: allows kubectl logs" {
    assert_allowed "kubecmd.sh myapp-dev kubectl logs my-pod -n app-ns"
}

@test "guard: allows kubectl top pods" {
    assert_allowed "kubecmd.sh myapp-dev kubectl top pods -A"
}

@test "guard: allows kubectl get events" {
    assert_allowed "kubecmd.sh myapp-dev kubectl get events -A"
}

@test "guard: allows helm list" {
    assert_allowed "kubecmd.sh myapp-dev helm list -A"
}

@test "guard: allows helm history" {
    assert_allowed "kubecmd.sh myapp-dev helm history my-release -n app-ns"
}

# ── kubectl write commands (blocked) ──

@test "guard: blocks kubectl delete" {
    assert_blocked "kubecmd.sh myapp-dev kubectl delete pod my-pod -n app-ns"
}

@test "guard: blocks kubectl apply" {
    assert_blocked "kubecmd.sh myapp-dev kubectl apply -f deployment.yaml"
}

@test "guard: blocks kubectl set image" {
    assert_blocked "kubecmd.sh myapp-dev kubectl set image deployment/my-app my-app=myimage:v2"
}

@test "guard: blocks kubectl scale" {
    assert_blocked "kubecmd.sh myapp-dev kubectl scale deployment/my-app --replicas=3"
}

@test "guard: blocks kubectl rollout restart" {
    assert_blocked "kubecmd.sh myapp-dev kubectl rollout restart deployment/my-app"
}

@test "guard: blocks kubectl drain" {
    assert_blocked "kubecmd.sh myapp-dev kubectl drain node-1"
}

@test "guard: blocks kubectl edit" {
    assert_blocked "kubecmd.sh myapp-dev kubectl edit deployment/my-app"
}

@test "guard: blocks kubectl create" {
    assert_blocked "kubecmd.sh myapp-dev kubectl create namespace new-ns"
}

@test "guard: blocks kubectl patch" {
    assert_blocked "kubecmd.sh myapp-dev kubectl patch deployment my-app -p '{\"spec\":{\"replicas\":0}}'"
}

# ── helm write commands (blocked) ──

@test "guard: blocks helm install" {
    assert_blocked "kubecmd.sh myapp-dev helm install my-release my-chart"
}

@test "guard: blocks helm upgrade" {
    assert_blocked "kubecmd.sh myapp-dev helm upgrade my-release my-chart"
}

@test "guard: blocks helm uninstall" {
    assert_blocked "kubecmd.sh myapp-dev helm uninstall my-release"
}

@test "guard: blocks helm rollback" {
    assert_blocked "kubecmd.sh myapp-dev helm rollback my-release 1"
}

# ── kubectl exec (selective) ──

@test "guard: allows kubectl exec with cat" {
    assert_allowed "kubecmd.sh myapp-dev kubectl exec my-pod -- cat /etc/config"
}

@test "guard: allows kubectl exec with env" {
    assert_allowed "kubecmd.sh myapp-dev kubectl exec my-pod -- env"
}

@test "guard: blocks kubectl exec with bash" {
    assert_blocked "kubecmd.sh myapp-dev kubectl exec -it my-pod -- bash"
}

@test "guard: blocks kubectl exec with rm" {
    assert_blocked "kubecmd.sh myapp-dev kubectl exec my-pod -- rm -rf /data"
}

# ── Non-cloud commands (allowed) ──

@test "guard: allows git status" {
    assert_allowed "git status"
}

@test "guard: allows ls" {
    assert_allowed "ls -la"
}

@test "guard: allows jq" {
    assert_allowed "jq '.aws.profiles' ~/.claude/cloud-config.json"
}
