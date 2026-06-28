#!/usr/bin/env bash
# build-antigravity.sh — Aggiunge layer Antigravity CLI su dist/devflow/.
# Richiede build-claude.sh già eseguito.
# Variabili richieste (esportate da build-plugin.sh):
#   DIST_DIR, NAME, VERSION, DESCRIPTION, AUTHOR, ROOT_DIR, TEMPLATE_DIR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

step "Build Antigravity CLI plugin"

[ -d "$DIST_DIR/skills" ] || fail "skills/ non trovata in $DIST_DIR — eseguire prima build-claude.sh"

mkdir -p "$DIST_DIR/.antigravity-plugin"

# Genera .antigravity-plugin/plugin.json
step "Generazione .antigravity-plugin/plugin.json"

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
  }' > "$DIST_DIR/.antigravity-plugin/plugin.json"

ok ".antigravity-plugin/plugin.json generato (v$VERSION)"

# Copia plugin.json anche alla radice del plugin (richiesto da agy plugin validate/install)
step "Copia plugin.json alla radice di dist/"
cp "$DIST_DIR/.antigravity-plugin/plugin.json" "$DIST_DIR/plugin.json"
ok "plugin.json copiato alla radice"

# Genera hooks.json alla radice (richiesto da agy plugin validate/install)
step "Generazione hooks.json alla radice"

if [ -f "$TEMPLATE_DIR/hooks/hooks.json" ]; then
  sed 's|\${CLAUDE_PLUGIN_ROOT}|\${ANTIGRAVITY_PLUGIN_ROOT}|g' \
    "$TEMPLATE_DIR/hooks/hooks.json" > "$DIST_DIR/hooks.json"
  ok "hooks.json generato alla radice"
else
  warn "hooks/hooks.json non trovato — hooks.json non generato alla radice"
fi

# Genera hooks.antigravity.json (sostituisce variabile plugin root)
step "Generazione hooks/hooks.antigravity.json"

if [ -f "$DIST_DIR/hooks/hooks.json" ]; then
  sed 's|\${CLAUDE_PLUGIN_ROOT}|\${ANTIGRAVITY_PLUGIN_ROOT}|g' \
    "$DIST_DIR/hooks/hooks.json" > "$DIST_DIR/hooks/hooks.antigravity.json"
  ok "hooks.antigravity.json generato"
else
  warn "hooks/hooks.json non trovato — hooks.antigravity.json non generato"
fi

# Aggiorna source e version in .antigravity-plugin/marketplace.json
step "Aggiornamento .antigravity-plugin/marketplace.json"

MARKETPLACE="$ROOT_DIR/.antigravity-plugin/marketplace.json"

if [ -f "$MARKETPLACE" ]; then
  jq --arg name "$NAME" --arg src "./dist/$NAME" --arg ver "$VERSION" \
    '(.plugins[] | select(.name == $name)) |= (.source = $src | .version = $ver)' \
    "$MARKETPLACE" > "${MARKETPLACE}.tmp" \
    && mv "${MARKETPLACE}.tmp" "$MARKETPLACE"
  ok "marketplace.json: source → ./dist/$NAME, version → $VERSION"
else
  warn "marketplace.json non trovato — skip"
fi
