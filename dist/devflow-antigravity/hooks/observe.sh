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
STATE_FILE=".devflow-state.json"
MAX_LINES=500

# Guard: jq required
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Guard: event must be pre or post
if [ "$EVENT" != "pre" ] && [ "$EVENT" != "post" ]; then
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
fi

# ------------------------------------------------------------------
# Ensure .devflow-observe.jsonl is gitignored
# ------------------------------------------------------------------
if [ -f ".gitignore" ] && ! grep -qF ".devflow-observe.jsonl" .gitignore 2>/dev/null; then
  printf '\n# devflow observe log\n.devflow-observe.jsonl\n.devflow-observe.jsonl.1\n' >> .gitignore 2>/dev/null || true
fi

exit 0
