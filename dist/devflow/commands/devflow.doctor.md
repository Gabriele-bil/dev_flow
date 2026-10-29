---
name: devflow.doctor
description: Pre-flight diagnostic check for DevFlow — verifies MCP servers, CLI toolchains, active adapter configuration, and pipeline state integrity. Supports --json and --fix.
argument-hint: "[--json] [--fix]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-doctor/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, run diagnostics read-only (no `--json`, no `--fix`).
