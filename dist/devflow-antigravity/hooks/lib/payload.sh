#!/usr/bin/env bash
# shellcheck disable=SC2034  # DF_* are consumed by the hooks that source this file
# lib/payload.sh — host-neutral hook input. Source it, then call df_read_input.
#
# Claude Code stdin:  { hook_event_name, session_id, cwd, transcript_path,
#                       tool_name, tool_input, tool_response }
# Antigravity stdin:  { conversationId, workspacePaths[], transcriptPath,
#                       lastUserInput, modelName, toolCall: {name, args},
#                       error (PostToolUse), ... } — event name comes from
#                       DEVFLOW_EVENT (set by the generated hooks.json); hook
#                       cwd is the plugin dir, so the workspace comes from
#                       workspacePaths[0].
# Legacy `.tool_use.{name,input}` shape still parsed (old fixtures).
#
# After df_read_input:
#   DF_RAW DF_HOST(claude|antigravity) DF_EVENT DF_TOOL_RAW
#   DF_TOOL(shell|write|edit|read|fetch|subagent|other|"")
#   DF_FILE DF_CMD DF_URL DF_IS_ERROR(true|false|"") DF_SESSION DF_TRANSCRIPT
#   DF_WORKSPACE (cwd is changed to it; DEVFLOW_WORKSPACE overrides)
#   Telemetry: DF_CALL_ID (tool_use_id, or conversationId-stepIdx on agy)
#   DF_AGENT_TYPE (set when a subagent made the call) DF_SKILL DF_SUBAGENT_TYPE
#   DF_RESPONSE_CHARS (size of the tool output fed back to the model)
# Returns 1 when jq is missing — callers exit 0 (fail-open).

df_read_input() {
  DF_RAW="$(cat 2>/dev/null || true)"
  DF_HOST="${DEVFLOW_HOST:-}"
  DF_EVENT="" DF_TOOL_RAW="" DF_TOOL="" DF_FILE="" DF_CMD="" DF_URL=""
  DF_IS_ERROR="" DF_SESSION="" DF_TRANSCRIPT="" DF_WORKSPACE=""
  DF_CALL_ID="" DF_AGENT_TYPE="" DF_SKILL="" DF_SUBAGENT_TYPE="" DF_RESPONSE_CHARS=0
  local cwd_in="" event_in="" agy_shape=""

  command -v jq >/dev/null 2>&1 || return 1

  if [ -n "$DF_RAW" ] && printf '%s' "$DF_RAW" | jq -e 'type == "object"' >/dev/null 2>&1; then
    eval "$(printf '%s' "$DF_RAW" | jq -r '
      def obj: if type == "object" then . else {} end;
      ((.tool_input // .toolInput // .toolCall.args // .args // .tool_use.input // {}) | obj) as $i
      | (.tool_response | obj) as $resp
      | ($resp.is_error // $resp.isError // .tool_result.is_error) as $err
      | @sh "event_in=\(.hook_event_name // .hookEventName // "")",
        @sh "agy_shape=\(if (has("conversationId") or has("workspacePaths")) then "1" else "" end)",
        @sh "DF_TOOL_RAW=\(.tool_name // .toolName // .toolCall.name // .tool.name // .tool_use.name // "")",
        @sh "DF_FILE=\($i.file_path // $i.FilePath // $i.TargetFile // $i.Path // $i.AbsolutePath // $i.notebook_path // $i.path // "")",
        @sh "DF_CMD=\($i.command // $i.CommandLine // $i.Command // "")",
        @sh "DF_URL=\($i.url // $i.Url // "")",
        @sh "DF_IS_ERROR=\(if $err != null then ($err | tostring) elif (.hook_event_name // "") == "PostToolUseFailure" then "true" elif (.error | type) == "string" and has("toolCall") then (.error != "" | tostring) else "" end)",
        @sh "DF_SESSION=\(.session_id // .conversationId // "")",
        @sh "DF_TRANSCRIPT=\(.transcript_path // .transcriptPath // "")",
        @sh "cwd_in=\(.cwd // ((.workspacePaths // [])[0]) // "")",
        @sh "DF_CALL_ID=\(.tool_use_id // (if .stepIdx != null then "\(.conversationId // "")-\(.stepIdx)" else "" end))",
        @sh "DF_AGENT_TYPE=\(.agent_type // "")",
        @sh "DF_SKILL=\($i.skill // "")",
        @sh "DF_SUBAGENT_TYPE=\($i.subagent_type // "")",
        @sh "DF_RESPONSE_CHARS=\(.tool_response // .toolCall.output // null | if . == null then 0 elif type == "string" then length else tojson | length end)"
    ' 2>/dev/null)" || true
  else
    DF_RAW=""
  fi

  if [ -z "$DF_HOST" ]; then
    if [ -n "$agy_shape" ]; then DF_HOST="antigravity"; else DF_HOST="claude"; fi
  fi
  DF_EVENT="${event_in:-${DEVFLOW_EVENT:-}}"

  case "$DF_TOOL_RAW" in
    Bash|run_command|execute_command|run_shell_command) DF_TOOL="shell" ;;
    Write|write_to_file|write_file) DF_TOOL="write" ;;
    Edit|MultiEdit|NotebookEdit|replace_file_content|multi_replace_file_content|edit_file) DF_TOOL="edit" ;;
    Read|view_file|read_file) DF_TOOL="read" ;;
    WebFetch|read_url_content) DF_TOOL="fetch" ;;
    Agent|Task|invoke_subagent) DF_TOOL="subagent" ;;
    "") DF_TOOL="" ;;
    *) DF_TOOL="other" ;;
  esac

  # Workspace: payload cwd (Claude Code) or workspacePaths[0] (Antigravity),
  # else the hook's own cwd; then its git toplevel. CLAUDE_PROJECT_DIR is not
  # used: it leaks into test runs launched from inside a Claude Code session.
  local base="${DEVFLOW_WORKSPACE:-${cwd_in:-$PWD}}"
  [ -d "$base" ] || base="$PWD"
  DF_WORKSPACE="$(cd "$base" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || (cd "$base" 2>/dev/null && pwd))"
  [ -n "$DF_WORKSPACE" ] || DF_WORKSPACE="$PWD"
  cd "$DF_WORKSPACE" 2>/dev/null || true
  return 0
}

