#!/bin/bash
# test-output-filter.sh — Unit tests for post-bash-output-filter.sh
# Usage: bash templates/devflow/hooks/tests/test-output-filter.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/post-bash-output-filter.sh"
export DEVFLOW_FILTER_STATS=off  # keep repo clean; T8 overrides with temp path
PASS=0
FAIL=0
ERRORS=()

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); ERRORS+=("FAIL: $label"); echo "  FAIL: $label"
  fi
}

# Build a payload with given tool, command, and output string
run_hook() {
  local tool="$1" cmd="$2" output="$3"
  jq -cn --arg tool "$tool" --arg cmd "$cmd" --arg out "$output" \
    '{tool_name: $tool, tool_input: {command: $cmd}, tool_response: $out}' \
    | bash "$HOOK" 2>/dev/null || true
}

# Generate N-line output with error/warning lines sprinkled mid-file
big_output() {
  local n="$1"
  awk -v n="$n" 'BEGIN {
    for (i = 1; i <= n; i++) {
      if (i == 50)       print "Error: something exploded at line 50"
      else if (i == 120) print "Warning: deprecated API at line 120"
      else if (i == 200) print "FAIL: test_widget_renders"
      else               printf("verbose progress line %04d with padding text to add bulk\n", i)
    }
  }'
}

echo "=== test-output-filter.sh ==="
echo ""

# T1: non-Bash tool → passthrough (no output)
echo "--- T1: non-Bash tool ignored ---"
out=$(run_hook "Edit" "flutter test" "$(big_output 300)")
[ -z "$out" ] && assert "Edit tool ignored" pass || assert "Edit tool ignored" fail

# T2: unrecognized command → passthrough
echo "--- T2: unrecognized command ignored ---"
out=$(run_hook "Bash" "ls -la && cat README.md" "$(big_output 300)")
[ -z "$out" ] && assert "ls command ignored" pass || assert "ls command ignored" fail

# T3: recognized command, small output → passthrough
echo "--- T3: under threshold ignored ---"
out=$(run_hook "Bash" "flutter test" "All tests passed!")
[ -z "$out" ] && assert "small output ignored" pass || assert "small output ignored" fail

# T4: recognized command, big output → filtered
echo "--- T4: flutter test large output filtered ---"
out=$(run_hook "Bash" "flutter test test/ --reporter expanded" "$(big_output 300)")
echo "$out" | jq -e '.hookSpecificOutput.updatedToolOutput' >/dev/null 2>&1 \
  && assert "emits updatedToolOutput" pass \
  || assert "emits updatedToolOutput" fail
FILTERED=$(echo "$out" | jq -r '.hookSpecificOutput.updatedToolOutput' 2>/dev/null)
echo "$FILTERED" | grep -q "verbose progress line 0001" \
  && assert "keeps head lines" pass || assert "keeps head lines" fail
echo "$FILTERED" | grep -q "Error: something exploded at line 50" \
  && assert "keeps error line" pass || assert "keeps error line" fail
echo "$FILTERED" | grep -q "Warning: deprecated API at line 120" \
  && assert "keeps warning line" pass || assert "keeps warning line" fail
echo "$FILTERED" | grep -q "FAIL: test_widget_renders" \
  && assert "keeps FAIL line" pass || assert "keeps FAIL line" fail
echo "$FILTERED" | grep -q "verbose progress line 0300" \
  && assert "keeps tail lines" pass || assert "keeps tail lines" fail
echo "$FILTERED" | grep -q "\[devflow-filter\] kept" \
  && assert "marker line present" pass || assert "marker line present" fail
[ "${#FILTERED}" -lt 10000 ] \
  && assert "output under 10k cap (${#FILTERED} chars)" pass \
  || assert "output under 10k cap (${#FILTERED} chars)" fail
echo "$FILTERED" | grep -q "verbose progress line 0150" \
  && assert "drops mid-file noise" fail || assert "drops mid-file noise" pass

# T5: other adapter command classes recognized
echo "--- T5: command class coverage ---"
for cmd in "pnpm test -- --watchAll=false" "pnpm run lint" "npm run build" "ng test" "dart analyze" "git diff HEAD~1"; do
  out=$(run_hook "Bash" "$cmd" "$(big_output 300)")
  echo "$out" | jq -e '.hookSpecificOutput.updatedToolOutput' >/dev/null 2>&1 \
    && assert "recognizes: $cmd" pass \
    || assert "recognizes: $cmd" fail
