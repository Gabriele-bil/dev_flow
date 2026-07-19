#!/bin/bash
# stop-learn-distill.sh — Stop hook: distill churn signals into project instincts.
# Detects file churn (≥4 edits in session) and upserts instinct stubs to
# .devflow-instincts.yaml in the consumer project root.
# Passthrough: reads stdin and writes it back to stdout unchanged.

RAW=$(cat)

OBSERVE_LOG=".devflow-observe.jsonl"
INSTINCTS_FILE=".devflow-instincts.yaml"
CHURN_THRESHOLD=4
WINDOW_LINES=200

# Guards: jq and yq both required
if ! command -v jq >/dev/null 2>&1; then printf '%s' "$RAW"; exit 0; fi
if ! command -v yq >/dev/null 2>&1; then  printf '%s' "$RAW"; exit 0; fi

# Guard: nothing to analyse
if [ ! -f "$OBSERVE_LOG" ] || [ ! -s "$OBSERVE_LOG" ]; then
  printf '%s' "$RAW"
  exit 0
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

# ── Detect churn: files written/edited ≥ CHURN_THRESHOLD times ───────────────
CHURNED_FILES=$(
  tail -n "$WINDOW_LINES" "$OBSERVE_LOG" 2>/dev/null \
  | jq -r 'select(.event=="pre" and (.tool=="Write" or .tool=="Edit" or .tool=="MultiEdit") and (.file != null and .file != "")) | .file' 2>/dev/null \
  | sort | uniq -c | awk -v thr="$CHURN_THRESHOLD" '$1 >= thr { print $2 }'
) || true

if [ -z "$CHURNED_FILES" ]; then
  printf '%s' "$RAW"
  exit 0
fi

# ── Ensure instincts file exists ──────────────────────────────────────────────
if [ ! -f "$INSTINCTS_FILE" ]; then
  printf '%s\n' "# DevFlow project instincts" "instincts: []" > "$INSTINCTS_FILE"
fi

# ── Upsert instinct for each churned file ─────────────────────────────────────
while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue

  # Derive kebab-case id
  ID_SLUG=$(printf '%s' "$filepath" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
  INSTINCT_ID="churn-${ID_SLUG}"

  # Domain inference from file extension / path
  DOMAIN="general"
  case "$filepath" in *.dart)     DOMAIN="flutter"    ;; esac
  case "$filepath" in *.ts|*.tsx) DOMAIN="typescript" ;; esac
  case "$filepath" in *.py)       DOMAIN="python"     ;; esac
  case "$filepath" in *.sh)       DOMAIN="shell"      ;; esac
  case "$filepath" in *devflow*)  DOMAIN="devflow"    ;; esac

  TRIGGER="when editing $filepath"
  ACTION="File edited multiple times — review full flow before patching"

  # Check if instinct already exists
  EXISTING_CONF=$(yq -r \
    ".instincts // [] | .[] | select(.id == \"$INSTINCT_ID\") | .confidence" \
    "$INSTINCTS_FILE" 2>/dev/null | head -1) || true

  if [ -n "$EXISTING_CONF" ] && [ "$EXISTING_CONF" != "null" ]; then
    # Bump confidence by 0.05, cap at 0.95
    # LC_ALL=C: decimal-comma locales (it_IT, de_DE) break yq float assignment
    NEW_CONF=$(LC_ALL=C awk -v c="$EXISTING_CONF" 'BEGIN {v=c+0.05; if(v>0.95) v=0.95; printf "%.2f", v}')
    yq -i \
      "(.instincts[] | select(.id == \"$INSTINCT_ID\") | .confidence) = $NEW_CONF |
       (.instincts[] | select(.id == \"$INSTINCT_ID\") | .ts) = \"$TS\"" \
      "$INSTINCTS_FILE" 2>/dev/null || true
  else
    # Append new instinct stub
    yq -i \
      ".instincts += [{\"id\": \"$INSTINCT_ID\", \"trigger\": \"$TRIGGER\", \"confidence\": 0.5, \"domain\": \"$DOMAIN\", \"scope\": \"project\", \"action\": \"$ACTION\", \"evidence\": \"churn: 1 session\", \"ts\": \"$TS\"}]" \
      "$INSTINCTS_FILE" 2>/dev/null || true
  fi

done <<< "$CHURNED_FILES"

# ── Ensure gitignore entries ──────────────────────────────────────────────────
if [ -f ".gitignore" ]; then
  if ! grep -qF ".devflow-instincts.yaml" .gitignore 2>/dev/null; then
    printf '\n# devflow instincts\n.devflow-instincts.yaml\n.devflow-learnings.jsonl.migrated\n' \
      >> .gitignore 2>/dev/null || true
  fi
fi

printf '%s' "$RAW"
exit 0
