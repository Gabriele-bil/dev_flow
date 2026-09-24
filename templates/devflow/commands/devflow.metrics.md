---
name: devflow.metrics
description: Show DevFlow metrics dashboard — total tokens saved by bash filter, estimated cost per feature, pass@1 success rate, and step durations. Supports --json and --feature.
argument-hint: [--json] [--feature <name>]
disable-model-invocation: true
---

Use `@devflow/skills/devflow-metrics/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Execute `@devflow/scripts/metrics.sh` with supplied flags (`--json`, `--feature`).
- Display token savings from bash output filter (`.devflow-filter-stats.jsonl`).
- Display estimated cost breakdown by feature and session (`.devflow-metrics.jsonl`).
- Report pass@1 stability rate and retry loop count (`.devflow-observe.jsonl`).
