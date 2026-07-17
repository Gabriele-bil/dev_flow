#!/bin/bash
# test-pre-config-protect.sh — Unit tests for pre-config-protect.sh matcher correctness
# Usage: bash templates/devflow/hooks/tests/test-pre-config-protect.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-config-protect.sh"
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

run_hook() {
  local file_path="$1"
  local payload
  payload=$(jq -cn --arg fp "$file_path" '{tool_use: {name: "Edit", input: {file_path: $fp}}}')
  printf '%s' "$payload" | bash "$HOOK" 2>/dev/null || true
}

expect_block() {
  local label="$1" file_path="$2"
  local out
  out=$(run_hook "$file_path")
  echo "$out" | grep -qE '"decision"[[:space:]]*:[[:space:]]*"block"' \
    && assert "$label blocked" pass \
    || assert "$label blocked (output: '$out')" fail
}

expect_allow() {
  local label="$1" file_path="$2"
  local out
  out=$(run_hook "$file_path")
  [ -z "$out" ] \
    && assert "$label allowed" pass \
    || assert "$label allowed (unexpected output: '$out')" fail
}

echo "=== test-pre-config-protect.sh ==="
echo ""

echo "--- T1: protected configs blocked ---"
expect_block "analysis_options.yaml"   "/app/analysis_options.yaml"
expect_block "eslint.config.js"        "eslint.config.js"
expect_block "eslint.config.mjs"       "src/eslint.config.mjs"
expect_block ".eslintrc"               ".eslintrc"
expect_block ".eslintrc.json"          "web/.eslintrc.json"
expect_block "tsconfig.json"           "tsconfig.json"
expect_block "tsconfig.app.json"       "apps/web/tsconfig.app.json"
expect_block ".editorconfig"           ".editorconfig"
expect_block "biome.json"              "biome.json"
expect_block ".prettierrc"             ".prettierrc"
expect_block "prettier.config.js"      "prettier.config.js"

echo "--- T2: normal files allowed ---"
expect_allow "pubspec.yaml"            "pubspec.yaml"
expect_allow "main.dart"               "lib/main.dart"
expect_allow "component.ts"            "src/app/app.component.ts"
expect_allow "package.json"            "package.json"
expect_allow "tsconfig lookalike"      "src/not-tsconfig.md"

echo "--- T3: degenerate input allowed silently ---"
out=$(printf '' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "empty stdin allowed" pass || assert "empty stdin allowed" fail
out=$(printf '{"tool_use":{"input":{}}}' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "missing file_path allowed" pass || assert "missing file_path allowed" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
