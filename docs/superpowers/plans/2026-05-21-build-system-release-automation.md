# Build System manifest-driven + Release Automation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce manifest-driven build system (templates/ → dist/) and release-please automation, porting the pattern from `ai-setup-meta` into `dev_flow`.

**Architecture:** Source lives in `templates/devflow/`, built output in `dist/devflow/` (committed). A bash build system reads `manifest.json` and regenerates `dist/` idempotently. Release-please reads Conventional Commits and automates semver bump + GitHub Release via GitHub Actions.

**Tech Stack:** bash, jq, `googleapis/release-please-action@v4`, GitHub Actions

---

## File map

| Action | Path | Responsibility |
|--------|------|---------------|
| Move | `devflow/` → `templates/devflow/` | Source del plugin |
| Create | `templates/devflow/manifest.json` | Metadata: name, version, description, author, platform support |
| Create | `dist/devflow/` | Build output (committed) |
| Create | `scripts/build-plugin.sh` | Orchestratore: legge manifest, chiama builder |
| Create | `scripts/builders/common.sh` | Funzioni condivise: ok/warn/fail/step |
| Create | `scripts/builders/build-claude.sh` | Genera dist/ per Claude Code |
| Create | `scripts/builders/build-cursor.sh` | Aggiunge layer Cursor su dist/ |
| Modify | `.claude-plugin/marketplace.json` | source: `./devflow` → `./dist/devflow` |
| Modify | `CLAUDE.md` | Aggiorna tutti i path devflow/ → templates/devflow/ |
| Modify | `templates/devflow/CONTRIBUTING.md` | Aggiorna path script validate-skills |
| Create | `release-please-config.json` | Config release-please (package devflow, extra-files) |
| Create | `.release-please-manifest.json` | Versione corrente: `{ ".": "1.0.0" }` |
| Create | `CHANGELOG.md` | Header iniziale, gestito da release-please |
| Create | `.github/workflows/build-verify.yml` | CI: verifica dist/ in sync su ogni PR |
| Create | `.github/workflows/release-please.yml` | CI: bump semver + GitHub Release su push main |

---

## Task 1: Sposta devflow/ → templates/devflow/

**Files:**
- Move: `devflow/` → `templates/devflow/`
- Create: `templates/devflow/manifest.json`

