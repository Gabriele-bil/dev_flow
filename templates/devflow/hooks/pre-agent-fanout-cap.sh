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
# Triggered by: Agent tool (subagent launch — some Claude Code builds expose
# it as "Task")
# Input (stdin): JSON { "tool_use": { "name": "Agent", "input": {...} } }
# Block output:  { "decision": "block", "reason": "..." } → stdout, exit 0
# Allow output:  (silent) → exit 0

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.devflow-fanout-state.json"
WINDOW_MS="${DEVFLOW_FANOUT_WINDOW_MS:-10000}"
MAX_FANOUT="${DEVFLOW_MAX_FANOUT:-5}"

now_ms() {
  python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "$(($(date +%s) * 1000))"
}

NOW=$(now_ms)
LAST_TS=0
COUNT=0
if [[ -f "$STATE_FILE" ]]; then
  LAST_TS=$(jq -r '.last_ts // 0' "$STATE_FILE" 2>/dev/null || echo 0)
  COUNT=$(jq -r '.count // 0' "$STATE_FILE" 2>/dev/null || echo 0)
fi
[[ "$LAST_TS" =~ ^[0-9]+$ ]] || LAST_TS=0
[[ "$COUNT" =~ ^[0-9]+$ ]] || COUNT=0

GAP=$(( NOW - LAST_TS ))
if (( GAP > WINDOW_MS )); then
  COUNT=0
fi
COUNT=$(( COUNT + 1 ))

jq -cn --argjson count "$COUNT" --argjson ts "$NOW" '{count:$count, last_ts:$ts}' > "$STATE_FILE" 2>/dev/null || true

if (( COUNT > MAX_FANOUT )); then
  REASON="Blocked: agent fan-out cap ($MAX_FANOUT) exceeded within ${WINDOW_MS}ms.

devflow.ship's thorough profile tops out at $MAX_FANOUT reviewer agents. Wait for the current batch's results before dispatching more, or reduce scope to the profile's actual agent count."
  printf '%s' "$(jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}')"
  exit 0
fi

exit 0
