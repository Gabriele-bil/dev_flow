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
for DIR in skills adapters hooks agents contexts references templates; do
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

# File di sviluppo del plugin, non per chi lo usa: test degli hook
rm -rf "$DIST_DIR/hooks/tests"

# Pulizia di sicurezza in dist/ per rimuovere file temporanei o di runtime
find "$DIST_DIR" \( -name ".devflow-*" ! -name ".devflow-instincts.shared.yaml" -o -name ".DS_Store" -o -name "*.tmp" \) -exec rm -rf {} + 2>/dev/null || true

# Percorsi del plugin. @devflow/<dir>/ è la notazione degli autori; nel progetto
# consumer devflow/ contiene solo config.md e features/, quindi quei percorsi non
# esistono. Claude Code sostituisce ${CLAUDE_PLUGIN_ROOT} solo nel testo di skill,
# comandi e agenti caricati dall'host: lì il percorso diventa assoluto. Un file
# letto con Read (references/, adapters/, contexts/, e il SKILL.md che un
# orchestratore fa leggere) resta letterale, e la variabile non esiste nell'ambiente di Bash:
# la nota "Plugin root" in testa a skill e agenti dà al modello la
# radice assoluta. @devflow/config.md resta com'è: è un file del progetto consumer.
step "Percorsi @devflow/ → \${CLAUDE_PLUGIN_ROOT}"
PLUGIN_DIRS_RE='(references|adapters|skills|agents|scripts|contexts)'
PATHS_NOTE='> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.'
for f in "$DIST_DIR"/skills/*/SKILL.md "$DIST_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  sed -E "s#@devflow/${PLUGIN_DIRS_RE}/#\${CLAUDE_PLUGIN_ROOT}/\1/#g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
for f in "$DIST_DIR"/skills/*/SKILL.md "$DIST_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  awk -v note="$PATHS_NOTE" '{ print } $0 == "---" && ++n == 2 { print ""; print note }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
LEFT="$(grep -lE "@devflow/${PLUGIN_DIRS_RE}/" "$DIST_DIR"/skills/*/SKILL.md "$DIST_DIR"/agents/*.md 2>/dev/null || true)"
[ -z "$LEFT" ] || fail "@devflow/ non riscritto in: $LEFT"
ok "Percorsi del plugin risolti in skill e agenti"

# Nomi slash. Le skill sono l'unico ingresso: name: devflow-<passo> diventa
# name: <passo>, quindi /<plugin>:<passo> (es. /devflow:plan). Nei testi la
# notazione degli autori /devflow.<passo> diventa lo stesso nome. Solo i passi
# che hanno una skill: nessun altro /devflow.<x> viene toccato.
step "Nomi slash → /$NAME:<passo>"
STEPS_RE="$(find "$DIST_DIR/skills" -mindepth 1 -maxdepth 1 -type d -name 'devflow-*' | sed 's#.*/devflow-##' | sort -r | paste -sd'|' -)"
for f in "$DIST_DIR"/skills/devflow-*/SKILL.md; do
  awk 'NR > 1 && /^---$/ { fm = 1 } !fm && !done && /^name: devflow-/ { sub(/^name: devflow-/, "name: "); done = 1 } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
while IFS= read -r f; do
  sed -E "s#/devflow\.(${STEPS_RE})([^a-z-]|\$)#/${NAME}:\1\2#g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < <(grep -rlE "/devflow\.(${STEPS_RE})" "$DIST_DIR" --include='*.md' --include='*.sh' --include='*.yaml' --include='*.html' --include='*.json' 2>/dev/null)
LEFT="$(grep -rlE "/devflow\.(${STEPS_RE})([^a-z-]|\$)" "$DIST_DIR" 2>/dev/null || true)"
[ -z "$LEFT" ] || fail "/devflow.<passo> non riscritto in: $LEFT"
[ "$(grep -l '^name: devflow-' "$DIST_DIR"/skills/devflow-*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')" = 0 ] || fail "name: devflow-<passo> rimasto in una skill"
ok "Skill invocabili come /$NAME:<passo>"

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
