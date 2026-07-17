#!/bin/bash
# post-bash-output-filter.sh — PostToolUse(Bash) hook: compress verbose command output.
# Recognizes adapter command classes (flutter/dart, pnpm/npm/yarn/ng, git diff|log).
# Output over threshold → head + all error/warning lines + tail, emitted via
# hookSpecificOutput.updatedToolOutput (replaces tool output in context, cap 10k chars).
# Not applicable / under threshold → exit 0 silently (original output kept).

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

# Command classes: adapter Implement/Test/PR commands + git diff/log.
# Keyed to ADAPTER.md commands: flutter analyze|test|build, dart format|analyze|test,
# pnpm|npm|yarn [run] lint|test|build, ng lint|test|build.
if ! printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(flutter[[:space:]]+(test|analyze|build)|dart[[:space:]]+(format|analyze|test)|(pnpm|npm|yarn)([[:space:]]+run)?[[:space:]]+(lint|test|build)|ng[[:space:]]+(lint|test|build)|git[[:space:]]+(diff|log))([[:space:]]|$)'; then
  exit 0
fi

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

jq -n --arg out "$RESULT" '{
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    updatedToolOutput: $out
  }
}'
exit 0
