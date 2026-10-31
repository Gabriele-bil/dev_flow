# DevFlow — punti da migliorare

Analisi del plugin `devflow` v1.19.0 (commit `de796f3`, 2026-10-28), come plugin per due host: **Claude Code** e **Antigravity CLI** (`agy` 1.2.14).

## Come è stata fatta l'analisi

Verifiche eseguite:

- `validate-skills.sh --strict`, `validate-adapters.sh`, `validate-doc-links.sh`, `run-evals.sh`: tutti verdi.
- `run-hook-tests.sh`: **fallisce** su macOS (vedi [T-1](#t-1)).
- `bash scripts/build-plugin.sh` su una copia pulita: `dist/` è allineato a `templates/`.
- `claude plugin validate dist/devflow`: 23 warning più un errore per la directory ufficiale (LICENSE).
- `agy plugin validate dist/devflow`: ok, ma `hooks : skipped (not found)`.
- Revisione manuale di hook, skill, comandi, agenti, build e CI, più prove dirette degli hook con payload realistici.
- Documentazione ufficiale: hook di Claude Code (code.claude.com/docs/en/hooks) e plugin e hook di Antigravity CLI (antigravity.google/docs/cli/plugins e la reference del repo `google-antigravity/antigravity-cli`).

**Legenda**

| Simbolo | Significato |
| --- | --- |
| 🔴 / 🟠 / 🟡 | Priorità alta / media / bassa |
| `CC` / `AGY` / `CC+AGY` | Host coinvolto: Claude Code, Antigravity CLI, entrambi |
| ✅ | Verificato con una prova eseguita durante l'analisi |
| 📄 | Ricavato da documentazione o lettura del codice, non provato in una sessione reale |

Percorsi relativi a `templates/devflow/` salvo dove indicato.

---

## Sintesi

Le parti statiche (skill, eval, adapter, link nella documentazione, sincronia di `dist/`) sono in ordine. I problemi stanno nel **comportamento reale degli hook** e nella **portabilità verso Antigravity**:

1. Su Claude Code buona parte degli hook legge un formato di payload che l'host non invia. Le guard di sicurezza non bloccano nulla e i test non se ne accorgono perché usano lo stesso formato sbagliato.
2. Su Antigravity gli hook non vengono installati con il comando documentato nel README. Anche installandoli, sono la copia del file di Claude Code con una sola variabile sostituita: eventi, nomi dei tool e struttura del file non corrispondono a quelli di Antigravity.
3. Lo stato condiviso (`.devflow-state.json`) si può corrompere con hook in parallelo.
4. Alcuni passaggi della pipeline si contraddicono (resume, ciclo di correzione di ship, run e auto in background).

### I dieci interventi principali

| # | Intervento | Host | Priorità |
| --- | --- | --- | --- |
| [H-1](#h-1) | Leggere `tool_name` / `tool_input` negli hook e aggiornare i fixture dei test | CC | 🔴 |
| [A-1](#a-1) | Rendere gli hook installabili su Antigravity con `agy plugin install` | AGY | 🔴 |
| [A-2](#a-2) | Generare un `hooks.json` nativo per Antigravity (eventi, matcher, formato) | AGY | 🔴 |
| [H-2](#h-2) | Usare il formato di output corretto per SessionStart, Stop e PreCompact | CC | 🔴 |
| [H-3](#h-3) | Leggere il `config.md` del progetto, non quello del plugin | CC+AGY | 🔴 |
| [S-1](#s-1) | Scritture atomiche e lock su `.devflow-state.json` | CC+AGY | 🔴 |
| [H-4](#h-4) | Fallback per `timeout` su macOS | CC+AGY | 🔴 |
| [P-1](#p-1) | Implement che accetta la ripresa (`implementing`) | CC+AGY | 🔴 |
| [P-2](#p-2) | Il ciclo di correzione di ship deve rieseguire i test | CC+AGY | 🔴 |
| [C-1](#c-1) | CI su tutti i path e sui push su `main`, con validazione di entrambi gli host | CC+AGY | 🟠 |
| [C-7](#c-7) | Rimuovere il supporto a Cursor (build, release, install, doc, skill) | repo | 🟠 |

---

## 1. Architettura multi-host

Il problema di fondo è uno solo: **c'è un solo `hooks.json`, scritto per Claude Code, e la variante Antigravity viene prodotta con un `sed`** che sostituisce soltanto `${CLAUDE_PLUGIN_ROOT}` (`scripts/builders/build-antigravity.sh`, alla radice del repo). Gli host differiscono in molto altro.

| Aspetto | Claude Code | Antigravity CLI | Stato attuale in DevFlow |
| --- | --- | --- | --- |
| Posizione di `hooks.json` | `hooks/hooks.json` | `hooks.json` nella radice del plugin | Solo `hooks/`. Antigravity lo trova solo con `scripts/install-plugin.sh` |
| Struttura del file | `{"hooks":{"Evento":[{"matcher","hooks":[{"type":"command","command"}]}]}}` | `{"Evento":[{"matcher","run"}]}` 📄 | Struttura di Claude Code usata per entrambi |
| Eventi | SessionStart, PreToolUse, PostToolUse, PostToolUseFailure, PreCompact, Stop, SessionEnd, Pre/PostModelSwitch… | PreToolUse, PostToolUse, PostInvocation, Stop 📄 | Usati SessionStart, PreCompact e Pre/PostModelSwitch, che Antigravity non documenta |
| Nomi dei tool (matcher) | `Bash`, `Edit`, `Write`, `MultiEdit`, `WebFetch`, `Agent`/`Task` | `write_to_file`, `view_file`, `read_url_content`, `invoke_subagent`, tool shell da verificare 📄 | Solo i nomi di Claude Code |
| Comandi slash | `commands/*.md` | Nessuna cartella `commands/`: `agy` converte i comandi in skill ✅ | 27 skill più 27 comandi convertiti, con nomi quasi uguali (`devflow-ship` e `devflow.ship`) |
| Frontmatter degli agenti | `tools: Read, Grep, Glob, Bash`, `model: sonnet` | `tools: [view_file, …]`, `model: pro`, `subagent: true` 📄 | Solo il formato di Claude Code |
| Frontmatter delle skill | `model`, `effort`, `allowed-tools`, `context: fork`, `disable-model-invocation` | Supporto non documentato | 20 `model`, 20 `effort`, 37 `disable-model-invocation`, 2 `context: fork` |
| Contesto statico | `CLAUDE.md` e iniezione da SessionStart | Cartella `rules/` del plugin | Nessuna cartella `rules/` |

### Proposta di architettura

1. **Un normalizzatore unico** in *hooks/lib/payload.sh* (nuovo). Ogni script lo carica con `source` e ottiene variabili comuni (`DF_HOST`, `DF_EVENT`, `DF_TOOL`, `DF_FILE`, `DF_CMD`, `DF_URL`, `DF_IS_ERROR`), indipendentemente dal formato dell'host. Gli script non leggono più direttamente `.tool_use.*` né `.tool_input.*`.
2. **Un emettitore unico** in *hooks/lib/emit.sh* (nuovo), con funzioni come `df_deny "<motivo>"`, `df_context "<testo>"` e `df_notify "<testo>"`. Ognuna produce il JSON corretto per l'host corrente (`hookSpecificOutput.permissionDecision` su Claude Code, campo `decision` su Antigravity).
3. **Una sola fonte per gli hook**, ad esempio *hooks/hooks.src.json* (nuovo), con nomi logici di eventi e tool (`shell`, `file-edit`, `web-fetch`, `subagent`). Il build genera:
   - `hooks/hooks.json` per Claude Code;
   - `hooks.json` nella radice per Antigravity, traducendo eventi e matcher e **omettendo** gli hook che dipendono da eventi assenti.
4. **Una matrice delle funzioni per host** nel README: cosa funziona su Claude Code, cosa su Antigravity, cosa è degradato. Così l'utente Antigravity sa che l'orientamento a inizio sessione, l'audit dei cambi di modello e il salvataggio prima della compattazione non ci sono.

---

## 2. Hook: correttezza

### H-1

🔴 `CC` ✅ **Gli hook leggono un payload che Claude Code non invia.**

- **Dove:**
  - `hooks/pre-bash-destructive-guard.sh:28`
  - `hooks/pre-config-protect.sh:27`
  - `hooks/pre-scope-guard.sh:20`
  - `hooks/observe.sh:38,70,77`
  - `hooks/post-edit-accumulate.sh:18,26`
  - `hooks/post-edit-instinct-context.sh:32`
  - `hooks/post-task-create.sh:16`
- **Problema:** questi script leggono `.tool_use.name` e `.tool_use.input.*`. Claude Code invia `tool_name`, `tool_input` e `tool_response`.
- **Impatto, provato:**
  - Con il payload reale `rm -rf /` passa e le modifiche a `tsconfig.json` sono consentite.
  - Non viene scritto nulla in `.devflow-changed-files.tmp`, quindi `stop-format-typecheck` non parte mai.
  - `observe` registra `tool:""`, quindi non funzionano churn, instinct, rilevamento dei loop di retry e timing dei comandi.
  - `next_feature_number` non viene incrementato.
- **Test:** i test usano lo stesso formato sbagliato e passano:
  - `hooks/tests/test-pre-bash-destructive-guard.sh:26`
  - `hooks/tests/test-pre-config-protect.sh:25`
  - `test-compact-counter.sh`, `test-retry-loop.sh`, `test-revert-decay.sh`, `test-post-task-create.sh`, `test-post-edit-instinct-context.sh`
- **Correzione:**
  - Introdurre [il normalizzatore](#proposta-di-architettura). Come tampone, usare `.tool_input.X // .tool_use.input.X`, come già fanno `hooks/pre-fetch-cache.sh` e `hooks/post-bash-output-filter.sh`.
  - Riscrivere i fixture con il formato reale.
  - Aggiungere `hooks/tests/fixtures/` con payload **catturati da sessioni reali** di entrambi gli host, e un test che esegue ogni hook su quei payload.

### H-1b

🟠 `CC` 📄 **Il rilevamento dei loop di retry non può attivarsi.**

- **Dove:** `hooks/observe.sh:158`.
- **Problema:** legge `.tool_result.is_error`, ma `PostToolUse` scatta solo sui successi. I fallimenti generano `PostToolUseFailure`.
- **Correzione:** registrare `observe.sh` anche su `PostToolUseFailure`.

### H-2

🔴 `CC` 📄 **Il formato degli output non è quello che Claude Code si aspetta, quindi il contesto non arriva.**

- **Dove e cosa:**
  - `hooks/session-start.sh` e `hooks/session-start-learnings.sh` stampano `{"priority","message"}`, campi che non esistono nello schema di output. Il contesto di orientamento e gli instinct non vengono iniettati.
  - Gli hook Stop (`hooks/stop-format-typecheck.sh`, `hooks/stop-debug-check.sh`) e gli avvisi `/compact` in `observe.sh:224,307` scrivono su stderr ed escono con 0. Né Claude né l'utente li vedono: finiscono solo nel log di debug.
  - L'output di `PreCompact` (`hooks/pre-compact.sh:126`) non viene mai iniettato.
  - `hooks/post-bash-output-filter.sh:186-192` passa `updatedToolOutput` come stringa. Per Bash serve un oggetto `{stdout, stderr, interrupted, isImage}`. Il filtro non ha effetto, ma `.devflow-filter-stats.jsonl` registra risparmi.
  - La convenzione di "passthrough" degli hook Stop (rimandare l'input su stdout) non fa parte del contratto di Claude Code: l'oggetto rimandato viene interpretato come output dell'hook.
- **Correzione:**
  - Usare `hookSpecificOutput.additionalContext` per il contesto destinato a Claude e `systemMessage` per l'utente.
  - Spostare il promemoria post-compattazione in un hook `SessionStart` con matcher `compact`.
  - Eliminare il passthrough.
  - **Aggiornare la tabella "Adding Hooks" in `CONTRIBUTING.md`**, che oggi documenta i comportamenti sbagliati.

### H-3

🔴 `CC+AGY` ✅ **`session-start.sh` legge il `config.md` del plugin.**

- **Dove:** `hooks/session-start.sh:17`, che usa `CONFIG_FILE="${DEVFLOW_CONFIG_FILE:-$SCRIPT_DIR/../config.md}"`.
- **Problema:** quel file è il template distribuito, che contiene ancora `[TODO`. Ogni progetto configurato riceve l'avviso "not configured".
- **Incoerenza nei percorsi:** gli altri hook leggono `$WORKSPACE_ROOT/devflow/config.md`. Nelle skill, 10 file scrivono `@devflow/config.md` e 12 `devflow/config.md`.
- **Correzione:** usare un unico percorso relativo al progetto, `devflow/config.md`, ovunque.

### H-4

🔴 `CC+AGY` ✅ **`timeout` non esiste su macOS.**

- **Dove:** `hooks/stop-format-typecheck.sh:176,181,208,213,240,245`.
- **Problema:** il comando fallisce con "command not found" e il risultato viene riportato come "⚠ dart format issues". I controlli non girano mai.
- **Altri effetti:** `dart format .` (riga 176) riscrive l'intero progetto senza avvisare. L'hook è sincrono, con un timeout fino a 90 s, a ogni fine turno.
- **Correzione:** usare `timeout`, altrimenti `gtimeout`, altrimenti nessun timeout. Formattare solo i file modificati.

### H-5

🟠 `CC+AGY` ✅ **`pre-bash-destructive-guard.sh` si aggira facilmente, anche dopo H-1.**

- **Comandi che passano:** `rm -rf /*`, `rm -rf "$HOME"`, `rm -r -f /`, `git -C . reset --hard`, `git push origin +main`, `git commit -n`, `git -c core.hooksPath=/dev/null commit`.
- **Correzione:**
  - Rimuovere le opzioni globali di git (`-C`, `-c`) prima del confronto.
  - Gestire i flag separati, `/*`, `$HOME`/`${HOME}`, le refspec `+ref` e `-n`.
- **Formato di blocco:** `decision:"block"` è deprecato per `PreToolUse` su Claude Code; il formato attuale è `hookSpecificOutput.permissionDecision:"deny"`. Va aggiornato anche in `pre-config-protect.sh`, `pre-agent-fanout-cap.sh` e `pre-fetch-cache.sh`.
- **Su Antigravity:** valutare di aggiungere a `scripts/install-plugin.sh` una configurazione `permissions.deny` (ad esempio `command(rm -rf)`, `write_file(.git/)`). È un meccanismo nativo, deterministico e indipendente dagli hook.

### H-6

🟠 `CC+AGY` 📄 **Il filtro `yq` di `post-edit-instinct-context.sh` fallisce sempre.**

- **Dove:** `hooks/post-edit-instinct-context.sh:44-48`.
- **Problema:** in `A or B or (.trigger//"") | test(...)` la pipe ha la precedenza più bassa, quindi `test()` riceve un booleano e va in errore. L'errore viene ignorato e l'hook non produce mai output.
- **Altro difetto:** `BASENAME` e `FILE_PATH` sono inseriti nell'espressione senza escape, quindi `[id].tsx` o un apice nel percorso rompono l'espressione.
- **Correzione:** `((.trigger//"") | contains($b))`, con i valori passati tramite `strenv()`.

### H-7

🟠 `CC` 📄 **`stop-metrics.sh` sovrastima token e costi.**

- **Dove:** `hooks/stop-metrics.sh:86-95`.
- **Problemi:**
  - A ogni Stop somma l'uso sugli ultimi 2 MB di transcript, non sul turno corrente. Le righe sono quindi cumulative, e status e board le sommano più volte.
  - Le letture di cache sono contate a prezzo pieno; costano circa un decimo.
  - Il prezzo predefinito di Opus ($15/$75) non è aggiornato.
- **Correzione:**
  - Contare solo i messaggi successivi all'ultimo prompt dell'utente, oppure salvare nello stato l'offset elaborato.
  - Prezzare la cache separatamente.
  - Tenere i prezzi in una sola tabella configurabile.
- **Su Antigravity:** il transcript non esiste nello stesso formato. Disattivare l'hook o leggere i dati d'uso dal payload della status line.

### H-8

🟠 `CC+AGY` 📄 **`pre-agent-fanout-cap.sh` ha una race condition e un bug nelle variabili d'ambiente.**

- **Dove:** `hooks/pre-agent-fanout-cap.sh:28-52`.
- **Race condition:** il contatore viene aggiornato senza lock. Le chiamate parallele nello stesso messaggio, cioè il caso che l'hook dovrebbe limitare, leggono tutte N e scrivono N+1.
- **Bug nelle variabili:**
  - `${CLAUDE_PROJECT_DIR:-${DEVFLOW_FANOUT_STATE_FILE:-…}}` ignora l'override perché `CLAUDE_PROJECT_DIR` è sempre impostata.
  - Tratta inoltre `CLAUDE_PROJECT_DIR` come un file invece che come una directory.
  - Il file di stato non viene aggiunto a `.gitignore`.
  - Stesso errore di precedenza in `post-edit-instinct-context.sh:23`.
- **Su Antigravity:** il matcher `Agent|Task` va tradotto in `invoke_subagent`.

### H-9

🟡 `CC+AGY` 📄 **Il monorepo non funziona in `stop-format-typecheck.sh`.**

- **Dove:** riga 265.
- **Problema:** i percorsi dei file modificati sono assoluti, ma vengono confrontati con il pattern relativo `"$app_path"/*`, quindi nessuna app corrisponde. Anche `cd "$cwd"` e il rilevamento di `.husky`/lefthook dipendono dalla cwd dell'hook.
- **Correzione:** rimuovere il prefisso `$WORKSPACE_ROOT/` e fare `cd` su `$WORKSPACE_ROOT/$app_path`.

### H-10

🟡 `CC+AGY` **Problemi minori negli hook.**

- Sei hook usano `set -euo pipefail`, contro la regola di `CONTRIBUTING.md`: `observe`, `post-edit-instinct-context`, `pre-bash-destructive-guard`, `pre-agent-fanout-cap`, `pre-config-protect`, `pre-scope-guard`.
- `post-edit-instinct-context.sh:27` esce prima di leggere stdin.
- `stop-notify.sh:41` inserisce testo preso dallo stato dentro AppleScript senza escape.
- `post-edit-accumulate.sh:36` usa `grep -qF`, un confronto per sottostringa: `a.ts` risulta già presente se c'è `data.ts`.
- `pre-model-switch.sh:29` blocca il passaggio a Haiku quando `next_step` è `devflow.ship`, cioè quando ship è il prossimo passo e non quando è in esecuzione.
- I `timeout` sugli hook asincroni in `hooks.json` non hanno effetto su Claude Code.
- `${CLAUDE_PLUGIN_ROOT}` non è tra virgolette in tutte e 23 le voci di `hooks.json`: gli hook si rompono se il percorso contiene spazi. Lo segnala `claude plugin validate`.

### H-11

🟡 `CC+AGY` **I log crescono senza limite e alcuni file finiscono nella directory sbagliata.**

- **Mai ruotati:** `.devflow-metrics.jsonl`, `.devflow-timings.jsonl`, `.devflow-filter-stats.jsonl`, `.devflow-model-switch.jsonl`, `.devflow-learnings.jsonl`. Solo `observe.sh` ruota, e il suo `mv` va in race con le altre istanze asincrone.
- **Percorsi relativi alla cwd:** `post-bash-output-filter.sh:63,171` e `post-fetch-cache.sh:77`. Dopo un `cd` i file e le modifiche a `.gitignore` finiscono in sottocartelle.
- **Correzione:** un helper condiviso per la rotazione a dimensione massima, con percorsi ancorati a `WORKSPACE_ROOT`.

---

## 3. Antigravity CLI

### A-1

🔴 `AGY` ✅ **Gli hook non vengono installati con il comando documentato.**

- **Evidenza:** `agy plugin validate ./dist/devflow` riporta `hooks : skipped (not found)`, perché Antigravity cerca `hooks.json` nella radice del plugin. Solo `scripts/install-plugin.sh` (radice del repo) copia *hooks/hooks.antigravity.json* in `hooks.json`. Il README indica invece `agy plugin install ./dist/devflow`, che non installa nessun hook.
- **Correzione:** fare generare a `build-antigravity.sh` direttamente *dist/devflow/hooks.json* (nuovo). Claude Code legge `hooks/hooks.json` e ignora il file nella radice. Allineare README e `install-plugin.sh`.

### A-2

🔴 `AGY` 📄 **Il `hooks.json` di Antigravity è quello di Claude Code con una variabile cambiata.**

- **Eventi:** SessionStart, PreCompact e Pre/PostModelSwitch non sono documentati in Antigravity, che espone PreToolUse, PostToolUse, PostInvocation e Stop.
- **Matcher:** `Bash`, `Write|Edit|MultiEdit`, `WebFetch` e `Agent|Task` non esistono. I nomi nativi sono `write_to_file`, `read_url_content`, `invoke_subagent` e il tool shell (nome da verificare).
- **Struttura:** la documentazione mostra `{"Evento":[{"matcher","run"}]}`, non il formato annidato di Claude Code.
- **Variabile:** `${ANTIGRAVITY_PLUGIN_ROOT}` non compare nella documentazione consultata. I plugin vengono copiati in `~/.gemini/antigravity-cli/plugins/<nome>/`, quindi va verificato se la variabile esiste o se serve un percorso assoluto calcolato all'installazione.
- **Effetto:** anche dopo A-1 è probabile che nessun hook scatti su Antigravity.
- **Verifica:** installare, aprire `/hooks` (elenca anche gli hook dei plugin) ed eseguire un comando innocuo per ciascun matcher. `agy plugin validate` conta il file ma non ne valida la struttura: con un file arbitrario risponde comunque `hooks : 1 processed`.
- **Correzione:** generazione per host, come nella [proposta di architettura](#proposta-di-architettura).

### A-3

🟠 `AGY` 📄 **Payload e formato di blocco sono da verificare.**

- **Problema:** lo schema dello stdin degli hook di Antigravity non è documentato con precisione; per PreToolUse si parla di una stringa `decision`. Le guard emettono `{"decision":"block"}` e leggono i campi di Claude Code.
- **Correzione:**
  - Catturare un payload reale per ciascun evento con un hook `run: "cat > /tmp/agy-<evento>.json"`.
  - Aggiungerlo ai fixture.
  - Mapparlo nel normalizzatore.

### A-4

🟠 `AGY` **Le funzioni basate su SessionStart e PreCompact non esistono su Antigravity.**

- **Funzioni interessate:** orientamento a inizio sessione, instinct iniettati, salvataggio dello stato prima della compattazione, audit dei cambi di modello.
- **Correzione:**
  - Spostare la parte statica dell'orientamento in *rules/devflow-orientation.md* (nuovo), una componente nativa dei plugin Antigravity.
  - Valutare `PostInvocation` per ciò che oggi gira su Stop.
  - Documentare il degrado nella matrice per host.

### A-5

🟠 `AGY` ✅/📄 **Comandi e skill risultano duplicati e il frontmatter è specifico di Claude Code.**

- **Duplicati (✅):** `agy` converte i 27 comandi in skill (`commands : 27 processed (converted to skills)`), che si aggiungono alle 27 skill esistenti. Probabile doppione nel menu slash: `devflow.ship` (comando) e `devflow-ship` (skill).
- **Frontmatter (📄):** `model: sonnet|haiku|opus`, `effort`, `allowed-tools`, `context: fork`, `agent`, `background` e `disable-model-invocation` sono campi di Claude Code. Su Antigravity vengono ignorati o interpretati diversamente: lì `model` accetta valori come `pro`. Le 37 skill e comandi con `disable-model-invocation: true` potrebbero essere invocati automaticamente.
- **Correzione:**
  - Nel build Antigravity, non distribuire `commands/`, oppure non convertirli quando esiste già la skill.
  - Rimuovere o tradurre i campi del frontmatter.
  - Verificare con `/skills` in `agy`.

### A-6

🟠 `AGY` 📄 **Gli agenti di review usano i nomi dei tool di Claude Code.**

- **Dove:** `agents/*.md`, con `tools: Read, Grep, Glob, Bash`.
- **Problema:** gli agenti personalizzati di Antigravity elencano tool nativi (`view_file`, …) e campi come `subagent: true`. Su Antigravity i revisori potrebbero partire senza tool.
- **Correzione:** generare il frontmatter degli agenti per host nel build.

### A-7

🟡 `AGY` 📄 **Manifest e marketplace hanno campi in eccesso.**

- **Manifest:** lo schema pubblicato di `plugin.json` ammette solo `name` e `description` (`additionalProperties: false`), mentre il build aggiunge `version`, `author`, `repository`, `homepage` e `keywords`. `agy plugin validate` oggi accetta il file, ma è un rischio di rottura futura.
- **Marketplace:** `.antigravity-plugin/marketplace.json` (radice del repo) non sembra usato. `agy plugin install` accetta il marketplace ufficiale, un URL GitHub o un percorso locale. Va rimosso o se ne va documentato l'uso.
- **README:** alla riga 134 della radice dice che `plugin.json` è "confined here — never at dist root", ma `build-antigravity.sh` lo copia nella radice di `dist/`.

---

## 4. Stato e concorrenza

### S-1

🔴 `CC+AGY` ✅ **Gli hook in parallelo possono svuotare `.devflow-state.json`.**

- **Dove:**
  - `hooks/observe.sh:115-125,199-216,231-233` e `hooks/stop-metrics.sh:204` usano file temporanei a nome fisso (`${STATE_FILE}.tmp`).
  - `hooks/post-task-create.sh:46` sovrascrive il file in modo non atomico.
- **Prova:** con 6 `observe.sh post` concorrenti il file è rimasto vuoto in 3 prove su 8, perdendo `next_step` e `feature_path`.
- **Correzione:**
  - Usare `mktemp "${STATE_FILE}.XXXXXX"` e un lock con `mkdir`, perché `flock` non esiste su macOS.
  - In alternativa, spostare i contatori in un file scritto solo da `observe`.

### S-2

🔴 `CC` ✅ **`pre-compact.sh` sostituisce lo stato invece di aggiornarlo.**

- **Dove:** `hooks/pre-compact.sh:86-111`, che usa `jq -n`.
- **Problemi:**
  - Perde `feature_path`, `branch`, `task_status`, `active_feature` e `tool_call_count`.
  - Sceglie il piano in base alla data di modifica.
  - Mappa ogni stato sconosciuto su `devflow.implement`.
- **Correzione:** unire i campi con `jq '. + {...}'` in modo atomico e preferire `.feature_path`.

### S-3

🟠 `CC+AGY` **Lo stato non ha uno schema.**

- **Nomi delle chiavi:** `feature` in `pre-compact.sh`, `references/status-schema.md` e resume; `active_feature` in init, recovery, `post-task-create.sh` e `skills/devflow-plan/SKILL.md:15,65`. task aggiunge `feature_path`, `branch` e `task_status`.
- **Fonte di verità:** `skills/devflow-status/SKILL.md:39` legge prima il file di stato, anche se la fonte autorevole è `plan.md` (`references/state-machine.md:17`).
- **Correzione:** uno schema JSON unico in `references/state-machine.md`, con `active_feature` mantenuto come alias in sola lettura.

### S-4

🟠 `CC+AGY` **Ci sono quattro regole diverse per scegliere la "feature attiva".**

- **Le quattro regole:**
  - I comandi clarify, plan, analyze, implement, test e run prendono l'`NNN` più alto.
  - `skills/devflow-plan/SKILL.md:65` dice di non prendere mai il più alto, ma il task non pianificato con numero più basso.
  - `references/status-schema.md:66` usa il file modificato più di recente.
  - Implement (riga 52) prende "latest".
- **Effetto:** dopo `devflow.init`, `/devflow.plan` senza argomenti lavora sull'ultimo task della roadmap invece che sul prossimo.
- **Correzione:** una sezione unica "Active feature resolution" in `references/state-machine.md`, richiamata da tutti.

---

## 5. Pipeline e skill

### P-1

🔴 `CC+AGY` ✅ **Implement accetta solo un piano con stato `ready`.**

- **Dove:** `skills/devflow-implement/SKILL.md:44`.
- **Chiamanti che arrivano con un altro stato:**
  - `references/state-machine.md:31` instrada `implementing` verso implement.
  - Resume, al passo 4, rientra a metà implementazione.
  - Il ciclo di correzione di ship (passo 4b) rilancia implement con stato `tested`.
  - Backprop (riga 72) rientra dopo una correzione.
- **Effetto:** tutti falliscono il contratto di input.
- **Correzione:**
  - Accettare `ready` e `implementing`.
  - Aggiungere una modalità di rientro mirato, con l'elenco di finding o file da correggere. Questa modalità riporta lo stato a `implementing`, come transizione all'indietro documentata, e non tocca gli altri `[done]`.

### P-2

🔴 `CC+AGY` 📄 **Il ciclo di correzione di ship non riesegue i test.**

- **Dove:** `skills/devflow-ship/SKILL.md`, passo 4b.
- **Problema:** il ciclo rilancia implement e beautify, poi imposta `shipped` con un `verification.md` ormai vecchio. Viola la regola `tested → shipped` (`references/state-machine.md:46`).
- **Correzione:** a ogni iterazione rieseguire implement, beautify e test, inclusa la verifica del passo 6b, e scrivere ogni passaggio di stato.

### P-3

🔴 `CC` ✅ **`devflow-run` e `devflow-auto` girano in fork in background ma chiedono conferme.**

- **Dove:** frontmatter con `context: fork` e `background: true`. Le richieste di conferma sono in `skills/devflow-run/SKILL.md:63` e `skills/devflow-auto/SKILL.md:61-62`.
- **Problema:** un'esecuzione in fork non ha la cronologia della conversazione e non può interagire con l'utente. Il fan-out parallelo di ship dentro il fork potrebbe ricadere sull'esecuzione inline.
- **Correzione:**
  - Togliere `context: fork` da run.
  - Per auto, raccogliere le conferme nel comando prima del fork.
  - Verificare che `background` sia un campo di frontmatter supportato.
- **Su Antigravity:** il campo viene ignorato. Documentare il comportamento.

### P-4

🟠 `CC+AGY` ✅ **Hotfix ha bug di ordine e di contratto.**

- **Dove e cosa:**
  - Tag di checkpoint creato dopo la fix (`skills/devflow-hotfix/SKILL.md:51-52`), quindi il rollback non annulla nulla.
  - Test di regressione scritto dopo la fix, contro il principio Prove-It.
  - PR con base `main` scritta fissa (riga 77): salta il rilevamento del branch base e la pulizia fatta da `devflow-pr`.
  - Task e piano compatti privi di `Traceability` e `**Branch:**`, quindi backprop, analyze e rollback falliscono.
- **Correzione:**
  - Creare il tag prima di modificare il codice.
  - Scrivere prima un test che fallisce.
  - Generare task e piano dai template reali.
  - Passare la PR a `devflow-pr`.

### P-5

🟠 `CC+AGY` 📄 **Recovery non sblocca una feature `blocked`.**

- **Dove:** `skills/devflow-recovery/SKILL.md`.
- **Problemi:**
  - Manca una categoria per lo stato `blocked`.
  - Scrive solo `.devflow-state.json` (riga 187) e mai lo Status di `plan.md`.
  - Il risync alle righe 142-147 sovrascrive il file intero.
  - L'opzione 1 riprende sempre da implement.
  - Il report elenca le categorie A-E ma ne esiste anche una F.
- **Correzione:** aggiungere una categoria "Blocked" con reset dello Status confermato dall'utente, fare merge con jq e scegliere il passo da riprendere in base allo stato.

### P-6

🟠 `CC+AGY` 📄 **La documentazione di routing salta ship.**

- **Dove:** `AGENTS.md:9,20`, *skills/devflow-discovery/SKILL.md:60-61,78* e `agent.yaml:9` descrivono "test → pr".
- **Dichiarazione falsa:** "skills do not invoke each other" è smentita, perché ship, run, auto e hotfix concatenano altre skill.
- **`AGENTS.md`:** cita solo Flutter e Angular. La riga 3 dice che setup lo copia nei progetti, ma setup usa `AGENTS.template.md`.
- **Correzione:** aggiornare i tre file e riscrivere o eliminare `AGENTS.md`.

### P-7

🟡 `CC+AGY` 📄 **Le deviazioni di implement non arrivano nella PR.**

- **Problema:** implement scrive `## Implementation deviations` (riga 186), mentre auto (riga 154) e pr (riga 147) leggono `## Deviations`.
- **Correzione:** usare un'intestazione unica, presente anche in `skills/devflow-plan/references/plan-template.md`.

---

## 6. Comandi, agenti e descrizioni

### K-1

🟠 `CC` 📄 **I comandi contraddicono le skill che chiamano.**

- **Contraddizioni:**
  - commands/devflow.ship.md (rimosso in 3.0.0) lancia sempre 3 agenti; la skill ne lancia 1, 3 o 5 secondo la complessità.
  - commands/devflow.analyze.md (rimosso in 3.0.0) dichiara 5 passate; la skill ne esegue 7.
  - Il comando metrics parla di pass@1, la skill di pass@k.
  - L'`argument-hint` di learn non include `check`.
- **Modelli incoerenti:**
  - pr: sonnet nel comando, haiku nella skill.
  - beautify: haiku per una revisione che include la sicurezza.
  - discover: haiku con effort basso per scrivere ADR.
- **Correzione:** ridurre ogni comando alla riga di dispatch più la regola per gli argomenti vuoti, con modello ed effort definiti in un solo posto. Questo semplifica anche [A-5](#a-5).

### K-2

🟠 `CC+AGY` 📄 **Gli agenti di review non hanno modello né vincolo di sola lettura.**

- **Dove:** tutti e 5 i file in `agents/`.
- **Problemi:**
  - Nessuno ha `model:`.
  - Tutti hanno `Bash` senza vincolo di sola lettura, quindi revisori in parallelo possono modificare il working tree.
  - `agents/code-reviewer.md:53-59` duplica l'asse di sicurezza del security-auditor.
  - `agents/code-reviewer.md:137-141` assume il vecchio fan-out a 3 agenti.
- **Correzione:**
  - Aggiungere `disallowedTools: Write, Edit` e una allowlist per Bash.
  - Far saltare l'asse di sicurezza al code-reviewer quando c'è anche il security-auditor.

### K-3

🟠 `CC` 📄 **Alcune descrizioni instradano verso la skill sbagliata.**

- **Status, recovery e discovery:**
  - `devflow-status` ha `disable-model-invocation: true`, ma la sua descrizione risponde esattamente a "dove sono / cosa faccio dopo".
  - Recovery si può invocare automaticamente, scrive lo stato e si presenta come utile quando "l'agente non sa quale passo eseguire".
  - Discovery si può invocare automaticamente, anche se dovrebbe essere iniettata dall'hook.
  - Risultato: "cosa faccio adesso?" finisce su recovery o su discovery.
- **Task:** la descrizione di `devflow-task` ("or provides a feature idea") scatta su richieste generiche del tipo "aggiungi X". Al passo 7 crea un branch da HEAD invece che da `origin/main`.
- **Correzione:**
  - Rendere status invocabile dal modello (è in sola lettura).
  - Togliere quella frase da recovery.
  - Rendere discovery non invocabile.
  - Restringere il trigger di task.

---

## 7. Build, packaging e CI

### C-1

🟠 `CC+AGY` 📄 **La CI non copre tutto.**

- **Dove:** `.github/workflows/build-verify.yml:6-15` (radice del repo).
- **Problemi:**
  - Gira solo sulle PR, con un filtro `paths` che esclude `README.md`, `docs/**`, `CHANGELOG.md` e i file di release-please. `validate-doc-links.sh` non gira proprio sulle PR che toccano la documentazione.
  - Nessun trigger `push: main`.
  - Mancano `shellcheck` (oggi 17 warning) e `claude plugin validate`.
  - Manca un job con `agy plugin validate` e un test di installazione su Antigravity che verifichi `hooks.json` nella radice.
- **Correzione:** togliere il filtro `paths`, aggiungere il trigger `push: main` e aggiungere i tre validatori.

### C-2

🟠 `CC+AGY` 📄 **La PR di release non viene mai verificata.**

- **Dove:** `.github/workflows/release-please.yml:26-31` (radice del repo).
- **Problema:** la PR è aperta con `GITHUB_TOKEN`, che non avvia altri workflow. Se Build Verify è un check obbligatorio, la PR di release non si può mergiare.
- **Correzione:** usare una GitHub App o un PAT.
- **Step inutile:** il rebuild post-release (righe 36-49) non cambia nulla, e un `git push origin main` fallisce con la protezione del branch. Va rimosso.

### C-3

🟠 `CC` 📄 **Manca il file LICENSE.**

- **Problema:** non c'è un LICENSE e `plugin.json` non ha il campo `license`. `claude plugin validate` riporta `LICENSE_MISSING`, che blocca l'inserimento nella directory ufficiale. Senza licenza, legalmente il codice è "tutti i diritti riservati".
- **Correzione:** aggiungere il file LICENSE e passare il campo `license` in `scripts/builders/build-claude.sh`.

### C-4

🟡 `CC+AGY` 📄 **`agent.yaml` dichiara la versione `1.0.0`.**

- **Problema:** tutti gli altri file sono a 1.19.0, e `agent.yaml` non è tra gli `extra-files` di `release-please-config.json`.
- **Correzione:** aggiungere una voce `{"type":"yaml","path":"templates/devflow/agent.yaml","jsonpath":"$.version"}`.

### C-5

🟡 `CC+AGY` 📄 **`build-plugin.sh` accetta valori errati in silenzio.**

- **Dove:** `scripts/build-plugin.sh` (radice del repo).
- **Problemi:**
  - Righe 21-27: `export X=$(jq ...)` nasconde gli errori di `jq` (SC2155). Una chiave mancante diventa la stringa `"null"`, che può finire nella versione.
  - L'aggiornamento dei marketplace (`jq … > tmp && mv`) non fa fallire il build se `jq` va in errore.
  - Riga 32: `rm -rf` sui file `.devflow-*` dentro `templates/devflow/` cancella file sorgente.
  - `python3` è una dipendenza non dichiarata. Si può sostituire con `jq --indent 2`.
- **Correzione:** usare `jq -er`, validare la versione come semver e filtrare i file solo in `dist/`.

### C-6

🟡 `CC` 📄 **`dist/` contiene file inutili.**

- **Problema:** il build per Claude Code include `hooks/tests/` (108K) e la variante `hooks.antigravity.json`; `hooks.cursor.json` sparisce con [C-7](#c-7). Anche il comando lint-skills (rimosso in 3.0.0) è uno strumento per chi mantiene il plugin, non per chi lo usa. Inoltre usa una sintassi non valida (`${ $ARGUMENTS ? … }`).
- **Correzione:** escludere questi file dal build.

### C-7

🟠 `repo` **Rimuovere il supporto a Cursor.**

- **Decisione:** gli host supportati sono solo Claude Code e Antigravity CLI. Il target Cursor va rimosso del tutto. Oggi raddoppia il lavoro di build, documentazione e test per un host che non viene verificato da nessuna parte: non ha test, CI né validazione.
- **Build e release:**
  - Eliminare *scripts/builders/build-cursor.sh*.
  - In `scripts/build-plugin.sh` (righe 28, 47-48, 57) togliere la lettura di `cursor_support`, la chiamata al builder e la voce "+ Cursor".
  - In `templates/devflow/manifest.json` (riga 15) togliere `"cursor_support": true`.
  - In `release-please-config.json` (riga 32) togliere l'`extra-file` *dist/devflow/.cursor-plugin/plugin.json*. Senza questa modifica release-please fallisce, perché il file non esisterà più.
  - Rigenerare `dist/`: spariscono `dist/devflow/.cursor-plugin/` e *dist/devflow/hooks/hooks.cursor.json*. Il builder Claude fa già `rm -rf dist`, quindi non restano file orfani.
- **Installazione:** in `scripts/install-plugin.sh` (24 occorrenze) togliere il target `cursor`, la funzione di installazione e disinstallazione e la voce nel ramo `all`. Aggiornare `--help` e il messaggio d'errore "Choose: antigravity | cursor | claude | all".
- **Script del plugin:** in `templates/devflow/scripts/doctor.sh` (righe 62-67) togliere il rilevamento del client Cursor e i percorsi *.cursor/mcp.json*.
- **Skill e comandi:** togliere Cursor dagli elenchi dei client MCP in:
  - `templates/devflow/skills/devflow-setup/SKILL.md:209`
  - `templates/devflow/commands/devflow.setup.md:22`
  - `templates/devflow/skills/devflow-doctor/SKILL.md:70`
  - `templates/devflow/skills/devflow-init/references/interview-protocol.md:112`

  Dopo la modifica servono `validate-skills.sh --strict`, `run-evals.sh` e il rebuild.
- **Documentazione:**
  - `README.md` (11 occorrenze): sezioni "Plugins (Claude Code, Cursor & Antigravity CLI)" e "Install locally (Cursor)", e il riferimento a `code-review-graph` "in both Cursor and Claude".
  - `templates/devflow/README.md` (4 occorrenze): sezione Cursor con manifest e installazione locale.
  - `docs/architecture.md:9,101` e `docs/comparison.md:18`: elenco degli host.
  - `CLAUDE.md:3`: "Claude Code + Cursor plugin" diventa "Claude Code + Antigravity CLI plugin".
  - `.gitignore:28`: `.cursor/*.log` si può togliere.
- **Da non toccare:**
  - Le occorrenze di `cursor: pointer` / `cursor-pointer` nel CSS (`templates/devflow/adapters/angular/skills/angular-aria/references/aria-patterns.md`, `templates/devflow/adapters/nextjs/skills/nextjs-ui/SKILL.md`, `devflow-board/assets/board-template.html`) non riguardano l'host.
  - Lasciare invariati `CHANGELOG.md`, `docs/tokless-gap-analysis.md` (analisi di un progetto esterno) e *devflow/features/003_devflow-board/plan.md* (storico).
- **Comunicazione:** è una modifica che rompe la compatibilità per chi usa il plugin su Cursor. Va rilasciata con un commit `feat!:` o con `BREAKING CHANGE:` nel corpo, così release-please passa alla versione major (2.0.0). Nel CHANGELOG serve una nota di migrazione.
- **Verifica:**
  - `bash scripts/build-plugin.sh`
  - `bash templates/devflow/scripts/validate-doc-links.sh`
  - `grep -rIi cursor` fuori da `CHANGELOG.md`, `.git/` e dalle eccezioni sopra: nessun risultato.
  - `claude plugin validate dist/devflow` e `agy plugin validate dist/devflow` senza nuovi errori.
- **Ordine:** conviene farlo **prima della fase 2**. Così la generazione di `hooks.json` per host e la matrice nel README riguardano solo due host.

### C-8

🟡 `repo` **Igiene del repository.**

- Contenuti committati che non sono sorgente del plugin:
  - `devflow/features/00{1,2,3}_*`: output di prova della pipeline;
  - `.serena/`: configurazione personale di uno strumento;
  - `.agents/skills/clarity/`: skill di terze parti con 92 file.
- `.claude/settings.json` consente `pnpm lint/test`, che questo repo non usa.
- Il CHANGELOG 1.19.0 duplica le voci, perché i merge commit sono letti come `feat:`. Conviene usare lo squash merge.
- Manca il campo `description` di primo livello in `.claude-plugin/marketplace.json`; `claude plugin validate` lo segnala.

---

## 8. Test e dipendenze

### T-1

🟠 `CC+AGY` ✅ **`run-hook-tests.sh` fallisce su macOS senza `yq`.**

- **Dove:** `hooks/tests/test-revert-decay.sh:53`.
- **Problema:** chiama `yq` senza controllare che sia installato ed esce con 127 senza messaggi, per via di `set -euo pipefail`.
- **Test saltati in silenzio:** altre suite saltano ed escono con 0 quando `yq` manca (`scripts/test-learning-hooks.sh:73`), quindi i test del learning passano senza verificare nulla.
- **Correzione:**
  - Aggiungere lo stesso controllo su `yq` al test.
  - In CI installare `yq` esplicitamente.
  - Con `CI=true`, far fallire il test se `yq` manca invece di saltarlo.

### T-2

🟠 `CC+AGY` **Mancano i test per alcuni hook.**

- **Hook senza test:** `pre-scope-guard.sh` (una guard), `stop-debug-check.sh`, `stop-notify.sh`.
- **Mancanza generale:** nessun test usa payload reali, ed è la causa di [H-1](#h-1).
- **Correzione:** aggiungere fixture per host (`fixtures/cc/*.json`, `fixtures/agy/*.json`) e una suite che esegue ogni hook con ciascuna.

### T-3

🟠 `CC+AGY` 📄 **Le dipendenze mancanti disattivano funzioni in silenzio.**

- **Dove:** `scripts/doctor.sh:221-223` controlla solo `git`, `gh` e `jq`.
- **Non controllati:**
  - `yq`: senza, tutti gli hook degli instinct escono in silenzio.
  - `timeout`/`gtimeout`: vedi H-4.
  - `curl` e `shasum`: servono alla cache dei fetch.
  - `python3`: senza, il limite al fan-out passa a una risoluzione al secondo. Inoltre `doctor.sh:336` lo chiama senza controllo.
- **Correzione:**
  - Aggiungere controlli opzionali con il comando di installazione (`brew install yq coreutils`).
  - Far stampare all'hook di avvio una riga di avviso se manca `yq`.
  - In `doctor` aggiungere una sezione per host: su Antigravity, versione di `agy`, `hooks.json` nella radice, plugin abilitato.

### T-4

🟡 `CC+AGY` **Mancano validatori per regole già scritte.**

- 16 skill degli adapter superano le 100 righe, contro la regola di `CONTRIBUTING.md` che chiede di spostare il contenuto in `references/`. Tra le altre: `angular-routing` (179), `common-web-interface-guidelines` (166), `nextjs-state` (167). `validate-skills.sh` non controlla questa regola.
- Gli adapter `nestjs` e `nextjs` non hanno `PRODUCT.template.md`. È opzionale secondo `adapters/ADAPTER.schema.md`, ma conviene per uniformità.

---

## 9. Manutenibilità e costo in token

- **Discovery** 🟡: *skills/devflow-discovery/SKILL.md* non ha comando né le sezioni richieste, e `session-start.sh:99-108` la inietta intera (998 parole) quando manca lo stato. Conviene spostarla in *references/orientation.md* (nuovo), ridotta all'albero di decisione. Su Antigravity diventerebbe `rules/`.
- **Run e auto** 🟡: auto (1.982 parole) ripete per ogni passo le regole della modalità run, e il formato dei flag di decisione sta dentro `devflow-run`. Conviene un *references/run-mode.md* (nuovo) condiviso e un solo orchestratore con preset `--from/--until`.
- **`allowed-tools` fissi** 🟡: implement, beautify, test e pr condividono una stringa che copre solo Flutter, Angular e npm/pnpm (no yarn, bun, nx). Non copre neanche la forma monorepo `(cd app && cmd)`.
- **Metriche duplicate** 🟡: le righe Savings e Cost di status duplicano `devflow-metrics`.
- **Varie** 🟡: `argument-hint: "[]"` in resume e recovery. La descrizione di learn in `agent.yaml` è obsoleta.

---

## 10. Piano di intervento proposto

| Fase | Contenuto | Esito atteso |
| --- | --- | --- |
| **0. Rimozione di Cursor** | C-7 | Solo due host da costruire, documentare e testare. Rilascio major (2.0.0) |
| **1. Hook corretti su Claude Code** | H-1, H-2, H-3, H-4, S-1, S-2, T-1, T-2 (fixture reali) | Le guard bloccano davvero, il contesto arriva, lo stato non si corrompe |
| **2. Antigravity reale** | Cattura dei payload (A-3), poi normalizzatore ed emettitore, poi generazione per host di `hooks.json` (A-1, A-2), poi `rules/` (A-4), comandi e frontmatter (A-5, A-6), matrice per host nel README | Hook funzionanti e documentati su `agy`, senza duplicati nel menu slash |
| **3. Contratti della pipeline** | P-1, P-2, P-3, P-4, P-5, S-3, S-4, P-6 | Resume, ciclo di correzione di ship, run e auto, hotfix coerenti con la macchina a stati |
| **4. CI e release** | C-1, C-2, C-3, C-4, C-5, T-3 | Ogni PR e ogni push validati su entrambi gli host. Plugin pubblicabile nella directory ufficiale |
| **5. Pulizia** | H-5 … H-11, K-1 … K-3, C-6, C-8, T-4, sezione 9 | Meno token, meno duplicati, regole verificate automaticamente |

Le voci marcate 📄 relative ad Antigravity (A-2 … A-7) vanno confermate con il primo passo della fase 2: un plugin minimo di prova che registra i payload reali di ogni evento. Il resto della fase dipende da quei dati.
