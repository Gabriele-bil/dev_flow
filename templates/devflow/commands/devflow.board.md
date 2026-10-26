---
name: devflow.board
description: Generate and sync a deterministic, static, read-only HTML project board in devflow/board/index.html showing all tasks, Kanban pipeline stages, inter-task dependency DAG, Markdown specifications, and per-command development timings. Supports --open, --sync, --port, and --json.
argument-hint: "[--open] [--sync] [--port <port>] [--json]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-board/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Execute `@devflow/scripts/board.sh` with supplied flags (`--open`, `--sync`, `--port <port>`, `--json`).
- Enforce deterministic portability: `devflow/board/index.html` must always be copied byte-for-byte from `@devflow/skills/devflow-board/assets/board-template.html`, never hand-authored or custom-generated per project.
- Keep the board strictly static and read-only: zero state mutation, drag-and-drop status changes, or file writes from the browser UI.
- When `--sync` is passed (or triggered automatically by DevFlow hooks), update `devflow/board/board-data.js` and `devflow/board/board-data.json` in place without recreating `devflow/board/index.html`.
- Surface project summary, 5-column Kanban state, dependency DAG critical path, and per-command execution timings (`.devflow-timings.jsonl` / `.devflow-metrics.jsonl`).

User arguments:
`$ARGUMENTS`
