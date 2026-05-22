#!/bin/bash
# stop-learn-distill.sh — Stop hook: distill learning signals from observe.jsonl.
# Detects file churn (≥4 edits in session) and appends deduplicated entries to
# .devflow-learnings.jsonl in the consumer project root.
# Passthrough: reads stdin and writes it back to stdout unchanged.

RAW=$(cat)

OBSERVE_LOG=".devflow-observe.jsonl"
LEARNINGS_LOG=".devflow-learnings.jsonl"
STATE_FILE=".devflow-state.json"
CHURN_THRESHOLD=4
# Analyse the most recent entries (covers a typical session without crossing into old history)
WINDOW_LINES=200
MAX_LEARNINGS=200

# Guard: jq required
if ! command -v jq >/dev/null 2>&1; then
  printf '%s' "$RAW"
  exit 0
fi

# Guard: nothing to analyse
if [ ! -f "$OBSERVE_LOG" ] || [ ! -s "$OBSERVE_LOG" ]; then
  printf '%s' "$RAW"
  exit 0
fi

# ── Read current pipeline context ────────────────────────────────────────────
FEATURE=""
STEP=""
if [ -f "$STATE_FILE" ]; then
  FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null) || true
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

# ── Detect churn: files written/edited ≥ CHURN_THRESHOLD times ───────────────
# Count occurrences of each file path in pre-events from the session window.
# jq produces one "file path" per matching line; sort+uniq-c finds repeats.
CHURNED_FILES=$(
  tail -n "$WINDOW_LINES" "$OBSERVE_LOG" 2>/dev/null \
  | jq -r 'select(.event=="pre" and (.tool=="Write" or .tool=="Edit" or .tool=="MultiEdit") and (.file != null and .file != "")) | .file' 2>/dev/null \
  | sort | uniq -c | awk -v thr="$CHURN_THRESHOLD" '$1 >= thr { print $2 }'
) || true

if [ -z "$CHURNED_FILES" ]; then
  printf '%s' "$RAW"
  exit 0
fi

# ── Load existing learnings for dedup check ───────────────────────────────────
EXISTING=""
if [ -f "$LEARNINGS_LOG" ]; then
  EXISTING=$(jq -r 'select(.type=="churn_file") | .file' "$LEARNINGS_LOG" 2>/dev/null) || true
fi

# ── Append new churn learnings (skip duplicates) ──────────────────────────────
NEW_ENTRIES=0
while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue

  # Dedup: skip if same file already recorded as churn_file
  if echo "$EXISTING" | grep -qxF "$filepath" 2>/dev/null; then
    continue
  fi

  jq -cn \
    --arg ts      "$TS"       \
    --arg feature "$FEATURE"  \
    --arg step    "$STEP"     \
    --arg file    "$filepath" \
    '{
      ts:      $ts,
      type:    "churn_file",
      source:  "auto",
      feature: (if $feature != "" then $feature else null end),
      step:    (if $step    != "" then $step    else null end),
      file:    $file,
      note:    ("File edited \($file | split("/") | last) multiple times in session — potential plan ambiguity or complex module")
    } | with_entries(select(.value != null))' \
    >> "$LEARNINGS_LOG" 2>/dev/null || true

  NEW_ENTRIES=$((NEW_ENTRIES + 1))
done <<< "$CHURNED_FILES"

# ── Rotate learnings log if it exceeds MAX_LEARNINGS lines ───────────────────
if [ -f "$LEARNINGS_LOG" ]; then
  LINE_COUNT=$(wc -l < "$LEARNINGS_LOG" 2>/dev/null | tr -d '[:space:]') || true
  if [ -n "$LINE_COUNT" ] && [ "$LINE_COUNT" -ge "$MAX_LEARNINGS" ]; then
    mv "$LEARNINGS_LOG" "${LEARNINGS_LOG}.1" 2>/dev/null || true
  fi
fi

# ── Ensure .devflow-learnings.jsonl is gitignored ────────────────────────────
if [ -f ".gitignore" ] && ! grep -qF ".devflow-learnings.jsonl" .gitignore 2>/dev/null; then
  printf '\n# devflow learnings log\n.devflow-learnings.jsonl\n.devflow-learnings.jsonl.1\n' >> .gitignore 2>/dev/null || true
fi

printf '%s' "$RAW"
exit 0
