# Design: Build System manifest-driven + Release Automation

**Data:** 2026-05-21  
**Scope:** Porta da `ai-setup-meta` → `dev_flow`: separazione source/dist, build system manifest-driven, release automation con release-please + GitHub Actions.  
**Stack auto-detection:** già implementato in `devflow.setup` Step 1 — fuori scope.

---

## Contesto

`dev_flow` oggi ha `devflow/` che è simultaneamente source e plugin installabile. I plugin manifest (`.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`) sono mantenuti a mano e non hanno versioning automatico. Non esiste CI né release process.

`ai-setup-meta` usa un paradigma `templates/` (source) → `dist/` (output compilato) con build system manifest-driven e release-please per versioning automatico. Questo design porta lo stesso pattern in `dev_flow`.

---

## 1. Struttura repo

### Trasformazione

```
PRIMA                              DOPO
dev_flow/                          dev_flow/
  devflow/                           templates/
    skills/                            devflow/          ← source (rinominato)
    adapters/                            manifest.json   ← NEW
    hooks/                               skills/
    agents/                              adapters/
    commands/                            hooks/
    contexts/                            contexts/
    references/                          references/
    scripts/                             agents/
    templates/                           commands/
    .claude-plugin/                      scripts/
    .cursor-plugin/                      templates/
    ...                                  ...
                                     dist/
                                       devflow/          ← output (committato)
                                         .claude-plugin/ ← generato
                                         .cursor-plugin/ ← generato
                                         skills/
                                         adapters/
                                         hooks/
                                         agents/
                                         commands/
                                         contexts/
                                         references/
                                         templates/
                                         ...
                                     scripts/
                                       build-plugin.sh
                                       builders/
                                         common.sh
                                         build-claude.sh
                                         build-cursor.sh
                                     .github/
                                       workflows/
                                         release-please.yml
                                         build-verify.yml
                                     release-please-config.json
                                     .release-please-manifest.json
                                     CHANGELOG.md
```

### Regole dist/

- `dist/devflow/` = copia di `templates/devflow/` **esclusi** `CONTRIBUTING.md` e `scripts/`
- Plugin manifest (`.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`) **rigenerati** da `manifest.json`
- `dist/` è **committato** — il marketplace Claude Code installa da `./dist/devflow`
- Build è **idempotente**: ogni run ricrea `dist/devflow/` da zero

### marketplace.json

```json
// PRIMA
{ "source": "./devflow" }

// DOPO
{ "source": "./dist/devflow" }
```

---

## 2. Build system

### `templates/devflow/manifest.json`

```json
{
  "name": "devflow",
  "description": "Spec-driven development pipeline: idea → task → plan → implement → beautify → test → PR. Adapter-based architecture — supports Angular, Flutter and Next.js.",
  "version": "1.0.0",
  "author": "DevFlow",
  "cursor_support": true
}
```

Source of truth per nome, versione, description, author. Release-please bumpa `$.version` qui.

### `scripts/build-plugin.sh`

Orchestratore:
1. Legge `templates/devflow/manifest.json` con `jq`
2. Esporta variabili condivise: `TEMPLATE_DIR`, `DIST_DIR`, `NAME`, `VERSION`, `DESCRIPTION`, `AUTHOR`
3. Chiama `build-claude.sh`
4. Se `cursor_support: true` → chiama `build-cursor.sh`

Prerequisiti: `bash`, `jq`.

### `scripts/builders/common.sh`

Funzioni condivise con output colorato:
- `ok()` → verde ✓
- `warn()` → giallo ⚠
- `fail()` → rosso ✗ + exit 1
- `step()` → giallo ▶ (header di fase)

### `scripts/builders/build-claude.sh`

Genera `dist/devflow/` per Claude Code:

