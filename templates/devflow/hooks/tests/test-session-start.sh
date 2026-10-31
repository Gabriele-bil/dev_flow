#!/bin/bash
# test-session-start.sh — Unit tests for session-start.sh orientation injection
# Covers: inactive pointer, state-aware compact branch, full meta-skill branch,
# corrupted/unknown state fallback, config warning in both branches.
# Usage: bash templates/devflow/hooks/tests/test-session-start.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/session-start.sh"
PASS=0
FAIL=0
ERRORS=()

# ── helpers ──────────────────────────────────────────────────────────────────

tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t devflow-test
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

OUT=/tmp/devflow-test-sessionstart-out

# run_hook <workdir> <config-file>
run_hook() {
  local workdir="$1" config="$2"
  (cd "$workdir" && DEVFLOW_CONFIG_FILE="$config" bash "$HOOK" </dev/null >"$OUT" 2>&1) || true
}

# write a configured (no [TODO) or unconfigured config.md
write_config() {
  local path="$1" state="$2"
  if [ "$state" = "configured" ]; then
    printf '# DevFlow Configuration\n\n**Adapter:** flutter\n' > "$path"
  else
    printf '# DevFlow Configuration\n\n**Adapter:** [TODO: fill]\n' > "$path"
  fi
}

# ── tests ─────────────────────────────────────────────────────────────────────

echo "=== test-session-start.sh ==="
echo ""

# T1: inactive project → short pointer, no orientation content
echo "--- T1: inactive project ---"
D=$(tmpdir)
write_config "$D/config.md" "unconfigured"
run_hook "$D" "$D/config.md"
jq -e '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | test("not set up"))' "$OUT" >/dev/null 2>&1 \
  && assert "SessionStart additionalContext pointer for inactive project" pass \
  || assert "SessionStart additionalContext pointer for inactive project" fail
grep -q "## Decision tree" "$OUT" \
  && assert "no decision tree injected" fail \
  || assert "no decision tree injected" pass
rm -rf "$D"

# T2: active + state with known next_step → compact IMPORTANT message
echo "--- T2: compact branch on known next_step ---"
D=$(tmpdir)
mkdir "$D/devflow"
write_config "$D/config.md" "configured"
printf '{"next_step":"devflow.implement","feature":"001_login"}' > "$D/.devflow-state.json"
run_hook "$D" "$D/config.md"
jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' "$OUT" >/dev/null 2>&1 \
  && assert "SessionStart additionalContext JSON" pass \
  || assert "SessionStart additionalContext JSON" fail
grep -q "devflow.implement" "$OUT" \
  && assert "next step named" pass \
  || assert "next step named" fail
grep -q "run /devflow:implement" "$OUT" \
  && assert "Claude Code slash form suggested" pass \
  || assert "Claude Code slash form suggested" fail
grep -q "001_login" "$OUT" \
  && assert "feature named" pass \
  || assert "feature named" fail
grep -q "contexts/" "$OUT" \
  && assert "no context file hinted (the skill is the context)" fail \
  || assert "no context file hinted (the skill is the context)" pass
grep -q "## Decision tree" "$OUT" \
  && assert "meta-skill NOT injected (compact)" fail \
  || assert "meta-skill NOT injected (compact)" pass
grep -q "devflow not configured" "$OUT" \
  && assert "no config warning when configured" fail \
  || assert "no config warning when configured" pass
rm -rf "$D"

# T3: active without state file → full meta-skill injection
echo "--- T3: full branch without state ---"
D=$(tmpdir)
mkdir "$D/devflow"
write_config "$D/config.md" "configured"
run_hook "$D" "$D/config.md"
jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' "$OUT" >/dev/null 2>&1 \
  && assert "SessionStart additionalContext JSON" pass \
  || assert "SessionStart additionalContext JSON" fail
grep -q "## Decision tree" "$OUT" \
  && assert "full meta-skill injected" pass \
  || assert "full meta-skill injected" fail
rm -rf "$D"

# T4: corrupted state / unknown next_step → full meta-skill injection
echo "--- T4: fallback on bad state ---"
D=$(tmpdir)
mkdir "$D/devflow"
write_config "$D/config.md" "configured"
printf 'not-json{{{' > "$D/.devflow-state.json"
run_hook "$D" "$D/config.md"
grep -q "## Decision tree" "$OUT" \
  && assert "corrupted state → full injection" pass \
  || assert "corrupted state → full injection" fail

printf '{"next_step":"devflow.bogus"}' > "$D/.devflow-state.json"
run_hook "$D" "$D/config.md"
grep -q "## Decision tree" "$OUT" \
  && assert "unknown next_step → full injection" pass \
  || assert "unknown next_step → full injection" fail
rm -rf "$D"

# T5: unconfigured config.md → warning present in both branches
echo "--- T5: config warning ---"
D=$(tmpdir)
mkdir "$D/devflow"
write_config "$D/config.md" "unconfigured"
printf '{"next_step":"devflow.plan","feature":"002_x"}' > "$D/.devflow-state.json"
run_hook "$D" "$D/config.md"
grep -q "devflow not configured" "$OUT" \
  && assert "warning in compact branch" pass \
  || assert "warning in compact branch" fail

rm "$D/.devflow-state.json"
run_hook "$D" "$D/config.md"
grep -q "devflow not configured" "$OUT" \
  && assert "warning in full branch" pass \
  || assert "warning in full branch" fail
rm -rf "$D"

# T6: project config read from the workspace, never from the plugin dir
echo "--- T6: config.md resolved in the consumer project ---"
D=$(tmpdir)
mkdir -p "$D/devflow"
write_config "$D/devflow/config.md" "configured"
printf '{"next_step":"devflow.plan","feature":"002_x"}' > "$D/.devflow-state.json"
(cd "$D" && bash "$HOOK" </dev/null >"$OUT" 2>&1) || true
grep -q "devflow not configured" "$OUT" \
  && assert "configured project gets no warning (plugin template ignored)" fail \
  || assert "configured project gets no warning (plugin template ignored)" pass
write_config "$D/devflow/config.md" "unconfigured"
(cd "$D" && bash "$HOOK" </dev/null >"$OUT" 2>&1) || true
grep -q "devflow not configured" "$OUT" \
  && assert "unconfigured project config warns" pass \
  || assert "unconfigured project config warns" fail
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
