#!/usr/bin/env bats

load test_helper

SETUP_DIR="$REPO_DIR/claude/skills/setup"
RESEARCH_DIR="$REPO_DIR/claude/skills/research"

# ── Schema ──

@test "decision-log: locked schema present in setup references" {
    [ -f "$SETUP_DIR/references/decision-log-schema.md" ]
}

@test "decision-log: schema defines D-NNN records, status, and living-log rules" {
    run grep -qE "D-NNN|D-001" "$SETUP_DIR/references/decision-log-schema.md"
    [ "$status" -eq 0 ]
    run grep -qiE "proposed .* accepted .* superseded|status:" "$SETUP_DIR/references/decision-log-schema.md"
    [ "$status" -eq 0 ]
    run grep -qiE "never delete or renumber|sequential and never reused" "$SETUP_DIR/references/decision-log-schema.md"
    [ "$status" -eq 0 ]
}

# ── /setup scaffolds the log ──

@test "decision-log: /setup scaffolds docs/architecture/decisions/" {
    run grep -qE "docs/architecture/decisions/" "$SETUP_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "decision-log: /setup documents the numbered living-log convention" {
    run grep -qiE "Decision Log" "$SETUP_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}

# ── /research appends to the log ──

@test "decision-log: /research records a decision in the log on status decided" {
    run grep -qE "docs/architecture/decisions/" "$RESEARCH_DIR/SKILL.md"
    [ "$status" -eq 0 ]
    run grep -qiE "D-NNN" "$RESEARCH_DIR/SKILL.md"
    [ "$status" -eq 0 ]
}