# df_rel_path <path> — path relative to DF_WORKSPACE (unchanged if outside).
df_rel_path() {
  local p="$1"
  printf '%s' "${p#"$DF_WORKSPACE/"}"
}

# df_is_edit — true when the current tool writes or edits a file.
df_is_edit() {
  [ "$DF_TOOL" = "write" ] || [ "$DF_TOOL" = "edit" ]
}

# ── Locked, atomic JSON state updates ─────────────────────────────────────────
# Hooks run concurrently (async hooks, parallel tool calls). Every read-modify-
# write of a shared file goes through df_lock + mktemp + mv. mkdir is atomic on
# every filesystem and needs no flock (absent on macOS).

df_lock() {
  local lock="$1.lock" i=0
  while ! mkdir "$lock" 2>/dev/null; do
    i=$((i + 1))
    # Stale lock (holder crashed): break it after ~3s of waiting
    if [ "$i" -ge 60 ]; then rm -rf "$lock" 2>/dev/null; mkdir "$lock" 2>/dev/null && return 0; return 1; fi
    sleep 0.05 2>/dev/null || sleep 1
  done
  return 0
}

df_unlock() {
  rm -rf "$1.lock" 2>/dev/null || true
}

# df_json_update <file> <jq-filter> [jq args...]
# Applies <jq-filter> to the file's current object ({} when absent/corrupt) and
# writes the result atomically. Never truncates the file on jq failure.
df_json_update() {
  local file="$1" filter="$2"; shift 2
  local dir tmp base
  dir="$(dirname "$file")"
  df_lock "$file" || return 0
  base="{}"
  if [ -s "$file" ] && jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
    base="$(cat "$file")"
  fi
  tmp="$(mktemp "$dir/.devflow-tmp.XXXXXX" 2>/dev/null)" || { df_unlock "$file"; return 0; }
  if printf '%s' "$base" | jq "$@" "$filter" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv -f "$tmp" "$file" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
  df_unlock "$file"
  return 0
}

# df_append <file> <line> — locked append (keeps concurrent JSONL lines whole).
df_append() {
  df_lock "$1" || return 0
  printf '%s\n' "$2" >> "$1" 2>/dev/null || true
  df_unlock "$1"
}

# df_rotate <file> [max_bytes] — move <file> to <file>.1 when it grows past
# max_bytes (default 1 MiB). Locked so concurrent writers never lose the race.
df_rotate() {
  local file="$1" max="${2:-1048576}" size
  [ -f "$file" ] || return 0
  size=$(wc -c < "$file" 2>/dev/null | tr -d '[:space:]')
  [ -n "$size" ] && [ "$size" -gt "$max" ] 2>/dev/null || return 0
  df_lock "$file" || return 0
  mv -f "$file" "$file.1" 2>/dev/null || true
  df_unlock "$file"
}

# df_gitignore <entry...> — append runtime artefacts to the workspace
# .gitignore (only when one exists and the entry is missing).
df_gitignore() {
  local gi="$DF_WORKSPACE/.gitignore" e
  [ -f "$gi" ] || return 0
  for e in "$@"; do
    grep -qxF "$e" "$gi" 2>/dev/null || printf '%s\n' "$e" >> "$gi" 2>/dev/null || true
  done
}

