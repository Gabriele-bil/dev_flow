# DevFlow plugin bundle

This directory is the **installable DevFlow package**: core pipeline skills, slash commands, configuration, and technology **adapters**.

## Quick start

1. **Active stack** — edit [`config.md`](config.md); set **Adapter** to `flutter` (only bundled adapter today).
2. **Run setup once** — execute `devflow.setup` to generate root `AGENTS.md` and `REGISTRY.md` for the consumer project.
3. **Run the pipeline** — invoke commands under [`commands/`](commands/) (e.g. `devflow.task`) or load as a plugin and use your host’s namespaced invocations.

## Adapters

- [`adapters/flutter/ADAPTER.md`](adapters/flutter/ADAPTER.md) — Flutter/Dart commands, extra `plan.md` sections, MCP hints, test and PR gates.
- [`adapters/flutter/templates/`](adapters/flutter/templates/) — adapter-specific templates used by `devflow.setup` to generate `AGENTS.md` and `REGISTRY.md`.
- **Add a stack:** copy `adapters/flutter/` to `adapters/<name>/`, replace `ADAPTER.md` and `skills/`, then point `config.md` at `<name>`.

## Setup command

`devflow.setup` is a standalone pre-pipeline command.

- Target output (consumer root): `AGENTS.md`, `REGISTRY.md`
- Default behavior: update only `devflow-managed` blocks and preserve user content outside those blocks
- Force rewrite: pass `--force` to overwrite full file contents
- Template resolution: adapter `templates/` first, then `skills/devflow-setup/templates/` fallback

## Claude Code

- Manifest: [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json)
- Local run: `claude --plugin-dir /path/to/devflow`
- Docs: [Create plugins](https://code.claude.com/docs/en/plugins)

## Cursor

- Manifest: [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json)
- Local install: `ln -s /path/to/devflow ~/.cursor/plugins/local/devflow` then reload the window.
- Docs: [Plugins](https://cursor.com/docs/plugins)

## Features output

`features/[NNN]_[name]/` holds `task.md` and `plan.md`. In a **consumer app repo**, this folder can be symlinked or copied; paths in skills assume `devflow/features/` relative to the plugin root unless you fork the skills.
