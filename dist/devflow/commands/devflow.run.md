---
name: devflow.run
description: Chain implement → beautify → test as one unattended session — decision flags instead of pauses, consolidated report, stop before ship.
argument-hint: "[--from implement|beautify|test] [--until beautify|test|ship]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-run/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, use `--from implement --until test` on the feature resolved per `@devflow/references/state-machine.md` → **Active feature resolution**.
