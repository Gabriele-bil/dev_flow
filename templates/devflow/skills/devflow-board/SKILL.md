---
name: devflow-board
description: "Generates and auto-syncs a deterministic, static, read-only HTML project board in devflow/board/index.html visualizing Kanban task stages, dependency DAG critical path, formatted Markdown specs, and per-command execution timings. Use when user runs devflow.board, opens the visual project kanban board, or inspects task lead times."
argument-hint: "[--open] [--sync] [--port <port>] [--json]"
disable-model-invocation: true
---

# Skill: devflow.board

**Arguments:** `$ARGUMENTS` — empty → generate the board without opening or syncing.

## Quick Start

Run `/devflow.board [--open] [--sync] [--port <port>] [--json]`.

- First run initializes `devflow/board/index.html` from `@devflow/skills/devflow-board/assets/board-template.html` and writes `devflow/board/board-data.js` + `devflow/board/board-data.json`
- Subsequent runs or hook invocations (`board.sh --sync`) refresh `devflow/board/board-data.js` in place without recreating `index.html`
- `--open`: open `devflow/board/index.html` in system browser; `--port <N>`: serve over local read-only HTTP; `--json`: emit compiled JSON payload to stdout

## Purpose

Generate and synchronize a deterministic, portable, strictly read-only HTML project board (`devflow/board/index.html`) that visualizes all tasks in `devflow/features/`, Kanban pipeline stages, inter-task dependency graphs (`Blockers`/`Unlocks`), formatted Markdown documents, and per-command development timing telemetry.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` are written and approved
- **traceability** — every subtask maps to an acceptance criterion; every acceptance criterion maps to one or more files
- **vertical slices** — for plans with >5 files: implement end-to-end user-visible increments, never layers
- **token-lean** — caveman-compress all written output: drop articles, hedging, filler, linking phrases; keep technical terms, file paths, commands, verbs, negations, conditions exact

## When NOT to Use

- Terminal-only pipeline state check or CI exit-code gate — use `devflow.status` instead
- Terminal-only bash filter token savings and pass@1 report — use `devflow.metrics` instead
- Modifying task status, editing specifications, or moving pipeline state — edit `task.md`/`plan.md` via pipeline commands (`devflow.task`, `devflow.plan`, `devflow.implement`), never via the board

## Input contract

Before proceeding, verify:

- [ ] `jq` is installed (`command -v jq >/dev/null 2>&1`) — if missing, stop and provide `brew install jq` remediation
- [ ] Canonical template `@devflow/skills/devflow-board/assets/board-template.html` and generator `@devflow/scripts/board.sh` exist
- [ ] If `--port <port>` is passed, `<port>` is numeric and not already bound by another process

If any item fails → stop, report which check failed, do not write partial board artifacts.

## Workflow

### Step 1 — Parse Arguments

Inspect `$ARGUMENTS` for optional flags:

- `--sync`: fast incremental update of `devflow/board/board-data.js` and `devflow/board/board-data.json` without recreating `devflow/board/index.html`
- `--open`: launch system browser pointing to `devflow/board/index.html` (or `http://localhost:<port>/devflow/board/index.html` when combined with `--port`)
- `--port <port>`: start read-only local HTTP server (`python3 -m http.server <port> --bind 127.0.0.1`) so the board can also use direct `fetch()` for `.md` files and `board-data.json`
- `--json`: print compiled board JSON payload to stdout and exit

### Step 2 — Execute Deterministic Board Generator

Run `board.sh`:

```bash
bash "@devflow/scripts/board.sh" $ARGUMENTS
```

What `board.sh` executes deterministically:

