#!/bin/bash
# test-learning-hooks.sh — TDD tests for the instinct learning system hooks.
# Usage: bash templates/devflow/scripts/test-learning-hooks.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(dirname "$SCRIPT_DIR")/hooks"
PASS=0
FAIL=0
ORIG_DIR="$PWD"
T=""

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

assert_not_contains() {
  local label="$1" path="$2" needle="$3"
  if ! grep -q "$needle" "$path" 2>/dev/null; then pass "$label"; else fail "$label" "'$needle' found in $path (should be absent)"; fi
}

assert_str_contains() {
  local label="$1" str="$2" needle="$3"
  if echo "$str" | grep -q "$needle" 2>/dev/null; then pass "$label"; else fail "$label" "'$needle' not in output"; fi
}

assert_str_empty() {
  local label="$1" str="$2"
  if [ -z "$str" ]; then pass "$label"; else fail "$label" "expected empty, got: $str"; fi
}

assert_yaml_field() {
  # Assert a yq expression on a YAML file returns a specific value
  local label="$1" path="$2" expr="$3" want="$4"
  local got
  got=$(yq "$expr" "$path" 2>/dev/null) || got=""
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label" "got='$got' want='$want'"; fi
}

setup() {
  T=$(mktemp -d)
  cd "$T" || { echo "ERROR: cd to tmpdir failed"; exit 1; }
}

teardown() {
  local tmp="$T"
  cd "$ORIG_DIR"
  rm -rf "$tmp"
  T=""
}

# ── Guard: yq required ────────────────────────────────────────────────────────
if ! command -v yq >/dev/null 2>&1; then
  echo "SKIP: yq not installed — install with: brew install yq"
  exit 0
fi

# ── session-start-learnings.sh tests ─────────────────────────────────────────

echo ""
echo "session-start-learnings.sh"
echo "──────────────────────────"

# T1: no files at all → silent exit
setup
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "no files: silent" "$OUTPUT"
teardown

# T2: instincts file exists but empty → silent exit
setup
touch .devflow-instincts.yaml
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "empty instincts: silent" "$OUTPUT"
teardown

# T3: instincts below confidence threshold → silent exit
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: low-conf-thing
    trigger: "when doing something"
    confidence: 0.2
    domain: general
    scope: project
    action: "do the thing"
    evidence: "churn: 1 session"
    ts: "2026-05-26T10:00:00Z"
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "below threshold (0.2): silent" "$OUTPUT"
teardown

# T4: instincts above threshold → valid JSON with priority + message
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: prefer-riverpod
    trigger: "when choosing state management"
    confidence: 0.8
    domain: flutter
    scope: project
    action: "Use Riverpod, never Provider"
    evidence: "manual"
    ts: "2026-05-26T10:00:00Z"
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_contains "instincts present: has priority field" "$OUTPUT" '"priority"'
assert_str_contains "instincts present: has message field" "$OUTPUT" '"message"'
if echo "$OUTPUT" | jq . > /dev/null 2>&1; then
  pass "instincts present: output is valid JSON"
else
  fail "instincts present: output is valid JSON" "jq parse failed: $OUTPUT"
fi
teardown

# T5: instinct content appears in message
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: prefer-riverpod
    trigger: "when choosing state management"
    confidence: 0.8
    domain: flutter
    scope: project
    action: "Use Riverpod, never Provider"
    evidence: "manual"
    ts: "2026-05-26T10:00:00Z"
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_contains "trigger text in output" "$OUTPUT" "state management"
assert_str_contains "action text in output" "$OUTPUT" "Riverpod"
teardown

# T6: migration — old JSONL converted to YAML, old file renamed
setup
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"churn_file",source:"auto",feature:"auth",file:"lib/auth.dart",note:"File edited auth.dart multiple times"}' \
  > .devflow-learnings.jsonl
bash "$HOOKS_DIR/session-start-learnings.sh" > /dev/null
assert_file_exists "migration: instincts file created" ".devflow-instincts.yaml"
assert_file_exists "migration: old file renamed to .migrated" ".devflow-learnings.jsonl.migrated"
assert_file_not_exists "migration: original JSONL removed" ".devflow-learnings.jsonl"
teardown

# T7: migration — migrated instinct has correct fields
setup
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"warning",source:"manual",file:"lib/auth.dart",note:"Auth module is fragile"}' \
  > .devflow-learnings.jsonl
bash "$HOOKS_DIR/session-start-learnings.sh" > /dev/null
assert_contains "migration: trigger references file" ".devflow-instincts.yaml" "when editing"
assert_contains "migration: action from note" ".devflow-instincts.yaml" "Auth module is fragile"
assert_yaml_field "migration: warning type gets confidence 0.7" ".devflow-instincts.yaml" \
  '.instincts[0].confidence' "0.7"
teardown

# T8: migration not re-run if instincts file already exists
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: existing-instinct
    trigger: "when working"
    confidence: 0.9
    domain: general
    scope: project
    action: "keep going"
    evidence: "manual"
    ts: "2026-05-26T10:00:00Z"
YAML
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"lesson",source:"manual",note:"Old lesson"}' \
  > .devflow-learnings.jsonl
bash "$HOOKS_DIR/session-start-learnings.sh" > /dev/null
# JSONL should NOT have been renamed — migration skipped
assert_file_exists "migration skip: JSONL still present when yaml exists" ".devflow-learnings.jsonl"
assert_yaml_field "migration skip: existing instinct untouched" ".devflow-instincts.yaml" \
  '.instincts[0].id' "existing-instinct"
