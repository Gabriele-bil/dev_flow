#!/bin/bash
# devflow observe hook — continuous learning observer
# Captures PreToolUse / PostToolUse events to .devflow-observe.jsonl for pattern analysis.
# Usage:
#   bash .../observe.sh pre   — PreToolUse  (before tool call)
#   bash .../observe.sh post  — PostToolUse (after tool call)
# This hook is async; output on stdout is ignored by the runtime. Exit 0 always.

set -euo pipefail

EVENT="${1:-}"
LOG_FILE=".devflow-observe.jsonl"
LEARNINGS_FILE=".devflow-learnings.jsonl"
STATE_FILE=".devflow-state.json"
MAX_LINES=500
RETRY_THRESHOLD=3
RETRY_WINDOW=20

# Guard: jq required
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Guard: event must be pre or post
if [ "$EVENT" != "pre" ] && [ "$EVENT" != "post" ] && [ "$EVENT" != "stop" ]; then
  exit 0
fi

# Read all stdin upfront so we don't leave stdin open
RAW=$(cat) || true
[ -z "$RAW" ] && exit 0

# Timestamp
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

# Extract tool name from stdin
TOOL=$(printf '%s' "$RAW" | jq -r '.tool_use.name // empty' 2>/dev/null) || true

# Extract session id
SESSION=$(printf '%s' "$RAW" | jq -r '.session_id // empty' 2>/dev/null) || true

# ------------------------------------------------------------------
# Read optional devflow state
# ------------------------------------------------------------------
STEP=""
FEATURE=""
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null) || true
fi

# ------------------------------------------------------------------
# Log rotation: if log exceeds MAX_LINES, rotate
# ------------------------------------------------------------------
if [ -f "$LOG_FILE" ]; then
  LINE_COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d '[:space:]') || true
  if [ -n "$LINE_COUNT" ] && [ "$LINE_COUNT" -ge "$MAX_LINES" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null || true
  fi
fi

# ------------------------------------------------------------------
# Build and append JSONL entry
# ------------------------------------------------------------------
if [ "$EVENT" = "pre" ]; then
  # For pre events: include optional file (only for Write/Edit tools)
  FILE_PATH=""
  if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
    FILE_PATH=$(printf '%s' "$RAW" | jq -r '.tool_use.input.file_path // empty' 2>/dev/null) || true
  fi

  # Build JSON incrementally using jq to ensure proper escaping
  jq -cn \
    --arg ts      "$TS"      \
    --arg event   "$EVENT"   \
    --arg tool    "$TOOL"    \
    --arg session "$SESSION" \
    --arg step    "$STEP"    \
    --arg feature "$FEATURE" \
    --arg file    "$FILE_PATH" \
    '{
      ts:      $ts,
      event:   $event,
      tool:    $tool,
      session: (if $session != "" then $session else empty end),
      step:    (if $step    != "" then $step    else empty end),
      feature: (if $feature != "" then $feature else empty end),
      file:    (if $file    != "" then $file    else empty end)
    } | with_entries(select(.value != null))' \
    >> "$LOG_FILE" 2>/dev/null || true

