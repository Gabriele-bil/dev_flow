#!/bin/bash
# metrics-collect.sh — lifecycle telemetry into .devflow-metrics/ (gitignored).
# Usage (async, no stdout):
#   bash .../metrics-collect.sh session-start  — SessionStart  → sessions.jsonl
#   bash .../metrics-collect.sh prompt         — UserPromptSubmit → prompts.jsonl
#   bash .../metrics-collect.sh pre-compact    — PreCompact    → sessions.jsonl
#   bash .../metrics-collect.sh session-end    — SessionEnd    → sessions.jsonl
#   bash .../metrics-collect.sh subagent-stop  — SubagentStop  → subagents.jsonl
# Per-turn usage is stop-metrics.sh, per-tool rows are observe.sh, context
# injected by hooks is lib/emit.sh. Prompt text is never stored: only its
# size and the slash command it starts with. `prompt` also marks the turn start
# (prompt_started_ms) and the devflow command in .devflow-observe-state.json so
# stop-metrics.sh times and attributes the turn exactly.
# DEVFLOW_METRICS_DIR=off disables. Exit 0 always.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"

EVENT="${1:-}"
case "$EVENT" in session-start|prompt|pre-compact|session-end|subagent-stop) ;; *) cat >/dev/null 2>&1; exit 0 ;; esac

df_read_input || exit 0
[ -z "$DF_RAW" ] && exit 0
df_metrics_dir || exit 0

WORKSPACE_ROOT="$DF_WORKSPACE"
OBS_STATE="${DEVFLOW_OBSERVE_STATE_FILE:-$WORKSPACE_ROOT/.devflow-observe-state.json}"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

FEATURE=""
STEP=""
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null) || true
fi

# field <jq-path> — one value from the raw payload ("" when absent)
field() { printf '%s' "$DF_RAW" | jq -r "$1 // empty" 2>/dev/null || true; }