# ── Local telemetry (.devflow-metrics/) ───────────────────────────────────────
# One gitignored folder per workspace for every usage/cost/timing log.
# DEVFLOW_METRICS_DIR=<path> relocates it, =off disables all telemetry.

# df_metrics_dir — sets DF_METRICS_DIR, creating the folder on first use.
# Returns 1 when telemetry is off or the folder cannot be created.
df_metrics_dir() {
  DF_METRICS_DIR="${DEVFLOW_METRICS_DIR:-$DF_WORKSPACE/.devflow-metrics}"
  [ "$DF_METRICS_DIR" = "off" ] && return 1
  if [ ! -d "$DF_METRICS_DIR" ]; then
    # mkdir (not -p) is the race winner: only one concurrent hook migrates
    mkdir -p "$(dirname "$DF_METRICS_DIR")" 2>/dev/null || return 1
    if mkdir "$DF_METRICS_DIR" 2>/dev/null; then
      df_metrics_migrate
    fi
    [ -d "$DF_METRICS_DIR" ] || return 1
    [ -z "${DEVFLOW_METRICS_DIR:-}" ] && df_gitignore ".devflow-metrics/"
  fi
  return 0
}

# df_metrics_migrate — one-time move of the pre-2.1 root-level logs.
df_metrics_migrate() {
  local pair old new
  for pair in ".devflow-metrics.jsonl:turns.jsonl" ".devflow-timings.jsonl:timings.jsonl" \
              ".devflow-filter-stats.jsonl:filter-stats.jsonl" ".devflow-model-switch.jsonl:model-switch.jsonl"; do
    old="$DF_WORKSPACE/${pair%%:*}" new="$DF_METRICS_DIR/${pair#*:}"
    [ -f "$old.1" ] && { cat "$old.1" >> "$new" 2>/dev/null && rm -f "$old.1"; }
    [ -f "$old" ] && { cat "$old" >> "$new" 2>/dev/null && rm -f "$old"; }
  done
  return 0
}

# df_metric <name> <json-line> — locked append to <dir>/<name>.jsonl (rotated at 2 MiB).
df_metric() {
  df_metrics_dir || return 0
  [ -n "$2" ] || return 0
  df_rotate "$DF_METRICS_DIR/$1.jsonl" 2097152
  df_append "$DF_METRICS_DIR/$1.jsonl" "$2"
}

# df_now_ms — wall clock in milliseconds (bash 5 EPOCHREALTIME, else perl, else seconds).
df_now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local t="${EPOCHREALTIME/,/.}"; printf '%s' "$(( ${t%.*} * 1000 + 10#$(printf '%.3s' "${t#*.}000") ))"
  elif command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%d", time * 1000' 2>/dev/null
  else
    printf '%s' "$(( $(date +%s) * 1000 ))"
  fi
}

# df_plugin_version — plugin version (top-level `version:` of agent.yaml, shipped to both hosts).
df_plugin_version() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  sed -n 's/^version:[[:space:]]*//p' "$root/agent.yaml" 2>/dev/null | head -1 | tr -d "\"' "
}

# df_estimate_cost <model> <in> <out> <cache_write> <cache_read> — USD estimate,
# "null" for unknown model families. Latest generation per family (Fable 5.1,
# Opus 5.5, Sonnet 5.5, Haiku 5.5), USD/MTok, cache_write = 1.25 × input.
# Local estimate for relative tracking, not billing. Override with
# DEVFLOW_PRICING_JSON='{"opus":{"in":4,"out":20,"cache_write":5,"cache_read":0.2}, ...}'
df_estimate_cost() {
  local key cost
  case "$1" in
    *fable*|*mythos*) key="fable" ;;
    *opus*)   key="opus" ;;
    *sonnet*) key="sonnet" ;;
    *haiku*)  key="haiku" ;;
    *) printf 'null'; return 0 ;;
  esac
  local pricing='{
    "fable":  {"in": 10,  "out": 50,  "cache_write": 12.5,  "cache_read": 0.25},
    "opus":   {"in": 4,   "out": 20,  "cache_write": 5,     "cache_read": 0.2},
    "sonnet": {"in": 2,   "out": 10,  "cache_write": 2.5,   "cache_read": 0.2},
    "haiku":  {"in": 0.1, "out": 0.5, "cache_write": 0.125, "cache_read": 0.01}
  }'
  cost=$(jq -n --argjson p "${DEVFLOW_PRICING_JSON:-$pricing}" --arg k "$key" \
    --argjson i "${2:-0}" --argjson o "${3:-0}" --argjson cw "${4:-0}" --argjson cr "${5:-0}" \
    '($p[$k] // null) as $r
     | if $r == null then null
       else ($i * $r.in + $o * $r.out + $cw * ($r.cache_write // $r.in) + $cr * ($r.cache_read // ($r.in / 10))) / 1000000
       end' 2>/dev/null) || cost=""
  printf '%s' "${cost:-null}"
}
