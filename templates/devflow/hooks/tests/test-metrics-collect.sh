#!/bin/bash
# shellcheck disable=SC2034  # ROW is read inside single-quoted check() strings via eval
# test-metrics-collect.sh — local telemetry folder (.devflow-metrics/):
# metrics-collect.sh lifecycle rows, observe.sh tool rows, lib/emit.sh context
# rows, gitignore entry, off switch. Real Claude Code / Antigravity payloads.
# Usage: bash templates/devflow/hooks/tests/test-metrics-collect.sh

set -uo pipefail

HOOKS="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$HOOKS/tests/fixtures"
PASS=0
FAIL=0

assert() {
  if [ "$2" = "pass" ]; then PASS=$((PASS + 1)); echo "  PASS: $1"
  else FAIL=$((FAIL + 1)); echo "  FAIL: $1"; fi
}
check() { if eval "$2"; then assert "$1" pass; else assert "$1" fail; fi; }

new_ws() {
  local d; d=$(mktemp -d 2>/dev/null || mktemp -d -t devflow-test)
  (cd "$d" && git init -q && printf 'node_modules/\n' > .gitignore)
  printf '%s' "$d"
}
fixture() { sed "s#__WS__#$1#g; s#__HOME__#$HOME#g" "$FIX/$2"; }
run() { local ws="$1" script="$2"; shift 2; (cd "$ws" && bash "$HOOKS/$script" "$@" >/dev/null 2>&1) || true; }
last() { tail -1 "$1/.devflow-metrics/$2.jsonl" 2>/dev/null; }

echo "metrics-collect / tool telemetry tests"
echo "──────────────────────────────────────"

# ── T1: session-start row, folder gitignored ────────────────────────────────
d=$(new_ws)
fixture "$d" claude/session-start.json | run "$d" metrics-collect.sh session-start
ROW=$(last "$d" sessions)
check "T1a: session_start row with source and host" \
  '[ "$(jq -r ".event + \"/\" + .source + \"/\" + .host" <<<"$ROW")" = "session_start/startup/claude" ]'
check "T1b: plugin version recorded" '[ -n "$(jq -r ".plugin_version // empty" <<<"$ROW")" ]'
check "T1c: .devflow-metrics/ added to .gitignore once" '[ "$(grep -cxF ".devflow-metrics/" "$d/.gitignore")" = "1" ]'
fixture "$d" claude/session-start.json | run "$d" metrics-collect.sh session-start
check "T1d: no duplicate gitignore entry on reuse" '[ "$(grep -cxF ".devflow-metrics/" "$d/.gitignore")" = "1" ]'
rm -rf "$d"

# ── T2: prompt row stores size + command, never the text; marks the turn ───
d=$(new_ws)
jq -cn --arg ws "$d" '{session_id:"s1", cwd:$ws, hook_event_name:"UserPromptSubmit", prompt:"/devflow:devflow-implement secret-token-xyz"}' \
  | run "$d" metrics-collect.sh prompt
ROW=$(last "$d" prompts)
check "T2a: slash command and devflow command recorded" \
  '[ "$(jq -r ".slash_command + \"|\" + .command" <<<"$ROW")" = "devflow:devflow-implement|implement" ]'
check "T2b: prompt text never stored" '! grep -q "secret-token-xyz" "$d/.devflow-metrics/prompts.jsonl"'
check "T2c: turn start + active command marked for stop-metrics" \
  '[ "$(jq -r "(.prompt_started_ms > 0 | tostring) + \"|\" + .active_command" "$d/.devflow-observe-state.json")" = "true|implement" ]'
rm -rf "$d"

# ── T3: tool row — duration from pre/post pair, output size, MCP server ────
d=$(new_ws)
fixture "$d" claude/pre-bash.json | run "$d" observe.sh pre
jq -c '.hook_event_name = "PostToolUse" | .tool_response = {stdout: "0123456789012345678901234567890123456789"}' "$FIX/claude/pre-bash.json" \
  | sed "s#__WS__#$d#g" | run "$d" observe.sh post
ROW=$(last "$d" tools)
check "T3a: tool row has duration_ms" '[ "$(jq -r ".duration_ms | type" <<<"$ROW")" = "number" ]'
check "T3b: output size measured" '[ "$(jq -r ".output_chars" <<<"$ROW")" -gt 40 ]'
check "T3c: pending start mark consumed" '[ -z "$(ls -A "$d/.devflow-metrics/.pending" 2>/dev/null)" ]'
jq -cn --arg ws "$d" '{session_id:"s1", cwd:$ws, hook_event_name:"PostToolUseFailure", tool_name:"mcp__serena__find_symbol", tool_input:{}, tool_use_id:"toolu_9", error:"boom"}' \
  | run "$d" observe.sh post