# transcript_usage <path> — usage summary of a whole transcript (subagents),
# or of its last model call (context size at compaction) with "last".
transcript_usage() {
  local path="$1" mode="${2:-all}"
  [ -n "$path" ] && [ -f "$path" ] || { echo '{}'; return 0; }
  tail -c "${DEVFLOW_METRICS_TAIL_BYTES:-2000000}" "$path" 2>/dev/null \
    | jq -R 'fromjson? // empty' 2>/dev/null | jq -sc --arg mode "$mode" '
      def ms: (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601? // null) as $s
        | if $s == null then null else $s * 1000 + ((capture("\\.(?<f>[0-9]{1,3})") | .f + "00" | .[0:3] | tonumber) // 0) end;
      ( [ .[] | select(.type == "assistant" and .message.usage != null) ]
        | unique_by(.message.id // (.message.usage | tostring)) ) as $a
      | if $mode == "last" then
          (($a | last | .message.usage) // {}) as $u
          | {context_tokens: (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0))}
        else
          ( [ .[] | (.timestamp // empty) | strings | ms | numbers ] ) as $t
          | {model: ([ $a[] | .message.model // empty ] | last),
             api_calls: ($a | length),
             input_tokens: ([ $a[] | .message.usage.input_tokens // 0 ] | add // 0),
             output_tokens: ([ $a[] | .message.usage.output_tokens // 0 ] | add // 0),
             cache_creation_tokens: ([ $a[] | .message.usage.cache_creation_input_tokens // 0 ] | add // 0),
             cache_read_tokens: ([ $a[] | .message.usage.cache_read_input_tokens // 0 ] | add // 0),
             peak_context_tokens: ([ $a[] | .message.usage | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) ] | max // 0),
             tool_calls: ([ $a[] | (.message.content // [])[]? | select(type == "object" and .type == "tool_use") ] | unique_by(.id // tostring) | length),
             duration_ms: (if ($t | length) > 1 then ($t | max) - ($t | min) else null end)}
          | with_entries(select(.value != null))
        end' 2>/dev/null || echo '{}'
}

case "$EVENT" in
  session-start)
    # Stale tool-call start marks (crashed sessions) older than a day
    find "$DF_METRICS_DIR/.pending" -type f -mmin +1440 -delete 2>/dev/null || true
    ADAPTER=""
    [ -f "$WORKSPACE_ROOT/devflow/config.md" ] \
      && ADAPTER=$(sed -n 's/^\*\*Adapter:\*\*[[:space:]]*//p' "$WORKSPACE_ROOT/devflow/config.md" 2>/dev/null | head -1 | tr -d ' `' | grep -v '^\[TODO') || true
    ACTIVE=false
    { [ -d "$WORKSPACE_ROOT/devflow" ] || [ -f "$STATE_FILE" ]; } && ACTIVE=true
    ROW=$(jq -cn --arg ts "$TS" --arg session "$DF_SESSION" --arg host "$DF_HOST" \
      --arg source "$(field '.source')" --arg model "$(field '.model // .modelName')" \
      --arg version "$(df_plugin_version)" --arg adapter "$ADAPTER" --argjson active "$ACTIVE" \
      --arg step "$STEP" --arg feature "$FEATURE" \
      '{ts:$ts, event:"session_start", session:$session, host:$host, source:$source,
        model:$model, plugin_version:$version, adapter:$adapter, devflow_active:$active,
        step:$step, feature:$feature} | with_entries(select(.value != ""))' 2>/dev/null) || ROW=""
    df_metric sessions "$ROW"
    ;;

  prompt)
    PROMPT=$(field '.prompt')
    SLASH=""
    case "$PROMPT" in /*) SLASH=$(printf '%s' "$PROMPT" | head -1 | awk '{print $1}' | cut -c2-80) ;; esac
    DEVFLOW_CMD=""
    case "$SLASH" in *devflow*) DEVFLOW_CMD=$(printf '%s' "$SLASH" | sed -E 's/^.*devflow[-.]//') ;; esac
    df_json_update "$OBS_STATE" \
      '.prompt_started_ms = $ms | (if $cmd != "" then .active_command = $cmd else . end)' \
      --argjson ms "$(df_now_ms)" --arg cmd "$DEVFLOW_CMD"
    ROW=$(jq -cn --arg ts "$TS" --arg session "$DF_SESSION" --arg host "$DF_HOST" \
      --argjson chars "${#PROMPT}" --arg slash "$SLASH" --arg command "$DEVFLOW_CMD" \
      --arg step "$STEP" --arg feature "$FEATURE" \
      '{ts:$ts, session:$session, host:$host, chars:$chars, est_tokens:(($chars / 4) | ceil),
        slash_command:$slash, command:$command, step:$step, feature:$feature}
       | with_entries(select(.value != ""))' 2>/dev/null) || ROW=""
    df_metric prompts "$ROW"
    ;;

  pre-compact)
    CALLS=0
    [ -f "$OBS_STATE" ] && CALLS=$(jq -r '.tool_call_count // 0' "$OBS_STATE" 2>/dev/null)
    [[ "$CALLS" =~ ^[0-9]+$ ]] || CALLS=0
    ROW=$(jq -cn --arg ts "$TS" --arg session "$DF_SESSION" --arg host "$DF_HOST" \
      --arg trigger "$(field '.trigger')" --argjson usage "$(transcript_usage "$DF_TRANSCRIPT" last)" \
      --argjson calls "$CALLS" --arg step "$STEP" --arg feature "$FEATURE" \
      '{ts:$ts, event:"compact", session:$session, host:$host, trigger:$trigger,
        tool_calls_in_session:$calls, step:$step, feature:$feature} + $usage
       | with_entries(select(.value != ""))' 2>/dev/null) || ROW=""
    df_metric sessions "$ROW"
    ;;

  session-end)
    ROW=$(jq -cn --arg ts "$TS" --arg session "$DF_SESSION" --arg host "$DF_HOST" \
      --arg reason "$(field '.reason')" --arg step "$STEP" --arg feature "$FEATURE" \
      '{ts:$ts, event:"session_end", session:$session, host:$host, reason:$reason,
        step:$step, feature:$feature} | with_entries(select(.value != ""))' 2>/dev/null) || ROW=""
    df_metric sessions "$ROW"
    ;;

  subagent-stop)
    COMMAND=""
    [ -f "$OBS_STATE" ] && COMMAND=$(jq -r '.active_command // empty' "$OBS_STATE" 2>/dev/null)
    USAGE=$(transcript_usage "$(field '.agent_transcript_path')")
    COST=$(eval "df_estimate_cost $(printf '%s' "$USAGE" | jq -r '[.model // "", .input_tokens // 0, .output_tokens // 0,
      .cache_creation_tokens // 0, .cache_read_tokens // 0] | @sh' 2>/dev/null)")
    ROW=$(jq -cn --arg ts "$TS" --arg session "$DF_SESSION" --arg host "$DF_HOST" \
      --arg agent_type "$(field '.agent_type')" --arg agent_id "$(field '.agent_id')" \
      --argjson usage "$USAGE" --argjson cost "${COST:-null}" \
      --arg command "$COMMAND" --arg step "$STEP" --arg feature "$FEATURE" \
      '{ts:$ts, session:$session, host:$host, agent_type:$agent_type, agent_id:$agent_id,
        command:$command, step:$step, feature:$feature} + $usage + {estimated_cost_usd:$cost}
       | with_entries(select(.value != "" and .value != null))' 2>/dev/null) || ROW=""
    df_metric subagents "$ROW"
    ;;
esac

exit 0
