# DevFlow plugin bundle

This directory is the **installable DevFlow package**: core pipeline skills, slash commands, configuration, and technology **adapters**.

## Quick start

1. **Active stack** — edit [`config.md`](config.md); set **Adapter** to `flutter` (only bundled adapter today).
2. **Run setup once** — execute `devflow.setup` to generate root `AGENTS.md` and `REGISTRY.md` for the consumer project.
3. **Run the pipeline** — invoke commands under [`commands/`](commands/) (e.g. `devflow.task`) or load as a plugin and use your host’s namespaced invocations.
4. **Enable code-review-graph** — install and configure once for all detected hosts:
   - `pipx install code-review-graph` (or `pip install code-review-graph`)
   - `code-review-graph install`
   - `code-review-graph build`
5. **Ensure required MCP baseline**:
   - `context7`
   - `sequential-thinking` ([server reference](https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking))
   - `dart` for Flutter adapters/projects

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
- Generated `AGENTS.md` includes `code-review-graph` skill reference for graph-aware reviews.

## Claude Code

- Manifest: [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json)
- Local run: `claude --plugin-dir /path/to/devflow`
- Docs: [Create plugins](https://code.claude.com/docs/en/plugins)

## Cursor

- Manifest: [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json)
- Local install: `ln -s /path/to/devflow ~/.cursor/plugins/local/devflow` then reload the window.
- Docs: [Plugins](https://cursor.com/docs/plugins)

## Commands

| Command | What it does |
|---|---|
| `devflow.task` | Define and scope a task |
| `devflow.plan` | Generate `plan.md` from task |
| `devflow.implement` | Execute plan step by step |
| `devflow.beautify` | Apply design/style pass |
| `devflow.ship` | Pre-handoff review |
| `devflow.setup` | Generate `AGENTS.md` + `REGISTRY.md` |
| `devflow.status` | Show current pipeline state |
| `devflow.learn` | Log, search, list, or prune project learnings |

## Hooks

Ten hooks activate automatically — no user invocation required.

| Event | Script | What it does |
|---|---|---|
| SessionStart | `session-start.sh` | Injects discovery skill + suggests context file based on active pipeline step |
| SessionStart | `session-start-learnings.sh` | Injects past learnings from `.devflow-learnings.jsonl` into session context |
| PreToolUse | `pre-config-protect.sh` | Blocks edits to linter/analyzer config files |
| PreToolUse | `observe.sh pre` | Logs tool calls to `.devflow-observe.jsonl` |
| PostToolUse | `observe.sh post` | Logs tool results to `.devflow-observe.jsonl` |
| PostToolUse | `post-edit-accumulate.sh` | Tracks modified files for batch format check |
| PreCompact | `pre-compact.sh` | Snapshots `plan.md` progress to `.devflow-state.json` |
| Stop | `stop-format-typecheck.sh` | Runs adapter format+analyze after each response |
| Stop | `stop-notify.sh` | Sends macOS desktop notification on response complete |
| Stop | `stop-debug-check.sh` | Warns about `print()` / `console.log` in modified files |
| Stop | `stop-learn-distill.sh` | Detects file churn (≥4 edits) in `.devflow-observe.jsonl`; appends to `.devflow-learnings.jsonl` |

## Contexts

Three context files in `devflow/contexts/` tune Claude's behavior per pipeline phase. The SessionStart hook suggests which one to load based on the active step.

| Context | Suggested for | Focus |
|---|---|---|
| `contexts/implement.md` | devflow.implement, devflow.beautify | Code-first, follow plan.md order, mark [done] |
| `contexts/review.md` | devflow.ship | 7-axis review, severity-ordered findings |
| `contexts/research.md` | devflow.task, devflow.plan | Explore before acting, no application code |

## Core Principles

`ETHOS.md` defines the four non-negotiable principles injected into every skill:

| Principle | Rule |
|---|---|
| `spec-first` | No code before `task.md` + `plan.md` approved |
| `traceability` | Every subtask → acceptance criterion → file(s) |
| `vertical slices` | End-to-end increments, never layers |
| `token-lean` | Caveman-compress: drop articles/hedging/filler; keep precision |

## Plugin Catalog

`agent.yaml` at the plugin root is a machine-readable index of all pipeline components — steps, agents, skills, adapters, hooks, contexts. Use it for tooling, automation, or quick reference.

## Features output

`features/[NNN]_[name]/` holds `task.md` and `plan.md`. In a **consumer app repo**, this folder can be symlinked or copied; paths in skills assume `devflow/features/` relative to the plugin root unless you fork the skills.
