#!/bin/bash
# devflow observe hook — continuous learning observer
# Captures tool events to .devflow-observe.jsonl for pattern analysis.
# Usage:
#   bash .../observe.sh pre   — PreToolUse  (before tool call, async)
#   bash .../observe.sh post  — PostToolUse / PostToolUseFailure (async)
#   bash .../observe.sh stop  — Stop (sync: may emit a /compact notice)
# Counters and turn timing live in .devflow-observe-state.json (owned by this
# hook; read by stop-metrics.sh and post-task-create.sh). .devflow-state.json is
# only read here. All writes are locked + atomic (lib/payload.sh).
# Exit 0 always.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

EVENT="${1:-}"
case "$EVENT" in pre|post|stop) ;; *) cat >/dev/null 2>&1; exit 0 ;; esac

df_read_input || exit 0
[ -z "$DF_RAW" ] && exit 0

WORKSPACE_ROOT="$DF_WORKSPACE"
LOG_FILE="${DEVFLOW_OBSERVE_LOG:-$WORKSPACE_ROOT/.devflow-observe.jsonl}"
LEARNINGS_FILE="${DEVFLOW_LEARNINGS_FILE:-$WORKSPACE_ROOT/.devflow-learnings.jsonl}"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
OBS_STATE="${DEVFLOW_OBSERVE_STATE_FILE:-$WORKSPACE_ROOT/.devflow-observe-state.json}"
MAX_BYTES="${DEVFLOW_OBSERVE_MAX_BYTES:-524288}"
RETRY_THRESHOLD=3
RETRY_WINDOW=20
COMPACT_THRESHOLD="${DEVFLOW_COMPACT_THRESHOLD:-50}"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true
TOOL="$DF_TOOL_RAW"
KIND="$DF_TOOL"
SESSION="$DF_SESSION"

# ------------------------------------------------------------------
# Read optional devflow state (read-only here)
# ------------------------------------------------------------------
STEP=""
FEATURE=""
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null) || true
fi

obs_get() {
  [ -f "$OBS_STATE" ] || return 0
  jq -r "$1" "$OBS_STATE" 2>/dev/null || true
}

df_rotate "$LOG_FILE" "$MAX_BYTES"

