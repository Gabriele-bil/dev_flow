#!/usr/bin/env bash
# build-plugin.sh — Legge templates/devflow/manifest.json e invoca i builder.
# Uso: bash scripts/build-plugin.sh
# Prerequisiti: jq (brew install jq)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDERS_DIR="$SCRIPT_DIR/builders"
export ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$BUILDERS_DIR/common.sh"

command -v jq >/dev/null 2>&1 || fail "jq non trovato. Installa con: brew install jq"

export TEMPLATE_DIR="$ROOT_DIR/templates/devflow"
export MANIFEST="$TEMPLATE_DIR/manifest.json"
export DIST_DIR="$ROOT_DIR/dist/devflow"

[ -f "$MANIFEST" ] || fail "manifest.json non trovato in $TEMPLATE_DIR/"

export NAME=$(jq -r '.name'           "$MANIFEST")
export DESCRIPTION=$(jq -r '.description' "$MANIFEST")
export VERSION=$(jq -r '.version'     "$MANIFEST")
export AUTHOR=$(jq -r '.author'       "$MANIFEST")
CURSOR_SUPPORT=$(jq -r '.cursor_support // false' "$MANIFEST")
ANTIGRAVITY_SUPPORT=$(jq -r '.antigravity_support // false' "$MANIFEST")

step "Build plugin: $NAME v$VERSION"

bash "$BUILDERS_DIR/build-claude.sh"

if [ "$CURSOR_SUPPORT" = "true" ]; then
  bash "$BUILDERS_DIR/build-cursor.sh"
fi

if [ "$ANTIGRAVITY_SUPPORT" = "true" ]; then
  bash "$BUILDERS_DIR/build-antigravity.sh"
fi

echo ""
TARGETS="Claude Code"
[ "$CURSOR_SUPPORT" = "true" ] && TARGETS="$TARGETS + Cursor"
[ "$ANTIGRAVITY_SUPPORT" = "true" ] && TARGETS="$TARGETS + Antigravity CLI"
ok "Build completato → dist/ ($TARGETS)"
