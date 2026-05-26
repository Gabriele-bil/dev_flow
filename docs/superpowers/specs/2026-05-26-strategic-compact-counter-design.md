# Strategic Compact Counter — Design Spec

**Date:** 2026-05-26  
**Status:** Approved  
**Files in scope:** `templates/devflow/hooks/observe.sh`, `templates/devflow/hooks/hooks.json`

---

## Problem

Claude Code's auto-compaction kicks in late, often mid-task. There is no proactive signal to the user that context is growing large. We want to suggest `/compact` at *natural break points* in the conversation — end of a Claude turn (Stop event) or end of a pipeline phase (step change) — rather than interrupting mid-work.

---

## Solution

Add a `tool_call_count` counter to `.devflow-state.json`, incremented on every `PostToolUse` event. When the count exceeds a configurable threshold **and** a natural break point is detected, emit an advisory on `stderr`.

---

## Natural Break Points

| Trigger | When it fires | Hook event |
|---|---|---|
| End of Claude turn | Every time Claude finishes responding | `Stop` |
| Pipeline step change | When `next_step` in `.devflow-state.json` changes | `PostToolUse` (detected inline) |

The advisory is **not** emitted on every tool call — only at these moments. This avoids noise mid-task.

---

## Configuration

| Env var | Default | Meaning |
|---|---|---|
| `DEVFLOW_COMPACT_THRESHOLD` | `50` | Tool calls before advisories become active |

---

## Advisory Message

Emitted to `stderr` (visible to Claude as hook output):

```
⚡ devflow: ~<N> tool calls this session — consider /compact to keep context fresh.
```

---

## State Shape

`observe.sh` adds three fields to `.devflow-state.json` (alongside existing fields, never removes them):

```json
{
  "tool_call_count": 57,
  "last_session_id": "abc-123",
  "last_observed_step": "build"
}
```

| Field | Written by | Purpose |
|---|---|---|
| `tool_call_count` | `observe.sh post` | Cumulative count for current session |
| `last_session_id` | `observe.sh post` | Detects new session → triggers counter reset |
| `last_observed_step` | `observe.sh post` | Detects step change → triggers advisory at step transitions |

---

## observe.sh Changes

### `post` event (existing block — additions)

1. Read `tool_call_count` and `last_session_id` from state file (default 0 / empty if absent)
2. If `SESSION != last_session_id` → reset `tool_call_count = 0`, `last_observed_step = ""`
3. Increment `tool_call_count += 1`
4. Write updated state atomically: `jq ... > tmp && mv tmp state`
5. If `tool_call_count >= THRESHOLD` and `STEP != last_observed_step` and `STEP != ""` → emit advisory to stderr
6. Update `last_observed_step = STEP` in state

### `stop` event (new)

1. Read `tool_call_count` and `DEVFLOW_COMPACT_THRESHOLD` (default 50)
2. If `tool_call_count >= THRESHOLD` → emit advisory to stderr
3. Exit 0

---

## hooks.json Change

Add a Stop hook entry:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/observe.sh stop",
      "async": true,
      "timeout": 5
    }
  ]
}
```

---

## Reset Logic

Counter resets automatically when `observe.sh post` detects a new `session_id` (i.e., a new Claude session started). No changes to `session-start.sh` are needed.

---

## Error Handling

- All state reads/writes wrapped with `|| true` (existing pattern in observe.sh)
- If `.devflow-state.json` is missing or malformed: counter treated as 0, script continues
- Atomic state write: `jq > .devflow-state.json.tmp && mv .devflow-state.json.tmp .devflow-state.json`
- If `SESSION` is empty (no session_id in hook input): skip session-reset check, still increment

---

## Out of Scope

- Resetting counter via `PreCompact` hook (could be added later)
- Making repeat interval configurable (fires every natural break point when above threshold)
- Tracking per-tool breakdown in the advisory
