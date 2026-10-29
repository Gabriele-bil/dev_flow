---
name: devflow.run
description: Chain implement → beautify → test as one unattended session — decision flags instead of pauses, consolidated report, stop before ship.
argument-hint: "[--from implement|beautify|test] [--until beautify|test|ship]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-run/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, use `--from implement --until test` on the feature resolved per `${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` → **Active feature resolution**.
