#!/bin/bash
# post-bash-output-filter.sh — PostToolUse(Bash) hook: compress verbose command output.
# Recognizes adapter command classes (flutter/dart, pnpm/npm/yarn/ng, git diff|log)
# plus generic dev-tool classes (pytest, go, cargo, gradle/mvn, docker build|compose,
# tsc, eslint, jest, vitest). Extend without editing this script:
# DEVFLOW_FILTER_EXTRA=<ERE> — extra command-class regex, ORed with the built-in set.
# Output over threshold → head + all error/warning lines + tail, emitted via
# hookSpecificOutput.updatedToolOutput (replaces tool output in context, cap 10k chars).
# Not applicable / under threshold → exit 0 silently (original output kept).
# Savings telemetry: each filtered command appends one JSONL line to
# .devflow-filter-stats.jsonl (DEVFLOW_FILTER_STATS=<path> overrides, =off disables).
# Read by devflow.status → "Filter savings" line.
# Structured test-summary: for pytest/jest/vitest/flutter-test/go-test/cargo-test/
# ng-test commands, best-effort parses the framework's own pass/fail summary line
# and overwrites .devflow-test-summary.json (latest run wins — not a JSONL log;
# DEVFLOW_TEST_SUMMARY=<path> overrides, =off disables). Runs independent of the
# threshold check above (a short "all passed" run still gets recorded). Read by
# devflow.test Step 3-6 as a structured signal instead of re-deriving pass/fail
# counts from raw scrollback.

# ── Thresholds (single place — override via env) ─────────────────────────────
THRESHOLD_CHARS="${DEVFLOW_FILTER_THRESHOLD:-2000}"  # below this: no filtering
HEAD_LINES="${DEVFLOW_FILTER_HEAD:-15}"              # always keep first N lines
TAIL_LINES="${DEVFLOW_FILTER_TAIL:-10}"              # always keep last N lines
MAX_SIGNAL_LINES="${DEVFLOW_FILTER_SIGNALS:-40}"     # cap on kept error/warning lines
MAX_OUTPUT_CHARS=9000                                # hard cap: updatedToolOutput limit is 10000

command -v jq >/dev/null 2>&1 || exit 0

RAW=$(cat)
[ -z "$RAW" ] && exit 0

