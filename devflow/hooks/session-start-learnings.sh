#!/bin/bash
# session-start-learnings.sh — SessionStart hook: inject past learnings into session context.
# Reads .devflow-learnings.jsonl from the consumer project root.
# Outputs a JSON priority message with relevant entries; exits silently if none.

LEARNINGS_LOG=".devflow-learnings.jsonl"
STATE_FILE=".devflow-state.json"
MAX_SHOW=8
# Learnings older than this many days are not surfaced (still kept in file)
MAX_AGE_DAYS=30

# Guard: jq required
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Guard: no learnings file or empty
if [ ! -f "$LEARNINGS_LOG" ] || [ ! -s "$LEARNINGS_LOG" ]; then
  exit 0
fi

# ── Read current pipeline context ────────────────────────────────────────────
FEATURE=""
if [ -f "$STATE_FILE" ]; then
  FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null) || true
fi

# ── Compute cutoff timestamp for MAX_AGE_DAYS ────────────────────────────────
# date -d is GNU; date -v is BSD/macOS — support both
CUTOFF=""
if date -d "-${MAX_AGE_DAYS} days" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
  CUTOFF=$(date -d "-${MAX_AGE_DAYS} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || true
elif date -v "-${MAX_AGE_DAYS}d" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
  CUTOFF=$(date -v "-${MAX_AGE_DAYS}d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || true
fi

# ── Select relevant entries ───────────────────────────────────────────────────
# -s (slurp) reads all JSONL lines into one array for sorting + limiting.
# Priority: entries for the current feature, then manual entries, then all recent.
# Filter by age if cutoff available.
ENTRIES=$(
  jq -rs \
    --arg feature "$FEATURE" \
    --arg cutoff  "$CUTOFF"  \
    --argjson max "$MAX_SHOW" \
    '
    [ .[] |
      if ($cutoff != "") then select(.ts >= $cutoff)
      else . end
    ]
    | sort_by(
        if (.feature == $feature and $feature != "") then 0
        elif (.source == "manual") then 1
        else 2
        end
      )
    | .[0:$max]
    | .[]
    | "• [\(.type)] \(if .file then .file + ": " else "" end)\(.note)"
    ' "$LEARNINGS_LOG" 2>/dev/null
) || true

[ -z "$ENTRIES" ] && exit 0

# ── Build context label ───────────────────────────────────────────────────────
CONTEXT_LABEL="Past learnings for this project"
if [ -n "$FEATURE" ]; then
  CONTEXT_LABEL="Past learnings (feature: $FEATURE)"
fi

# ── Emit JSON priority message ────────────────────────────────────────────────
jq -cn \
  --arg label   "$CONTEXT_LABEL" \
  --arg entries "$ENTRIES"       \
  '{
    priority: "INFO",
    message: ($label + ":\n\n" + $entries + "\n\nUse /devflow.learn to log, search, or prune learnings.")
  }'

exit 0
