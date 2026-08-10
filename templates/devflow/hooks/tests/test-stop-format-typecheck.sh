#!/bin/bash
# test-stop-format-typecheck.sh — behavioral tests for stop-format-typecheck.sh,
# covering single-app (zero-migration) and monorepo per-app grouping.
# Usage: bash templates/devflow/hooks/tests/test-stop-format-typecheck.sh
# Exit code: 0 = all pass, non-zero = failure

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/stop-format-typecheck.sh"
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

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR" || exit 1

# Minimal PATH so dart/pnpm are deterministically "not found" regardless of
# the host's toolchain — isolates the test to grouping/parsing logic only.
BARE_PATH="/usr/bin:/bin"

run_hook_with() {
  local changed_files="$1"
  printf '%s\n' "$changed_files" > .devflow-changed-files.tmp
  PATH="$BARE_PATH" bash "$HOOK" <<< "passthrough-payload"
}

echo "=== test-stop-format-typecheck.sh ==="
echo ""

echo "--- T1: no accumulated changed files -> pure passthrough ---"
rm -f .devflow-changed-files.tmp devflow/config.md 2>/dev/null
rm -rf devflow
out=$(PATH="$BARE_PATH" bash "$HOOK" <<< "passthrough-payload")
[ "$out" = "passthrough-payload" ] && assert "no tmp file: RAW passthrough" pass || assert "no tmp file: RAW passthrough (got '$out')" fail

echo "--- T2: single-app, no config.md, auto-detect via .dart extension ---"
rm -rf devflow
out=$(run_hook_with "lib/main.dart" 2>/tmp/stderr.$$)
err=$(cat /tmp/stderr.$$); rm -f /tmp/stderr.$$
[ "$out" = "passthrough-payload" ] && assert "single-app auto-detect: RAW passthrough" pass || assert "single-app auto-detect: RAW passthrough (got '$out')" fail
echo "$err" | grep -q "dart not found" && assert "single-app auto-detect: reached flutter branch" pass || assert "single-app auto-detect: reached flutter branch (stderr: '$err')" fail
[ ! -f .devflow-changed-files.tmp ] && assert "single-app: tmp file consumed" pass || assert "single-app: tmp file consumed" fail

echo "--- T3: single-app, explicit **Adapter:** in config.md (no Apps table) ---"
mkdir -p devflow
printf '**Adapter:** flutter\n**Adapter root:** .\n' > devflow/config.md
out=$(run_hook_with "lib/foo.dart" 2>/tmp/stderr.$$)
err=$(cat /tmp/stderr.$$); rm -f /tmp/stderr.$$
[ "$out" = "passthrough-payload" ] && assert "single-app explicit adapter: RAW passthrough" pass || assert "single-app explicit adapter: RAW passthrough (got '$out')" fail
echo "$err" | grep -q "dart not found" && assert "single-app explicit adapter: flutter branch reached" pass || assert "single-app explicit adapter: flutter branch reached (stderr: '$err')" fail
rm -rf devflow

echo "--- T4: monorepo, Apps table, files grouped per app + unmatched file skipped ---"
mkdir -p devflow apps/web apps/mobile
cat > devflow/config.md <<'EOF'
**Mode:** monorepo

## Apps

| App | Path | Adapter | Adapter root |
| --- | --- | --- | --- |
| web | apps/web | nextjs | apps/web |
| mobile | apps/mobile | flutter | apps/mobile |

See @devflow/references/adapter-resolution.md for resolution rules.
EOF
changed=$'apps/web/src/app/page.tsx\napps/mobile/lib/main.dart\nREADME.md'
out=$(run_hook_with "$changed" 2>/tmp/stderr.$$)
err=$(cat /tmp/stderr.$$); rm -f /tmp/stderr.$$
[ "$out" = "passthrough-payload" ] && assert "monorepo: RAW passthrough" pass || assert "monorepo: RAW passthrough (got '$out')" fail
echo "$err" | grep -q "pnpm not found" && assert "monorepo: web/nextjs group reached" pass || assert "monorepo: web/nextjs group reached (stderr: '$err')" fail
echo "$err" | grep -q "dart not found" && assert "monorepo: mobile/flutter group reached" pass || assert "monorepo: mobile/flutter group reached (stderr: '$err')" fail
[ ! -f .devflow-changed-files.tmp ] && assert "monorepo: tmp file consumed" pass || assert "monorepo: tmp file consumed" fail
rm -rf devflow apps

echo "--- T5: monorepo, no files match any declared app -> no crash, still passthrough ---"
mkdir -p devflow
cat > devflow/config.md <<'EOF'
## Apps

| App | Path | Adapter | Adapter root |
| --- | --- | --- | --- |
| web | apps/web | nextjs | apps/web |
EOF
out=$(run_hook_with "docs/product.md" 2>/tmp/stderr.$$)
err=$(cat /tmp/stderr.$$); rm -f /tmp/stderr.$$
[ "$out" = "passthrough-payload" ] && assert "monorepo unmatched file: RAW passthrough" pass || assert "monorepo unmatched file: RAW passthrough (got '$out')" fail
[ -z "$err" ] && assert "monorepo unmatched file: no adapter branch reached" pass || assert "monorepo unmatched file: no adapter branch reached (stderr: '$err')" fail
rm -rf devflow

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
