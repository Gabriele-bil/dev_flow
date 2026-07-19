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
