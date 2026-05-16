# DevFlow Plugin — Claude Code Context

Plugin Claude Code + Cursor per pipeline di sviluppo spec-driven.
Leggi `devflow/CONTRIBUTING.md` per quality bar e stile prima di modificare qualsiasi skill.

## Struttura critica

- `devflow/` — plugin root (questo è `CLAUDE_PLUGIN_ROOT` a runtime)
- `devflow/.claude-plugin/plugin.json` — manifest Claude Code
- `devflow/skills/<name>/SKILL.md` — skill pipeline core
- `devflow/adapters/<stack>/skills/<name>/SKILL.md` — skill adapter-specifiche
- `devflow/hooks/` — shell scripts + `hooks.json` (lifecycle hooks)
- `devflow/commands/` — entry point comandi slash

## Regole operative

- Ogni SKILL.md deve avere frontmatter YAML con `name` e `description`
- Sections obbligatorie: `## Purpose`, `## Core Principles`, `## When NOT to Use`, `## I/O Reference`
- Validare con `bash devflow/scripts/validate-skills.sh` dopo ogni modifica a SKILL.md
- Non toccare `devflow/config.md` — è generato da `devflow.setup` nel consumer project
- Non scrivere file dentro `devflow/features/` — sono artefatti del consumer project

## Comandi utili

```bash
# Validare tutti i SKILL.md
bash devflow/scripts/validate-skills.sh

# Verificare sintassi hook scripts
bash -n devflow/hooks/<script>.sh
```

## Cosa NON fare

- Non aggiungere logica di business nelle template — vanno nelle skills
- Non aggiungere hook sincroni pesanti (`async: true` + `timeout` per operazioni I/O)
- Non modificare `hooks.json` senza aggiornare i relativi script in `devflow/hooks/`
