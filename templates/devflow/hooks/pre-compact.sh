#!/bin/bash
# devflow pre-compact state save
# Snapshots pipeline progress from plan.md [done]/[pending] markers before context compaction.
# Merges the snapshot into .devflow-state.json (never drops feature_path,
# branch, task_status, app, ...) and tells the user state was saved.
# PreCompact output never reaches the model; the post-compaction reminder is
# emitted by session-start.sh (SessionStart matcher "compact").

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

df_read_input || exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
WORKSPACE_ROOT="$DF_WORKSPACE"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"

# Active plan: feature recorded in state first (feature_path, then feature),
# most recently modified plan.md only as a last resort.
PLAN_FILE=""
if [ -f "$STATE_FILE" ]; then
  FP=$(jq -r '.feature_path // empty' "$STATE_FILE" 2>/dev/null) || FP=""
  FN=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null) || FN=""
  if [ -n "$FP" ] && [ -f "$WORKSPACE_ROOT/$FP/plan.md" ]; then
    PLAN_FILE="$WORKSPACE_ROOT/$FP/plan.md"
  elif [ -n "$FN" ] && [ -f "$WORKSPACE_ROOT/devflow/features/$FN/plan.md" ]; then
    PLAN_FILE="$WORKSPACE_ROOT/devflow/features/$FN/plan.md"
  fi
fi
if [ -z "$PLAN_FILE" ] && [ -d "$WORKSPACE_ROOT/devflow/features" ]; then
  PLAN_FILE=$(find "$WORKSPACE_ROOT/devflow/features" -name "plan.md" -type f -exec ls -t {} + 2>/dev/null \
    | head -1)
fi

[ -z "$PLAN_FILE" ] && exit 0

# Feature name from path: devflow/features/NNN_name/plan.md -> NNN_name
FEATURE=$(echo "$PLAN_FILE" | sed "s|$WORKSPACE_ROOT/devflow/features/||" | sed 's|devflow/features/||' | sed 's|/plan.md||')

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
if [ -d "$WORKSPACE_ROOT/devflow/features" ]; then
  HIGHEST=$(for d in "$WORKSPACE_ROOT"/devflow/features/[0-9][0-9][0-9]_*; do
      [ -d "$d" ] && basename "$d" | cut -c1-3
    done | sort -n | tail -1)
  if [ -n "$HIGHEST" ]; then
    NEXT_FEATURE_NUMBER=$(printf '%03d' $((10#$HIGHEST + 1)))
  fi
fi

# Map plan status to the next devflow pipeline step.
# Source of truth: references/state-machine.md — keep this case in sync.
# Unknown status: keep whatever next_step the skills last wrote.
case "$PLAN_STATUS" in
  "ready")        NEXT_STEP="devflow.implement" ;;
  "implementing") NEXT_STEP="devflow.implement" ;;
  "implemented")  NEXT_STEP="devflow.beautify"  ;;
  "beautified")   NEXT_STEP="devflow.test"      ;;
  "tested")       NEXT_STEP="devflow.ship"      ;;
  "shipped")      NEXT_STEP="devflow.pr"        ;;
  "pr-opened")    NEXT_STEP="devflow.task"      ;;
  "blocked")      NEXT_STEP="devflow.recovery"  ;;
  *)              NEXT_STEP="" ;;
esac

# Merge snapshot into existing state (atomic, locked)
df_json_update "$STATE_FILE" '
  . + {
    saved_at:       $saved_at,
    plan_path:      $plan_path,
    feature:        $feature,
    feature_path:   ("devflow/features/" + $feature),
    plan_status:    $plan_status,
    progress: {
      done:    $done_count,
      pending: $pending_count,
      total:   ($done_count + $pending_count)
    },
    done_files:    $done_files,
    pending_files: $pending_files
  }
  | del(.active_feature)
  | (if $next_step != "" then .next_step = $next_step else . end)
  | ((.next_feature_number // 0) | tonumber? // 0) as $cur
  | (if $cur < $nfn then .next_feature_number = $nfn else .next_feature_number = $cur end)' \
  --arg saved_at "$TIMESTAMP" --arg plan_path "${PLAN_FILE#"$WORKSPACE_ROOT/"}" \
  --arg feature "$FEATURE" --arg plan_status "$PLAN_STATUS" --arg next_step "$NEXT_STEP" \
  --argjson done_count "$DONE_COUNT" --argjson pending_count "$PENDING_COUNT" \
  --argjson done_files "$DONE_JSON" --argjson pending_files "$PENDING_JSON" \
  --argjson nfn "$((10#$NEXT_FEATURE_NUMBER))"

df_gitignore ".devflow-state.json"
[ -z "$NEXT_STEP" ] && NEXT_STEP=$(jq -r '.next_step // "devflow.resume"' "$STATE_FILE" 2>/dev/null)

# Build a human-readable pending list for the context message (max 10 entries)
if [ "$PENDING_COUNT" -gt 0 ]; then
  PENDING_LINES=$(printf '%s\n' "$PENDING_PATHS" | head -10 | sed 's/^/  - /')
else
  PENDING_LINES="  (none — all files complete)"
fi

# User-visible notice (PreCompact output never reaches the model)
df_notify "DevFlow state saved before compaction: $FEATURE — $PLAN_STATUS → next: $NEXT_STEP ($DONE_COUNT/$TOTAL files done).
Remaining files:
$PENDING_LINES"
exit 0
