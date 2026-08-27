#!/bin/bash
# pre-fetch-cache.sh — PreToolUse(WebFetch) hook: serve cached response on HTTP 304.
# Cache lives at .devflow-fetch-cache/<sha256(url)-32hex>.json, written by
# post-fetch-cache.sh. Freshness is delegated to the origin via conditional
# request (If-None-Match / If-Modified-Since); a 304 is the only cache-hit
# signal — no TTL. Entries without an ETag or Last-Modified are never served
# (can't revalidate).
#
# Cache hit: emits {"decision":"block","reason":"<cached content>"} so Claude
# reads the cached body in place of a live fetch. Cache miss, stale, or any
# missing dependency: silent exit 0 — fetch proceeds normally.
#
# Dependencies: jq, curl, shasum (or sha256sum).

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || exit 0

RAW="$(cat 2>/dev/null || true)"
[ -z "$RAW" ] && exit 0

TOOL=$(printf '%s' "$RAW" | jq -r '.tool_name // .tool_use.name // empty' 2>/dev/null)
[ "$TOOL" = "WebFetch" ] || exit 0

URL=$(printf '%s' "$RAW" | jq -r '.tool_input.url // .tool_use.input.url // empty' 2>/dev/null)
[ -z "$URL" ] && exit 0

hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR=".devflow-fetch-cache"
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"
[ -f "$CACHE_FILE" ] || exit 0

FETCHED_AT=$(jq -r '.fetched_at // 0' "$CACHE_FILE" 2>/dev/null || echo 0)
ORIGINAL_PROMPT=$(jq -r '.prompt // empty' "$CACHE_FILE" 2>/dev/null || true)
ETAG=$(jq -r '.etag // empty' "$CACHE_FILE" 2>/dev/null || true)
LAST_MOD=$(jq -r '.last_modified // empty' "$CACHE_FILE" 2>/dev/null || true)

# No validator means freshness cannot be verified — never serve from cache.
if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  exit 0
fi

HEADERS=()
[ -n "$ETAG" ] && HEADERS+=(-H "If-None-Match: $ETAG")
[ -n "$LAST_MOD" ] && HEADERS+=(-H "If-Modified-Since: $LAST_MOD")

STATUS=$(curl -sI -o /dev/null -w "%{http_code}" --max-time 5 -L "${HEADERS[@]}" "$URL" 2>/dev/null || echo "000")
[ "$STATUS" = "304" ] || exit 0

CONTENT=$(jq -r '.content // empty' "$CACHE_FILE" 2>/dev/null || true)
[ -z "$CONTENT" ] && exit 0

VERIFIED_AT_ISO=$(date -u -r "$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "@$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "unknown")

REASON="[devflow-fetch-cache] Revalidated via HTTP 304; unchanged since $VERIFIED_AT_ISO. Use the cached content below as if WebFetch had just returned it."
if [ -n "$ORIGINAL_PROMPT" ]; then
  REASON="$REASON
Original WebFetch prompt: \"$ORIGINAL_PROMPT\". If your angle differs, judge whether this reading still covers it."
fi
REASON="$REASON

----- BEGIN CACHED CONTENT -----
$CONTENT
----- END CACHED CONTENT -----"

jq -n --arg reason "$REASON" '{decision:"block",reason:$reason}' 2>/dev/null || exit 0
exit 0
