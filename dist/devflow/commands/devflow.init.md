---
name: devflow.init
description: Bootstrap a greenfield project end-to-end — upfront long-running process notice, multi-phase interview, evergreen technology scaffolding (Nx, Angular, Next.js, Flutter, NestJS), DevFlow context + ADR-001 generation, and ordered multi-task roadmap generation with inter-task dependencies.
argument-hint: "[optional-project-name-or-brief] [--mcp]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-init/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, start the interview (project name/brief asked there).
