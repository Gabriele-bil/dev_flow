#!/bin/bash
# run-hook-tests.sh — syntax pass + behavioral test suites for all hook scripts.
# Usage: bash templates/devflow/scripts/run-hook-tests.sh
# Exit 0: all pass. Exit 1: any syntax error or failing suite.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(dirname "$SCRIPT_DIR")/hooks"
FAILED=0

echo "── Syntax check (bash -n) ──────────────────────────────"
for f in "$HOOKS_DIR"/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    echo "  ok: $(basename "$f")"
  else
    echo "  SYNTAX FAIL: $(basename "$f")"
    bash -n "$f" || true
    FAILED=1
  fi
done

echo ""
echo "── Behavioral suites ───────────────────────────────────"
for t in "$HOOKS_DIR"/tests/test-*.sh; do
  echo ""
  if ! bash "$t"; then
    FAILED=1
  fi
done

echo ""
if ! bash "$SCRIPT_DIR/test-learning-hooks.sh"; then
  FAILED=1
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "✅ All hook tests passed"
else
  echo "❌ Hook test failures — see above"
fi
exit $FAILED
