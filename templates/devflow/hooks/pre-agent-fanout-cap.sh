#!/usr/bin/env bash
# pre-agent-fanout-cap.sh
# PreToolUse hook for Claude Code: deterministic backstop on subagent fan-out.
# devflow-ship's thorough profile caps fan-out at 5 agents (code-reviewer,
# security-auditor, test-engineer, accessibility-auditor, docs-reviewer) but
# that cap lives only in skill prose today — a model can miscount or ignore
# it. This hook enforces a hard ceiling regardless of skill compliance.
#
# Counts Agent/Task tool calls within a sliding window (resets after a gap
# with no such calls) and blocks once the ceiling is exceeded. Not aware of
# which skill/profile is running — it's a floor-level safety net, not a
# substitute for devflow-ship's own profile-aware fan-out logic.
#
# Triggered by: Agent|Task (Claude Code), invoke_subagent (Antigravity CLI)
# Input: host payload, parsed by lib/payload.sh
# Block output: lib/emit.sh df_deny → stdout, exit 0
# Allow output: (silent) → exit 0
# Parallel launches fire this hook concurrently: the counter update is locked
# so N simultaneous calls count as N.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

df_read_input || exit 0
[ -z "$DF_RAW" ] && exit 0

WORKSPACE_ROOT="$DF_WORKSPACE"
STATE_FILE="${DEVFLOW_FANOUT_STATE_FILE:-$WORKSPACE_ROOT/.devflow-fanout-state.json}"
WINDOW_MS="${DEVFLOW_FANOUT_WINDOW_MS:-10000}"
MAX_FANOUT="${DEVFLOW_MAX_FANOUT:-5}"

now_ms() {
  python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "$(($(date +%s) * 1000))"
}

NOW=$(now_ms)
df_json_update "$STATE_FILE" '
  (if ($now - ((.last_ts // 0) | tonumber? // 0)) > $window then .count = 0 else . end)
  | .count = (((.count // 0) | tonumber? // 0) + 1)
  | .last_ts = $now' \
  --argjson now "$NOW" --argjson window "$WINDOW_MS"
COUNT=$(jq -r '.count // 0' "$STATE_FILE" 2>/dev/null || echo 0)
[[ "$COUNT" =~ ^[0-9]+$ ]] || COUNT=0
df_gitignore ".devflow-fanout-state.json"

if (( COUNT > MAX_FANOUT )); then
  REASON="Blocked: agent fan-out cap ($MAX_FANOUT) exceeded within ${WINDOW_MS}ms.

devflow.ship's thorough profile tops out at $MAX_FANOUT reviewer agents. Wait for the current batch's results before dispatching more, or reduce scope to the profile's actual agent count."
  df_deny "$REASON"
  exit 0
fi

exit 0