1. Ricrea directory da zero (`rm -rf dist/devflow && mkdir -p`)
2. Copia da `templates/devflow/`:
   - `skills/`, `adapters/`, `hooks/`, `agents/`, `commands/`
   - `contexts/`, `references/`, `templates/`
   - `config.md`, `ETHOS.md`, `AGENTS.md`, `agent.yaml`, `README.md`
   - *(esclusi: `CONTRIBUTING.md`, `scripts/`, `manifest.json`)*
3. Genera `dist/devflow/.claude-plugin/plugin.json` da manifest (nome, versione, description, author)
4. Aggiorna `source` in `.claude-plugin/marketplace.json` → `./dist/devflow`

### `scripts/builders/build-cursor.sh`

Aggiunge layer Cursor su `dist/devflow/` (richiede build-claude già eseguito):

1. Genera `dist/devflow/.cursor-plugin/plugin.json` da manifest (senza `mcpServers`, `userConfig`)
2. Genera `dist/devflow/hooks/hooks.cursor.json`:  
   `sed 's|${CLAUDE_PLUGIN_ROOT}|${cursorPluginRoot}|g' hooks/hooks.json`

---

## 3. Release automation

### Conventional Commits

| Tipo | Impatto versione |
|------|-----------------|
| `feat:` | MINOR bump (1.0.0 → 1.1.0) |
| `fix:` | PATCH bump (1.0.0 → 1.0.1) |
| `feat!:` / `BREAKING CHANGE:` | MAJOR bump |
| `docs:`, `chore:`, `refactor:`, `test:` | nessun bump |

### `release-please-config.json`

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "devflow",
      "include-component-in-tag": true,
      "tag-separator": "-",
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
  }
}
```

### `.release-please-manifest.json`

```json
{ ".": "1.0.0" }
```

### `.github/workflows/release-please.yml`

Trigger: push su `main`

1. `googleapis/release-please-action@v4` — calcola bump dai commit, apre/aggiorna release PR
2. Al merge della release PR:
   - Crea tag annotato `devflow-v*` + GitHub Release
   - Esegue `bash scripts/build-plugin.sh` con la nuova versione
   - Se `dist/` ha diff → committa `chore(dist): rebuild after release <tag>`

### `.github/workflows/build-verify.yml`

Trigger: PR su `main` che tocca `templates/**`, `scripts/**`, `dist/**`, `.claude-plugin/**`

1. Installa `jq`
2. `bash scripts/build-plugin.sh`
3. `git diff --quiet -- dist/ .claude-plugin/` → fail se out of sync

---

## 4. File da aggiornare

| File | Modifica |
|------|---------|
| `CLAUDE.md` | `devflow/` → `templates/devflow/` come source; `dist/devflow/` come installabile; path script `bash templates/devflow/scripts/validate-skills.sh` |
| `.claude-plugin/marketplace.json` | `"source": "./devflow"` → `"source": "./dist/devflow"` |
| `.gitignore` | Verificare che `dist/` NON sia ignorato (deve essere committato) |
| `templates/devflow/CONTRIBUTING.md` | Aggiornare path script validate-skills |

---

## 5. Verifica

```bash
# 1. Build funziona
bash scripts/build-plugin.sh
# Output atteso: ✓ per ogni step, dist/devflow/ popolato

# 2. dist/ in sync dopo build
git diff --quiet -- dist/ .claude-plugin/ && echo "IN SYNC" || echo "OUT OF SYNC"

# 3. Plugin manifest corretti
cat dist/devflow/.claude-plugin/plugin.json  # version, name, description ok
cat dist/devflow/.cursor-plugin/plugin.json  # idem, senza mcpServers/userConfig

# 4. hooks.cursor.json generato correttamente
grep 'cursorPluginRoot' dist/devflow/hooks/hooks.cursor.json

# 5. validate-skills.sh funziona dal nuovo path
bash templates/devflow/scripts/validate-skills.sh

# 6. marketplace.json aggiornato
cat .claude-plugin/marketplace.json | grep '"source"'  # deve essere ./dist/devflow
```
