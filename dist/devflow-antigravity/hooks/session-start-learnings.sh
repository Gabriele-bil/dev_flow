#!/bin/bash
# session-start-learnings.sh — SessionStart hook: inject project instincts into session context.
# Reads .devflow-instincts.yaml (auto-migrating from .devflow-learnings.jsonl if needed).
# Outputs a JSON priority message with relevant instincts; exits silently if none.

INSTINCTS_FILE=".devflow-instincts.yaml"
LEARNINGS_LOG=".devflow-learnings.jsonl"
MAX_SHOW=6
MIN_CONFIDENCE="0.4"

# Guards: jq and yq both required
if ! command -v jq >/dev/null 2>&1; then exit 0; fi
if ! command -v yq >/dev/null 2>&1; then exit 0; fi

# ── Auto-migrate from old JSONL format (one-time) ────────────────────────────
if [ ! -f "$INSTINCTS_FILE" ] && [ -f "$LEARNINGS_LOG" ] && [ -s "$LEARNINGS_LOG" ]; then
  YAML_OUT="# DevFlow project instincts — auto-migrated from .devflow-learnings.jsonl"$'\n'"instincts:"

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    TYPE=$(printf '%s' "$line" | jq -r '.type // "lesson"' 2>/dev/null) || continue
    NOTE=$(printf '%s' "$line" | jq -r '.note // ""'       2>/dev/null) || continue
    FILE=$(printf '%s' "$line" | jq -r '.file // ""'       2>/dev/null) || true
    TS=$(printf '%s'   "$line" | jq -r '.ts // ""'         2>/dev/null) || true
    [ -z "$NOTE" ] && continue

    # Trigger and id
    if [ -n "$FILE" ]; then
      TRIGGER="when editing $FILE"
      ID_SLUG=$(printf '%s' "$FILE" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
      INSTINCT_ID="churn-${ID_SLUG}"
    else
      TRIGGER="when working on this project"
      ID_SLUG=$(printf '%s' "$NOTE" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
        | cut -c1-40 | sed 's/-$//')
      INSTINCT_ID="migrated-${ID_SLUG}"
    fi

    # Confidence by type
    case "$TYPE" in
      churn_file) CONF=0.5  ;;
      quirk)      CONF=0.6  ;;
      lesson)     CONF=0.65 ;;
      warning)    CONF=0.7  ;;
      *)          CONF=0.6  ;;
    esac

    # Domain inference
    DOMAIN="general"
    case "$FILE" in *.dart)     DOMAIN="flutter"    ;; esac
    case "$FILE" in *.ts|*.tsx) DOMAIN="typescript" ;; esac
    case "$FILE" in *.py)       DOMAIN="python"     ;; esac
    case "$FILE" in *.sh)       DOMAIN="shell"      ;; esac
    case "$FILE" in *devflow*)  DOMAIN="devflow"    ;; esac

    SAFE_NOTE=$(printf '%s'    "$NOTE"    | sed 's/"/\\"/g')
    SAFE_TRIGGER=$(printf '%s' "$TRIGGER" | sed 's/"/\\"/g')
    TS_VAL="${TS:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

    YAML_OUT="${YAML_OUT}"$'\n'"  - id: ${INSTINCT_ID}"
    YAML_OUT="${YAML_OUT}"$'\n'"    trigger: \"${SAFE_TRIGGER}\""
    YAML_OUT="${YAML_OUT}"$'\n'"    confidence: ${CONF}"
    YAML_OUT="${YAML_OUT}"$'\n'"    domain: ${DOMAIN}"
    YAML_OUT="${YAML_OUT}"$'\n'"    scope: project"
    YAML_OUT="${YAML_OUT}"$'\n'"    action: \"${SAFE_NOTE}\""
    YAML_OUT="${YAML_OUT}"$'\n'"    evidence: \"migrated from ${TYPE}\""
    YAML_OUT="${YAML_OUT}"$'\n'"    ts: \"${TS_VAL}\""
  done < "$LEARNINGS_LOG"

  printf '%s\n' "$YAML_OUT" > "$INSTINCTS_FILE"
  mv "$LEARNINGS_LOG" "${LEARNINGS_LOG}.migrated" 2>/dev/null || true
fi

# Guard: no instincts file or empty
if [ ! -f "$INSTINCTS_FILE" ] || [ ! -s "$INSTINCTS_FILE" ]; then exit 0; fi

# ── Read and surface instincts ────────────────────────────────────────────────
ENTRIES=$(
  yq -r \
    ".instincts // [] | sort_by(.confidence) | reverse | map(select(.confidence >= ${MIN_CONFIDENCE})) | .[0:${MAX_SHOW}] | .[] | \"• [\" + (.confidence | tostring) + \" \" + (.domain // \"general\") + \"] \" + .trigger + \" → \" + .action" \
    "$INSTINCTS_FILE" 2>/dev/null
) || true

[ -z "$ENTRIES" ] && exit 0

jq -cn \
  --arg entries "$ENTRIES" \
  '{
    priority: "INFO",
    message: ("🧠 Project instincts (confidence ≥ 0.4):\n\n" + $entries + "\n\nUse /devflow.learn to manage instincts (log, search, list, prune, boost).")
  }'

exit 0
