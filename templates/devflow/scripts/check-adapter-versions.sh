#!/usr/bin/env bash
# check-adapter-versions.sh — compares each adapter's "**Verified against:**"
# line with the latest published versions (npm registry, pub.dev) and lists the
# packages that moved past it. Dev-only: run by CI weekly, never blocks.
#
# Usage: bash templates/devflow/scripts/check-adapter-versions.sh [--strict]
#   --strict  exit 1 when a newer major is out (minor bumps only warn)
# Line format (ADAPTER.md): **Verified against:** next@16.4, pub:freezed@4.0, sdk:flutter@3.47 (2026-10-30)
#   <name>@x.y → npm · pub:<name>@x.y → pub.dev · sdk:<name>@x.y → not checked
# Needs network, plus npm or curl; jq for pub.dev. Missing tool → that source is skipped.

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STRICT=""; [ "${1:-}" = "--strict" ] && STRICT=1
MAJORS=0 MINORS=0 CHECKED=0 SKIPPED=0

# Highest stable release: some packages tag a pre-release as "latest" (prisma 8 rc)
latest_npm() {
  local v; v=$(npm view "$1" version 2>/dev/null | tail -1)
  case "$v" in *-*) v=$(npm view "$1" versions --json 2>/dev/null | jq -r '[.[] | select(test("-") | not)] | last // empty' 2>/dev/null) ;; esac
  printf '%s' "$v"
}
latest_pub() { curl -fsS --max-time 15 "https://pub.dev/api/packages/$1" 2>/dev/null | jq -r '.latest.version // empty' 2>/dev/null; }

for md in "$PLUGIN_ROOT"/adapters/*/ADAPTER.md; do
  adapter=$(basename "$(dirname "$md")")
  line=$(grep -m1 '^\*\*Verified against:\*\*' "$md" | sed 's/^\*\*Verified against:\*\*[[:space:]]*//')
  [ -n "$line" ] || { echo "⚠ $adapter: no **Verified against:** line"; continue; }
  date=$(printf '%s' "$line" | grep -oE '\([0-9]{4}-[0-9]{2}-[0-9]{2}\)' | tr -d '()')
  echo "── $adapter (verified ${date:-?})"
  for item in $(printf '%s' "$line" | sed 's/([^)]*)//g' | tr ',' ' '); do
    pkg="${item%@*}" want="${item##*@}"
    case "$pkg" in
      sdk:*) SKIPPED=$((SKIPPED + 1)); continue ;;
      pub:*) command -v curl >/dev/null && command -v jq >/dev/null || { SKIPPED=$((SKIPPED + 1)); continue; }
             pkg="${pkg#pub:}"; have=$(latest_pub "$pkg") ;;
      *)     command -v npm >/dev/null || { SKIPPED=$((SKIPPED + 1)); continue; }
             have=$(latest_npm "$pkg") ;;
    esac
    [ -n "$have" ] || { echo "  ? $pkg: lookup failed"; SKIPPED=$((SKIPPED + 1)); continue; }
    CHECKED=$((CHECKED + 1))
    wmaj="${want%%.*}" wmin=$(printf '%s' "$want" | cut -d. -f2)
    hmaj="${have%%.*}" hmin=$(printf '%s' "$have" | cut -d. -f2)
    if [ "${hmaj:-0}" -gt "${wmaj:-0}" ] 2>/dev/null; then
      echo "  ✗ $pkg: $want → $have (new major)"; MAJORS=$((MAJORS + 1))
    elif [ "${hmaj:-0}" -eq "${wmaj:-0}" ] 2>/dev/null && [ "${hmin:-0}" -gt "${wmin:-0}" ] 2>/dev/null; then
      echo "  ⚠ $pkg: $want → $have (new minor)"; MINORS=$((MINORS + 1))
    fi
  done
done

echo ""
echo "Results: $CHECKED checked, $MAJORS new major(s), $MINORS new minor(s), $SKIPPED skipped"
[ -n "$STRICT" ] && [ "$MAJORS" -gt 0 ] && exit 1
exit 0
