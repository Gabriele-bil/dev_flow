#!/bin/bash
# post-fetch-cache.sh — PostToolUse(WebFetch) hook: cache response for pre-fetch-cache.sh.
# Stores body + prompt in .devflow-fetch-cache/<sha256(url)-32hex>.json, with
# ETag/Last-Modified captured via a HEAD request so the pre hook can
# revalidate on the next fetch. Entries without a validator are not cached
# (can't safely revalidate later).
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
PROMPT=$(printf '%s' "$RAW" | jq -r '.tool_input.prompt // .tool_use.input.prompt // empty' 2>/dev/null)

# tool_response may be a plain string or an object; WebFetch content commonly
# lives at .result, with .output/.text/.content/.body kept as defensive
# fallbacks in case the shape differs.
CONTENT=$(printf '%s' "$RAW" | jq -r '
  (.tool_response // .tool_result // "") as $r |
  if ($r | type) == "object" then
    ($r.result // $r.output // $r.text // $r.content // $r.body // empty)
  elif ($r | type) == "string" then $r
  else empty end' 2>/dev/null)
[ -z "$CONTENT" ] && exit 0

hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR=".devflow-fetch-cache"
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"

# Capture validators from the origin, following redirects so they match what
# the agent actually talked to. Strip CR; keep only the final hop's headers
# (awk paragraph mode) so an intermediate redirect's ETag isn't picked up.
HEAD_OUT=$(curl -sI -L --max-time 5 "$URL" 2>/dev/null | tr -d '\r' || true)
FINAL_HEADERS=$(printf '%s' "$HEAD_OUT" | awk 'BEGIN{RS="";last=""}{last=$0}END{print last}')

extract_header() {
  local name="$1"
  printf '%s' "$FINAL_HEADERS" | awk -v h="$name" '
    BEGIN { FS = ":" }
    tolower($1) == tolower(h) {
      sub(/^[^:]*:[ \t]*/, "")
      sub(/[ \t]+$/, "")
      print
      exit
    }'
}

ETAG=$(extract_header "ETag")
LAST_MOD=$(extract_header "Last-Modified")

# No validator from the origin — cannot revalidate later, drop any stale entry.
if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  rm -f "$CACHE_FILE" 2>/dev/null || true
  exit 0
fi

mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0
if [ -f .gitignore ] && ! grep -qF ".devflow-fetch-cache/" .gitignore 2>/dev/null; then
  printf '\n# devflow fetch cache\n.devflow-fetch-cache/\n' >> .gitignore 2>/dev/null || true
fi

NOW=$(date +%s)
TMP="${CACHE_FILE}.$$.tmp"
if jq -n \
  --arg url "$URL" \
  --arg prompt "$PROMPT" \
  --arg etag "$ETAG" \
  --arg last_modified "$LAST_MOD" \
  --arg content "$CONTENT" \
  --argjson fetched_at "$NOW" \
  '{url:$url,prompt:$prompt,etag:$etag,last_modified:$last_modified,content:$content,fetched_at:$fetched_at}' \
  > "$TMP" 2>/dev/null
then
  mv "$TMP" "$CACHE_FILE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
else
  rm -f "$TMP" 2>/dev/null || true
fi

exit 0