elif [ "$EVENT" = "post" ]; then
  # For post events: include is_error from tool_result
  IS_ERROR=$(printf '%s' "$RAW" | jq '.tool_result.is_error // empty' 2>/dev/null) || true

  jq -cn \
    --arg  ts       "$TS"      \
    --arg  event    "$EVENT"   \
    --arg  tool     "$TOOL"    \
    --arg  session  "$SESSION" \
    --argjson is_error "${IS_ERROR:-null}" \
    '{
      ts:       $ts,
      event:    $event,
      tool:     $tool,
      session:  (if $session != "" then $session else empty end),
      is_error: (if $is_error != null then $is_error else empty end)
    } | with_entries(select(.value != null))' \
    >> "$LOG_FILE" 2>/dev/null || true

  # ----------------------------------------------------------------
  # Strategic-compact counter: track cumulative tool calls per session
  # ----------------------------------------------------------------
  COMPACT_THRESHOLD="${DEVFLOW_COMPACT_THRESHOLD:-50}"

  # Read current counter state (defaults if absent or malformed)
  STORED_COUNT=0
  STORED_SESSION=""
  STORED_LAST_STEP=""
  if [ -f "$STATE_FILE" ]; then
    STORED_COUNT=$(jq -r '.tool_call_count // 0'            "$STATE_FILE" 2>/dev/null) || STORED_COUNT=0
    STORED_SESSION=$(jq -r '.last_session_id // empty'      "$STATE_FILE" 2>/dev/null) || STORED_SESSION=""
    STORED_LAST_STEP=$(jq -r '.last_observed_step // empty' "$STATE_FILE" 2>/dev/null) || STORED_LAST_STEP=""
  fi

  # Session reset: new session_id means fresh context — reset counter
  if [ -n "$SESSION" ] && [ "$SESSION" != "$STORED_SESSION" ]; then
    STORED_COUNT=0
    STORED_LAST_STEP=""
  fi

  NEW_COUNT=$(( STORED_COUNT + 1 ))

  # Atomic state write: merge counter fields into existing state
  STATE_TMP="${STATE_FILE}.tmp"
  if [ -f "$STATE_FILE" ]; then
    jq \
      --argjson count "$NEW_COUNT" \
      --arg session   "$SESSION" \
      --arg last_step "$STORED_LAST_STEP" \
      '. + {tool_call_count: $count, last_session_id: $session, last_observed_step: $last_step}' \
      "$STATE_FILE" > "$STATE_TMP" 2>/dev/null \
      && mv "$STATE_TMP" "$STATE_FILE" 2>/dev/null || true
  else
    jq -cn \
      --argjson count "$NEW_COUNT" \
      --arg session   "$SESSION" \
      --arg last_step "$STORED_LAST_STEP" \
      '{tool_call_count: $count, last_session_id: $session, last_observed_step: $last_step}' \
      > "$STATE_TMP" 2>/dev/null \
      && mv "$STATE_TMP" "$STATE_FILE" 2>/dev/null || true
  fi

  # Step-change advisory: if pipeline step changed AND above threshold → advise
  CURRENT_STEP="$STEP"
  if [ -n "$CURRENT_STEP" ] \
      && [ "$CURRENT_STEP" != "$STORED_LAST_STEP" ] \
      && [ -n "$STORED_LAST_STEP" ] \
      && [ "$NEW_COUNT" -ge "$COMPACT_THRESHOLD" ] 2>/dev/null; then
    printf '⚡ devflow: ~%s tool calls this session — consider /compact to keep context fresh.\n' \
      "$NEW_COUNT" >&2
  fi

  # Update last_observed_step to current step (only if step is non-empty and changed)
  if [ -n "$CURRENT_STEP" ] && [ "$CURRENT_STEP" != "$STORED_LAST_STEP" ]; then
    if [ -f "$STATE_FILE" ]; then
      jq --arg step "$CURRENT_STEP" '.last_observed_step = $step' \
        "$STATE_FILE" > "$STATE_TMP" 2>/dev/null \
        && mv "$STATE_TMP" "$STATE_FILE" 2>/dev/null || true
    fi
  fi

  # ----------------------------------------------------------------
  # Retry-loop detection: count consecutive trailing post events
  # where tool == $TOOL AND is_error == true.
  # If count >= RETRY_THRESHOLD, append a retry_loop learning.
  # ----------------------------------------------------------------
  if [ -n "$TOOL" ] && [ "${IS_ERROR:-}" = "true" ]; then
    CONSEC=$(
      tail -n "$RETRY_WINDOW" "$LOG_FILE" 2>/dev/null \
      | jq -r 'select(.event=="post") | [.tool, (.is_error | tostring)] | join(":")' 2>/dev/null \
      | awk -v target="${TOOL}:true" '
          { lines[NR] = $0 }
          END {
            count = 0
            for (i = NR; i >= 1; i--) {
              if (lines[i] == target) count++
              else break
            }
            print count
          }
        '
    ) || true

    if [ -n "$CONSEC" ] && [ "$CONSEC" -ge "$RETRY_THRESHOLD" ] 2>/dev/null; then
      # Dedup: skip if same (tool, session) already recorded as retry_loop
      ALREADY=""
      if [ -f "$LEARNINGS_FILE" ]; then
        ALREADY=$(
          jq -r --arg t "$TOOL" --arg s "$SESSION" \
            'select(.type=="retry_loop" and .tool==$t and .session==$s) | .tool' \
            "$LEARNINGS_FILE" 2>/dev/null | head -1
        ) || true
      fi

      if [ -z "$ALREADY" ]; then
        jq -cn \
          --arg ts        "$TS"               \
          --arg tool      "$TOOL"             \
          --arg session   "$SESSION"          \
          --arg feature   "$FEATURE"          \
          --arg step      "$STEP"             \
          --argjson thr   "$RETRY_THRESHOLD"  \
          '{
            ts:      $ts,
            type:    "retry_loop",
            source:  "auto",
            tool:    $tool,
            session: (if $session != "" then $session else null end),
            feature: (if $feature != "" then $feature else null end),
            step:    (if $step    != "" then $step    else null end),
            note:    ("Tool \($tool) called with errors \($thr)+ times consecutively — possible retry loop or stubborn error")
          } | with_entries(select(.value != null))' \
          >> "$LEARNINGS_FILE" 2>/dev/null || true

        # Ensure learnings file is gitignored
        if [ -f ".gitignore" ] && ! grep -qF ".devflow-learnings.jsonl" .gitignore 2>/dev/null; then
          printf '\n# devflow learnings log\n.devflow-learnings.jsonl\n.devflow-learnings.jsonl.1\n' >> .gitignore 2>/dev/null || true
        fi
      fi
    fi
  fi
fi

# ------------------------------------------------------------------
# Ensure .devflow-observe.jsonl is gitignored
# ------------------------------------------------------------------
if [ -f ".gitignore" ] && ! grep -qF ".devflow-observe.jsonl" .gitignore 2>/dev/null; then
  printf '\n# devflow observe log\n.devflow-observe.jsonl\n.devflow-observe.jsonl.1\n' >> .gitignore 2>/dev/null || true
fi

exit 0