done

# T5b: generic dev-tool command classes recognized
echo "--- T5b: generic command class coverage ---"
for cmd in "pytest -q tests/" "python -m pytest tests/unit" "go test ./..." "cargo test --workspace" "cargo clippy" "./gradlew build" "mvn package" "docker build -t app ." "docker compose up -d" "tsc --noEmit" "eslint src/" "npx jest --ci" "npx vitest run"; do
  out=$(run_hook "Bash" "$cmd" "$(big_output 300)")
  echo "$out" | jq -e '.hookSpecificOutput.updatedToolOutput' >/dev/null 2>&1 \
    && assert "recognizes: $cmd" pass \
    || assert "recognizes: $cmd" fail
done

# T5c: near-miss commands stay unfiltered
echo "--- T5c: near-miss commands ignored ---"
for cmd in "docker ps" "go version" "cat gradle.properties"; do
  out=$(run_hook "Bash" "$cmd" "$(big_output 300)")
  [ -z "$out" ] && assert "ignores: $cmd" pass || assert "ignores: $cmd" fail
done

# T5d: DEVFLOW_FILTER_EXTRA extends command classes
echo "--- T5d: env-extended command class ---"
out=$(DEVFLOW_FILTER_EXTRA='(^|[[:space:]])mytool[[:space:]]+build' run_hook "Bash" "mytool build --release" "$(big_output 300)")
echo "$out" | jq -e '.hookSpecificOutput.updatedToolOutput' >/dev/null 2>&1 \
  && assert "extra class recognized with env" pass \
  || assert "extra class recognized with env" fail
out=$(run_hook "Bash" "mytool build --release" "$(big_output 300)")
[ -z "$out" ] && assert "extra class ignored without env" pass \
  || assert "extra class ignored without env" fail

# T6: object-shaped tool_response ({stdout, stderr})
echo "--- T6: object tool_response ---"
out=$(jq -cn --arg out "$(big_output 300)" \
  '{tool_name: "Bash", tool_input: {command: "flutter test"}, tool_response: {stdout: $out, stderr: "Error: from stderr"}}' \
  | bash "$HOOK" 2>/dev/null || true)
FILTERED=$(echo "$out" | jq -r '.hookSpecificOutput.updatedToolOutput' 2>/dev/null)
[ -n "$FILTERED" ] && [ "$FILTERED" != "null" ] \
  && assert "object response handled" pass || assert "object response handled" fail
echo "$FILTERED" | grep -q "Error: from stderr" \
  && assert "stderr merged and kept" pass || assert "stderr merged and kept" fail

# T7: giant single-line output capped by chars
echo "--- T7: char cap on few huge lines ---"
HUGE=$(awk 'BEGIN { s=""; for (i=0;i<3000;i++) s = s "xxxxxxxxxx"; print s; print s }')
out=$(run_hook "Bash" "pnpm build" "$HUGE")
FILTERED=$(echo "$out" | jq -r '.hookSpecificOutput.updatedToolOutput' 2>/dev/null)
[ -n "$FILTERED" ] && [ "${#FILTERED}" -lt 10000 ] \
  && assert "huge lines capped under 10k (${#FILTERED} chars)" pass \
  || assert "huge lines capped under 10k (${#FILTERED:-0} chars)" fail

# T8: savings telemetry appended to stats file
echo "--- T8: stats telemetry ---"
STATS="$(mktemp -d)/stats.jsonl"
out=$(DEVFLOW_FILTER_STATS="$STATS" run_hook "Bash" "flutter test" "$(big_output 300)")
[ -f "$STATS" ] && assert "stats file created" pass || assert "stats file created" fail
jq -e '.raw_chars > 0 and .kept_chars > 0 and .kept_chars < .raw_chars and .raw_lines == 300 and (.cmd | startswith("flutter test"))' \
  "$STATS" >/dev/null 2>&1 \
  && assert "stats line has expected fields" pass \
  || assert "stats line has expected fields" fail
COUNT=$(wc -l < "$STATS" | tr -d ' ')
[ "$COUNT" = "1" ] && assert "one line per filtered command" pass || assert "one line per filtered command" fail
out=$(run_hook "Bash" "flutter test" "$(big_output 300)")
COUNT=$(wc -l < "$STATS" | tr -d ' ')
[ "$COUNT" = "1" ] && assert "DEVFLOW_FILTER_STATS=off: no append" pass \
  || assert "DEVFLOW_FILTER_STATS=off: no append" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
