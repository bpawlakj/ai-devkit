#!/usr/bin/env bats

load test_helper

# Tests the inline safety-guard PreToolUse hook in claude/settings.template.json
# by extracting the hook command and piping tool-input JSON through it.
# Exit 2 = blocked, exit 0 = allowed.

setup() {
    GUARD=$(jq -r '.hooks.PreToolUse[].hooks[].command' "$REPO_DIR/claude/settings.template.json" | grep -m1 'no-verify')
    [ -n "$GUARD" ]
}

run_guard() {
    echo "{\"command\":\"$1\"}" | bash -c "$GUARD"
}

# ── Blocked: pre-existing patterns still hold ──

@test "safety-guard: blocks git push --force" {
    run run_guard "git push --force origin main"
    [ "$status" -eq 2 ]
}

@test "safety-guard: blocks git reset --hard" {
    run run_guard "git reset --hard HEAD~1"
    [ "$status" -eq 2 ]
}

# ── Blocked: T-006 git patterns ──

@test "safety-guard: blocks git clean -fd" {
    run run_guard "git clean -fd"
    [ "$status" -eq 2 ]
}

@test "safety-guard: blocks git clean -xdf variant" {
    run run_guard "git clean -xdf"
    [ "$status" -eq 2 ]
}

@test "safety-guard: blocks git branch -D" {
    run run_guard "git branch -D feature/foo"
    [ "$status" -eq 2 ]
}

@test "safety-guard: blocks git checkout ." {
    run run_guard "git checkout ."
    [ "$status" -eq 2 ]
}

@test "safety-guard: blocks git checkout -- ." {
    run run_guard "git checkout -- ."
    [ "$status" -eq 2 ]
}

# ── Allowed: safe forms pass through ──

@test "safety-guard: allows git push --force-with-lease" {
    run run_guard "git push --force-with-lease origin main"
    [ "$status" -eq 0 ]
}

@test "safety-guard: allows plain git push" {
    run run_guard "git push origin main"
    [ "$status" -eq 0 ]
}

@test "safety-guard: allows git clean dry-run (-n)" {
    run run_guard "git clean -nd"
    [ "$status" -eq 0 ]
}

@test "safety-guard: allows git branch -d (lowercase)" {
    run run_guard "git branch -d merged-branch"
    [ "$status" -eq 0 ]
}

@test "safety-guard: allows git checkout <branch>" {
    run run_guard "git checkout main"
    [ "$status" -eq 0 ]
}

@test "safety-guard: allows git checkout .env file path" {
    run run_guard "git checkout .gitignore"
    [ "$status" -eq 0 ]
}
