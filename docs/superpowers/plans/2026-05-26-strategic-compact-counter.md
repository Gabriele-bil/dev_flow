# Strategic Compact Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Proactively suggest `/compact` at natural conversational break points (end of Claude turn, pipeline step change) when the tool-call counter exceeds a configurable threshold.

**Architecture:** `observe.sh` already runs on every PostToolUse event. We extend its `post` block to maintain a `tool_call_count` in `.devflow-state.json` (with session-ID-based reset and step-change advisory), and add a new `stop` event handler called from a new Stop hook entry. No new files needed.

**Tech Stack:** Bash, jq (already required by observe.sh), standard POSIX tools.

---

## File Map

| File | Action | What changes |
|---|---|---|
| `templates/devflow/hooks/observe.sh` | Modify | Add counter + advisory logic to `post` block; add `stop` event handler |
| `templates/devflow/hooks/hooks.json` | Modify | Add Stop hook entry for `observe.sh stop` |
| `templates/devflow/hooks/tests/test-compact-counter.sh` | Create | Unit tests for all new behaviour |

---

## Task 1: Write the failing tests

**Files:**
- Create: `templates/devflow/hooks/tests/test-compact-counter.sh`

- [ ] **Step 1.1: Create test file**

```bash
cat > templates/devflow/hooks/tests/test-compact-counter.sh << 'TESTEOF'
#!/bin/bash
# test-compact-counter.sh — Unit tests for strategic-compact counter in observe.sh
# Usage: bash templates/devflow/hooks/tests/test-compact-counter.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/observe.sh"
PASS=0
FAIL=0
ERRORS=()

# ── helpers ──────────────────────────────────────────────────────────────────

tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t devflow-test
}

run_post() {
  local workdir="$1" tool="${2:-Bash}" session="${3:-sess-001}" step="${4:-}"
  local payload
  payload=$(jq -cn \
    --arg tool    "$tool" \
    --arg session "$session" \
    --arg step    "$step" \
    '{
      tool_use:    {name: $tool},
      session_id:  $session,
      tool_result: {is_error: false}
    }')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK" post 2>/tmp/devflow-test-stderr) || true
}

run_stop() {
  local workdir="$1" session="${2:-sess-001}"
  local payload
  payload=$(jq -cn --arg session "$session" '{session_id: $session}')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK" stop 2>/tmp/devflow-test-stderr) || true
}

read_counter() {
  local workdir="$1"
  jq -r '.tool_call_count // 0' "$workdir/.devflow-state.json" 2>/dev/null || echo 0
}

read_last_session() {
  local workdir="$1"
  jq -r '.last_session_id // empty' "$workdir/.devflow-state.json" 2>/dev/null || echo ""
}

read_last_step() {
  local workdir="$1"
  jq -r '.last_observed_step // empty' "$workdir/.devflow-state.json" 2>/dev/null || echo ""
}

stderr_contains() {
  grep -qF "$1" /tmp/devflow-test-stderr 2>/dev/null
}

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $label")
    echo "  FAIL: $label"
  fi
}

# ── tests ─────────────────────────────────────────────────────────────────────

echo "=== test-compact-counter.sh ==="
echo ""

# T1: counter increments on post
echo "--- T1: counter increments on post ---"
D=$(tmpdir)
run_post "$D" Bash sess-1
count=$(read_counter "$D")
[ "$count" -eq 1 ] && assert "counter is 1 after first post" pass \
                    || assert "counter is 1 after first post (got $count)" fail
run_post "$D" Bash sess-1
count=$(read_counter "$D")
[ "$count" -eq 2 ] && assert "counter is 2 after second post" pass \
                    || assert "counter is 2 after second post (got $count)" fail
rm -rf "$D"

# T2: last_session_id written correctly
echo "--- T2: last_session_id stored ---"
D=$(tmpdir)
run_post "$D" Bash sess-abc
sess=$(read_last_session "$D")
[ "$sess" = "sess-abc" ] && assert "last_session_id stored" pass \
                          || assert "last_session_id stored (got '$sess')" fail
rm -rf "$D"

# T3: counter resets on new session
echo "--- T3: counter resets on new session ---"
D=$(tmpdir)
run_post "$D" Bash sess-1
run_post "$D" Bash sess-1
run_post "$D" Bash sess-2   # new session
count=$(read_counter "$D")
[ "$count" -eq 1 ] && assert "counter reset to 1 on new session" pass \
                    || assert "counter reset to 1 on new session (got $count)" fail
rm -rf "$D"

# T4: no advisory below threshold (stop event)
echo "--- T4: no advisory below threshold at stop ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=5
for i in $(seq 1 4); do run_post "$D" Bash sess-1; done
run_stop "$D" sess-1
stderr_contains "devflow" \
  && assert "no advisory below threshold at stop" fail \
  || assert "no advisory below threshold at stop" pass
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T5: advisory emitted on stop when count >= threshold
echo "--- T5: advisory emitted at stop when threshold reached ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=3
for i in $(seq 1 3); do run_post "$D" Bash sess-1; done
run_stop "$D" sess-1
stderr_contains "devflow" \
  && assert "advisory emitted at stop (threshold=3, count=3)" pass \
  || assert "advisory emitted at stop (threshold=3, count=3)" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T6: advisory on stop contains tool call count
echo "--- T6: advisory message contains call count ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=2
for i in $(seq 1 2); do run_post "$D" Bash sess-1; done
run_stop "$D" sess-1
stderr_contains "/compact" \
  && assert "advisory mentions /compact" pass \
  || assert "advisory mentions /compact" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T7: no advisory on stop after session reset
echo "--- T7: no advisory after session reset (counter back below threshold) ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=3
for i in $(seq 1 3); do run_post "$D" Bash sess-1; done
# new session — counter resets
run_post "$D" Bash sess-2
run_stop "$D" sess-2
stderr_contains "devflow" \
  && assert "no advisory after session reset" fail \
  || assert "no advisory after session reset" pass
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T8: step-change advisory when above threshold
echo "--- T8: step-change triggers advisory when above threshold ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=2
# Seed state with step=build so first run sees a change
printf '{"next_step":"build"}' > "$D/.devflow-state.json"
for i in $(seq 1 2); do run_post "$D" Bash sess-1 "build"; done
# Now run with a different step
(cd "$D" && jq '.next_step = "review"' .devflow-state.json > .devflow-state.json.tmp && mv .devflow-state.json.tmp .devflow-state.json)
payload=$(jq -cn '{tool_use:{name:"Bash"},session_id:"sess-1",tool_result:{is_error:false}}')
(cd "$D" && printf '%s' "$payload" | bash "$HOOK" post 2>/tmp/devflow-test-stderr) || true
stderr_contains "devflow" \
  && assert "step-change triggers advisory when above threshold" pass \
  || assert "step-change triggers advisory when above threshold" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T9: no step-change advisory below threshold
echo "--- T9: no step-change advisory below threshold ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=10
printf '{"next_step":"build","last_observed_step":"build","tool_call_count":1,"last_session_id":"sess-1"}' > "$D/.devflow-state.json"
(cd "$D" && jq '.next_step = "review"' .devflow-state.json > .devflow-state.json.tmp && mv .devflow-state.json.tmp .devflow-state.json)
payload=$(jq -cn '{tool_use:{name:"Bash"},session_id:"sess-1",tool_result:{is_error:false}}')
(cd "$D" && printf '%s' "$payload" | bash "$HOOK" post 2>/tmp/devflow-test-stderr) || true
stderr_contains "devflow" \
  && assert "no step-change advisory below threshold" fail \
  || assert "no step-change advisory below threshold" pass
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T10: last_observed_step updated after step change
echo "--- T10: last_observed_step updated after post ---"
D=$(tmpdir)
printf '{"next_step":"plan","tool_call_count":0,"last_session_id":"sess-1","last_observed_step":"build"}' > "$D/.devflow-state.json"
run_post "$D" Bash sess-1 "plan"
step=$(read_last_step "$D")
[ "$step" = "plan" ] && assert "last_observed_step updated to plan" pass \
                      || assert "last_observed_step updated to plan (got '$step')" fail
rm -rf "$D"

# T11: existing state fields not clobbered by counter write
echo "--- T11: existing state fields preserved ---"
D=$(tmpdir)
printf '{"feature":"my-feature","next_step":"build","tool_call_count":0,"last_session_id":"sess-1","last_observed_step":"build"}' > "$D/.devflow-state.json"
run_post "$D" Bash sess-1
feature=$(jq -r '.feature // empty' "$D/.devflow-state.json" 2>/dev/null)
[ "$feature" = "my-feature" ] && assert "feature field preserved after counter write" pass \
                               || assert "feature field preserved after counter write (got '$feature')" fail
rm -rf "$D"

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "Failures:"
  for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
TESTEOF
chmod +x templates/devflow/hooks/tests/test-compact-counter.sh
```

