#!/usr/bin/env bats

load test_helper

SKILL_DIR="$REPO_DIR/claude/skills/bitbucket-review"
BB="$SKILL_DIR/scripts/bb_review.py"

# ── Skill structure ──

@test "bitbucket-review: SKILL.md exists with frontmatter name" {
    [ -f "$SKILL_DIR/SKILL.md" ]
    run head -5 "$SKILL_DIR/SKILL.md"
    [[ "$output" == *"name: bitbucket-review"* ]]
}

@test "bitbucket-review: reference files present" {
    [ -f "$SKILL_DIR/references/review-rubric.md" ]
    [ -f "$SKILL_DIR/references/bitbucket-api.md" ]
}

# ── Helper script ──

@test "bitbucket-review: helper compiles" {
    run python3 -m py_compile "$BB"
    [ "$status" -eq 0 ]
}

@test "bitbucket-review: meta requires credentials" {
    local home="$BATS_TEST_TMPDIR/empty-home"
    mkdir -p "$home"
    run env -u BITBUCKET_EMAIL -u BITBUCKET_API_TOKEN HOME="$home" python3 "$BB" meta ws/repo 1
    [ "$status" -ne 0 ]
    [[ "$output" == *"BITBUCKET_EMAIL"* ]]
    [[ "$output" == *"--bitbucket-creds"* ]]
}

@test "bitbucket-review: loads creds from ~/.claude/bitbucket-review.env fallback" {
    local home="$BATS_TEST_TMPDIR/home"
    mkdir -p "$home/.claude"
    printf 'export BITBUCKET_EMAIL="x@y.z"\nexport BITBUCKET_API_TOKEN="tok"\n' \
        > "$home/.claude/bitbucket-review.env"
    run env -u BITBUCKET_EMAIL -u BITBUCKET_API_TOKEN HOME="$home" python3 -c "
import importlib.util, os
spec = importlib.util.spec_from_file_location('bb', '$BB')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m._load_creds_file()
print(os.environ.get('BITBUCKET_EMAIL'), os.environ.get('BITBUCKET_API_TOKEN'))
"
    [ "$status" -eq 0 ]
    [[ "$output" == "x@y.z tok" ]]
}

@test "bitbucket-review: diff line-mapper maps added + context, skips deleted" {
    local diff="$BATS_TEST_TMPDIR/sample.diff"
    cat > "$diff" <<'EOF'
diff --git a/src/app.js b/src/app.js
--- a/src/app.js
+++ b/src/app.js
@@ -10,4 +10,6 @@
 const a = 1;
-const b = 2;
+const b = 3;
+const c = 4;
 return a + b;
@@ -40,2 +42,3 @@
 doThing();
+doOther();
EOF
    run python3 "$BB" map --diff "$diff"
    [ "$status" -eq 0 ]
    # new-file lines: 10,11,12,13 (hunk 1) and 42,43 (hunk 2); deleted line consumes none
    [[ "$(echo "$output" | python3 -c 'import sys,json;print(json.load(sys.stdin)["src/app.js"])')" == "[10, 11, 12, 13, 42, 43]" ]]
}
