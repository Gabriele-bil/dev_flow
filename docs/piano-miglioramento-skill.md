# DevFlow — piano di miglioramento delle skill

Analisi delle skill del plugin `devflow` (branch `next`, commit `f621664`, 2026-10-29). Tre obiettivi:

1. **Qualità dell'output**: skill corrette, coerenti tra loro e verificabili.
2. **Aggiornamento al 29 ottobre 2026**: funzionalità attuali di Claude Code e Antigravity CLI e versioni correnti dei framework degli adapter.
3. **Meno token e meno tempo** per ogni passo della pipeline.

Il plugin gira su due host: **Claude Code** (`dist/devflow/`) e **Antigravity CLI** (`dist/devflow-antigravity/`, generato da `scripts/builders/build-antigravity.sh` nella radice del repo). Ogni intervento deve funzionare su entrambi, oppure dichiarare cosa succede sull'host che non lo supporta.

**Principio guida**: il comportamento che deve valere su entrambi gli host va in **script e file**, non in campi della frontmatter. La frontmatter (`model`, `effort`, `context`, `allowed-tools`, `disable-model-invocation`) oggi è solo di Claude Code: il build Antigravity la elimina.

Il piano riprende `docs/miglioramenti-plugin.md` (hook, Antigravity, contratti della pipeline) senza ripeterne le voci già chiuse nei commit `6082055`, `8c26b49` ed `e4418df`.

## Come è stata fatta l'analisi

- `validate-skills.sh --strict` (65 ok) e `run-evals.sh` (31/31) sono verdi. Il verde dice poco: 15 casi sono saltati per `disable-model-invocation`, il punteggio è a bag-of-words e manca un livello comportamentale.
- Lettura completa di 26 skill core, `references/`, `agents/`, `contexts/`, `commands/` e dei 4+1 adapter (39 skill tecnologiche con le loro `references/`).
- Documentazione ufficiale di Claude Code aggiornata a oggi: skill, subagent, plugin, prompt caching, `claude plugin eval` e `/skill-doctor` (code.claude.com/docs).
- Versioni correnti dei framework da npm, pub.dev e note di rilascio. API verificate con Context7.
- I punti più gravi sono stati riscontrati a campione direttamente nei file.

**Legenda**

| Simbolo | Significato |
| --- | --- |
| 🔴 / 🟠 / 🟡 | Priorità alta / media / bassa |
| ✅ | Riscontrato direttamente nei file durante l'analisi |
| 📄 | Ricavato da lettura del codice o della documentazione, da confermare durante l'intervento |
| *corsivo* | File nuovo, ancora da creare |
| `CC` / `AGY` / `CC+AGY` | Host coinvolto: Claude Code, Antigravity CLI, entrambi |

Lo stato di avanzamento delle voci è nella sezione 7 (**Avanzamento**): ✅ nei titoli indica solo un riscontro dell'analisi, non una voce chiusa.

Le voci senza indicazione di host valgono per entrambi. Percorsi relativi a `templates/devflow/` salvo dove indicato. Le stime in byte e token sono approssimate (token ≈ byte / 4).

---

## Sintesi

Le skill sono ben strutturate. I problemi stanno in quattro punti:

1. **Il modo in cui vengono caricate non corrisponde a come funzionano gli host oggi.** Su Claude Code i comandi sono un formato legacy e scavalcano `model:` ed `effort:` delle skill. Su Antigravity quei campi vengono eliminati dal build, insieme a `disable-model-invocation`: tutte le 26 skill diventano invocabili dal modello, comprese pr e rollback. Su entrambi i percorsi `@devflow/...` non esistono nel progetto consumer.
2. **Ogni passo rilegge le stesse cose.** `references/state-machine.md` (15 KB) viene letto 8 volte in una pipeline interattiva, circa 30K token, il 18% di tutto il testo del plugin. In `devflow.auto` restano in contesto circa 71K token di istruzioni prima di qualsiasi riga di codice.
3. **Gli stessi controlli girano 3-5 volte**: format/analyze in implement, nell'hook Stop, nei contratti di beautify, test e ship, e di nuovo in pr.
4. **Gli adapter contengono codice che non compila** con le versioni correnti, ad esempio freezed 3, Zod 4, Riverpod 3 e Angular 22. Hanno anche circa 175 KB di riferimenti su 395 che ripetono la documentazione dei framework.

### Stima del costo attuale

| Flusso | Testo del plugin letto | Token stimati | Contributo maggiore |
| --- | --- | --- | --- |
| task → plan → implement → test → ship → pr, una sessione per passo | ~384 KB | ~170K | `state-machine.md` letto 8 volte, ~30K token |
| `devflow.auto` in un solo contesto | ~228 KB unici | ~71K residenti, più ~25K negli agenti di ship | Tutti i corpi delle skill accumulati nello stesso contesto: compattazione probabile a metà run |
| Agenti di ship (profilo standard) | 3 × ~28 KB | ~25K più 3 diff | Ogni agente rilegge task, plan, constitution e registry |

### I dodici interventi principali

