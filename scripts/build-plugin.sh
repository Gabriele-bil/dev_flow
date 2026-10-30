#!/usr/bin/env bash
# build-plugin.sh — Legge templates/devflow/manifest.json e invoca i builder.
# Uso: bash scripts/build-plugin.sh
# Prerequisiti: jq (brew install jq)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDERS_DIR="$SCRIPT_DIR/builders"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export ROOT_DIR

source "$BUILDERS_DIR/common.sh"

command -v jq >/dev/null 2>&1 || fail "jq non trovato. Installa con: brew install jq"

export TEMPLATE_DIR="$ROOT_DIR/templates/devflow"
export MANIFEST="$TEMPLATE_DIR/manifest.json"
export DIST_DIR="$ROOT_DIR/dist/devflow"

[ -f "$MANIFEST" ] || fail "manifest.json non trovato in $TEMPLATE_DIR/"

# Campi obbligatori: jq -e fallisce su chiave mancante/null (niente "null" nei manifest)
NAME=$(jq -er '.name' "$MANIFEST")               || fail "manifest.json: name mancante"
DESCRIPTION=$(jq -er '.description' "$MANIFEST") || fail "manifest.json: description mancante"
VERSION=$(jq -er '.version' "$MANIFEST")         || fail "manifest.json: version mancante"
AUTHOR=$(jq -er '.author' "$MANIFEST")           || fail "manifest.json: author mancante"
LICENSE_ID=$(jq -er '.license' "$MANIFEST")      || fail "manifest.json: license mancante"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]] || fail "manifest.json: version '$VERSION' non è semver"
REPOSITORY=$(jq -r '.repository // empty' "$MANIFEST")
HOMEPAGE=$(jq -r '.homepage // empty' "$MANIFEST")
KEYWORDS_JSON=$(jq -c '.keywords // []' "$MANIFEST")
ANTIGRAVITY_SUPPORT=$(jq -r '.antigravity_support // false' "$MANIFEST")
export NAME DESCRIPTION VERSION AUTHOR LICENSE_ID REPOSITORY HOMEPAGE KEYWORDS_JSON

step "Build plugin: $NAME v$VERSION"

bash "$BUILDERS_DIR/build-claude.sh"

# Ship runtime scripts in dist/devflow/scripts/ (the rest of scripts/ is dev-only)
mkdir -p "$DIST_DIR/scripts"
for RUNTIME_SH in board.sh metrics.sh doctor.sh devflow-state.sh verify-stamp.sh; do
  if [ -f "$TEMPLATE_DIR/scripts/$RUNTIME_SH" ]; then
    cp "$TEMPLATE_DIR/scripts/$RUNTIME_SH" "$DIST_DIR/scripts/$RUNTIME_SH"
    chmod +x "$DIST_DIR/scripts/$RUNTIME_SH" 2>/dev/null || true
  fi
done
# Every script a skill, agent or reference calls must ship
MISSING=""
for REF in $(grep -rhoE '(CLAUDE_PLUGIN_ROOT\}|@devflow)/scripts/[A-Za-z0-9_.-]+\.sh' \
    "$DIST_DIR/skills" "$DIST_DIR/agents" "$DIST_DIR/references" "$DIST_DIR/commands" 2>/dev/null | sed 's#.*/scripts/##' | sort -u); do
  [ -f "$DIST_DIR/scripts/$REF" ] || MISSING="$MISSING $REF"
done
[ -z "$MISSING" ] || { echo "✗ scripts referenced but not shipped:$MISSING (add them to RUNTIME_SH)" >&2; exit 1; }

if [ "$ANTIGRAVITY_SUPPORT" = "true" ]; then
  bash "$BUILDERS_DIR/build-antigravity.sh"
fi

echo ""
TARGETS="Claude Code"
[ "$ANTIGRAVITY_SUPPORT" = "true" ] && TARGETS="$TARGETS + Antigravity CLI"
ok "Build completato → dist/ ($TARGETS)"

# ── Catalog integrity ─────────────────────────────────────────────────────────
SKILLS_COUNT=$(find "$DIST_DIR" -name "SKILL.md" | wc -l | tr -d ' ')
AGENTS_COUNT=$(find "$DIST_DIR/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
REFS_COUNT=$(find "$DIST_DIR/references" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "  Catalog: ${SKILLS_COUNT} skill(s)  ${AGENTS_COUNT} agent(s)  ${REFS_COUNT} reference(s)"

# Fail if skills drop below baseline (updated after adding new skills)
SKILLS_MIN=45
if [ "$SKILLS_COUNT" -lt "$SKILLS_MIN" ]; then
  echo "  ERROR: skill count ($SKILLS_COUNT) below minimum ($SKILLS_MIN) — possible build regression"
  exit 1
fi
