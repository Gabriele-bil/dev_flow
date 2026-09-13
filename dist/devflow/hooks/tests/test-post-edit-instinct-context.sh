#!/bin/bash
# test-post-edit-instinct-context.sh — Unit tests for post-edit-instinct-context.sh
# Usage: bash templates/devflow/hooks/tests/test-post-edit-instinct-context.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/post-edit-instinct-context.sh"
PASS=0
FAIL=0
SKIP=0
ERRORS=()

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); ERRORS+=("FAIL: $label"); echo "  FAIL: $label"
  fi
}

skip() {
  SKIP=$((SKIP + 1)); echo "  SKIP: $1"
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export CLAUDE_PROJECT_DIR="$TMPDIR"

run_hook() {
  local file_path="$1"
  local payload
  payload=$(jq -cn --arg fp "$file_path" '{tool_use: {name: "Edit", input: {file_path: $fp}}}')
  printf '%s' "$payload" | bash "$HOOK" 2>/dev/null || true
}

echo "=== test-post-edit-instinct-context.sh ==="
echo ""

echo "--- T1: no instincts file -> silent ---"
rm -f "$TMPDIR/.devflow-instincts.yaml"
out=$(run_hook "src/app.ts")
[ -z "$out" ] && assert "no instincts file silent" pass || assert "no instincts file silent" fail

if ! command -v yq >/dev/null 2>&1; then
  skip "yq not installed — remaining cases need yq, matches hook's own graceful degrade"
else
  cat > "$TMPDIR/.devflow-instincts.yaml" <<'EOF'
instincts:
  - id: ts-strict
    trigger: "when working on this project"
    confidence: 0.8
    domain: typescript
    scope: project
    action: "always type function returns explicitly"
    evidence: "test fixture"
    ts: "2026-01-01T00:00:00Z"
  - id: low-conf
    trigger: "when working on this project"
    confidence: 0.1
    domain: typescript
    scope: project
    action: "below threshold, must not surface"
    evidence: "test fixture"
    ts: "2026-01-01T00:00:00Z"
  - id: dart-null-safety
    trigger: "when working on this project"
    confidence: 0.9
    domain: flutter
    scope: project
    action: "always enable null safety"
    evidence: "test fixture"
    ts: "2026-01-01T00:00:00Z"
EOF

  echo "--- T2: matching domain surfaces additionalContext ---"
  out=$(run_hook "src/app.ts")
  echo "$out" | grep -qF "always type function returns explicitly" \
    && assert "typescript file surfaces ts domain instinct" pass \
    || assert "typescript file surfaces ts domain instinct (output: '$out')" fail
  echo "$out" | grep -qE '"hookEventName"[[:space:]]*:[[:space:]]*"PostToolUse"' \
    && assert "output uses PostToolUse hookSpecificOutput schema" pass \
    || assert "output uses PostToolUse hookSpecificOutput schema (output: '$out')" fail

  echo "--- T3: below-confidence instinct excluded ---"
  echo "$out" | grep -qF "below threshold, must not surface" \
    && assert "low-confidence instinct excluded" fail \
    || assert "low-confidence instinct excluded" pass

  echo "--- T4: non-matching domain stays silent ---"
  out=$(run_hook "lib/main.py")
  echo "$out" | grep -qF "always enable null safety" \
    && assert "python file does not surface flutter instinct" fail \
    || assert "python file does not surface flutter instinct" pass
fi

echo "--- T5: degenerate input allowed silently ---"
out=$(printf '' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "empty stdin silent" pass || assert "empty stdin silent" fail

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
