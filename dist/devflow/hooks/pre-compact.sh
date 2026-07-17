#!/bin/bash
# devflow pre-compact state save
# Snapshots pipeline progress from plan.md [done]/[pending] markers before context compaction.
# Saves .devflow-state.json at the consumer project root and outputs a context reminder for Claude.

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_FILE=".devflow-state.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '{"priority":"INFO","message":"devflow pre-compact: jq not found. Install jq (brew install jq) to enable pipeline state persistence."}\n'
  exit 0
fi

# Find the most recently modified plan.md in devflow/features/
PLAN_FILE=""
if [ -d "devflow/features" ]; then
  PLAN_FILE=$(find devflow/features -name "plan.md" -type f 2>/dev/null \
    | xargs ls -t 2>/dev/null \
    | head -1)
fi

if [ -z "$PLAN_FILE" ]; then
  printf '{"priority":"INFO","message":"devflow pre-compact: no active plan.md found. No pipeline state to save."}\n'
  exit 0
fi

# Feature name from path: devflow/features/NNN_name/plan.md -> NNN_name
FEATURE=$(echo "$PLAN_FILE" | sed 's|devflow/features/||' | sed 's|/plan.md||')

# Plan status from frontmatter: format is **Status:** <value>
PLAN_STATUS=$(grep -m1 "^\*\*Status:\*\*" "$PLAN_FILE" 2>/dev/null \
  | sed 's/\*\*Status:\*\*[[:space:]]*//' \
  | tr -d '\r\n' \
  || echo "unknown")

# Count [done] and [pending] File List entries (### headings).
# grep -c outputs "0" on no matches but exits 1; "; true" normalises exit code.
DONE_COUNT=$(grep -cE "^###.*\[done\]" "$PLAN_FILE" 2>/dev/null; true)
PENDING_COUNT=$(grep -cE "^###.*\[pending\]" "$PLAN_FILE" 2>/dev/null; true)

# Strip any accidental whitespace
DONE_COUNT=$(echo "$DONE_COUNT" | tr -d '[:space:]')
PENDING_COUNT=$(echo "$PENDING_COUNT" | tr -d '[:space:]')

# Ensure numeric
[ -z "$DONE_COUNT" ]    && DONE_COUNT=0
[ -z "$PENDING_COUNT" ] && PENDING_COUNT=0

# Extract backtick-quoted file paths from matching ### headings
DONE_PATHS=$(grep -E "^###.*\[done\]"    "$PLAN_FILE" 2>/dev/null \
  | grep -oE '`[^`]+`' | tr -d '`' || true)
PENDING_PATHS=$(grep -E "^###.*\[pending\]" "$PLAN_FILE" 2>/dev/null \
  | grep -oE '`[^`]+`' | tr -d '`' || true)

DONE_JSON=$(printf '%s\n' "$DONE_PATHS"    | jq -Rn '[inputs | select(length > 0)]' 2>/dev/null || echo "[]")
PENDING_JSON=$(printf '%s\n' "$PENDING_PATHS" | jq -Rn '[inputs | select(length > 0)]' 2>/dev/null || echo "[]")

TOTAL=$((DONE_COUNT + PENDING_COUNT))

# Compute next_feature_number from devflow/features/ directory
NEXT_FEATURE_NUMBER="001"
if [ -d "devflow/features" ]; then
  HIGHEST=$(ls -1 "devflow/features" 2>/dev/null \
    | grep -oE '^[0-9]{3}' | sort -n | tail -1)
  if [ -n "$HIGHEST" ]; then
    NEXT_FEATURE_NUMBER=$(printf '%03d' $((10#$HIGHEST + 1)))
  fi
fi

# Map plan status to the next devflow pipeline step.
# Source of truth: references/state-machine.md — keep this case in sync.
case "$PLAN_STATUS" in
  "ready")        NEXT_STEP="devflow.implement" ;;
  "implementing") NEXT_STEP="devflow.implement" ;;
  "implemented")  NEXT_STEP="devflow.beautify"  ;;
  "beautified")   NEXT_STEP="devflow.test"      ;;
  "tested")       NEXT_STEP="devflow.ship"      ;;
  "shipped")      NEXT_STEP="devflow.pr"        ;;
  "pr-opened")    NEXT_STEP="devflow.task"      ;;
  "blocked")      NEXT_STEP="devflow.recovery"  ;;
  *)              NEXT_STEP="devflow.implement" ;;
esac

# Save state snapshot to project root
jq -n \
  --arg saved_at      "$TIMESTAMP"    \
  --arg plan_path     "$PLAN_FILE"    \
  --arg feature       "$FEATURE"      \
  --arg plan_status   "$PLAN_STATUS"  \
  --arg next_step     "$NEXT_STEP"    \
  --argjson done_count    "$DONE_COUNT"    \
  --argjson pending_count "$PENDING_COUNT" \
  --argjson done_files    "$DONE_JSON"     \
  --argjson pending_files "$PENDING_JSON"  \
  --arg next_feature_number "$NEXT_FEATURE_NUMBER" \
  '{
    saved_at:       $saved_at,
    plan_path:      $plan_path,
    feature:        $feature,
    plan_status:    $plan_status,
    next_step:      $next_step,
    next_feature_number: $next_feature_number,
    progress: {
      done:    $done_count,
      pending: $pending_count,
      total:   ($done_count + $pending_count)
    },
    done_files:    $done_files,
    pending_files: $pending_files
  }' > "$STATE_FILE" 2>/dev/null

# Ensure .devflow-state.json is gitignored in the consumer project
if [ -f ".gitignore" ] && ! grep -qF ".devflow-state.json" .gitignore 2>/dev/null; then
  printf '\n# devflow runtime state\n.devflow-state.json\n' >> .gitignore
fi

# Build a human-readable pending list for the context message (max 10 entries)
if [ "$PENDING_COUNT" -gt 0 ]; then
  PENDING_LINES=$(printf '%s\n' "$PENDING_PATHS" | head -10 | sed 's/^/  - /')
else
  PENDING_LINES="  (none — all files complete)"
fi

# Output context reminder injected into the compacted context
jq -cn \
  --arg feature       "$FEATURE"      \
  --arg plan          "$PLAN_FILE"    \
  --arg status        "$PLAN_STATUS"  \
  --arg next_step     "$NEXT_STEP"    \
  --argjson done      "$DONE_COUNT"    \
  --argjson pending   "$PENDING_COUNT" \
  --argjson total     "$TOTAL"         \
  --arg pending_lines "$PENDING_LINES" \
  '{
    priority: "IMPORTANT",
    message: (
      "DevFlow state saved before compaction.\n\n"
      + "Feature:    " + $feature + "\n"
      + "Plan:       " + $plan + "\n"
      + "Status:     " + $status + "  →  next: " + $next_step + "\n"
      + "Progress:   " + ($done|tostring) + "/" + ($total|tostring) + " files done, " + ($pending|tostring) + " remaining\n\n"
      + "Remaining files:\n" + $pending_lines + "\n\n"
      + "On resume: run devflow.resume (reads state, cross-checks plan.md, confirms position) — or re-read plan.md → first [pending] entry → confirm position with user."
    )
  }'
