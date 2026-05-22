#!/usr/bin/env bash
# build-antigravity.sh — Genera dist/devflow-antigravity/ per Antigravity CLI.
# Variabili richieste (esportate da build-plugin.sh):
#   ROOT_DIR, TEMPLATE_DIR, NAME, VERSION
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

step "Build Antigravity CLI plugin"

ANTIGRAVITY_DIST="$ROOT_DIR/dist/devflow-antigravity"

# Ricrea dist/ da zero (idempotente)
rm -rf "$ANTIGRAVITY_DIST"
mkdir -p "$ANTIGRAVITY_DIST/skills" "$ANTIGRAVITY_DIST/rules" "$ANTIGRAVITY_DIST/hooks"

# Copia skills core del pipeline
step "Copia skills core"
if [ -d "$TEMPLATE_DIR/skills" ]; then
  cp -r "$TEMPLATE_DIR/skills/." "$ANTIGRAVITY_DIST/skills/"
  ok "Skills core copiati"
else
  warn "skills/ non trovata — skip"
fi

# Flattenare adapter skills in skills/
step "Flatten adapter skills"
for ADAPTER_DIR in "$TEMPLATE_DIR/adapters"/*/; do
  [ -d "$ADAPTER_DIR" ] || continue
  ADAPTER_SKILLS_DIR="$ADAPTER_DIR/skills"
  [ -d "$ADAPTER_SKILLS_DIR" ] || continue
  ADAPTER_NAME=$(basename "$ADAPTER_DIR")
  for SKILL_DIR in "$ADAPTER_SKILLS_DIR"/*/; do
    [ -d "$SKILL_DIR" ] || continue
    SKILL_NAME=$(basename "$SKILL_DIR")
    cp -r "$SKILL_DIR" "$ANTIGRAVITY_DIST/skills/$SKILL_NAME"
    ok "Adapter skill: $ADAPTER_NAME/$SKILL_NAME"
  done
done

# Genera rules/ da ETHOS.md e AGENTS.md
step "Generazione rules/"
for FILE in ETHOS.md AGENTS.md; do
  SRC="$TEMPLATE_DIR/$FILE"
  if [ -f "$SRC" ]; then
    DEST_NAME=$(echo "$FILE" | tr '[:upper:]' '[:lower:]')
    cp "$SRC" "$ANTIGRAVITY_DIST/rules/$DEST_NAME"
    ok "Rule: $DEST_NAME"
  else
    warn "$FILE non trovato — skip"
  fi
done

# Copia hook scripts e adatta hooks.json alla root
step "Copia hooks"
for SCRIPT in "$TEMPLATE_DIR/hooks/"*.sh; do
  [ -f "$SCRIPT" ] || continue
  cp "$SCRIPT" "$ANTIGRAVITY_DIST/hooks/"
done
ok "Hook scripts copiati"

# Genera hooks.json alla root (formato Antigravity): rimpiazza variabile plugin root
# NOTE: ${PLUGIN_ROOT} è il placeholder — verificare nome variabile nella doc Antigravity
# prima del rilascio; Claude Code usa ${CLAUDE_PLUGIN_ROOT}
if [ -f "$TEMPLATE_DIR/hooks/hooks.json" ]; then
  sed 's|\${CLAUDE_PLUGIN_ROOT}|${PLUGIN_ROOT}|g' \
    "$TEMPLATE_DIR/hooks/hooks.json" > "$ANTIGRAVITY_DIST/hooks.json"
  ok "hooks.json generato alla root"
else
  warn "hooks/hooks.json non trovato — hooks.json non generato"
fi

# Genera plugin.json (formato Antigravity: solo name)
step "Generazione plugin.json"
echo '{"name":"devflow"}' > "$ANTIGRAVITY_DIST/plugin.json"
ok "plugin.json generato"

ok "Build Antigravity completato → dist/devflow-antigravity/"