# ------------------------------------------------------------------
# pre: log the call and track per-command turn timing
# ------------------------------------------------------------------
if [ "$EVENT" = "pre" ]; then
  FILE_PATH=""
  case "$KIND" in write|edit|read) FILE_PATH="$DF_FILE" ;; esac

  # Shell command (truncated) so stop-learn-distill.sh can spot reverts/resets
  CMD=""
  [ "$KIND" = "shell" ] && CMD=$(printf '%s' "$DF_CMD" | cut -c1-300)

  NOW_EPOCH=$(date +%s 2>/dev/null || echo 0)
  INFERRED_CMD=""
  if echo "$FILE_PATH" | grep -qE 'skills/devflow-(task|clarify|plan|analyze|implement|beautify|test|ship|pr|hotfix)/SKILL\.md'; then
    INFERRED_CMD=$(echo "$FILE_PATH" | sed -E 's|.*skills/devflow-([a-z]+)/SKILL\.md.*|\1|')
  elif echo "$FILE_PATH" | grep -qE 'devflow/features/[0-9]{3}_[^/]+/task\.md$' && [ "$KIND" != "read" ]; then
    INFERRED_CMD="task"
  elif echo "$FILE_PATH" | grep -qE 'devflow/features/[0-9]{3}_[^/]+/plan\.md$' && [ "$KIND" != "read" ]; then
    [ -z "$(obs_get '.active_command // empty')" ] && INFERRED_CMD="plan"
  elif echo "$FILE_PATH" | grep -qE 'devflow/features/[0-9]{3}_[^/]+/verification\.md$' && [ "$KIND" != "read" ]; then
    INFERRED_CMD="test"
  fi

  STEP_CMD=""
  case "$STEP" in
    devflow.task|devflow.clarify|devflow.plan|devflow.analyze|devflow.implement|devflow.beautify|devflow.test|devflow.ship|devflow.pr|devflow.hotfix)
      STEP_CMD="${STEP#devflow.}" ;;
  esac

  if [ -n "$INFERRED_CMD" ] || [ -n "$STEP_CMD" ] || [ -f "$STATE_FILE" ]; then
    df_json_update "$OBS_STATE" '
      . + {
        turn_started_at: (if (.turn_started_at // "") != "" then .turn_started_at else $ts end),
        turn_started_epoch: (if (.turn_started_epoch // 0) > 0 then .turn_started_epoch else $epoch end)
      }
      + (if $inferred != "" then {active_command: $inferred}
         elif (.active_command // "") == "" and $stepcmd != "" then {active_command: $stepcmd}
         else {} end)' \
      --arg ts "$TS" --argjson epoch "$NOW_EPOCH" --arg inferred "$INFERRED_CMD" --arg stepcmd "$STEP_CMD"
  fi

  # Don't pollute the churn log with read paths
  [ "$KIND" = "read" ] && FILE_PATH=""

  ENTRY=$(jq -cn \
    --arg ts "$TS" --arg event "$EVENT" --arg tool "$TOOL" --arg kind "$KIND" \
    --arg session "$SESSION" --arg step "$STEP" --arg feature "$FEATURE" \
    --arg file "$FILE_PATH" --arg cmd "$CMD" \
    '{ts: $ts, event: $event, tool: $tool, kind: $kind, session: $session,
      step: $step, feature: $feature, file: $file, cmd: $cmd}
     | with_entries(select(.value != ""))' 2>/dev/null) || true
  [ -n "$ENTRY" ] && df_append "$LOG_FILE" "$ENTRY"

# ------------------------------------------------------------------
# post: log the outcome, count calls, detect retry loops
# ------------------------------------------------------------------
elif [ "$EVENT" = "post" ]; then
  IS_ERROR="${DF_IS_ERROR:-false}"
  [ "$IS_ERROR" = "true" ] || IS_ERROR="false"

  ENTRY=$(jq -cn \
    --arg ts "$TS" --arg event "$EVENT" --arg tool "$TOOL" --arg kind "$KIND" \
    --arg session "$SESSION" --argjson is_error "$IS_ERROR" \
    '{ts: $ts, event: $event, tool: $tool, kind: $kind, session: $session, is_error: $is_error}
     | with_entries(select(.value != ""))' 2>/dev/null) || true
  [ -n "$ENTRY" ] && df_append "$LOG_FILE" "$ENTRY"

  # Strategic-compact counter: cumulative tool calls per session (reset on new session)
  df_json_update "$OBS_STATE" '
    (if $session != "" and $session != (.last_session_id // "") then
       .tool_call_count = 0 | .last_observed_step = "" | .compact_notified = false
     else . end)
    | .tool_call_count = ((.tool_call_count // 0) + 1)
    | (if $session != "" then .last_session_id = $session else . end)
    | (if $step != "" then .last_observed_step = $step else . end)' \
    --arg session "$SESSION" --arg step "$STEP"

  # Retry-loop detection: consecutive trailing failed calls of the same tool
  if [ -n "$TOOL" ] && [ "$IS_ERROR" = "true" ]; then
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
      ALREADY=""
      if [ -f "$LEARNINGS_FILE" ]; then
        ALREADY=$(
          jq -r --arg t "$TOOL" --arg s "$SESSION" \
            'select(.type=="retry_loop" and .tool==$t and .session==$s) | .tool' \
            "$LEARNINGS_FILE" 2>/dev/null | head -1
        ) || true
      fi

      if [ -z "$ALREADY" ]; then
        LEARNING=$(jq -cn \
          --arg ts "$TS" --arg tool "$TOOL" --arg session "$SESSION" \
          --arg feature "$FEATURE" --arg step "$STEP" --argjson thr "$RETRY_THRESHOLD" \
          '{ts: $ts, type: "retry_loop", source: "auto", tool: $tool, session: $session,
            feature: $feature, step: $step,
            note: ("Tool \($tool) called with errors \($thr)+ times consecutively — possible retry loop or stubborn error")}
           | with_entries(select(.value != ""))' 2>/dev/null) || true
        [ -n "$LEARNING" ] && df_append "$LEARNINGS_FILE" "$LEARNING"
        df_gitignore ".devflow-learnings.jsonl" ".devflow-learnings.jsonl.1"
      fi
    fi
  fi

# ------------------------------------------------------------------
# stop: one /compact notice per session once the threshold is crossed
# ------------------------------------------------------------------
elif [ "$EVENT" = "stop" ]; then
  COUNT=$(obs_get '.tool_call_count // 0')
  NOTIFIED=$(obs_get '.compact_notified // false')
  if [ "${COUNT:-0}" -ge "$COMPACT_THRESHOLD" ] 2>/dev/null && [ "$NOTIFIED" != "true" ]; then
    df_json_update "$OBS_STATE" '.compact_notified = true'
    df_notify "⚡ devflow: ~${COUNT} tool calls this session — consider /compact to keep context fresh."
  fi
fi

df_gitignore ".devflow-observe.jsonl" ".devflow-observe.jsonl.1" ".devflow-observe-state.json" ".devflow-*.lock" ".devflow-tmp.*"
exit 0
