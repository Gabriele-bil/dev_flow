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
#   - le skill sono i comandi slash: name = nome della cartella (devflow-<passo>,
#     /devflow-<passo>), e /devflow:<passo> del build Claude Code → /devflow-<passo>.
#   - frontmatter: via i campi solo-Claude Code da skill e agenti;
#     disable-model-invocation resta: agy 1.4.9 lo rispetta (non documentato);
#     `tools` degli agenti tradotto nella lista di tool ammessi di agy.
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
for ITEM in skills adapters hooks agents references templates scripts config.md ETHOS.md agent.yaml README.md LICENSE; do
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
# disable-model-invocation non è qui: agy 1.4.9 lo rispetta (verificato: la skill
# non si attiva da sola e resta invocabile come /<nome>), anche se non è documentato.
CLAUDE_ONLY_SKILL_KEYS="model effort allowed-tools context agent background"
while IFS= read -r f; do
  # shellcheck disable=SC2086
  strip_frontmatter_keys "$f" $CLAUDE_ONLY_SKILL_KEYS
done < <(find "$AGY_DIR/skills" "$AGY_DIR/adapters" -name SKILL.md)
USER_ONLY_CC="$(grep -l '^disable-model-invocation: true' "$DIST_DIR"/skills/*/SKILL.md | wc -l | tr -d ' ')"
USER_ONLY_AGY="$(grep -l '^disable-model-invocation: true' "$AGY_DIR"/skills/*/SKILL.md | wc -l | tr -d ' ')"
[ "$USER_ONLY_CC" = "$USER_ONLY_AGY" ] || fail "disable-model-invocation perso: $USER_ONLY_CC skill in Claude Code, $USER_ONLY_AGY in Antigravity"

# agy_tools "Read, Grep, Bash" → "[view_file, grep_search, run_command]".
# In agy `tools` è una lista di tool ammessi (verificato su agy 1.4.10: un agente
# con [view_file, run_command] non ha tool di scrittura), quindi i revisori di
# ship restano in sola lettura come su Claude Code; disallowedTools non serve.
agy_tools() {
  local out="" t m
  for t in $(printf '%s' "$1" | tr ',[]' '   '); do
    case "$t" in
      Read) m="view_file" ;;
      Grep) m="grep_search" ;;
      Glob) m="find_by_name list_dir" ;;
      Bash) m="run_command" ;;
      Write) m="write_to_file" ;;
      Edit|MultiEdit) m="replace_file_content multi_replace_file_content" ;;
      WebFetch) m="read_url_content" ;;
      WebSearch) m="search_web" ;;
      Agent|Task) m="invoke_subagent" ;;
      *) return 1 ;;
    esac
    out="$out $m"
  done
  printf '[%s]' "$(printf '%s\n' $out | awk '!seen[$0]++' | paste -sd, - | sed 's/,/, /g')"
}

for f in "$AGY_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  CC_TOOLS="$(awk 'NR > 1 && /^---$/ { exit } /^tools:/ { sub(/^tools:[[:space:]]*/, ""); print }' "$f")"
  strip_frontmatter_keys "$f" tools disallowedTools model effort maxTurns experimental
  if [ -n "$CC_TOOLS" ]; then
    AGY_TOOLS="$(agy_tools "$CC_TOOLS")" || fail "$(basename "$f"): tool senza equivalente agy in '$CC_TOOLS' — aggiungerlo ad agy_tools"
  else
    # Senza tools Claude Code eredita tutto; un subagente agy senza tools resta
    # senza scrittura né shell (verificato su agy 1.4.10): set di sviluppo
    # esplicito, senza invoke_subagent (i subagenti non lanciano subagenti).
    AGY_TOOLS="$(agy_tools "Read, Grep, Glob, Bash, Write, Edit")"
  fi
  TOOLS_LINE="tools: $AGY_TOOLS"
  # Subagente invocabile via invoke_subagent, con gli stessi tool di Claude Code
  awk -v t="$TOOLS_LINE" 'NR == 1 && $0 == "---" { print; print "subagent: true"; if (t != "") print t; next } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
# Un agente senza Write/Edit su Claude Code non deve averli su Antigravity
for f in "$DIST_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  if awk 'NR > 1 && /^---$/ { exit } /^disallowedTools:/ && /Write/' "$f" | grep -q .; then
    grep -qE '^tools: .*(write_to_file|replace_file_content)' "$AGY_DIR/agents/$(basename "$f")" \
      && fail "$(basename "$f"): tool di scrittura nel build Antigravity"
    grep -q '^tools: \[' "$AGY_DIR/agents/$(basename "$f")" || fail "$(basename "$f"): tools mancante nel build Antigravity (l'agente avrebbe i tool di scrittura di default)"
  fi
