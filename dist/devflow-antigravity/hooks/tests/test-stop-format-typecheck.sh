#!/bin/bash
# test-stop-format-typecheck.sh — behavioral tests for stop-format-typecheck.sh,
# covering single-app (zero-migration) and monorepo per-app grouping.
# Results reach the user as one systemMessage on stdout, only when a check
# reports issues (⚠); skipped/ok checks stay silent.
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
WORKDIR=$(cd "$WORKDIR" && pwd -P)
trap 'rm -rf "$WORKDIR" "$BIN"' EXIT
cd "$WORKDIR" || exit 1

# Minimal PATH so dart/pnpm are deterministically "not found" regardless of
# the host's toolchain — only jq is exposed (the hook needs it to run).
BIN=$(mktemp -d)
ln -s "$(command -v jq)" "$BIN/jq"
BARE_PATH="$BIN:/usr/bin:/bin"
# Stub toolchain: every call fails and echoes its argv, so the report shows
# exactly which command ran on which files.
STUBS="$BIN/stubs"
mkdir -p "$STUBS"
for t in dart pnpm; do
  printf '#!/bin/sh\necho "STUB %s $*"\nexit 1\n' "$t" > "$STUBS/$t"; chmod +x "$STUBS/$t"
done
STUB_PATH="$STUBS:$BARE_PATH"

PAYLOAD='{"hook_event_name":"Stop","session_id":"s1"}'

# run_hook_with <newline-separated files> — creates the files, records them
# (absolute paths, like the PostToolUse accumulator) and runs the hook.
run_hook_with() {
  local f
  : > .devflow-changed-files.tmp
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    mkdir -p "$(dirname "$f")"; : > "$f"
    printf '%s\n' "$WORKDIR/$f" >> .devflow-changed-files.tmp
  done <<< "$1"
  printf '%s' "$PAYLOAD" | PATH="${RUN_PATH:-$STUB_PATH}" bash "$HOOK"
}

msg() { printf '%s' "$1" | jq -r '.systemMessage // empty' 2>/dev/null; }

echo "=== test-stop-format-typecheck.sh ==="
echo ""

echo "--- T1: no accumulated changed files -> silent ---"
rm -rf .devflow-changed-files.tmp devflow
out=$(printf '%s' "$PAYLOAD" | PATH="$BARE_PATH" bash "$HOOK")
[ -z "$out" ] && assert "no tmp file: no output (no passthrough echo)" pass || assert "no tmp file: no output (got '$out')" fail

echo "--- T2: single-app, no config.md, auto-detect via .dart extension ---"
out=$(run_hook_with "lib/main.dart")
msg "$out" | grep -q "STUB dart format $WORKDIR/lib/main.dart" && assert "single-app auto-detect: dart format on the changed file only" pass || assert "single-app auto-detect: flutter branch (got '$out')" fail
[ ! -f .devflow-changed-files.tmp ] && assert "single-app: tmp file consumed" pass || assert "single-app: tmp file consumed" fail

echo "--- T3: single-app, explicit **Adapter:** in config.md (no Apps table) ---"
mkdir -p devflow
printf '**Adapter:** flutter\n**Adapter root:** .\n' > devflow/config.md
out=$(run_hook_with "lib/foo.dart")
msg "$out" | grep -q "STUB dart analyze" && assert "single-app explicit adapter: flutter branch reached" pass || assert "single-app explicit adapter: flutter branch reached (got '$out')" fail
rm -rf devflow lib

echo "--- T4: monorepo, absolute changed paths grouped per app + unmatched file skipped ---"
mkdir -p devflow
cat > devflow/config.md <<'EOF'
**Mode:** monorepo

## Apps

| App | Path | Adapter | Adapter root |
| --- | --- | --- | --- |
| web | apps/web | nextjs | apps/web |
| mobile | apps/mobile/ | flutter | apps/mobile |

See @devflow/references/adapter-resolution.md for resolution rules.
EOF
changed=$'apps/web/src/app/page.tsx\napps/mobile/lib/main.dart\nREADME.md'
out=$(run_hook_with "$changed")
m=$(msg "$out")
echo "$m" | grep -q "\[web\]" && echo "$m" | grep -q "STUB pnpm lint" && assert "monorepo: web/nextjs group reached" pass || assert "monorepo: web/nextjs group reached (got '$m')" fail
echo "$m" | grep -q "\[mobile\]" && echo "$m" | grep -q "STUB dart format $WORKDIR/apps/mobile/lib/main.dart" && assert "monorepo: mobile/flutter group reached (trailing slash in Path)" pass || assert "monorepo: mobile/flutter group reached (got '$m')" fail
[ ! -f .devflow-changed-files.tmp ] && assert "monorepo: tmp file consumed" pass || assert "monorepo: tmp file consumed" fail
rm -rf devflow apps README.md

echo "--- T5: monorepo, no files match any declared app -> silent ---"
mkdir -p devflow
cat > devflow/config.md <<'EOF'
## Apps

| App | Path | Adapter | Adapter root |
| --- | --- | --- | --- |
| web | apps/web | nextjs | apps/web |
EOF
out=$(run_hook_with "docs/product.md")
[ -z "$out" ] && assert "monorepo unmatched file: silent" pass || assert "monorepo unmatched file: silent (got '$out')" fail
rm -rf devflow docs

echo "--- T6: husky pre-commit covers lint+format -> checks skipped silently ---"
mkdir -p .husky
printf '#!/bin/sh\ndart format --set-exit-if-changed .\nflutter analyze\n' > .husky/pre-commit
out=$(run_hook_with "lib/main.dart")
[ -z "$out" ] && assert "husky covers: no message (skip is not an issue)" pass || assert "husky covers: no message (got '$out')" fail
rm -rf .husky

echo "--- T7: DEVFLOW_FORCE_TYPECHECK overrides hook-manager detection ---"
mkdir -p .husky
printf '#!/bin/sh\ndart format .\nflutter analyze\n' > .husky/pre-commit
out=$(DEVFLOW_FORCE_TYPECHECK=1 run_hook_with "lib/main.dart")
msg "$out" | grep -q "STUB dart" && assert "force override: dart checks attempted despite husky" pass || assert "force override (got '$out')" fail
rm -rf .husky lib

echo "--- T8: missing timeout binary never breaks a check ---"
mkdir -p devflow; printf '**Adapter:** nextjs\n' > devflow/config.md
out=$(run_hook_with "src/x.ts")
m=$(msg "$out")
echo "$m" | grep -q "timeout: command not found" && assert "no 'timeout: command not found'" fail || assert "no 'timeout: command not found'" pass
echo "$m" | grep -q "STUB pnpm lint" && assert "real lint output reported" pass || assert "real lint output reported (got '$m')" fail
rm -rf devflow src

echo "--- T9: missing toolchain is a silent skip, not a per-turn warning ---"
out=$(RUN_PATH="$BARE_PATH" run_hook_with "lib/main.dart")
[ -z "$out" ] && assert "dart absent: no message" pass || assert "dart absent: no message (got '$out')" fail
rm -rf lib

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