- [ ] **Step 1.2: Run tests — verify they fail (observe.sh not yet modified)**

```bash
bash templates/devflow/hooks/tests/test-compact-counter.sh
```

Expected: most tests FAIL (counter-related assertions fail since the fields don't exist yet). Tests for existing behaviour (retry loop) should be unaffected. Exit code non-zero.

---

## Task 2: Add counter logic to `observe.sh` post block

**Files:**
- Modify: `templates/devflow/hooks/observe.sh` — post block (currently lines 92–170)

- [ ] **Step 2.1: Add counter + session-reset + atomic-write logic**

In `observe.sh`, after the existing `IS_ERROR` extraction (line ~94) and the existing JSONL append block (lines ~96–109), add the following **before** the retry-loop detection block:

```bash
  # ----------------------------------------------------------------
  # Strategic-compact counter: track cumulative tool calls per session
  # ----------------------------------------------------------------
  COMPACT_THRESHOLD="${DEVFLOW_COMPACT_THRESHOLD:-50}"

  # Read current counter state (defaults if absent or malformed)
  STORED_COUNT=0
  STORED_SESSION=""
  STORED_LAST_STEP=""
  if [ -f "$STATE_FILE" ]; then
    STORED_COUNT=$(jq -r '.tool_call_count // 0'        "$STATE_FILE" 2>/dev/null) || STORED_COUNT=0
    STORED_SESSION=$(jq -r '.last_session_id // empty'  "$STATE_FILE" 2>/dev/null) || STORED_SESSION=""
    STORED_LAST_STEP=$(jq -r '.last_observed_step // empty' "$STATE_FILE" 2>/dev/null) || STORED_LAST_STEP=""
  fi

  # Session reset: new session_id means fresh context — reset counter
  if [ -n "$SESSION" ] && [ "$SESSION" != "$STORED_SESSION" ]; then
    STORED_COUNT=0
    STORED_LAST_STEP=""
  fi

  NEW_COUNT=$(( STORED_COUNT + 1 ))

  # Atomic state write: merge counter fields into existing state
  STATE_TMP="${STATE_FILE}.tmp"
  if [ -f "$STATE_FILE" ]; then
    jq \
      --argjson count "$NEW_COUNT" \
      --arg session "$SESSION" \
      --arg last_step "$STORED_LAST_STEP" \
      '. + {tool_call_count: $count, last_session_id: $session, last_observed_step: $last_step}' \
      "$STATE_FILE" > "$STATE_TMP" 2>/dev/null \
      && mv "$STATE_TMP" "$STATE_FILE" 2>/dev/null || true
  else
    jq -cn \
      --argjson count "$NEW_COUNT" \
      --arg session "$SESSION" \
      --arg last_step "$STORED_LAST_STEP" \
      '{tool_call_count: $count, last_session_id: $session, last_observed_step: $last_step}' \
      > "$STATE_TMP" 2>/dev/null \
      && mv "$STATE_TMP" "$STATE_FILE" 2>/dev/null || true
  fi

  # Step-change advisory: if pipeline step changed AND above threshold → advise
  CURRENT_STEP="$STEP"
  if [ -n "$CURRENT_STEP" ] \
      && [ "$CURRENT_STEP" != "$STORED_LAST_STEP" ] \
      && [ -n "$STORED_LAST_STEP" ] \
      && [ "$NEW_COUNT" -ge "$COMPACT_THRESHOLD" ] 2>/dev/null; then
    printf '⚡ devflow: ~%s tool calls this session — consider /compact to keep context fresh.\n' \
      "$NEW_COUNT" >&2
  fi

  # Update last_observed_step to current step (only if step is non-empty)
  if [ -n "$CURRENT_STEP" ] && [ "$CURRENT_STEP" != "$STORED_LAST_STEP" ]; then
    if [ -f "$STATE_FILE" ]; then
      jq --arg step "$CURRENT_STEP" '.last_observed_step = $step' \
        "$STATE_FILE" > "$STATE_TMP" 2>/dev/null \
        && mv "$STATE_TMP" "$STATE_FILE" 2>/dev/null || true
    fi
  fi
```

- [ ] **Step 2.2: Run T1–T3 and T8–T11 to verify counter/step logic passes**

```bash
bash templates/devflow/hooks/tests/test-compact-counter.sh 2>&1 | grep -E "^  (PASS|FAIL)|Results"
```

Expected: T1, T2, T3, T8, T9, T10, T11 now PASS. T4–T7 still FAIL (stop event not yet implemented).

- [ ] **Step 2.3: Commit**

```bash
git add templates/devflow/hooks/observe.sh templates/devflow/hooks/tests/test-compact-counter.sh
git commit -m "feat(observe): add tool-call counter and step-change compact advisory"
```

---

## Task 3: Add `stop` event handler to `observe.sh`

**Files:**
- Modify: `templates/devflow/hooks/observe.sh` — add `stop` branch to event dispatch

- [ ] **Step 3.1: Add stop handler**

In `observe.sh`, the main dispatch is the `if [ "$EVENT" = "pre" ]` / `elif [ "$EVENT" = "post" ]` block. Add an `elif` for `stop` **after** the post block (before the gitignore section at the bottom):

```bash
elif [ "$EVENT" = "stop" ]; then
  # ----------------------------------------------------------------
  # Stop advisory: emit compact suggestion if counter >= threshold
  # ----------------------------------------------------------------
  COMPACT_THRESHOLD="${DEVFLOW_COMPACT_THRESHOLD:-50}"
  CURRENT_COUNT=0
  if [ -f "$STATE_FILE" ]; then
    CURRENT_COUNT=$(jq -r '.tool_call_count // 0' "$STATE_FILE" 2>/dev/null) || CURRENT_COUNT=0
  fi
  if [ "$CURRENT_COUNT" -ge "$COMPACT_THRESHOLD" ] 2>/dev/null; then
    printf '⚡ devflow: ~%s tool calls this session — consider /compact to keep context fresh.\n' \
      "$CURRENT_COUNT" >&2
  fi
fi
```

Also update the guard at the top of the file that rejects unknown events. Currently it reads:

```bash
if [ "$EVENT" != "pre" ] && [ "$EVENT" != "post" ]; then
  exit 0
fi
```

Change it to:

```bash
if [ "$EVENT" != "pre" ] && [ "$EVENT" != "post" ] && [ "$EVENT" != "stop" ]; then
  exit 0
fi
```

- [ ] **Step 3.2: Run all tests — expect full pass**

```bash
bash templates/devflow/hooks/tests/test-compact-counter.sh
```

Expected output:
```
=== test-compact-counter.sh ===

--- T1: counter increments on post ---
  PASS: counter is 1 after first post
  PASS: counter is 2 after second post
--- T2: last_session_id stored ---
  PASS: last_session_id stored
--- T3: counter resets on new session ---
  PASS: counter reset to 1 on new session
--- T4: no advisory below threshold at stop ---
  PASS: no advisory below threshold at stop
--- T5: advisory emitted at stop when threshold reached ---
  PASS: advisory emitted at stop (threshold=3, count=3)
--- T6: advisory message contains call count ---
  PASS: advisory mentions /compact
--- T7: no advisory after session reset (counter back below threshold) ---
  PASS: no advisory after session reset
--- T8: step-change triggers advisory when above threshold ---
  PASS: step-change triggers advisory when above threshold
--- T9: no step-change advisory below threshold ---
  PASS: no step-change advisory below threshold
--- T10: last_observed_step updated after post ---
  PASS: last_observed_step updated to plan
--- T11: existing state fields preserved ---
  PASS: feature field preserved after counter write

Results: 11 passed, 0 failed
```

- [ ] **Step 3.3: Validate hook script syntax**

```bash
bash -n templates/devflow/hooks/observe.sh && echo "syntax OK"
```

Expected: `syntax OK`

- [ ] **Step 3.4: Commit**

```bash
git add templates/devflow/hooks/observe.sh
git commit -m "feat(observe): add stop event handler for compact advisory"
```

---

## Task 4: Register Stop hook in `hooks.json`

**Files:**
- Modify: `templates/devflow/hooks/hooks.json`

- [ ] **Step 4.1: Add Stop hook entry**

In `hooks.json`, the `"Stop"` array currently has 4 entries. Add a fifth entry at the **end** of the `Stop` array (after `stop-learn-distill.sh`):

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

The full `Stop` array after the change:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-format-typecheck.sh"
      }
    ]
  },
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-notify.sh",
        "async": true,
        "timeout": 10
      }
    ]
  },
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-debug-check.sh"
      }
    ]
  },
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-learn-distill.sh"
      }
    ]
  },
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
]
```

- [ ] **Step 4.2: Validate JSON is well-formed**

```bash
jq empty templates/devflow/hooks/hooks.json && echo "valid JSON"
```

Expected: `valid JSON`

- [ ] **Step 4.3: Commit**

```bash
git add templates/devflow/hooks/hooks.json
git commit -m "feat(hooks): register observe.sh stop as Stop lifecycle hook"
```

---

## Task 5: Rebuild dist and run build verification

**Files:**
- Modify: `dist/devflow/` (build output)

- [ ] **Step 5.1: Validate all SKILL.md files (unchanged, sanity check)**

```bash
bash templates/devflow/scripts/validate-skills.sh
```

Expected: all skills valid, exit 0.

- [ ] **Step 5.2: Rebuild dist**

```bash
bash scripts/build-plugin.sh
```

Expected: exits 0, `dist/devflow/` updated.

- [ ] **Step 5.3: Run full test suite**

```bash
bash templates/devflow/hooks/tests/test-retry-loop.sh && echo "retry-loop OK"
bash templates/devflow/hooks/tests/test-compact-counter.sh && echo "compact-counter OK"
```

Expected: both print `OK`.

- [ ] **Step 5.4: Final commit**

```bash
git add dist/
git commit -m "build: rebuild dist after strategic-compact counter feature"
```