- [ ] **Step 1: Crea directory templates/ e sposta devflow/**

```bash
mkdir -p templates
git mv devflow templates/devflow
```

- [ ] **Step 2: Verifica che git tracki il move**

```bash
git status
```

Atteso: tutti i file `devflow/*` mostrati come rinominati in `templates/devflow/*`. Nessun file perso.

- [ ] **Step 3: Verifica che validate-skills.sh funzioni dal nuovo path**

```bash
bash templates/devflow/scripts/validate-skills.sh
```

Atteso: output con `Validating N skill files...` e `✓` o warning — nessun errore fatale. Lo script risolve il plugin root da `dirname "$0"/..` quindi funziona senza modifiche.

- [ ] **Step 4: Crea templates/devflow/manifest.json**

```json
{
  "name": "devflow",
  "description": "Spec-driven development pipeline: idea → task → plan → implement → beautify → test → PR. Adapter-based architecture — supports Angular, Flutter and Next.js.",
  "version": "1.0.0",
  "author": "DevFlow",
  "cursor_support": true
}
```

- [ ] **Step 5: Commit**

```bash
git add templates/ .
git commit -m "refactor: move devflow/ to templates/devflow/ and add manifest.json"
```

---

## Task 2: Crea scripts/builders/common.sh

**Files:**
- Create: `scripts/builders/common.sh`

- [ ] **Step 1: Crea directory scripts/builders/**

```bash
mkdir -p scripts/builders
```

- [ ] **Step 2: Scrivi common.sh**

Crea `scripts/builders/common.sh`:

```bash
#!/usr/bin/env bash
# common.sh — Funzioni condivise per i builder di plugin.
# Non eseguire direttamente: importato via source dai builder.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }
step() { echo -e "\n${YELLOW}▶ $1${NC}"; }
```

- [ ] **Step 3: Test smoke di common.sh**

```bash
bash -c 'source scripts/builders/common.sh && ok "common.sh caricato" && warn "test warn" && step "test step"'
```

Atteso: output colorato con ✓, ⚠, ▶. Nessun errore.

- [ ] **Step 4: Commit**

```bash
git add scripts/builders/common.sh
git commit -m "feat(build): add common.sh with ok/warn/fail/step helpers"
```

---

## Task 3: Crea scripts/builders/build-claude.sh

**Files:**
- Create: `scripts/builders/build-claude.sh`

- [ ] **Step 1: Scrivi il test di verifica (verrà eseguito in Task 5)**

Nota: `build-claude.sh` richiede le variabili esportate dall'orchestratore. Il test completo è in Task 5. Qui si verifica solo la sintassi.

```bash
bash -n scripts/builders/build-claude.sh
```

Atteso: nessun output (syntax ok). Eseguire questo comando DOPO il Step 2.

- [ ] **Step 2: Scrivi build-claude.sh**

Crea `scripts/builders/build-claude.sh`:

```bash
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

# Aggiorna source in .claude-plugin/marketplace.json
step "Aggiornamento .claude-plugin/marketplace.json"

MARKETPLACE="$ROOT_DIR/.claude-plugin/marketplace.json"

if [ -f "$MARKETPLACE" ]; then
  jq --arg name "$NAME" --arg src "./dist/$NAME" --arg ver "$VERSION" \
    '(.plugins[] | select(.name == $name)) |= (.source = $src | .version = $ver)' \
    "$MARKETPLACE" > "${MARKETPLACE}.tmp" \
    && mv "${MARKETPLACE}.tmp" "$MARKETPLACE"
  ok "marketplace.json: source → ./dist/$NAME, version → $ver"
else
  warn "marketplace.json non trovato — skip"
fi
```

- [ ] **Step 3: Rendi eseguibile e verifica sintassi**

```bash
chmod +x scripts/builders/build-claude.sh
bash -n scripts/builders/build-claude.sh
```

Atteso: nessun output (syntax ok).

- [ ] **Step 4: Commit**

```bash
git add scripts/builders/build-claude.sh
git commit -m "feat(build): add build-claude.sh"
```

---

## Task 4: Crea scripts/builders/build-cursor.sh

**Files:**
- Create: `scripts/builders/build-cursor.sh`

- [ ] **Step 1: Scrivi build-cursor.sh**

Crea `scripts/builders/build-cursor.sh`:

```bash
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
```

- [ ] **Step 2: Rendi eseguibile e verifica sintassi**

```bash
chmod +x scripts/builders/build-cursor.sh
bash -n scripts/builders/build-cursor.sh
```

Atteso: nessun output (syntax ok).

- [ ] **Step 3: Commit**

```bash
git add scripts/builders/build-cursor.sh
git commit -m "feat(build): add build-cursor.sh"
```

---

## Task 5: Crea scripts/build-plugin.sh ed esegui primo build

**Files:**
- Create: `scripts/build-plugin.sh`
- Create: `dist/devflow/` (output del build)

- [ ] **Step 1: Scrivi test di verifica (da eseguire DOPO il build)**

Salva questo snippet in testa per riferimento — verrà eseguito al Step 4:

```bash
# dist/ esiste
[ -d dist/devflow ] && echo "PASS: dist/devflow esiste" || echo "FAIL: dist/devflow mancante"

# plugin.json ha versione corretta
MANIFEST_VER=$(jq -r '.version' templates/devflow/manifest.json)
PLUGIN_VER=$(jq -r '.version' dist/devflow/.claude-plugin/plugin.json)
[ "$MANIFEST_VER" = "$PLUGIN_VER" ] \
  && echo "PASS: versione coerente ($PLUGIN_VER)" \
  || echo "FAIL: versione mismatch (manifest=$MANIFEST_VER, plugin=$PLUGIN_VER)"

# .cursor-plugin/plugin.json esiste
[ -f dist/devflow/.cursor-plugin/plugin.json ] \
  && echo "PASS: .cursor-plugin/plugin.json esiste" \
  || echo "FAIL: .cursor-plugin/plugin.json mancante"

# hooks.cursor.json generato
[ -f dist/devflow/hooks/hooks.cursor.json ] \
  && echo "PASS: hooks.cursor.json esiste" \
  || echo "FAIL: hooks.cursor.json mancante"

# marketplace.json aggiornato a ./dist/devflow
SOURCE=$(jq -r '.plugins[] | select(.name=="devflow") | .source' .claude-plugin/marketplace.json)
[ "$SOURCE" = "./dist/devflow" ] \
  && echo "PASS: marketplace source = ./dist/devflow" \
  || echo "FAIL: marketplace source = $SOURCE (atteso ./dist/devflow)"

# cursorPluginRoot in hooks.cursor.json
grep -q 'cursorPluginRoot' dist/devflow/hooks/hooks.cursor.json \
  && echo "PASS: hooks.cursor.json usa cursorPluginRoot" \
  || echo "FAIL: hooks.cursor.json non contiene cursorPluginRoot"
```

- [ ] **Step 2: Scrivi build-plugin.sh**

Crea `scripts/build-plugin.sh`:

```bash
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

step "Build plugin: $NAME v$VERSION"

bash "$BUILDERS_DIR/build-claude.sh"

if [ "$CURSOR_SUPPORT" = "true" ]; then
  bash "$BUILDERS_DIR/build-cursor.sh"
fi

echo ""
ok "Build completato → dist/devflow/ (Claude Code + Cursor)"
```

- [ ] **Step 3: Rendi eseguibile e verifica sintassi**

```bash
chmod +x scripts/build-plugin.sh
bash -n scripts/build-plugin.sh
```

- [ ] **Step 4: Esegui il build**

```bash
bash scripts/build-plugin.sh
```

Atteso: sequenza di `▶` e `✓` senza errori. Output finale: `✓ Build completato → dist/devflow/`.

- [ ] **Step 5: Esegui le verifiche del Step 1**

Copia e incolla il blocco del Step 1. Tutti i check devono stampare `PASS`.

- [ ] **Step 6: Commit scripts + dist/**

```bash
git add scripts/ dist/ .claude-plugin/marketplace.json
git commit -m "feat(build): add build-plugin.sh and initial dist/ output"
```

---

## Task 6: Aggiorna CLAUDE.md e CONTRIBUTING.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `templates/devflow/CONTRIBUTING.md`

- [ ] **Step 1: Aggiorna CLAUDE.md**

Sostituisci il contenuto di `CLAUDE.md` con:

```markdown
# DevFlow Plugin — Claude Code Context

Plugin Claude Code + Cursor per pipeline di sviluppo spec-driven.
Leggi `templates/devflow/CONTRIBUTING.md` per quality bar e stile prima di modificare qualsiasi skill.

## Struttura critica

- `templates/devflow/` — plugin source (modifica qui)
- `dist/devflow/` — plugin installabile (output del build, committato)
- `templates/devflow/.claude-plugin/` — NON esiste: il manifest è generato dal build
- `dist/devflow/.claude-plugin/plugin.json` — manifest Claude Code (generato)
- `templates/devflow/skills/<name>/SKILL.md` — skill pipeline core
- `templates/devflow/adapters/<stack>/skills/<name>/SKILL.md` — skill adapter-specifiche
- `templates/devflow/hooks/` — shell scripts + `hooks.json` (lifecycle hooks)
- `templates/devflow/commands/` — entry point comandi slash

## Regole operative

- Ogni SKILL.md deve avere frontmatter YAML con `name` e `description`
- Sections obbligatorie: `## Purpose`, `## Core Principles`, `## When NOT to Use`, `## I/O Reference`
- Dopo ogni modifica a SKILL.md: validare con `bash templates/devflow/scripts/validate-skills.sh`
- Dopo ogni modifica a skills/adapters/hooks: rebuilddare con `bash scripts/build-plugin.sh`
- Non toccare `templates/devflow/config.md` — è generato da `devflow.setup` nel consumer project
- Non scrivere file dentro `devflow/features/` — sono artefatti del consumer project

## Comandi utili

```bash
# Validare tutti i SKILL.md
bash templates/devflow/scripts/validate-skills.sh

# Rebuilddare dist/ dopo modifiche
bash scripts/build-plugin.sh

# Verificare sintassi hook scripts
bash -n templates/devflow/hooks/<script>.sh
```

## Cosa NON fare

- Non modificare file in `dist/` direttamente — sono output del build
- Non aggiungere logica di business nelle template — vanno nelle skills
- Non aggiungere hook sincroni pesanti (`async: true` + `timeout` per operazioni I/O)
- Non modificare `hooks.json` senza aggiornare i relativi script in `templates/devflow/hooks/`
```

- [ ] **Step 2: Aggiorna path script in templates/devflow/CONTRIBUTING.md**

Trova la riga che referenzia `devflow/scripts/validate-skills.sh` e aggiornala:

```bash
# Prima:   bash devflow/scripts/validate-skills.sh
# Dopo:    bash templates/devflow/scripts/validate-skills.sh
sed -i '' 's|bash devflow/scripts/validate-skills.sh|bash templates/devflow/scripts/validate-skills.sh|g' \
  templates/devflow/CONTRIBUTING.md
```

Verifica:
```bash
grep 'validate-skills' templates/devflow/CONTRIBUTING.md
```
Atteso: path `templates/devflow/scripts/validate-skills.sh`.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md templates/devflow/CONTRIBUTING.md
git commit -m "docs: update paths from devflow/ to templates/devflow/ after restructure"
```

---

## Task 7: Crea release-please-config.json e file correlati

**Files:**
- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Crea release-please-config.json**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "devflow",
      "include-component-in-tag": true,
      "tag-separator": "-",
      "bump-minor-pre-major": false,
      "bump-patch-for-minor-pre-major": false,
      "draft": false,
      "prerelease": false,
      "changelog-path": "CHANGELOG.md",
      "extra-files": [
        {
          "type": "json",
          "path": "templates/devflow/manifest.json",
          "jsonpath": "$.version"
        },
        {
          "type": "json",
          "path": "dist/devflow/.claude-plugin/plugin.json",
          "jsonpath": "$.version"
        },
        {
          "type": "json",
          "path": "dist/devflow/.cursor-plugin/plugin.json",
          "jsonpath": "$.version"
        },
        {
          "type": "json",
          "path": ".claude-plugin/marketplace.json",
          "jsonpath": "$.plugins[?(@.name == 'devflow')].version"
        }
      ]
    }
  },
  "plugins": ["sentence-case"]
}
```

- [ ] **Step 2: Crea .release-please-manifest.json**

```json
{
  ".": "1.0.0"
}
```

- [ ] **Step 3: Crea CHANGELOG.md**

```markdown
# Changelog
```

- [ ] **Step 4: Verifica JSON valido**

```bash
jq . release-please-config.json > /dev/null && echo "PASS: release-please-config.json valido" || echo "FAIL"
jq . .release-please-manifest.json > /dev/null && echo "PASS: .release-please-manifest.json valido" || echo "FAIL"
```

Atteso: entrambi `PASS`.

- [ ] **Step 5: Commit**

```bash
git add release-please-config.json .release-please-manifest.json CHANGELOG.md
git commit -m "chore: add release-please config and manifest"
```

---

## Task 8: Crea .github/workflows/build-verify.yml

**Files:**
- Create: `.github/workflows/build-verify.yml`

- [ ] **Step 1: Crea directory .github/workflows/**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Scrivi build-verify.yml**

Crea `.github/workflows/build-verify.yml`:

```yaml
name: Build Verify

# Verifica che dist/ sia in sync con templates/ e scripts/.
# Lancia build-plugin.sh e fallisce se il rebuild produce modifiche.

on:
  pull_request:
    branches: [main]
    paths:
      - 'templates/**'
      - 'scripts/**'
      - 'dist/**'
      - '.claude-plugin/**'
      - '.github/workflows/build-verify.yml'

permissions:
  contents: read

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install jq
        run: sudo apt-get update -qq && sudo apt-get install -y -qq jq

      - name: Build plugin
        run: bash scripts/build-plugin.sh

      - name: Check dist/ is in sync
        run: |
          if ! git diff --quiet -- dist/ .claude-plugin/; then
            echo "::error::dist/ o marketplace.json out of sync. Esegui 'bash scripts/build-plugin.sh' localmente e committa il risultato."
            git --no-pager diff --stat -- dist/ .claude-plugin/
            exit 1
          fi
          echo "✓ dist/ in sync con templates/"
```

- [ ] **Step 3: Verifica YAML valido**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-verify.yml'))" \
  && echo "PASS: YAML valido" || echo "FAIL: YAML non valido"
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/build-verify.yml
git commit -m "ci: add build-verify workflow to check dist/ sync on PRs"
```

---

## Task 9: Crea .github/workflows/release-please.yml

**Files:**
- Create: `.github/workflows/release-please.yml`

- [ ] **Step 1: Scrivi release-please.yml**

Crea `.github/workflows/release-please.yml`:

```yaml
name: Release Please

# Su ogni push su main, release-please calcola il bump dai Conventional Commits
# dall'ultimo tag devflow-v* e apre/aggiorna una release PR.
# Al merge della release PR: crea tag annotato devflow-v* + GitHub Release.
#
# Conventional Commits → impatto versione:
#   feat:             MINOR bump (1.0.0 → 1.1.0)
#   fix:              PATCH bump (1.0.0 → 1.0.1)
#   feat!: / BREAKING CHANGE:  MAJOR bump
#   docs:, chore:, refactor:, test:  nessun bump

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
          token: ${{ secrets.GITHUB_TOKEN }}

      - uses: actions/checkout@v4
        if: ${{ steps.release.outputs['.--release_created'] }}

      - name: Rebuild dist after release
        if: ${{ steps.release.outputs['.--release_created'] }}
        run: |
          sudo apt-get update -qq && sudo apt-get install -y -qq jq
          bash scripts/build-plugin.sh
          if ! git diff --quiet -- dist/; then
            git config user.name "github-actions[bot]"
            git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
            git add dist/
            git commit -m "chore(dist): rebuild after release ${{ steps.release.outputs['.--tag_name'] }}"
            git push origin main
          else
            echo "dist/ in sync — niente da committare"
          fi
```

- [ ] **Step 2: Verifica YAML valido**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release-please.yml'))" \
  && echo "PASS: YAML valido" || echo "FAIL: YAML non valido"
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release-please.yml
git commit -m "ci: add release-please workflow for automated semver + GitHub Release"
```

---

## Task 10: Verifica end-to-end

- [ ] **Step 1: Build pulito da zero**

```bash
rm -rf dist/devflow
bash scripts/build-plugin.sh
```

Atteso: nessun errore, `✓ Build completato → dist/devflow/`.

- [ ] **Step 2: Verifica struttura dist/**

```bash
ls dist/devflow/
```

Atteso (almeno): `skills/  adapters/  hooks/  agents/  commands/  contexts/  references/  .claude-plugin/  .cursor-plugin/  ETHOS.md  README.md  config.md  AGENTS.md`

- [ ] **Step 3: Verifica plugin.json**

```bash
jq '{name,version,description}' dist/devflow/.claude-plugin/plugin.json
jq '{name,version,description}' dist/devflow/.cursor-plugin/plugin.json
```

Atteso: `name: "devflow"`, `version: "1.0.0"`, description corretta.

- [ ] **Step 4: Verifica hooks.cursor.json**

```bash
grep -c 'cursorPluginRoot' dist/devflow/hooks/hooks.cursor.json
grep -c 'CLAUDE_PLUGIN_ROOT' dist/devflow/hooks/hooks.cursor.json
```

Atteso: prima riga > 0, seconda riga = 0.

- [ ] **Step 5: Verifica marketplace.json**

```bash
jq '.plugins[] | select(.name=="devflow") | {source, version}' .claude-plugin/marketplace.json
```

Atteso: `source: "./dist/devflow"`, `version: "1.0.0"` (campo version ora iniettato dal build)

- [ ] **Step 6: Verifica skills sono in dist/**

```bash
ls dist/devflow/skills/
ls dist/devflow/adapters/
```

Atteso: tutte le skill core (devflow-task, devflow-plan, ecc.) e tutti gli adapter (angular, flutter, nextjs, common).

- [ ] **Step 7: validate-skills dal path originale ancora funziona**

```bash
bash templates/devflow/scripts/validate-skills.sh
```

Atteso: output con conteggio skill, nessun errore fatale.

- [ ] **Step 8: Verifica JSON release-please**

```bash
jq . release-please-config.json && jq . .release-please-manifest.json
```

Atteso: JSON valido stampato senza errori.

- [ ] **Step 9: Commit finale se ci sono file non tracciati**

```bash
git status
# Se dist/ o altri file hanno modifiche non committate:
git add -A
git commit -m "chore: final dist/ sync after end-to-end verification"
```