TOOL=$(printf '%s' "$RAW" | jq -r '.tool_name // .tool_use.name // empty' 2>/dev/null)
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(printf '%s' "$RAW" | jq -r '.tool_input.command // .tool_use.input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Command classes: adapter Implement/Test/PR commands + git diff/log + generic dev tools.
# Keyed to ADAPTER.md commands: flutter analyze|test|build, dart format|analyze|test,
# pnpm|npm|yarn [run] lint|test|build, ng lint|test|build.
# Generic: pytest, go test|build|vet, cargo test|build|check|clippy, gradle/gradlew/mvn,
# docker build|compose, tsc, eslint, jest, vitest (bare names also match npx/python -m forms).
CLASS_RE='(^|[;&|[:space:]])(flutter[[:space:]]+(test|analyze|build)|dart[[:space:]]+(format|analyze|test)|(pnpm|npm|yarn)([[:space:]]+run)?[[:space:]]+(lint|test|build)|ng[[:space:]]+(lint|test|build)|git[[:space:]]+(diff|log)|pytest|go[[:space:]]+(test|build|vet)|cargo[[:space:]]+(test|build|check|clippy)|(\./)?gradlew|gradle|mvn|docker[[:space:]]+(build|compose)|tsc|eslint|jest|vitest)([[:space:]]|$)'
MATCHED=0
printf '%s' "$CMD" | grep -qE "$CLASS_RE" && MATCHED=1
if [ "$MATCHED" -eq 0 ] && [ -n "${DEVFLOW_FILTER_EXTRA:-}" ]; then
  printf '%s' "$CMD" | grep -qE "$DEVFLOW_FILTER_EXTRA" 2>/dev/null && MATCHED=1
fi
[ "$MATCHED" -eq 1 ] || exit 0

# Tool output may be a plain string or an object ({stdout, stderr, ...}).
OUTPUT=$(printf '%s' "$RAW" | jq -r '
  (.tool_response // .tool_result // "") as $r |
  if ($r | type) == "string" then $r
  elif ($r | type) == "object" then
    ([$r.stdout?, $r.stderr?, $r.output?]
     | map(select(. != null and . != "")) | join("\n"))
  else "" end' 2>/dev/null)
[ -z "$OUTPUT" ] && exit 0

# ── Structured test-summary extraction (runs regardless of threshold) ────────
SUMMARY_FILE="${DEVFLOW_TEST_SUMMARY:-.devflow-test-summary.json}"
if [ "$SUMMARY_FILE" != "off" ]; then
  T_FRAMEWORK="" T_PASSED="" T_FAILED="" T_SKIPPED=""

  if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])pytest([[:space:]]|$)|python[[:space:]]+-m[[:space:]]+pytest'; then
    T_LINE=$(printf '%s\n' "$OUTPUT" | grep -E '=+.*(passed|failed|error)' | tail -1)
    if [ -n "$T_LINE" ]; then
      T_FRAMEWORK="pytest"
      T_PASSED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ passed'  | grep -oE '[0-9]+' | head -1)
      T_FAILED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ failed'  | grep -oE '[0-9]+' | head -1)
      T_SKIPPED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ skipped' | grep -oE '[0-9]+' | head -1)
    fi
  elif printf '%s' "$CMD" | grep -qE 'vitest'; then
    T_LINE=$(printf '%s\n' "$OUTPUT" | grep -E '^ *Tests +' | tail -1)
    if [ -n "$T_LINE" ]; then
      T_FRAMEWORK="vitest"
      T_PASSED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1)
      T_FAILED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1)
      T_SKIPPED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ skipped' | grep -oE '[0-9]+' | head -1)
    fi
  elif printf '%s' "$CMD" | grep -qE 'jest'; then
    T_LINE=$(printf '%s\n' "$OUTPUT" | grep -E '^Tests:' | tail -1)
    if [ -n "$T_LINE" ]; then
      T_FRAMEWORK="jest"
      T_PASSED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1)
      T_FAILED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1)
      T_SKIPPED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ skipped' | grep -oE '[0-9]+' | head -1)
    fi
  elif printf '%s' "$CMD" | grep -qE '(^|[[:space:]])flutter[[:space:]]+test'; then
    T_LINE=$(printf '%s\n' "$OUTPUT" | grep -oE '\+[0-9]+( -[0-9]+)?' | tail -1)
    if [ -n "$T_LINE" ]; then
      T_FRAMEWORK="flutter_test"
      T_PASSED=$(printf '%s' "$T_LINE" | grep -oE '^\+[0-9]+' | grep -oE '[0-9]+')
      T_FAILED=$(printf '%s' "$T_LINE" | grep -oE ' -[0-9]+' | grep -oE '[0-9]+')
    fi
  elif printf '%s' "$CMD" | grep -qE '(^|[[:space:]])go[[:space:]]+(test|vet)'; then
    T_OK=$(printf '%s\n' "$OUTPUT" | grep -cE '^ok[[:space:]]' 2>/dev/null; true)
    T_FAIL=$(printf '%s\n' "$OUTPUT" | grep -cE '^FAIL[[:space:]]' 2>/dev/null; true)
    if [ "${T_OK:-0}" -gt 0 ] || [ "${T_FAIL:-0}" -gt 0 ]; then
      T_FRAMEWORK="go_test"
      T_PASSED="${T_OK:-0}"
      T_FAILED="${T_FAIL:-0}"
    fi
  elif printf '%s' "$CMD" | grep -qE '(^|[[:space:]])cargo[[:space:]]+test'; then
    T_LINE=$(printf '%s\n' "$OUTPUT" | grep -E '^test result:' | tail -1)
    if [ -n "$T_LINE" ]; then
      T_FRAMEWORK="cargo_test"
      T_PASSED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1)
      T_FAILED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1)
    fi
  elif printf '%s' "$CMD" | grep -qE '(^|[[:space:]])ng[[:space:]]+test'; then
    T_LINE=$(printf '%s\n' "$OUTPUT" | grep -E 'Executed [0-9]+ of [0-9]+' | tail -1)
    if [ -n "$T_LINE" ]; then
      T_FRAMEWORK="karma"
      T_EXECUTED=$(printf '%s' "$T_LINE" | grep -oE 'Executed [0-9]+' | grep -oE '[0-9]+')
      T_TOTAL=$(printf '%s' "$T_LINE" | grep -oE 'of [0-9]+' | grep -oE '[0-9]+')
      T_FAILED=$(printf '%s' "$T_LINE" | grep -oE '[0-9]+ FAILED' | grep -oE '[0-9]+' | head -1)
      [ -z "$T_FAILED" ] && T_FAILED=0
      [ -n "$T_EXECUTED" ] && T_PASSED=$(( T_EXECUTED - T_FAILED ))
      [ -n "$T_TOTAL" ] && [ -n "$T_EXECUTED" ] && T_SKIPPED=$(( T_TOTAL - T_EXECUTED ))
    fi
  fi

  if [ -n "$T_FRAMEWORK" ] && { [ -n "$T_PASSED" ] || [ -n "$T_FAILED" ]; } && command -v jq >/dev/null 2>&1; then
    [ -z "$T_PASSED" ]  && T_PASSED=0
    [ -z "$T_FAILED" ]  && T_FAILED=0
    [ -z "$T_SKIPPED" ] && T_SKIPPED=0
    jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)" \
      --arg framework "$T_FRAMEWORK" --arg cmd "$(printf '%s' "$CMD" | tr '\n' ' ' | head -c 120)" \
      --argjson passed "$T_PASSED" --argjson failed "$T_FAILED" --argjson skipped "$T_SKIPPED" \
      '{ts:$ts, framework:$framework, cmd:$cmd, passed:$passed, failed:$failed, skipped:$skipped}' \
      > "$SUMMARY_FILE" 2>/dev/null || true
    if [ -f .gitignore ] && ! grep -qF ".devflow-test-summary.json" .gitignore 2>/dev/null; then
      printf '\n# devflow test summary\n.devflow-test-summary.json\n' >> .gitignore 2>/dev/null || true
    fi
  fi
