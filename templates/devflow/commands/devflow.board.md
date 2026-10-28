---
name: devflow.board
description: Generate and sync a deterministic, static, read-only HTML project board in devflow/board/index.html showing all tasks, Kanban pipeline stages, inter-task dependency DAG, Markdown specifications, and per-command development timings. Supports --open, --sync, --port, and --json.
argument-hint: "[--open] [--sync] [--port <port>] [--json]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-board/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, generate the board without opening or syncing.