teardown

# T9: max 6 instincts surfaced
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - {id: a, trigger: "t1", confidence: 0.9, domain: general, scope: project, action: "a1", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: b, trigger: "t2", confidence: 0.85, domain: general, scope: project, action: "a2", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: c, trigger: "t3", confidence: 0.8, domain: general, scope: project, action: "a3", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: d, trigger: "t4", confidence: 0.75, domain: general, scope: project, action: "a4", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: e, trigger: "t5", confidence: 0.7, domain: general, scope: project, action: "a5", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: f, trigger: "t6", confidence: 0.65, domain: general, scope: project, action: "a6", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: g, trigger: "t7", confidence: 0.6, domain: general, scope: project, action: "a7", evidence: "x", ts: "2026-01-01T00:00:00Z"}
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
COUNT=$(echo "$OUTPUT" | jq -r '.message' 2>/dev/null | grep -c "^•" || echo 0)
[ "$COUNT" -le 6 ] && pass "max 6 instincts surfaced (got $COUNT)" \
                   || fail "max 6 instincts surfaced" "got $COUNT, want ≤6"
teardown

# ── stop-learn-distill.sh tests ───────────────────────────────────────────────

echo ""
echo "stop-learn-distill.sh"
echo "─────────────────────"

# T10: no observe.jsonl → passthrough, no instincts file
setup
INPUT='{"type":"assistant","message":"hello"}'
OUTPUT=$(printf '%s' "$INPUT" | bash "$HOOKS_DIR/stop-learn-distill.sh")
assert_equals "no observe.jsonl: passthrough stdin" "$OUTPUT" "$INPUT"
assert_file_not_exists "no observe.jsonl: no instincts file" ".devflow-instincts.yaml"
teardown

# T11: below churn threshold → no instincts file created
setup
jq -cn '{ts:"2026-05-03T10:00:01Z",event:"pre",tool:"Write",file:"lib/a.dart"}' >> .devflow-observe.jsonl
jq -cn '{ts:"2026-05-03T10:00:02Z",event:"pre",tool:"Write",file:"lib/a.dart"}' >> .devflow-observe.jsonl
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_file_not_exists "below threshold: no instincts created" ".devflow-instincts.yaml"
teardown

# T12: file edited ≥4 times → instinct stub written to YAML
setup
for i in 1 2 3 4; do
  jq -cn --arg ts "2026-05-03T10:00:0${i}Z" \
    '{ts:$ts,event:"pre",tool:"Write",file:"lib/auth/auth_provider.dart"}' \
    >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_file_exists "churn ≥4: instincts file created" ".devflow-instincts.yaml"
assert_contains "churn ≥4: id contains churn prefix" ".devflow-instincts.yaml" "churn-"
assert_contains "churn ≥4: trigger mentions file" ".devflow-instincts.yaml" "auth_provider"
assert_yaml_field "churn ≥4: initial confidence is 0.5" ".devflow-instincts.yaml" \
  '.instincts[0].confidence' "0.5"
teardown

# T13: churn on .dart file → domain is flutter
setup
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/home.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_yaml_field "dart file: domain is flutter" ".devflow-instincts.yaml" \
  '.instincts[0].domain' "flutter"
teardown

# T14: second churn of same file → confidence bumped, not duplicated
setup
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/auth.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
COUNT=$(yq '.instincts | length' .devflow-instincts.yaml 2>/dev/null)
assert_equals "dedup: only 1 instinct (not 2)" "$COUNT" "1"
CONF=$(yq '.instincts[0].confidence' .devflow-instincts.yaml 2>/dev/null)
if LC_ALL=C awk -v c="$CONF" 'BEGIN {exit (c+0 > 0.5) ? 0 : 1}'; then
  pass "dedup: confidence bumped above 0.5 (got $CONF)"
else
  fail "dedup: confidence bumped" "got $CONF, want > 0.5"
fi
teardown

# T14b: confidence bump under decimal-comma locale (it_IT regression:
# awk printf "%.2f" emitted "0,55" → yq union operator → YAML corrupted)
setup
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/auth.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
echo '{}' | LC_ALL=it_IT.UTF-8 bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
echo '{}' | LC_ALL=it_IT.UTF-8 bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
COUNT=$(yq '.instincts | length' .devflow-instincts.yaml 2>/dev/null)
assert_equals "locale it_IT: YAML valid, still 1 instinct" "$COUNT" "1"
CONF=$(yq '.instincts[0].confidence' .devflow-instincts.yaml 2>/dev/null)
if LC_ALL=C awk -v c="$CONF" 'BEGIN {exit (c+0 > 0.5) ? 0 : 1}'; then
  pass "locale it_IT: confidence bumped above 0.5 (got $CONF)"
else
  fail "locale it_IT: confidence bumped" "got $CONF, want > 0.5"
fi
teardown

# T15: passthrough preserves stdin exactly
setup
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/x.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
INPUT='{"type":"assistant","stop_reason":"end_turn","message":"done"}'
OUTPUT=$(printf '%s' "$INPUT" | bash "$HOOKS_DIR/stop-learn-distill.sh")
assert_equals "passthrough with churn: stdin unchanged" "$OUTPUT" "$INPUT"
teardown

# T16: instincts file gitignored after first write
setup
printf '# project ignores\n' > .gitignore
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/x.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_contains "gitignore: .devflow-instincts.yaml added" ".gitignore" ".devflow-instincts.yaml"
teardown

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

[ "$FAIL" -gt 0 ] && exit 1
exit 0
