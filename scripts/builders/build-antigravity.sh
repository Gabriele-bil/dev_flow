#!/usr/bin/env bash
# build-antigravity.sh — Genera dist/devflow-antigravity/ per Antigravity CLI (agy).
# Richiede build-claude.sh già eseguito (parte da dist/devflow/).
# Variabili richieste (esportate da build-plugin.sh):
#   DIST_DIR, NAME, VERSION, DESCRIPTION, AUTHOR, ROOT_DIR, TEMPLATE_DIR
#
# Albero separato da quello Claude Code perché i due host divergono:
#   - hooks.json nella radice, formato (agy 1.4.x) {"<nome>": {"<Evento>": [...]}}:
#     eventi tool [{matcher, hooks: [{command}]}], eventi di ciclo di vita [{command}];
#     eventi assenti in Antigravity (PreCompact, Pre/PostModelSwitch,
#     PostToolUseFailure) esclusi; matcher tradotti nei nomi tool di agy;
#     ogni comando riceve DEVFLOW_HOST/DEVFLOW_EVENT (il payload agy non
#     contiene il nome evento) e gira dalla radice del plugin (cwd di agy).
#   - niente commands/: agy non carica comandi; le skill sono già slash command.
#   - frontmatter: via i campi solo-Claude Code da skill e agenti.
#   - rules/: orientamento statico (agy non inietta contesto da SessionStart).
#   - ${CLAUDE_PLUGIN_ROOT} nelle skill → percorso di staging di agy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

step "Build Antigravity CLI plugin"

[ -d "$DIST_DIR/skills" ] || fail "skills/ non trovata in $DIST_DIR — eseguire prima build-claude.sh"

AGY_DIR="${AGY_DIST_DIR:-$ROOT_DIR/dist/$NAME-antigravity}"
AGY_STAGING="\$HOME/.gemini/antigravity-cli/plugins/$NAME"

rm -rf "$AGY_DIR"
mkdir -p "$AGY_DIR"
# AGENTS.md escluso: agy carica regole solo da rules/ (orientamento → rules/)
for ITEM in skills adapters hooks agents contexts references templates scripts config.md ETHOS.md agent.yaml README.md LICENSE; do
  [ -e "$DIST_DIR/$ITEM" ] && cp -R "$DIST_DIR/$ITEM" "$AGY_DIR/$ITEM"
done
rm -f "$AGY_DIR/hooks/hooks.json"
ok "Albero copiato (senza commands/ e manifest Claude Code)"

# ── Manifest ──────────────────────────────────────────────────────────────────
step "Generazione plugin.json"
mkdir -p "$AGY_DIR/.antigravity-plugin"
if ! jq -n \
  --arg name        "$NAME" \
  --arg description "$DESCRIPTION" \
  --arg author      "$AUTHOR" \
  --arg repository  "${REPOSITORY:-}" \
  --arg homepage    "${HOMEPAGE:-}" \
  '{name: $name, description: $description, author: {name: $author}}
   + (if $repository != "" then {repository: $repository} else {} end)
   + (if $homepage   != "" then {homepage:   $homepage}   else {} end)' \
  > "$AGY_DIR/.antigravity-plugin/plugin.json"; then
  fail "jq: generazione plugin.json fallita"
fi
ok ".antigravity-plugin/plugin.json"

# ── hooks.json ────────────────────────────────────────────────────────────────
step "Traduzione hooks/hooks.json → hooks.json (formato agy)"
if ! jq --arg name "$NAME" '
  def tool_matcher:
    if . == null or . == "*" or . == "" then ".*"
    else split("|") | map(
      if . == "Bash" then "run_command"
      elif . == "Write" then "write_to_file|write_file"
      elif . == "Edit" or . == "MultiEdit" then "replace_file_content|multi_replace_file_content|edit_file"
      elif . == "WebFetch" then "read_url_content"
      elif . == "Agent" or . == "Task" then "invoke_subagent"
      else . end) | unique | join("|")
    end;
  def agy_command($event):
    "DEVFLOW_HOST=antigravity DEVFLOW_EVENT=\($event) "
    + (sub("\"\\$\\{CLAUDE_PLUGIN_ROOT\\}/"; "\"") | sub("\\$\\{CLAUDE_PLUGIN_ROOT\\}/"; ""));
  .hooks
  | with_entries(select(.key | IN("SessionStart", "PreToolUse", "PostToolUse", "Stop")))
  | with_entries(.key as $event | .value |= [
      .[] | (.matcher | tool_matcher) as $m
      | .hooks[] | (.command | agy_command($event)) as $cmd
      | if ($event | IN("PreToolUse", "PostToolUse"))
        then {matcher: $m, hooks: [{command: $cmd}]}
        else {command: $cmd} end
    ])
  | {($name): .}
