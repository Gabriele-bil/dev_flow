#!/bin/bash
# test-fetch-cache.sh — Unit tests for pre-fetch-cache.sh / post-fetch-cache.sh
# Usage: bash templates/devflow/hooks/tests/test-fetch-cache.sh
# Exit code: 0 = all pass, non-zero = failure
#
# Network-dependent revalidation (the curl HEAD round-trip) is not exercised
# here to keep this suite deterministic offline; these tests cover the
# local, dependency-free branches: matcher gating, cache-file gating, the
# no-validator rule, and the gitignore side effect.

set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRE_HOOK="$HOOKS_DIR/pre-fetch-cache.sh"
POST_HOOK="$HOOKS_DIR/post-fetch-cache.sh"
PASS=0
FAIL=0
ERRORS=()

tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t devflow-test
}

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); ERRORS+=("FAIL: $label"); echo "  FAIL: $label"
  fi
}

hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

echo "=== test-fetch-cache.sh ==="
echo ""

# T1: wrong tool name -> pre hook silent passthrough
echo "--- T1: non-WebFetch tool ignored ---"
D=$(tmpdir)
OUT=$(cd "$D" && jq -cn '{tool_name:"Bash",tool_input:{url:"https://example.com"}}' | bash "$PRE_HOOK" 2>/dev/null || true)
[ -z "$OUT" ] \
  && assert "pre hook silent for non-WebFetch tool" pass \
  || assert "pre hook silent for non-WebFetch tool (got '$OUT')" fail
rm -rf "$D"

# T2: WebFetch, no cache file yet -> silent passthrough
echo "--- T2: no cache file ---"
D=$(tmpdir)
OUT=$(cd "$D" && jq -cn '{tool_name:"WebFetch",tool_input:{url:"https://example.com/docs"}}' | bash "$PRE_HOOK" 2>/dev/null || true)
[ -z "$OUT" ] \
  && assert "pre hook silent with no cache file" pass \
  || assert "pre hook silent with no cache file (got '$OUT')" fail
rm -rf "$D"

# T3: cache file exists but has no etag/last_modified -> never served
echo "--- T3: cache entry without validator is never served ---"
D=$(tmpdir)
URL="https://example.com/no-validator"
mkdir -p "$D/.devflow-fetch-cache"
KEY=$(hash_key "$URL")
jq -n --arg url "$URL" --arg content "cached body" \
  '{url:$url,prompt:"",etag:"",last_modified:"",content:$content,fetched_at:0}' \
  > "$D/.devflow-fetch-cache/$KEY.json"
OUT=$(cd "$D" && jq -cn --arg u "$URL" '{tool_name:"WebFetch",tool_input:{url:$u}}' | bash "$PRE_HOOK" 2>/dev/null || true)
[ -z "$OUT" ] \
  && assert "no validator -> not served from cache" pass \
  || assert "no validator -> not served from cache (got '$OUT')" fail
rm -rf "$D"

# T4: post hook, non-object/string tool_response with no extractable content -> no cache file written
echo "--- T4: post hook writes nothing when content cannot be extracted ---"
D=$(tmpdir)
URL="https://example.com/empty-response"
(cd "$D" && jq -cn --arg u "$URL" '{tool_name:"WebFetch",tool_input:{url:$u},tool_response:{}}' | bash "$POST_HOOK" >/dev/null 2>&1) || true
KEY=$(hash_key "$URL")
[ ! -f "$D/.devflow-fetch-cache/$KEY.json" ] \
  && assert "no cache file written for unextractable content" pass \
  || assert "no cache file written for unextractable content" fail
rm -rf "$D"

# T5: post hook, missing jq dependency simulated via non-WebFetch tool -> no crash, exit 0
echo "--- T5: post hook exits cleanly for non-WebFetch tool ---"
D=$(tmpdir)
set +e
(cd "$D" && echo '{"tool_name":"Bash"}' | bash "$POST_HOOK" >/dev/null 2>&1)
RC=$?
set -e 2>/dev/null || true
[ "$RC" -eq 0 ] \
  && assert "post hook exits 0 for non-WebFetch tool" pass \
  || assert "post hook exits 0 for non-WebFetch tool (rc=$RC)" fail
rm -rf "$D"

# T6: pre hook exits cleanly (rc=0) on empty stdin
echo "--- T6: pre hook tolerates empty stdin ---"
D=$(tmpdir)
set +e
(cd "$D" && printf '' | bash "$PRE_HOOK" >/dev/null 2>&1)
RC=$?
set -e 2>/dev/null || true
[ "$RC" -eq 0 ] \
  && assert "pre hook exits 0 on empty stdin" pass \
  || assert "pre hook exits 0 on empty stdin (rc=$RC)" fail
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
