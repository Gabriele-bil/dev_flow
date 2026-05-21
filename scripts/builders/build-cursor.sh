#!/usr/bin/env bash
# build-cursor.sh — Aggiunge layer Cursor su dist/devflow/.
# Richiede build-claude.sh già eseguito.
# Variabili richieste (esportate da build-plugin.sh):
#   DIST_DIR, NAME, VERSION, DESCRIPTION, AUTHOR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

step "Build Cursor plugin"

[ -d "$DIST_DIR/skills" ] || fail "skills/ non trovata in $DIST_DIR — eseguire prima build-claude.sh"

mkdir -p "$DIST_DIR/.cursor-plugin"

# Genera .cursor-plugin/plugin.json
step "Generazione .cursor-plugin/plugin.json"

jq -n \
  --arg name        "$NAME" \
  --arg version     "$VERSION" \
  --arg description "$DESCRIPTION" \
  --arg author      "$AUTHOR" \
  '{
    name:        $name,
    version:     $version,
    description: $description,
    author:      { name: $author }
  }' > "$DIST_DIR/.cursor-plugin/plugin.json"

ok ".cursor-plugin/plugin.json generato (v$VERSION)"

# Genera hooks.cursor.json (sostituisce variabile plugin root)
step "Generazione hooks/hooks.cursor.json"

if [ -f "$DIST_DIR/hooks/hooks.json" ]; then
  sed 's|\${CLAUDE_PLUGIN_ROOT}|\${cursorPluginRoot}|g' \
    "$DIST_DIR/hooks/hooks.json" > "$DIST_DIR/hooks/hooks.cursor.json"
  ok "hooks.cursor.json generato"
else
  warn "hooks/hooks.json non trovato — hooks.cursor.json non generato"
fi