ROW=$(last "$d" tools)
check "T3d: failed MCP call → mcp_server + is_error" \
  '[ "$(jq -r ".mcp_server + \"|\" + (.is_error | tostring)" <<<"$ROW")" = "serena|true" ]'
rm -rf "$d"

# ── T4: Skill tool attributes the devflow command ───────────────────────────
d=$(new_ws)
jq -cn --arg ws "$d" '{session_id:"s1", cwd:$ws, hook_event_name:"PreToolUse", tool_name:"Skill", tool_input:{skill:"devflow:devflow-ship"}, tool_use_id:"toolu_7"}' \
  | run "$d" observe.sh pre
check "T4: Skill load sets active_command" '[ "$(jq -r ".active_command" "$d/.devflow-observe-state.json")" = "ship" ]'
rm -rf "$d"

# ── T5: Antigravity tool pair matched by conversationId-stepIdx ─────────────
d=$(new_ws)
fixture "$d" antigravity/pre-tool-read.json | run "$d" observe.sh pre
fixture "$d" antigravity/post-tool-read.json | run "$d" observe.sh post
ROW=$(last "$d" tools)
check "T5: Antigravity tool row with host and duration" \
  '[ "$(jq -r ".host + \"|\" + (.duration_ms | type)" <<<"$ROW")" = "antigravity|number" ]'
rm -rf "$d"

# ── T6: subagent tokens, duration and cost from its own transcript ──────────
d=$(new_ws)
cat > "$d/agent.jsonl" <<'EOF'
{"type":"assistant","timestamp":"2026-11-04T10:00:00.000Z","message":{"id":"a1","model":"claude-sonnet-5-5","usage":{"input_tokens":100,"output_tokens":300,"cache_creation_input_tokens":2000,"cache_read_input_tokens":0},"content":[{"type":"tool_use","id":"x1","name":"Read","input":{}}]}}
{"type":"assistant","timestamp":"2026-11-04T10:00:12.500Z","message":{"id":"a2","model":"claude-sonnet-5-5","usage":{"input_tokens":50,"output_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":2000}}}
EOF
jq -cn --arg ws "$d" '{session_id:"s1", cwd:$ws, hook_event_name:"SubagentStop", agent_type:"code-reviewer", agent_id:"ag1", agent_transcript_path:($ws + "/agent.jsonl")}' \
  | run "$d" metrics-collect.sh subagent-stop
ROW=$(last "$d" subagents)
check "T6a: subagent tokens summed" '[ "$(jq -r ".input_tokens + .output_tokens" <<<"$ROW")" = "550" ]'
check "T6b: subagent duration and tool calls" '[ "$(jq -r "[.duration_ms, .tool_calls] | join(\",\")" <<<"$ROW")" = "12500,1" ]'
check "T6c: subagent cost estimated" '[ "$(jq -r ".estimated_cost_usd | type" <<<"$ROW")" = "number" ]'
rm -rf "$d"

# ── T7: compaction row carries trigger and context size ─────────────────────
d=$(new_ws)
printf '%s\n' '{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":5,"cache_creation_input_tokens":1000,"cache_read_input_tokens":150000,"output_tokens":10}}}' > "$d/transcript.jsonl"
fixture "$d" claude/pre-compact.json | run "$d" metrics-collect.sh pre-compact
ROW=$(last "$d" sessions)
check "T7: compact event with trigger and context_tokens" \
  '[ "$(jq -r ".event + \"|\" + .trigger + \"|\" + (.context_tokens | tostring)" <<<"$ROW")" = "compact|auto|151005" ]'
rm -rf "$d"

# ── T8: context injected by a hook is measured ──────────────────────────────
d=$(new_ws)
mkdir -p "$d/devflow"
fixture "$d" claude/session-start.json | run "$d" session-start.sh
ROW=$(last "$d" context)
check "T8: session-start injection logged with size" \
  '[ "$(jq -r ".hook" <<<"$ROW")" = "session-start" ] && [ "$(jq -r ".est_tokens" <<<"$ROW")" -gt 0 ]'
rm -rf "$d"

# ── T9: DEVFLOW_METRICS_DIR=off → nothing written, .gitignore untouched ────
d=$(new_ws)
fixture "$d" claude/session-start.json | (cd "$d" && DEVFLOW_METRICS_DIR=off bash "$HOOKS/metrics-collect.sh" session-start >/dev/null 2>&1)
fixture "$d" claude/pre-bash.json | (cd "$d" && DEVFLOW_METRICS_DIR=off bash "$HOOKS/observe.sh" pre >/dev/null 2>&1)
check "T9: off switch writes no telemetry folder" '[ ! -e "$d/.devflow-metrics" ] && ! grep -qF ".devflow-metrics/" "$d/.gitignore"'
rm -rf "$d"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