1. **Template Initialization:** On first run (or when `devflow/board/index.html` is absent), copies `@devflow/skills/devflow-board/assets/board-template.html` byte-for-byte to `devflow/board/index.html`. Never generates custom per-project HTML/CSS.
2. **Artifact & Telemetry Parsing:** Scans `devflow/features/[NNN]_*/` (`task.md`, `plan.md`, `verification.md`), `devflow/plans/project-blueprint.md`, `docs/adr/*.md`, `.devflow-state.json`, `.devflow-metrics.jsonl`, and `.devflow-timings.jsonl`.
3. **Kanban & Dependency DAG Computation:**
   - Assigns each task to one of 5 read-only columns (`Draft / Clarified`, `Planned / Ready`, `In Progress`, `Implemented / Verified`, `PR Opened / Done`).
   - Resolves `**Blockers:**` and `**Unlocks:**`, marks blocked vs ready tasks, and computes the topological **Critical Path**.
4. **Command Timing & Lead Time Aggregation:**
   - Aggregates `started_at`, `ended_at`, and `duration_sec` per DevFlow command (`task`, `clarify`, `plan`, `analyze`, `implement`, `beautify`, `test`, `ship`, `pr`, `hotfix`) associated with `active_feature`.
   - Computes total active development duration (`sum(duration_sec)`) and overall task lead time (`task.md` creation to `done` / `pr-opened`).
5. **Manifest Emission:** Atomically writes `devflow/board/board-data.js` (`window.__DEVFLOW_BOARD_DATA__`) and `devflow/board/board-data.json`.

### Step 3 — Present Summary & Continuous Sync Status

Report generated board location (`devflow/board/index.html`), project completion KPI (`completed / total tasks`, `%`, active feature), total tracked development time, and confirm that automatic hook synchronization (`post-task-create.sh`, `post-edit-accumulate.sh`, `stop-metrics.sh`) keeps `board-data.js` updated on every feature or state change.

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Write a custom HTML dashboard tailored to this repo's stack" | Forbidden. Every project must use the exact `@devflow/skills/devflow-board/assets/board-template.html` via `board.sh` |
| "Add drag-and-drop card moving or checkbox toggling in the browser" | Board is strictly static and read-only; state changes happen exclusively through DevFlow pipeline commands |
| "Recreate `devflow/board/index.html` from scratch on every hook event" | Once initialized, hooks run `board.sh --sync --quiet` to update only `board-data.js` |
| "Require npm/vite/webpack in the consumer project to build the board" | Zero consumer build dependencies allowed; `index.html` + `board-data.js` run directly on `file://` or static HTTP |

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Hand-editing `devflow/board/board-data.js` | Overwritten on next `--sync` hook trigger | Edit source `task.md` / `plan.md` and let `board.sh --sync` regenerate the manifest |
| Using `fetch()` only without `board-data.js` script tag | Browser CORS blocks `fetch()` when opening `devflow/board/index.html` via `file://` | Always emit `board-data.js` (`window.__DEVFLOW_BOARD_DATA__`) alongside `board-data.json` |
| Running synchronous heavy board builds inside `PreToolUse` hooks | Adds latency to every tool call | Run `board.sh --sync --quiet` only in async `PostToolUse` / `Stop` hooks |
| Rendering unescaped raw Markdown HTML in the drawer | Risks broken DOM or script injection from code snippets inside specs | Escape HTML entities before applying Markdown/Gherkin formatting |

## I/O Reference

| | |
| --- | --- |
| Reads | `@devflow/skills/devflow-board/assets/board-template.html`, `devflow/features/*/task.md`, `plan.md`, `verification.md`, `devflow/plans/project-blueprint.md`, `docs/adr/*.md`, `.devflow-state.json`, `.devflow-metrics.jsonl`, `.devflow-timings.jsonl` |
| Writes | `devflow/board/index.html` (initial setup), `devflow/board/board-data.js`, `devflow/board/board-data.json` (initial + `--sync`) |
| Executes | `@devflow/scripts/board.sh` |
| Related | `devflow.status`, `devflow.metrics`, `hooks/stop-metrics.sh`, `hooks/post-task-create.sh`, `hooks/post-edit-accumulate.sh` |