| # | Intervento | Obiettivo | Host | Priorità |
| --- | --- | --- | --- | --- |
| [Q-1](#q-1) | Correggere `devflow-pr`: flag inesistente, cancellazione di immagini, `git add .` | Qualità | CC+AGY | 🔴 |
| [CC-1](#cc-1) | Percorsi `@devflow/` risolti dal build per ciascun host | Qualità, tempo | CC+AGY | 🔴 |
| [AGY-1](#agy-1) | Su Antigravity pr, rollback, ship e le altre skill "solo su richiesta" diventano invocabili dal modello | Qualità, sicurezza | AGY | 🔴 |
| [CC-2](#cc-2) | Comandi assorbiti dalle skill: un solo punto d'ingresso, come già su Antigravity | Qualità, token | CC | 🔴 |
| [AD-1](#ad-1) | Correggere il codice degli adapter che non compila con le versioni correnti | Aggiornamento | CC+AGY | 🔴 |
| [T-1](#t-1) | Gestire lo stato con uno script (*scripts/devflow-state.sh*), non con la prosa di `state-machine.md` | Token, qualità | CC+AGY | 🔴 |
| [L-1](#l-1) | Timbro di verifica per hash dell'albero: niente controlli ripetuti | Tempo | CC+AGY | 🔴 |
| [L-3](#l-3) | `devflow.run` e `devflow.auto` eseguono ogni passo in un subagent | Token, tempo, qualità | CC+AGY | 🟠 |
| [CC-3](#cc-3) | Strategia dei modelli coerente e senza cache miss | Qualità, costo | CC | 🟠 |
| [AD-2](#ad-2) | Next.js 16.4, NestJS 12.1 e Flutter 3.47 al passo | Aggiornamento | CC+AGY | 🟠 |
| [T-7](#t-7) | Pacchetto di review per gli agenti di ship | Token, tempo | CC+AGY | 🟠 |
| [M-1](#m-1) | Misurare prima e dopo su entrambi gli host | Tutti | CC+AGY | 🟠 |

---

## 1. Allineamento agli host (ottobre 2026)

<a id="cc-1"></a>
### CC-1 🔴 ✅ I percorsi `@devflow/...` non si risolvono

Skill, comandi, agenti e template (ad esempio commands/devflow.plan.md (rimosso in 3.0.0), `skills/devflow-plan/SKILL.md` con 19 occorrenze) usano `@devflow/references/...` e `@devflow/skills/...`. Nel progetto consumer la cartella `devflow/` contiene solo `config.md` e `features/`. Il build copia questi percorsi invariati in `dist/devflow/`.

- La documentazione non garantisce che un `@path` nel corpo di una skill o di un comando venga espanso. Il modello deve cercare il file (round-trip in più), indovinarne la posizione dalla "base directory" della skill, oppure procedere senza.
- `${CLAUDE_PLUGIN_ROOT}` e `${CLAUDE_SKILL_DIR}` invece vengono sostituiti in skill, comandi e agenti (code.claude.com/docs/en/plugins/components.md#reference-plugin-paths-and-store-data).

**Intervento**

1. In `templates/` mantenere `@devflow/` come notazione per gli autori.
2. Riscriverla nel build, per host:
   - **CC**: `@devflow/` → `${CLAUDE_PLUGIN_ROOT}/`, nella build Claude Code;
   - **AGY**: `@devflow/` → percorso di staging di agy (`$HOME/.gemini/antigravity-cli/plugins/devflow/`), nello stesso passo in cui `scripts/builders/build-antigravity.sh` (radice del repo) traduce già `${CLAUDE_PLUGIN_ROOT}`. ✅ Oggi in `dist/devflow-antigravity/` restano 31 skill con `@devflow/` non tradotto.
3. Non toccare i percorsi `devflow/features/...` e `devflow/config.md`, che appartengono al consumer.
4. Aggiungere a `validate-skills.sh` un controllo sull'output di **entrambi** i build: nessun `@devflow/` deve restare in `dist/devflow/` né in `dist/devflow-antigravity/`.

<a id="cc-2"></a>
### CC-2 🔴 ✅ `CC` I comandi scavalcano `model:` ed `effort:` delle skill

I 27 file in `commands/` dicono soltanto "Use `@devflow/skills/<x>/SKILL.md` and execute it exactly". Nessuno ha `model:` o `effort:`. Quando l'utente digita `/devflow.plan`, il modello legge il SKILL.md come testo e la frontmatter della skill (`model: sonnet`, `effort: high`) **non viene applicata**. La messa a punto dei modelli per passo, introdotta con il commit "single model source", di fatto non è attiva sul percorso principale. 📄 Da confermare con una run.

La documentazione oggi descrive `commands/` come "the older format; skills supersede them for new work" (code.claude.com/docs/en/plugins/components.md#commands). Una skill con `disable-model-invocation: true` compare nel menu `/` e non occupa la lista delle descrizioni.

**Intervento**

1. Le skill diventano l'unico punto d'ingresso. `argument-hint` e `disable-model-invocation` sono già presenti nella frontmatter di quasi tutte.
2. Eliminare i comandi di solo rinvio. Il nome slash cambia (es. da `/devflow.plan` a `/devflow:devflow-plan`, oppure `/devflow:plan` impostando `name: plan`), quindi serve una release major e una tabella di migrazione nel README.
3. In alternativa, se il nome attuale va preservato: comando con la stessa frontmatter `model`/`effort` della skill, generata dal build a partire dalla skill. Va verificato come collidono un comando e una skill di plugin con lo stesso nome (non documentato).
4. **AGY**: il build Antigravity esclude già `commands/` e usa le skill come comandi slash. Con questo intervento i due host convergono su un unico modello: stesse skill, stessi nomi. I nomi slash possono restare diversi solo per il prefisso del plugin. La tabella di migrazione del README va scritta per entrambi.

<a id="cc-3"></a>
### CC-3 🟠 `CC` Strategia dei modelli coerente e senza cache miss

Su Antigravity `model` ed `effort` vengono eliminati dal build e tutti i passi girano col modello della sessione. Questa voce riguarda solo Claude Code. Su Antigravity la qualità per passo dipende dalle istruzioni e dagli script ([AGY-3](#agy-3)), non dalla scelta del modello.

Dalla documentazione sul prompt caching (code.claude.com/docs/en/prompt-caching.md):

- Un `model:` nella frontmatter di una skill è un **cambio di modello per quel turno**: tutta la cronologia viene riletta senza cache. Su una sessione lunga costa più di quanto si risparmia con un modello più piccolo.
- `context: fork` con `agent:` esegue la skill in un subagent con il suo modello e il suo contesto, senza invalidare la cache della sessione principale.
- Su Opus 5.5, Sonnet 5.5, Haiku 5.5 e Fable 5.1 cambiare `effort` non invalida la cache.
- I subagent hanno una cache con TTL di 5 minuti. `experimental.cacheTtl: 1h` la estende.

Incoerenze attuali:

| Dove | Problema |
| --- | --- |
| `references/model-selection.md` | ✅ Usa `claude-opus-4-7`, un ID precedente a Claude 5: usare gli alias (`opus`, `sonnet`, `haiku`, `fable`). Raccomanda Opus per gli agenti di ship, che però dichiarano tutti `model: sonnet`. Raccomanda Haiku per beautify, che dichiara `sonnet`. La tabella dei profili non è collegata a nessun meccanismo |
| `skills/devflow-task/SKILL.md` | `haiku`/`low` per scrivere storie INVEST/BDD con regole anti-allucinazione: sottodimensionato. Proposta: `sonnet`/`medium` |
| `skills/devflow-analyze/SKILL.md` | `haiku`/`low`, ma un suo verdetto Critical ferma `devflow.auto`. Proposta: `sonnet`/`low` |
| `skills/devflow-ship/SKILL.md` | `effort: high` per smistare e sintetizzare: basta `medium` |
| `agents/*.md` | Solo `model`. Mancano `effort`, `maxTurns` e `experimental.cacheTtl` |

**Intervento**

1. Togliere `model:` dalle skill eseguite nel contesto principale. Restano `effort:` e il modello della sessione.
2. Dove serve un modello diverso, usare `context: fork` + `agent:` (vedi [L-3](#l-3)).
3. Per i 5 agenti: `effort` per agente, `maxTurns` limitato, `experimental.cacheTtl: 1h` per gli agenti rilanciati nel ciclo di correzione di ship.
4. Riscrivere `references/model-selection.md` come tabella unica "passo → dove gira → modello → effort", generata o verificata da script.

<a id="cc-4"></a>
### CC-4 🟠 ✅ Nomi di tool superati

| Nome usato | Nome attuale | Dove |
| --- | --- | --- |
| `AskQuestion` | `AskUserQuestion` (1-4 domande per chiamata, opzioni `{label, description}`, `header`, `multiSelect`) | task, clarify, discover, init, setup, plan, `skills/devflow-clarify/references/interactive-interview.md` (anche la forma delle opzioni è sbagliata) |
| `MultiEdit` | non esiste più | matcher di `hooks/hooks.json`, `disallowedTools` degli agenti, `hooks/lib/payload.sh`, `agent.yaml`. Innocuo ma morto |
| `Task` (subagent) | `Agent` | commenti di `hooks/pre-agent-fanout-cap.sh`. Il matcher copre già entrambi |

Anche la tabella prezzi cablata in `hooks/stop-metrics.sh` va confrontata con i prezzi attuali dei modelli Claude 5.

<a id="cc-5"></a>
### CC-5 🟡 `CC` Funzionalità nuove da sfruttare

Ogni punto qui sotto è solo di Claude Code. Va adottato solo se su Antigravity esiste un'alternativa o una degradazione accettabile, indicata accanto.

- **Compattazione**: dopo una compattazione Claude Code riallega i primi 5.000 token di ogni skill (budget complessivo 25.000). Le regole critiche, come stop-condition, contratto di input e formato dell'output, vanno in cima al SKILL.md, non in fondo tra gli anti-pattern. *AGY*: nessun costo, ed è un ordine migliore anche lì.
- **Iniezione dinamica** `` !`comando` ``: stato della feature attiva, branch base e diff stat possono entrare nel prompt della skill come output di uno script, senza turni del modello. Va usata con `|| true`, perché un exit code diverso da zero annulla l'invocazione. *AGY*: supporto non documentato. Non usarla finché non è verificata: un `` !`…` `` letterale nel testo confonderebbe il modello. In alternativa, la prima riga del workflow dice di eseguire lo script, cosa che funziona su entrambi gli host.
- **`paths:`** nella frontmatter: limita l'attivazione automatica a certi glob. Esperimento: registrare le skill degli adapter come skill vere con `paths:` e `user-invocable: false`, al posto delle tabelle di trigger lette dal modello. Prima va misurato il costo della lista in `/context`. *AGY*: senza `paths:`, 39 skill di adapter in più nella lista. Le tabelle di trigger vanno quindi tenute comunque, e l'esperimento ha senso solo se il build Antigravity può escluderle.
- **`disallowed-tools`**: per skill di sola lettura (status, board, metrics, analyze) toglie Write ed Edit in modo deterministico. *AGY*: eliminato dal build. Resta la regola in prosa più un hook ([AGY-2](#agy-2)).

### Antigravity CLI

Cosa fa oggi `scripts/builders/build-antigravity.sh` (radice del repo) alle skill e agli agenti:

| Elemento | Claude Code | Antigravity (dopo il build) | Conseguenza |
| --- | --- | --- | --- |
| `model`, `effort` | applicati (se invocati come skill) | eliminati | Tutti i passi girano col modello della sessione |
| `context`, `agent`, `background` | subagent per skill | eliminati | Nessun fork: la skill gira nel contesto principale |
| `disable-model-invocation` | skill solo su richiesta | ✅ eliminato da tutte le skill | Tutte le 26 skill sono invocabili dal modello |
| `allowed-tools` | pre-approvazione | eliminato | Più richieste di permesso |
| `tools`, `disallowedTools` degli agenti | review in sola lettura imposta dall'host | ✅ eliminati, aggiunto `subagent: true` | Sola lettura garantita solo dalla prosa ("Tool constraints") |
| `commands/` | 27 comandi di rinvio | esclusi | Le skill sono i comandi slash |
| Orientamento | iniezione da `SessionStart` | `dist/devflow-antigravity/rules/devflow-orientation.md` | Già portato |

<a id="agy-1"></a>
#### AGY-1 🔴 ✅ `AGY` Skill "solo su richiesta" invocabili dal modello

Su Antigravity le 15 skill con `disable-model-invocation: true`, tra cui pr, rollback, hotfix, worktree, setup, init, ship e auto, diventano attivabili in automatico. pr fa commit e push, rollback riscrive lo stato: un'attivazione involontaria è un'azione irreversibile. Inoltre tutte le 26 descrizioni occupano la lista delle skill in ogni sessione.

**Intervento**

1. Verificare con una prova su `agy` se esiste un campo equivalente. Se esiste, il build lo traduce invece di eliminarlo.
2. Se non esiste:
   - il build antepone alla descrizione di quelle skill una formula esplicita ("Run only when the user explicitly types /…");
   - il contratto di input della skill termina subito se non è stata chiesta esplicitamente;
   - le azioni irreversibili (`git push`, `gh pr create`, `git reset`) passano da un hook `PreToolUse`, che su Antigravity esiste, attivo solo se c'è un marcatore di run o di invocazione esplicita.
3. Accorciare le descrizioni di queste skill, che su Antigravity costano in ogni sessione.

<a id="agy-2"></a>
#### AGY-2 🟠 `AGY` Revisori in sola lettura solo sulla carta

I revisori di ship girano in parallelo sullo stesso albero di lavoro. Su Claude Code `tools` e `disallowedTools` lo rendono sicuro, su Antigravity no.

**Intervento**

- Il build **traduce** `tools` nel formato degli agenti di agy (`tools: [view_file, …]`, 📄 da verificare), invece di eliminarlo.
- In mancanza di quel formato, un hook `PreToolUse` nega scritture e modifiche mentre è attivo il marcatore di fan-out di ship (`hooks/pre-agent-fanout-cap.sh` conosce già il fan-out).

<a id="agy-3"></a>
#### AGY-3 🟠 Script come strato comune ai due host

Su Antigravity mancano i campi che su Claude Code regolano modello, contesto e permessi, quindi la leva principale per qualità, token e tempo sono gli **script**. *scripts/devflow-state.sh* ([T-1](#t-1)), *scripts/verify-stamp.sh* ([L-1](#l-1)) e *scripts/review-packet.sh* ([T-7](#t-7)) devono:

- essere bash portabile (macOS e Linux, niente `timeout` GNU obbligatorio, `jq` opzionale come negli hook);
- essere richiamati con un percorso tradotto dal build per ogni host, come in [CC-1](#cc-1);
- produrre output compatto e identico sui due host, così le skill non hanno rami per host.

Per lo stesso motivo il timbro di verifica di [L-1](#l-1) si appoggia all'hook `Stop`, che esiste su entrambi gli host.

<a id="agy-4"></a>
#### AGY-4 🟡 `AGY` Domande all'utente e subagent con nomi neutri

Le skill nominano tool di Claude Code (`AskUserQuestion`, `Agent`). Proposta:

- scrivere le istruzioni in modo neutro ("chiedi all'utente, al massimo 4 domande per volta"; "avvia un subagent");
- oppure lasciare al build la sostituzione dei nomi per host, come già fa per i matcher degli hook (`Agent` → `invoke_subagent`).

Lo strumento di domanda di Antigravity va verificato.

---

## 2. Qualità dell'output

<a id="q-1"></a>
### Q-1 🔴 ✅ `devflow-pr` rompe la PR o cancella file

In `skills/devflow-pr/SKILL.md`:

| Problema | Effetto |
| --- | --- |
| `gh pr create --attach` (Step 5) non è un flag di `gh` | La creazione della PR fallisce proprio quando c'è uno screenshot |
| Il body incorpora `/tmp/devflow-ui-preview-...png` | L'immagine non può mai essere visualizzata su GitHub |
| `rm -f *.png *.jpg *.jpeg *.webp` nella radice | Cancella immagini legittime del progetto |
| `git add .` | Contraddice l'anti-pattern della stessa skill e può includere file non voluti |
| Tipo di commit `docs` contro tipo di branch `doc` (in `devflow-task`) | Convenzioni incoerenti |
| "Closes TASK-NNN" richiesto ma assente dal template del body | Il collegamento al task si perde |
| Checklist del body con caselle `- [ ]` non spuntate | Contraddice la regola "never open a PR with unresolved checklist items" |

**Intervento**

- Screenshot caricato con un commento alla PR, oppure omesso.
- Staging esplicito dei file della feature, con `git diff --cached --stat` mostrato prima del commit.
- Cancellare solo i file temporanei in `/tmp`.
- Checklist costruita dalle evidenze ([Q-3](#q-3)), non lasciata da spuntare.
- Aggiungere un caso di eval comportamentale per pr ([M-1](#m-1)).

<a id="q-2"></a>
### Q-2 🟠 Istruzioni che si contraddicono

| Tema | Contraddizione | Proposta |
| --- | --- | --- |
| Frequenza di format/analyze in implement | ✅ `contexts/implement.md` dice dopo ogni file. `skills/devflow-implement/SKILL.md` Step 6 dice una volta alla fine. Il suo anti-pattern dice dopo ogni slice verticale | Una sola regola: per slice. Eliminare `contexts/implement.md` ([T-6](#t-6)) |
| Branch base | implement usa `origin/main` cablato e "When NOT to Use" esige un branch da `main`. task e pr rilevano `$BASE_BRANCH` | Uno script condiviso per il branch base, usato da tutte le skill |
| Escalation di livello 4 in run mode | `references/escalation-ladder.md` chiede all'utente di approvare la scomposizione, ma run e auto non devono mai fare domande. `references/run-mode.md` non copre il caso | In run mode il livello 4 diventa un decision flag, oppure si passa direttamente al livello 5 |
| Menu finale di test | `skills/devflow-test/SKILL.md` offre 3 opzioni: due saltano il gate di ship, una ripete lo Step 3 di pr | Nessuna domanda: si passa a ship |
| Riferimenti interni | implement rimanda a "Step 8 deviations" e "before Step 7b", ma le deviazioni sono lo Step 7b. test legge constitution e registry senza scopo dichiarato | Correggere i rimandi e togliere le letture senza scopo |

<a id="q-3"></a>
### Q-3 🟠 Verifiche dichiarate ma non dimostrate

- La "Pre-handoff checklist" di implement non ha un campo per l'evidenza.
- I contratti di ship "beautify complete" e "analyze clean" non hanno un controllo: il modello o li rilancia o li presume.
- I conteggi "Files N/M" e "Tests N passed" nei report di run e auto li calcola il modello. Potrebbero venire da `.devflow-test-summary.json` e `git diff --stat`.
- Voci della checklist di PR come "coverage ≥80% on modified areas" (`adapters/nextjs/steps/pr.md`) non vengono mai calcolate.

**Intervento**: ogni voce di checklist ha una fonte di evidenza (file, comando, timbro di [L-1](#l-1)) oppure viene rimossa. Il report finale si compone da quei file con uno script, non a memoria.

<a id="q-4"></a>
### Q-4 🟠 Regole di CONTRIBUTING non applicate agli adapter

- 38 skill di adapter su 39 non hanno `## Purpose` e 33 non hanno `## When NOT to Use` né la clausola "file does not match trigger pattern". `scripts/validate-skills.sh` richiede agli adapter solo l'I/O Reference, quindi `--strict` passa.
- I trigger per percorso sono documentati in tre posti diversi: CONTRIBUTING dice `ADAPTER.md`, mentre le tabelle reali stanno in `adapters/<stack>/steps/implement.md`.
- Sei skill non vengono mai caricate da nessun trigger: `angular-testing`, `angular-theme`, `nextjs-metadata`, `nextjs-performance`, `nestjs-microservices`, `flutter-architecture`. Anche `common-state-patterns` non è referenziata da nessun adapter, e `common-web-interface-guidelines` è collegata solo a Next.js.

**Intervento**

1. Un unico posto per i trigger, `adapters/<stack>/steps/implement.md`, con CONTRIBUTING allineato.
2. Il validatore controlla che ogni skill di adapter sia raggiungibile da almeno un trigger e abbia le sezioni richieste.
3. Integrare le sezioni mancanti nei 38 file, in forma breve.

<a id="q-5"></a>
### Q-5 🟡 Eval che misurano davvero

Le eval Tier-2 attuali (`scripts/run-evals.sh`) controllano la sovrapposizione di parole tra prompt e descrizione. Non dicono se la skill produce l'output giusto. Doctor, hotfix, metrics e rollback non hanno casi, e metrics è invocabile dal modello. Vedi [M-1](#m-1).

---

## 3. Aggiornamento degli adapter al 29 ottobre 2026

Nessun adapter è fermo a una major vecchia: Angular punta a v22, Next.js a 16, NestJS a 11/12, Riverpod a 3. I problemi stanno nelle API e nei riferimenti.

### Versioni

| Stack | Assunto nei file | Corrente | Note |
| --- | --- | --- | --- |
| Angular | v22 | 22.2.x | `@angular/animations` deprecato dalla 20.2, rimozione prevista in v23. Vitest predefinito dalla v21 |
| Next.js / React | 16 / 19.0 | 16.4.3 / 19.3.1 | Cache Components attivo per default in `create-next-app`, default in Next 17 |
| Zod | API v3 | 4.6.x | API diverse (`.issues`, `z.email()`, `z.flattenError`) |
| Tailwind | v4 dichiarato, token in stile v3 | 4.3.x | Serve `@theme inline` |
| shadcn/ui | `Form`/`FormField` | `Field` + `Controller` | |
| NestJS | "11+/12+" | 12.1.x | `useSecurityHeaders()`, Standard Schema, Terminus senza `HealthIndicator`, Vitest nei progetti ESM |
| TypeORM / Prisma | solo TypeORM 0.3 | TypeORM 1.0, Prisma 7.x | Nessun percorso Prisma o Drizzle |
| BullMQ | API legacy `@nestjs/bull` | bullmq 6 | `WorkerHost`, `@OnWorkerEvent`, `upsertJobScheduler` |
| Flutter / Dart | ≥3.27 / Dart 3 | 3.47 / Dart 3.13 | |
| Riverpod | 3, misto a 2.x | flutter_riverpod 3.4, generator 4.0 | Ref tipizzati rimossi, `riverpod_lint` tramite `analysis_server_plugin` |
| freezed | sintassi 2.x | 4.0.x | `abstract class` obbligatorio |

Le versioni correnti vengono da npm e pub.dev (2026-10-29). Le patch sono indicative.

<a id="ad-1"></a>
### AD-1 🔴 Codice che non compila o fallisce a runtime

| Stack | File | Problema | Correzione |
| --- | --- | --- | --- |
| Flutter | ✅ `adapters/flutter/skills/flutter-models/references/models-patterns.md` | `@freezed class Pet with _$Pet` non genera codice con freezed ≥3. Il SKILL.md argomenta *contro* `abstract` | `abstract class Pet with _$Pet` |
| Flutter | `adapters/flutter/skills/flutter-supabase/references/supabase-patterns.md` | Ref tipizzati (`SupabaseClientRef`) non più generati | `Ref`, e `keepAlive: true` sul provider del client |
| Flutter | `adapters/flutter/skills/flutter-riverpod/SKILL.md` | `valueOrNull` indicato come deprecato: è stato rimosso. Manca il controllo `ref.mounted` dopo `await` | Aggiornare a Riverpod 3 |
| Next.js | ✅ `adapters/nextjs/skills/nextjs-forms/references/forms-patterns.md` | `parsed.error.errors` non esiste in Zod 4 | `.issues` |
| Next.js | ✅ `adapters/nextjs/skills/nextjs-testing/references/testing-patterns.md` | `setupFilesAfterFramework` non è un'opzione di Jest | `setupFilesAfterEnv` |
| Next.js | `adapters/nextjs/skills/nextjs-testing/SKILL.md` | Render di Server Component asincroni in Jest: non supportato | Test E2E |
| Angular | ✅ `adapters/angular/skills/angular-routing/SKILL.md` | `Routes` importato da `@angular/core` | `@angular/router` |
| Angular | ✅ `adapters/angular/skills/angular-component/references/component-patterns.md` | `afterRender` rimosso. `@case ('a'), @case ('b')` non è sintassi valida | `afterEveryRender` e un `@case` per valore |
| Angular | `adapters/angular/skills/angular-http/references/http-patterns.md` | `inject(Router)` dentro `catchError` (NG0203). `catchError` fuori da `switchMap` chiude lo stream al primo errore | `inject` nel contesto di injection, `catchError` dentro `switchMap` |
| Angular | `adapters/angular/skills/angular-testing/references/testing-patterns.md` | `fakeAsync`/`waitForAsync` richiedono zone e contraddicono la linea zoneless | `vi.useFakeTimers` |
| NestJS | `adapters/nestjs/skills/nestjs-error-handling/references/error-handling-patterns.md` | `Logger` iniettato come provider: errore di DI | `new Logger(Context.name)` |
| NestJS | `adapters/nestjs/skills/nestjs-microservices/references/microservices-patterns.md` | `HealthIndicator`/`HealthCheckError` rimossi in v12. API Bull legacy | Nuova API Terminus, `WorkerHost` |
| NestJS | `adapters/nestjs/steps/test.md` | `--testPathPattern` | Jest 30: `--testPathPatterns` |

<a id="ad-2"></a>
### AD-2 🟠 Pratiche superate

- **Next.js**: ✅ `revalidateTag(tag)` a un argomento è deprecato. Usare `revalidateTag(tag, 'max')`, oppure `updateTag`/`refresh()` nelle Server Action. La config di segmento (`dynamic`, `revalidate`, `fetchCache`) è superata da `use cache`/`cacheLife`. Proxy gira solo su Node. Image `priority` è sostituito da `preload`. `next lint` è stato rimosso nella 16, quindi `pnpm lint` non può appoggiarsi a lui. Token Tailwind v4 con `@theme inline`. shadcn `Field`.
- **Angular**: condizioni posizionali `hidden`/`disabled` nei signal form deprecate in favore di `{when}`. `linkedSignal` al posto di `effect()` per sincronizzare lo stato. `reportUploadProgress` con `withXhr()`. Rimuovere la guida su `@angular/animations` prima di v23. `prerender: true` → `ServerRoute` con `RenderMode.Prerender`.
- **NestJS**: `app.useSecurityHeaders()` ed `enableCsrfProtection()` al posto di helmet. `@Body({ schema })` con `StandardSchemaValidationPipe`. Shutdown e draining delle richieste sono già gestiti da v12. Vitest come opzione nei progetti ESM.
- **Flutter**: installare slang, non easy_localization (`adapters/flutter/steps/setup.md` contraddice tutti gli altri file). `riverpod_lint` tramite `plugins:`. `tester.view.physicalSize` per i test di layout. Definire o generare l'estensione `.skeleton(mock:)`, oggi obbligatoria ovunque ma mai creata.
- **Common**: `userNotifierProvider` diventa `userProvider` con il generator di Riverpod. Le regole di `common-web-interface-guidelines` sono specifiche di React e si contraddicono: `onKeyDown` obbligatorio contro `<button>` semantico, `autocomplete` obbligatorio contro `autocomplete=off`.

### AD-3 🟠 Contraddizioni interne agli adapter

- Angular: "No NgRx", ma il setup installa `@ngrx/signals` (va detto "no `@ngrx/store`"). "Niente HTTP nei componenti", ma la skill http mette `httpResource` nei componenti. npm in test e pr, pnpm in implement e nei template.
- Next.js: i test si aspettano 400, il pattern server restituisce 422. I glob di coverage puntano a `src/**` ma l'albero è `app/` alla radice. `nextjs-state` duplica `common-state-patterns` e lo contraddice sul mock degli store.
- NestJS: TypeORM cablato ovunque (ADAPTER, plan, beautify, REGISTRY).
- Setup che installa librerie senza skill (transloco, next-intl) e ne omette di usate (`@angular/aria`, Tailwind, next-themes, Playwright).

<a id="ad-4"></a>
### AD-4 🟠 Restare aggiornati, non solo aggiornarsi una volta

Il problema si ripresenterà alla prossima minor. Proposta:

1. **Intestazione di versione** in ogni `ADAPTER.md`: una riga `Verified against: Next.js 16.4, React 19.3, Zod 4.6 — 2026-10-29`. Le skill e i riferimenti la ereditano.
2. **Script di freschezza** (*scripts/check-adapter-versions.sh*, nuovo): confronta le versioni dichiarate con `npm view` e `pub.dev` e segnala le major o minor superate. Gira in CI su base settimanale, non blocca.
3. **Lista di API vietate** per adapter (*adapters/&lt;stack&gt;/deprecated-apis.txt*, nuovo): `afterRender(`, `setupFilesAfterFramework`, `error.errors`, `revalidateTag(` a un argomento, ecc. Un grep in `validate-adapters.sh` impedisce che rientrino.
4. **Riferimenti alla documentazione live**: per le API che cambiano spesso (caching di Next.js, signal form di Angular), la skill indica di consultare Context7 o la documentazione ufficiale invece di riportare esempi lunghi. Tiene anche bassi i token ([T-10](#t-10)).

---

## 4. Token

<a id="t-1"></a>
### T-1 🔴 Stato gestito da script, non da prosa

`references/state-machine.md` (15 KB) viene letto da 17 skill per eseguire il frammento jq di aggiornamento e il resolver della feature attiva. Il checkpoint "append" è composto a mano in jq.

**Intervento**: *scripts/devflow-state.sh* (nuovo) con i sottocomandi:

- `resolve`: feature attiva;
- `set-status <status> [next]`: aggiorna `**Status:**` in plan.md e il JSON in modo atomico, riusando `df_json_update` di `hooks/lib/`;
- `mark-done <path>`;
- `checkpoint-append`;
- `run arm|disarm|bump`.

Le skill chiamano lo script con una riga. `state-machine.md` resta solo per persone, recovery e status.

**Effetto stimato**: −30K token per pipeline interattiva, −4K per run auto, e nessun errore di composizione jq.

<a id="t-2"></a>
### T-2 🟠 Core Principles in una riga

CONTRIBUTING impone di copiare alla lettera i 4 punti di `ETHOS.md` in ogni skill: 20-23 copie, ~11 KB. Sostituirli con una riga di rimando più gli eventuali principi specifici della skill, e aggiornare il validatore. Se la regola deve valere sempre, la sede giusta è l'iniezione di `SessionStart`, non 23 copie.

<a id="t-3"></a>
### T-3 🟠 Anti-pattern e tabelle I/O caricati su richiesta

Anti-Patterns (22,8 KB) e I/O Reference (20,6 KB) si caricano a ogni invocazione. Proposta:

- nel SKILL.md restano le 3-5 regole più critiche, in cima ([CC-5](#cc-5));
- il catalogo completo va in `references/`, come `devflow-plan` fa già con il suo file di anti-pattern;
- l'I/O resta in un blocco compatto che il validatore continua a controllare.

**Effetto stimato**: −15 KB per run.

<a id="t-4"></a>
### T-4 🟠 Input di `devflow-task`

La skill più pesante in ingresso (~20K token). Le stesse regole compaiono tre volte: Core Principles, checklist dello Step 8 e Anti-Patterns. Lo Step 5 carica 6 file (`refinement-hints.md`, `examples.md` da 8,2 KB, INVEST, story splitting, BDD, intervista). Proposta: un'unica checklist, con `examples.md` letto solo se il primo tentativo non supera la checklist. **Effetto stimato**: −15 KB.

<a id="t-5"></a>
### T-5 🟠 Output grezzo dei test fuori dal report

Lo Step 7 di `skills/devflow-test/SKILL.md` incolla stdout e stderr di ogni target. Proposta: salvarli con `tee` in `devflow/features/NNN/test-output.log` come evidenza, e nel report mettere solo i conteggi e le righe decisive (principio "derive, don't dump" di `references/token-economy.md`). **Effetto stimato**: −5-50 KB per run, secondo lo stack.

<a id="t-6"></a>
### T-6 🟡 `contexts/*.md`

6,4 KB che l'hook di `SessionStart` invita a caricare. Duplicano le skill e sono superati: `contexts/implement.md` contraddice implement ([Q-2](#q-2)) e dice "stop and surface" anche in run mode. Eliminarli, oppure ridurli a 3 righe ciascuno.

<a id="t-7"></a>
### T-7 🟠 Pacchetto di review per gli agenti di ship

Ogni agente rilegge task, plan, constitution e registry e lancia il proprio `git diff`. Proposta: *scripts/review-packet.sh* (nuovo) produce un unico file con file cambiati, diff stat, criteri di accettazione e le regole di constitution pertinenti. Gli agenti leggono quello.

**Effetto stimato**: −56 KB per ship nel profilo standard, −112 KB nel profilo thorough. Gli agenti partono anche prima.

<a id="t-8"></a>
### T-8 🟡 Hook istinti senza deduplica

`hooks/post-edit-instinct-context.sh` reinietta gli stessi 3 istinti a ogni modifica, inclusa ogni marcatura `[done]` in plan.md. Proposta: tenere un registro per sessione degli istinti già inviati in `.devflow-observe-state.json`. **Effetto stimato**: −10-20 KB per implement.

<a id="t-9"></a>
### T-9 🟡 Testo morto

- Il ramo "Legacy adapters without `steps/`" compare 6 volte, ma tutti gli adapter hanno `steps/`.
- Plan scrive i marcatori `[P]` e `[route:]`, che implement non legge: usarli ([L-5](#l-5)) o toglierli.
- `argument-hint: "[]"` vuoti.

<a id="t-10"></a>
### T-10 🟠 Riferimenti degli adapter: ~175 KB su 395 ripetono la documentazione

| Adapter | Rimovibile (stima) | File più pesanti |
| --- | --- | --- |
| NestJS | ~69 KB | blocchi "Incorrect" (16 KB), esempi generici di pipe, guard, interceptor, Supertest e YAML K8s; ogni SKILL.md ripete le regole tre volte; rimandi "Source rules:" a ID inesistenti |
| Angular | ~57 KB | `http-patterns.md` (22,6 KB, ~16 KB rimovibili), `component-patterns.md`, `form-patterns.md` |
| Next.js | ~35 KB | `server-patterns.md` (contiene il testo del SKILL.md incollato), `components-patterns.md` |
| Flutter | ~23 KB | layout, supabase; `adapters/flutter/skills/flutter-models/SKILL.md` ripete parola per parola il suo riferimento |

**Criterio**: resta solo ciò che è una **decisione del progetto**, cioè cosa usare, cosa evitare e perché, con al massimo un esempio breve. Va via ciò che il modello sa già o che trova nella documentazione corrente ([AD-4](#ad-4)).

Anche `adapters/common/skills/common-clean-code/SKILL.md` è quasi tutto SOLID da manuale (~3 KB su 4,4). Alcune regole di Object Calisthenics ("max 2 variabili d'istanza") sono violate dagli esempi degli stessi adapter. Restano le regole specifiche: identificatori in inglese e la "Rule of 500".

<a id="t-11"></a>
### T-11 🟠 ✅ Import anticipati nei template AGENTS

`adapters/nestjs/templates/AGENTS.template.md` importa con `@` 3 skill core e 3 skill di adapter (~29 KB). `adapters/flutter/templates/AGENTS.template.md` ne importa 4 (~18 KB), anche se l'app non usa Supabase. Se il consumer carica `AGENTS.md` come memoria, questo testo entra in **ogni** sessione e annulla il caricamento per trigger. Sostituire gli import con l'elenco dei trigger.

---

## 5. Tempo

<a id="l-1"></a>
### L-1 🔴 Timbro di verifica: ogni controllo una volta sola

Oggi format e analyze girano in implement Step 6, poi nell'hook sincrono `hooks/stop-format-typecheck.sh` (timeout 90 s). I contratti di beautify, test e ship ricontrollano "analyze clean". Pr Step 3 rilancia lint, l'intera suite di test e il build.

**Intervento**: *scripts/verify-stamp.sh* (nuovo) registra l'esito di lint, typecheck e test associato all'hash dell'albero (`git write-tree` sui file tracciati più quelli modificati).

- I contratti controllano il timbro e rilanciano solo se l'albero è cambiato.
- Pr esegue solo il build.
- L'hook Stop non fa nulla se c'è un marcatore di run attivo o se il timbro è fresco.

**Effetto stimato**: 2-4 typecheck e una suite di test completa in meno per pipeline, cioè minuti a ogni run.

<a id="l-2"></a>
### L-2 🟠 Beautify non ripete la review di ship

Beautify analizza 8 assi (correttezza, sicurezza, prestazioni, accessibilità…), gli stessi coperti da code-reviewer, security-auditor e accessibility-auditor in ship. Proposta:

- Beautify diventa deterministico: lint autofix, conformità ai design token e la lista dei miglioramenti "certi".
- Si salta nel profilo `quick`.
- Più passaggi di approvazione si riducono a una domanda multi-select.

È coerente con `docs/new.md`, che già chiede di rendere beautify un passo opzionale.

<a id="l-3"></a>
### L-3 🟠 `devflow.run` e `devflow.auto`: un subagent per passo

Oggi i corpi di tutte le skill si accumulano nello stesso contesto (~71K token prima di qualsiasi codice) e la compattazione a metà run è probabile. `plan.md` e `.devflow-state.json` fanno già da passaggio di consegne tra i passi.

**Intervento**

- Ogni passo gira in un subagent **lanciato dall'orchestratore** (`Agent` su Claude Code, `invoke_subagent` su Antigravity). Non si usa `context: fork`, che esiste solo su Claude Code e che il build Antigravity elimina. Così il meccanismo è lo stesso sui due host.
- Il prompt del subagent è breve: il passo da eseguire, il percorso della skill tradotto dal build ([CC-1](#cc-1)) e l'esito atteso, cioè una riga di stato più il percorso del report.
- `CC`: il subagent può avere un modello e un effort per passo ([CC-3](#cc-3)), senza cache miss nel contesto principale. `AGY`: usa il modello della sessione, ma il contesto resta separato per ogni passo, quindi il risparmio in token vale anche lì.
- L'orchestratore resta piccolo: legge lo stato con *scripts/devflow-state.sh*, lancia il passo e legge l'esito strutturato.
- I subagent non possono fare domande all'utente. Non è un problema, perché auto raccoglie gli input prima di partire e run conferma una volta allo Step 0.

**Da verificare su Antigravity**: che i subagent possano a loro volta leggere ed eseguire una skill, e quanti ne possono girare in parallelo. In mancanza, serve una modalità in un solo contesto, documentata e dichiarata nel report finale.

<a id="l-4"></a>
### L-4 🟠 Meno round-trip con l'utente

- Chiarimenti di task e clarify: oggi fino a 5 domande una alla volta (`interactive-interview.md`). `AskUserQuestion` accetta 1-4 domande per chiamata, quindi le domande indipendenti vanno raggruppate.
- Menu finale di test: va rimosso ([Q-2](#q-2)).
- Approvazioni di beautify: una sola domanda multi-select ([L-2](#l-2)).

<a id="l-5"></a>
### L-5 🟡 Lavoro parallelo oggi sequenziale

- Implement: dopo la slice dei contratti, i file foglia marcati `[P]` / `[route: light]` vanno a subagent leggeri in parallelo.
- Ship: il controllo di `devflow.learn` allo Step 0 gira insieme al fan-out degli agenti.
- Lint e typecheck girano in background durante i test.
- I marcatori `[done]` si scrivono una volta per slice tramite *scripts/devflow-state.sh*, non con un Edit per file.

<a id="l-6"></a>
### L-6 🟡 Ciclo di correzione di ship più mirato

Ogni iterazione rilancia implement `--fix`, beautify, l'intero passo di test e l'intero fan-out. Proposta:

- si ritestano solo i criteri di accettazione i cui file sono cambiati;
- la stessa squadra di agenti rivede solo il diff dal checkpoint di ship;
- il rilancio completo resta per il profilo `thorough`.

Compromesso: si perde un po' di indipendenza nella seconda review.

---

## 6. Misurazione

<a id="m-1"></a>
### M-1 🟠 Baseline e confronto su entrambi gli host

Nessun intervento va considerato riuscito senza un numero prima e dopo, su Claude Code **e** su Antigravity.

1. **Baseline** (prima di toccare le skill): una feature di riferimento per adapter (es. "aggiungi un form con validazione e una lista paginata"), eseguita con `devflow.auto` su un progetto di esempio, una volta per host. Registrare per ogni passo:
   - token in ingresso e in uscita (`hooks/stop-metrics.sh`, `/context`);
   - durata;
   - numero di domande all'utente;
   - esito di build e test.
2. **Eval comportamentali `CC`** con `claude plugin eval` (code.claude.com/docs/en/plugin-evals.md):
   - grader `tool_used` con `input_match` sul nome della skill per l'accuratezza dei trigger, al posto del bag-of-words;
   - `file_exists` e `regex` per i contratti di output (plan.md con `**Status:**`, checklist con evidenze, nessun `@devflow/` non risolto);
   - grader `llm` per la qualità di task e plan;
   - `--ablation with-without` per misurare il valore aggiunto della skill rispetto al modello da solo.
3. **Prova `AGY`**: `claude plugin eval` non copre Antigravity.
   - Ogni release fa una prova minima con `agy` sulla stessa feature di riferimento: skill attivate, file prodotti, nessun `@devflow/` non risolto, nessuna attivazione involontaria di pr o rollback ([AGY-1](#agy-1)).
   - Se `agy` permette un'esecuzione non interattiva (da verificare), la prova entra in CI con gli stessi controlli `file_exists`/`regex` riscritti come script.
   - Per evitare due insiemi di casi, i casi stanno in un formato unico (prompt più controlli sui file) da cui si generano le eval Claude Code e la prova Antigravity.
4. **CI**:
   - `claude plugin validate dist/devflow --strict` e `agy plugin validate dist/devflow-antigravity` a ogni PR;
   - le eval comportamentali su `next` prima di ogni release, con `--max-cost-usd` per contenere il costo (ogni run è una vera chiamata al modello);
   - casi mancanti: doctor, hotfix, metrics, rollback;
   - casi comportamentali per pr ([Q-1](#q-1)) e per run/auto.
5. **Uso reale `CC`**: `/skill-doctor` per le skill mai invocate e il loro costo in contesto, `claude plugin details devflow` per il costo sempre presente della lista. Su Antigravity il costo della lista va stimato contando le descrizioni del build, perché lì sono tutte presenti ([AGY-1](#agy-1)).

### Obiettivi

| Metrica | Oggi (stima) | Obiettivo |
| --- | --- | --- |
| Token del plugin per pipeline interattiva | ~170K | ≤100K |
| Token residenti in `devflow.auto` prima del codice | ~71K | ≤20K nell'orchestratore |
| Typecheck e suite di test ripetuti per pipeline | 3-5 / 2 | 1 / 1 |
| Domande all'utente in task (5 chiarimenti) | 5 turni | ≤2 turni |
| API vietate negli adapter (`deprecated-apis.txt`) | da censire | 0, bloccato in CI |
| Accuratezza dei trigger (`plugin eval`) | non misurata | ≥95% |
| `@devflow/` non risolti in `dist/` (CC / AGY) | presenti / 31 skill | 0 / 0 |
| Skill "solo su richiesta" attivabili dal modello su Antigravity | 15 | 0 |

---

## 7. Piano di intervento proposto

| Fase | Contenuto | Esito atteso | Release |
| --- | --- | --- | --- |
| **0. Baseline** | M-1 punto 1 su entrambi gli host, eval comportamentali minime per pr, task, plan, implement, prova di frontmatter, domande e subagent su `agy` | Numeri di partenza per ogni passo e per host; elenco di cosa Antigravity supporta davvero | — |
| **1. Correzioni bloccanti** | Q-1, CC-1, AGY-1, AD-1, CC-4 | Nessuna PR rotta, nessun file cancellato, riferimenti risolti su entrambi i build, nessuna azione irreversibile attivata per sbaglio su Antigravity, codice di esempio che compila | patch |
| **2. Script al posto della prosa** | AGY-3, T-1, L-1, T-7, T-5, T-8, Q-3, AGY-2 | Stato, verifiche e review deterministiche e uguali sui due host; −30K token e minuti per run | minor |
| **3. Modello di esecuzione** | CC-2, CC-3, L-3, AGY-4, Q-2 | Skill come unico ingresso su entrambi gli host, modelli applicati davvero su Claude Code, run e auto senza accumulo di contesto | **major** (cambiano i nomi slash su Claude Code) |
| **4. Adapter al 29 ottobre** | AD-2, AD-3, Q-4, T-10, T-11, AD-4 | Adapter coerenti, raggiungibili, aggiornati, −175 KB, controllo di freschezza in CI | minor |
| **5. Snellimento e tempo** | T-2, T-3, T-4, T-6, T-9, L-2, L-4, L-5, L-6, CC-5, Q-5 | Meno boilerplate, meno domande, più parallelismo | minor |
| **6. Verifica** | M-1 punti 2-4 sulla stessa feature di riferimento | Confronto con la baseline sugli obiettivi della sezione 6 | — |

**Avanzamento**

| Fase | Stato | Voci chiuse | Commit su `next` |
| --- | --- | --- | --- |
| 1 | fatta | Q-1, CC-1, AGY-1, AD-1, CC-4 | `124a177`…`644f630` |
| 2 | fatta | AGY-3, T-1, L-1, T-5, T-7, T-8, Q-3, AGY-2 | `6ef76e6`…`8bcf7eb` |
| 3 | in corso | CC-2, CC-3, L-3, AGY-4, Q-2 | — |

**Ordine**: la fase 1 viene prima perché corregge rotture reali. La fase 2 precede la 3 perché gli script (stato, timbro, pacchetto di review) sono il passaggio di consegne che rende possibili i subagent per passo. La fase 4 è indipendente e può procedere in parallelo, adapter per adapter.

**Punti da confermare nella fase 0**, con una prova minima per host:

- `CC`: se `model:` di una skill viene applicato quando la si invoca tramite un comando;
- `CC`: come collidono un comando e una skill di plugin con lo stesso nome;
- `AGY`: quali campi della frontmatter rispetta (in particolare un equivalente di `disable-model-invocation` e il formato `tools` degli agenti);
- `AGY`: nome e limiti dello strumento per fare domande all'utente, se i subagent possono eseguire una skill, e se `agy` ha un'esecuzione non interattiva utilizzabile in CI.

Le voci 📄 su Antigravity dipendono da queste risposte. Il resto della fase 3 si decide in base ai dati raccolti, come in `docs/miglioramenti-plugin.md` per gli hook.