fi

CHARS=${#OUTPUT}
[ "$CHARS" -le "$THRESHOLD_CHARS" ] && exit 0

TOTAL=$(printf '%s\n' "$OUTPUT" | wc -l | tr -d ' ')

FILTERED=$(printf '%s\n' "$OUTPUT" | awk \
  -v head="$HEAD_LINES" -v tail="$TAIL_LINES" -v total="$TOTAL" -v maxsig="$MAX_SIGNAL_LINES" '
  BEGIN { sig = 0; skipped = 0 }
  {
    keep = 0
    if (NR <= head) keep = 1
    else if (NR > total - tail) keep = 1
    else if ($0 ~ /[Ee]rror|ERROR|[Ww]arning|WARN|FAIL|[Ff]ailed|✗|✘|[Ee]xception/ && sig < maxsig) { keep = 1; sig++ }
    if (keep) {
      if (skipped > 0) { printf("  … [%d lines skipped] …\n", skipped); skipped = 0 }
      print
    } else skipped++
  }
  END { if (skipped > 0) printf("  … [%d lines skipped] …\n", skipped) }')

KEPT=$(printf '%s\n' "$FILTERED" | grep -cv '^  … \[' 2>/dev/null; true)
KEPT=$(printf '%s' "$KEPT" | tr -d '[:space:]')
[ -z "$KEPT" ] && KEPT=0

# Reserve room for the marker line, then append it (never truncated away).
FILTERED=$(printf '%s' "$FILTERED" | head -c $((MAX_OUTPUT_CHARS - 120)))
RESULT="$FILTERED
[devflow-filter] kept $KEPT of $TOTAL lines ($CHARS chars raw)"

# ── Savings telemetry (one JSONL line per filtered command) ──────────────────
STATS_FILE="${DEVFLOW_FILTER_STATS:-.devflow-filter-stats.jsonl}"
if [ "$STATS_FILE" != "off" ]; then
  if [ ! -f "$STATS_FILE" ] && [ -f .gitignore ] \
     && ! grep -qF ".devflow-filter-stats.jsonl" .gitignore 2>/dev/null; then
    printf '\n# devflow filter savings\n.devflow-filter-stats.jsonl\n' >> .gitignore 2>/dev/null || true
  fi
  CMD_HEAD=$(printf '%s' "$CMD" | tr '\n' ' ' | head -c 60)
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)" \
    --arg cmd "$CMD_HEAD" \
    --argjson raw "$CHARS" --argjson kept "${#RESULT}" \
    --argjson raw_lines "$TOTAL" --argjson kept_lines "$KEPT" \
    '{ts:$ts,cmd:$cmd,raw_chars:$raw,kept_chars:$kept,raw_lines:$raw_lines,kept_lines:$kept_lines}' \
    >> "$STATS_FILE" 2>/dev/null || true
fi

jq -n --arg out "$RESULT" '{
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    updatedToolOutput: $out
  }
}'
exit 0