' "$DIST_DIR/hooks/hooks.json" > "$AGY_DIR/hooks.json"; then
  fail "jq: traduzione hooks.json fallita"
fi
ok "hooks.json: $(jq -r '[.[] | to_entries[] | .value | length] | add' "$AGY_DIR/hooks.json") hook, eventi $(jq -r '[.[] | keys[]] | join(", ")' "$AGY_DIR/hooks.json")"

# ── Frontmatter ───────────────────────────────────────────────────────────────
# strip_frontmatter_keys <file> <key...> — rimuove le chiavi (e le righe di
# continuazione indentate) dal primo blocco --- … --- del file.
strip_frontmatter_keys() {
  local file="$1"; shift
  local keys="|$*|"; keys="${keys// /|}"
  awk -v keys="$keys" '
    NR == 1 && $0 == "---" { fm = 1; print; next }
    fm && $0 == "---" { fm = 0; skip = 0; print; next }
    fm {
      if (match($0, /^[A-Za-z_-]+:/)) {
        k = substr($0, 1, RLENGTH - 1)
        skip = index(keys, "|" k "|") > 0
      } else if ($0 !~ /^[[:space:]]/) { skip = 0 }
      if (!skip) print
      next
    }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

step "Frontmatter skill e agenti"
CLAUDE_ONLY_SKILL_KEYS="model effort allowed-tools context agent background disable-model-invocation"
while IFS= read -r f; do
  # shellcheck disable=SC2086
  strip_frontmatter_keys "$f" $CLAUDE_ONLY_SKILL_KEYS
done < <(find "$AGY_DIR/skills" "$AGY_DIR/adapters" -name SKILL.md)

for f in "$AGY_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  strip_frontmatter_keys "$f" tools disallowedTools model
  # Subagente invocabile via invoke_subagent; tool di default dell'host
  awk 'NR == 1 && $0 == "---" { print; print "subagent: true"; next } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
ok "Campi solo-Claude Code rimossi"

# ${CLAUDE_PLUGIN_ROOT} nelle skill → cartella di staging di agy
while IFS= read -r f; do
  sed -e "s|\${CLAUDE_PLUGIN_ROOT}|$AGY_STAGING|g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < <(grep -rl 'CLAUDE_PLUGIN_ROOT' "$AGY_DIR/skills" "$AGY_DIR/references" 2>/dev/null || true)

# ── rules/ ────────────────────────────────────────────────────────────────────
step "rules/devflow-orientation.md"
mkdir -p "$AGY_DIR/rules"
{
  printf '%s\n' '---' 'trigger: model_decision' \
    'description: DevFlow pipeline routing — which devflow skill to run next for a spec-driven feature (task, plan, implement, test, ship, pr).' '---' ''
  cat "$AGY_DIR/references/orientation.md"
} > "$AGY_DIR/rules/devflow-orientation.md"
ok "rules/devflow-orientation.md"

# ── marketplace ───────────────────────────────────────────────────────────────
step "Aggiornamento .antigravity-plugin/marketplace.json"
MARKETPLACE="$ROOT_DIR/.antigravity-plugin/marketplace.json"
if [ -f "$MARKETPLACE" ]; then
  TMP="$(mktemp "${MARKETPLACE}.XXXXXX")"
  if jq --arg name "$NAME" --arg src "./dist/$NAME-antigravity" --arg ver "$VERSION" --arg desc "$DESCRIPTION" \
    '(.plugins[] | select(.name == $name)) |= (.source = $src | .version = $ver | .description = $desc)' \
    "$MARKETPLACE" > "$TMP"; then
    mv "$TMP" "$MARKETPLACE"
    ok "marketplace.json: source → ./dist/$NAME-antigravity, version → $VERSION"
  else
    rm -f "$TMP"; fail "jq: aggiornamento marketplace.json fallito"
  fi
else
  warn "marketplace.json non trovato — skip"
fi

if command -v agy >/dev/null 2>&1; then
  step "agy plugin validate"
  agy plugin validate "$AGY_DIR" || fail "agy plugin validate fallito"
fi
