---
name: devflow-metrics
description: Display token savings dashboard, estimated cost per feature, pass@k success rate, and step durations. Use when inspecting pipeline metrics, token consumption, or running devflow.metrics.
argument-hint: [--json, --feature <name>]
---

# Skill: devflow.metrics

## Purpose

Aggregate and visualize local telemetry across token optimization, estimated LLM costs, first-pass success rate, and step durations:
- **Token savings**: characters and tokens filtered out by `post-bash-output-filter.sh` before entering prompt context.
- **Cost telemetry**: estimated session and feature costs recorded by `stop-metrics.sh`.
- **Quality & stability**: first-pass tool invocation success (`pass@1`) and retry loop counts from `observe.sh`.
- **Step efficiency**: turn distribution and token intensity across pipeline stages.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- Environment and MCP diagnostics — use `devflow.doctor` instead
- Active pipeline step or branch progress — use `devflow.status` instead
- Managing learned rules or instincts — use `devflow.learn` instead

## Guards

Before executing the dashboard, verify required tools:

```bash
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not installed. Run: brew install jq"; exit 1; }
```

## Workflow

### Step 1 — Parse arguments

Identify flags from user invocation:
- `--json`: emit raw structured JSON payload (for CI or script consumers)
- `--feature <name>`: isolate metrics and turn breakdowns to a single feature

### Step 2 — Execute metrics script

Run the standalone telemetry aggregator:

```bash
PLUGIN_ROOT="$(dirname "$(dirname "$(dirname "$0")")")"
SCRIPT_PATH="$PLUGIN_ROOT/scripts/metrics.sh"
if [ ! -f "$SCRIPT_PATH" ]; then
  SCRIPT_PATH="scripts/metrics.sh"
fi

bash "$SCRIPT_PATH" "$@"
```

### Step 3 — Interpret key indicators

When presenting or inspecting dashboard numbers:
1. **Context Reduction %**: values >50% indicate bash output filter is effectively suppressing terminal noise.
2. **Cache Read Ratio**: high percentages (>40%) indicate prompt cache reuse across consecutive turns.
3. **Pass@1 Rate**: percentages >90% indicate clean tool execution with minimal command failures.
4. **Retry Loops**: any non-zero count highlights friction points in test or build commands.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Treating estimated USD costs as exact invoices | Pricing tables drift and exclude provider-specific discounts | Treat telemetry costs as relative indicators between features |
| Disabling filter telemetry | Blind to token bloat caused by verbose test outputs | Keep `.devflow-filter-stats.jsonl` active to measure filter ROI |
| Ignoring low pass@1 rates | Hidden build or test flakes slow down pipeline execution | Inspect `.devflow-observe.jsonl` to identify failing tool calls |
| Committing local metric JSONL files | Pollutes git history with developer-specific telemetry | Keep `.devflow-metrics.jsonl` and filter stats gitignored |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-filter-stats.jsonl`, `.devflow-metrics.jsonl`, `.devflow-observe.jsonl`, `.devflow-test-summary.json` |
| Executes | `@devflow/scripts/metrics.sh` |
| Related | `devflow.status`, `devflow.doctor`, `stop-metrics.sh`, `post-bash-output-filter.sh` |
