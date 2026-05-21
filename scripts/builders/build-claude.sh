#!/usr/bin/env bash
# build-claude.sh — Genera dist/devflow/ per Claude Code.
# Variabili richieste (esportate da build-plugin.sh):
#   ROOT_DIR, TEMPLATE_DIR, DIST_DIR, NAME, VERSION, DESCRIPTION, AUTHOR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

step "Build Claude Code plugin"

# Ricrea dist/ da zero (idempotente)
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/.claude-plugin"

# Copia directory
for DIR in skills adapters hooks agents commands contexts references templates; do
  SRC="$TEMPLATE_DIR/$DIR"
  if [ -d "$SRC" ]; then
    cp -r "$SRC" "$DIST_DIR/$DIR"
    ok "Copiato: $DIR/"
  else
    warn "Directory non trovata (skip): $DIR/"
  fi
done

# Copia file (escludi CONTRIBUTING.md, scripts/, manifest.json — dev-only)
for FILE in config.md ETHOS.md AGENTS.md agent.yaml README.md; do
  SRC="$TEMPLATE_DIR/$FILE"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$DIST_DIR/$FILE"
    ok "Copiato: $FILE"
  else
    warn "File non trovato (skip): $FILE"
  fi
done

# Genera .claude-plugin/plugin.json da manifest
step "Generazione .claude-plugin/plugin.json"

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
  }' > "$DIST_DIR/.claude-plugin/plugin.json"

ok "plugin.json generato (v$VERSION)"

# Aggiorna source e version in .claude-plugin/marketplace.json
step "Aggiornamento .claude-plugin/marketplace.json"

MARKETPLACE="$ROOT_DIR/.claude-plugin/marketplace.json"

if [ -f "$MARKETPLACE" ]; then
  jq --arg name "$NAME" --arg src "./dist/$NAME" --arg ver "$VERSION" \
    '(.plugins[] | select(.name == $name)) |= (.source = $src | .version = $ver)' \
    "$MARKETPLACE" > "${MARKETPLACE}.tmp" \
    && mv "${MARKETPLACE}.tmp" "$MARKETPLACE"
  ok "marketplace.json: source → ./dist/$NAME, version → $VERSION"
else
  warn "marketplace.json non trovato — skip"
fi
