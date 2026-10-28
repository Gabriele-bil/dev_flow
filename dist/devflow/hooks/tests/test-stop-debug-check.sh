#!/bin/bash
# test-stop-debug-check.sh — Unit tests for stop-debug-check.sh
# Usage: bash templates/devflow/hooks/tests/test-stop-debug-check.sh
# Exit code: 0 = all pass, non-zero = failure

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/stop-debug-check.sh"
PASS=0
FAIL=0
ERRORS=()

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); ERRORS+=("FAIL: $label"); echo "  FAIL: $label"
  fi
}

D=$(mktemp -d); D=$(cd "$D" && pwd -P)
trap 'rm -rf "$D"' EXIT
(
  cd "$D" && git init -q && git config user.email t@t && git config user.name t
  mkdir -p src && printf 'export const a = 1;\n' > src/a.ts
  git add . && git commit -qm init
) >/dev/null 2>&1

PAYLOAD=$(jq -cn --arg cwd "$D" '{hook_event_name: "Stop", session_id: "s1", cwd: $cwd}')

echo "=== test-stop-debug-check.sh ==="
echo ""

echo "--- T1: clean tree → silent ---"
out=$(printf '%s' "$PAYLOAD" | bash "$HOOK" 2>/dev/null)
[ -z "$out" ] && assert "no modified files: no output" pass || assert "no modified files: no output (got '$out')" fail

echo "--- T2: console.log in a modified .ts → user-visible systemMessage ---"
printf 'export const a = 1;\nconsole.log(a);\n' > "$D/src/a.ts"
out=$(printf '%s' "$PAYLOAD" | (cd /tmp && bash "$HOOK") 2>/dev/null)
printf '%s' "$out" | jq -e '.systemMessage | test("console.log")' >/dev/null 2>&1 \
  && assert "systemMessage names console.log (workspace from payload cwd)" pass \
  || assert "systemMessage names console.log (got '$out')" fail
printf '%s' "$out" | grep -q '"hook_event_name"' \
  && assert "input not echoed" fail || assert "input not echoed" pass

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