done
ok "Campi solo-Claude Code rimossi, tools degli agenti tradotti"

# Percorsi del plugin: agy installa in una cartella fissa, quindi anche i file
# letti con Read possono usare il percorso assoluto e la nota "Plugin root"
# della build Claude Code non serve. I template per il consumer (adapters/*/templates)
# restano invariati. @devflow/config.md è del consumer e non viene toccato.
step "Percorsi del plugin → $AGY_STAGING"
PLUGIN_DIRS_RE='(references|adapters|skills|agents|scripts)'
while IFS= read -r f; do
  sed -E -e '/^> \*\*Plugin root:\*\*/d' \
    -e "s#@devflow/${PLUGIN_DIRS_RE}/#$AGY_STAGING/\1/#g" \
    -e "s#\\\$\\{CLAUDE_PLUGIN_ROOT\\}#$AGY_STAGING#g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < <(find "$AGY_DIR/skills" "$AGY_DIR/references" "$AGY_DIR/agents" "$AGY_DIR/adapters" \
  -name '*.md' ! -path '*/templates/*' 2>/dev/null)
LEFT="$(find "$AGY_DIR/skills" "$AGY_DIR/references" "$AGY_DIR/agents" "$AGY_DIR/adapters" \
  -name '*.md' ! -path '*/templates/*' -exec grep -lE "@devflow/${PLUGIN_DIRS_RE}/|CLAUDE_PLUGIN_ROOT|Plugin root:" {} + 2>/dev/null || true)"
[ -z "$LEFT" ] || fail "percorsi non tradotti in: $LEFT"
ok "Percorsi del plugin risolti"

# ── Nomi slash ────────────────────────────────────────────────────────────────
# Il build Claude Code accorcia name: devflow-<passo> in name: <passo> (comando
# /devflow:<passo>). agy non mette prefissi di plugin e vuole name uguale alla
# cartella: qui il comando resta /devflow-<passo>, che non collide con /plan & co.
step "Nomi slash → /$NAME-<passo>"
for d in "$AGY_DIR"/skills/*/; do
  f="$d/SKILL.md"; [ -f "$f" ] || continue
  dir_name="$(basename "$d")"
  awk -v n="$dir_name" 'NR > 1 && /^---$/ { fm = 1 } !fm && !done && /^name:/ { print "name: " n; done = 1; next } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
AGY_STEPS_RE="$(find "$AGY_DIR/skills" -mindepth 1 -maxdepth 1 -type d -name "$NAME-*" | sed "s#.*/$NAME-##" | sort -r | paste -sd'|' -)"
while IFS= read -r f; do
  sed -E "s#/${NAME}:(${AGY_STEPS_RE})([^a-z-]|\$)#/${NAME}-\1\2#g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < <(grep -rlE "/${NAME}:(${AGY_STEPS_RE})" "$AGY_DIR" --include='*.md' --include='*.sh' --include='*.yaml' --include='*.html' --include='*.json' 2>/dev/null)
LEFT="$(grep -rlE "/${NAME}:(${AGY_STEPS_RE})([^a-z-]|\$)" "$AGY_DIR" 2>/dev/null || true)"
[ -z "$LEFT" ] || fail "/$NAME:<passo> non tradotto in: $LEFT"
ok "Skill invocabili come /$NAME-<passo>"

# ── Nomi dei tool ─────────────────────────────────────────────────────────────
# Il build Claude Code ha lasciato `AskUserQuestion`: qui diventa ask_question,
# tranne nelle righe di tabella etichettate per host (**Claude Code**), dove la
# sintassi della chiamata è quella di Claude Code.
step "Nomi dei tool → Antigravity"
while IFS= read -r f; do
  sed -E '/\*\*Claude Code\*\*/!s#AskUserQuestion#ask_question#g' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < <(grep -rl 'AskUserQuestion' "$AGY_DIR/skills" "$AGY_DIR/references" "$AGY_DIR/agents" "$AGY_DIR/adapters" 2>/dev/null)
LEFT="$(grep -rn 'AskUserQuestion' "$AGY_DIR/skills" "$AGY_DIR/references" "$AGY_DIR/agents" "$AGY_DIR/adapters" 2>/dev/null | grep -v '\*\*Claude Code\*\*' || true)"
[ -z "$LEFT" ] || fail "AskUserQuestion rimasto fuori dalle righe per host: $LEFT"
ok "Domande all'utente: ask_question"

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
