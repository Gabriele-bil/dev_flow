---
name: devflow.doctor
description: Pre-flight diagnostic check for DevFlow — verifies MCP servers, CLI toolchains, active adapter configuration, and pipeline state integrity. Supports --json and --fix.
argument-hint: "[--json] [--fix]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-doctor/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, run diagnostics read-only (no `--json`, no `--fix`).
