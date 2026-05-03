#!/bin/bash
# test-learning-hooks.sh — TDD tests for the learning system hooks.
# Usage: bash devflow/scripts/test-learning-hooks.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(dirname "$SCRIPT_DIR")/hooks"
PASS=0
FAIL=0
ORIG_DIR="$PWD"
T=""  # current test tmpdir (global, set by setup)

# ── helpers ──────────────────────────────────────────────────────────────────

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

assert_equals() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label" "got='$got' want='$want'"; fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label" "file not found: $path"; fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then pass "$label"; else fail "$label" "unexpected file: $path"; fi
}

assert_contains() {
  local label="$1" path="$2" needle="$3"
  if grep -q "$needle" "$path" 2>/dev/null; then pass "$label"; else fail "$label" "'$needle' not in $path"; fi
}

assert_str_contains() {
  local label="$1" str="$2" needle="$3"
  if echo "$str" | grep -q "$needle" 2>/dev/null; then pass "$label"; else fail "$label" "'$needle' not in output"; fi
}

assert_str_empty() {
  local label="$1" str="$2"
  if [ -z "$str" ]; then pass "$label"; else fail "$label" "expected empty, got: $str"; fi
}

# setup: creates isolated tmpdir, cds into it; sets global T
setup() {
  T=$(mktemp -d)
  cd "$T" || { echo "ERROR: cd to tmpdir failed"; exit 1; }
}

# teardown: removes tmpdir, restores ORIG_DIR; clears T
teardown() {
  local tmp="$T"
  cd "$ORIG_DIR"
  rm -rf "$tmp"
  T=""
}

# ── stop-learn-distill.sh tests ───────────────────────────────────────────────

echo ""
echo "stop-learn-distill.sh"
echo "─────────────────────"

# 1: no observe.jsonl → stdin passthrough, no learnings created
setup
INPUT='{"type":"assistant","message":"hello"}'
OUTPUT=$(printf '%s' "$INPUT" | bash "$HOOKS_DIR/stop-learn-distill.sh")
assert_equals "no observe.jsonl: passthrough stdin" "$OUTPUT" "$INPUT"
assert_file_not_exists "no observe.jsonl: no learnings written" ".devflow-learnings.jsonl"
teardown

# 2: observe.jsonl present but below churn threshold → no learnings
setup
jq -cn '{ts:"2026-05-03T10:00:01Z",event:"pre",tool:"Write",file:"lib/a.dart",step:"devflow.implement",feature:"001_test"}' >> .devflow-observe.jsonl
jq -cn '{ts:"2026-05-03T10:00:02Z",event:"post",tool:"Write",step:"devflow.implement",feature:"001_test"}' >> .devflow-observe.jsonl
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_file_not_exists "below threshold: no learnings" ".devflow-learnings.jsonl"
teardown

# 3: file edited ≥4 times → churn_file learning written
setup
for i in 1 2 3 4; do
  jq -cn \
    --arg ts "2026-05-03T10:00:0${i}Z" \
    '{ts:$ts,event:"pre",tool:"Write",file:"lib/auth/auth_provider.dart",step:"devflow.implement",feature:"003_auth"}' \
    >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_file_exists "churn ≥4: learnings file created" ".devflow-learnings.jsonl"
assert_contains "churn ≥4: type is churn_file" ".devflow-learnings.jsonl" "churn_file"
assert_contains "churn ≥4: file path recorded" ".devflow-learnings.jsonl" "auth_provider.dart"
teardown

# 4: churn learning not written twice (dedup)
setup
for i in 1 2 3 4; do
  jq -cn \
    --arg ts "2026-05-03T10:00:0${i}Z" \
    '{ts:$ts,event:"pre",tool:"Write",file:"lib/auth/auth_provider.dart",step:"devflow.implement",feature:"003_auth"}' \
    >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
COUNT=$(grep -c "churn_file" .devflow-learnings.jsonl 2>/dev/null || echo "0")
assert_equals "churn dedup: written only once" "$COUNT" "1"
teardown

# 5: passthrough preserves stdin exactly (with churn present)
setup
for i in 1 2 3 4; do
  jq -cn '{ts:"2026-05-03T10:00:01Z",event:"pre",tool:"Write",file:"lib/x.dart",step:"devflow.implement",feature:"001_test"}' \
    >> .devflow-observe.jsonl
done
INPUT='{"type":"assistant","stop_reason":"end_turn","message":"done"}'
OUTPUT=$(printf '%s' "$INPUT" | bash "$HOOKS_DIR/stop-learn-distill.sh")
assert_equals "passthrough with churn: stdin unchanged" "$OUTPUT" "$INPUT"
teardown

# 6: learnings file is gitignored after first write
setup
printf '# project ignores\n' > .gitignore
for i in 1 2 3 4; do
  jq -cn '{ts:"2026-05-03T10:00:01Z",event:"pre",tool:"Write",file:"lib/x.dart",step:"devflow.implement",feature:"001_test"}' \
    >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_contains "gitignore: entry added" ".gitignore" ".devflow-learnings.jsonl"
teardown

# ── session-start-learnings.sh tests ─────────────────────────────────────────

echo ""
echo "session-start-learnings.sh"
echo "──────────────────────────"

# 7: no learnings file → no output (silent)
setup
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "no learnings: silent" "$OUTPUT"
teardown

# 8: empty learnings file → no output
setup
touch .devflow-learnings.jsonl
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "empty learnings: silent" "$OUTPUT"
teardown

# 9: learnings present → JSON with priority + message fields
setup
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"churn_file",source:"auto",feature:"003_auth",file:"lib/auth/auth_provider.dart",note:"File edited auth_provider.dart multiple times"}' \
  > .devflow-learnings.jsonl
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_contains "learnings present: priority field" "$OUTPUT" "priority"
assert_str_contains "learnings present: message field" "$OUTPUT" "message"
teardown

# 10: learnings present → output is valid JSON
setup
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"churn_file",source:"auto",feature:"003_auth",file:"lib/auth.dart",note:"test"}' \
  > .devflow-learnings.jsonl
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
if echo "$OUTPUT" | jq . > /dev/null 2>&1; then
  pass "learnings present: output is valid JSON"
else
  fail "learnings present: output is valid JSON" "jq parse failed: $OUTPUT"
fi
teardown

# 11: matching feature → note content surfaced
setup
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"churn_file",source:"auto",feature:"003_auth",file:"lib/auth.dart",note:"Auth provider churn"}' \
  > .devflow-learnings.jsonl
jq -n '{next_step:"devflow.implement",feature:"003_auth"}' > .devflow-state.json
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_contains "feature match: note surfaced" "$OUTPUT" "auth"
teardown

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

[ "$FAIL" -gt 0 ] && exit 1
exit 0
