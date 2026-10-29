---
name: devflow.metrics
description: Show DevFlow metrics dashboard — total tokens saved by bash filter, estimated cost per feature, pass@1 success rate, and step durations. Supports --json and --feature.
argument-hint: "[--json] [--feature <name>]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-metrics/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, show the dashboard for all features.
