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

cp "$ROOT_DIR/LICENSE" "$DIST_DIR/LICENSE"
ok "Copiato: LICENSE"

# File di sviluppo del plugin, non per chi lo usa: test degli hook e il comando
# di lint delle skill (resta in templates/, eseguito dalla CI)
rm -rf "$DIST_DIR/hooks/tests" "$DIST_DIR/commands/devflow.lint-skills.md"

# Pulizia di sicurezza in dist/ per rimuovere file temporanei o di runtime
find "$DIST_DIR" \( -name ".devflow-*" ! -name ".devflow-instincts.shared.yaml" -o -name ".DS_Store" -o -name "*.tmp" \) -exec rm -rf {} + 2>/dev/null || true

# Genera .claude-plugin/plugin.json da manifest
step "Generazione .claude-plugin/plugin.json"

jq -n \
  --arg name        "$NAME" \
  --arg version     "$VERSION" \
  --arg description "$DESCRIPTION" \
  --arg author      "$AUTHOR" \
  --arg license     "$LICENSE_ID" \
  --arg repository  "${REPOSITORY:-}" \
  --arg homepage    "${HOMEPAGE:-}" \
  --argjson keywords "${KEYWORDS_JSON:-[]}" \
  '{
    name:        $name,
    version:     $version,
    description: $description,
    author:      { name: $author },
    license:     $license
  }
  + (if $repository != "" then { repository: $repository } else {} end)
  + (if $homepage   != "" then { homepage:   $homepage }   else {} end)
  + (if ($keywords | length) > 0 then { keywords: $keywords } else {} end)
  ' > "$DIST_DIR/.claude-plugin/plugin.json" || fail "jq: generazione plugin.json fallita"

ok "plugin.json generato (v$VERSION)"

# Aggiorna source e version in .claude-plugin/marketplace.json
step "Aggiornamento .claude-plugin/marketplace.json"

MARKETPLACE="$ROOT_DIR/.claude-plugin/marketplace.json"

if [ -f "$MARKETPLACE" ]; then
  TMP="$(mktemp "${MARKETPLACE}.XXXXXX")"
  if jq --arg name "$NAME" --arg src "./dist/$NAME" --arg ver "$VERSION" --arg desc "$DESCRIPTION" \
    '(.plugins[] | select(.name == $name)) |= (.source = $src | .version = $ver | .description = $desc)' \
    "$MARKETPLACE" > "$TMP"; then
    mv "$TMP" "$MARKETPLACE"
  else
    rm -f "$TMP"; fail "jq: aggiornamento marketplace.json fallito"
  fi
  ok "marketplace.json: source → ./dist/$NAME, version → $VERSION"
else
  warn "marketplace.json non trovato — skip"
fi
