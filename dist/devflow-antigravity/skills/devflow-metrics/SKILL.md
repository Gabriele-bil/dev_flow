---
name: devflow-metrics
description: Display the local telemetry dashboard — token savings, estimated cost per feature, command durations (which pipeline step takes longest), context-window use and compactions, context injected by devflow hooks, tool/skill/subagent usage, pass@1. Use when inspecting pipeline metrics, token or context consumption, step timing, plugin usage, or running devflow.metrics.
argument-hint: "[--json] [--feature <name>] [--since <YYYY-MM-DD>]"
---


# Skill: devflow.metrics

**Arguments:** `$ARGUMENTS` — empty → show the dashboard for all features.

## Purpose

Aggregate and visualize the local telemetry folder `.devflow-metrics/` (gitignored, written by hooks, never leaves the machine) — the evidence base for improving the plugin:

- **Token savings**: characters and tokens filtered out by `post-bash-output-filter.sh` before entering prompt context.
- **Cost telemetry**: tokens (input, output, cache write/read, thinking) and estimated cost per feature, step, model.
- **Commands**: per devflow command — turns, avg/p50/p90 duration, tokens and context per turn, tool calls, compactions, subagent cost.
- **Context & memory**: context window in use per turn (avg/peak), prompt-cache reads, compactions (auto vs manual, context size at compaction), tokens injected by each devflow hook (orientation, instincts).
- **Tools**: calls, error %, avg duration, output tokens fed back per tool; skills loaded, MCP servers, subagent runs.
- **Usage**: sessions by source/host/plugin version/model/adapter, prompts, share of slash commands, devflow commands typed.
- **Quality & stability**: first-pass tool invocation success (`pass@1`), retry loop counts, re-reads of the same file, checks run outside `verify-stamp.sh`, and tool calls per pipeline step, from `observe.sh`.

File-by-file schema: `references/telemetry-schema.md`.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

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

- `--json`: emit raw structured JSON payload (for CI, script consumers, or comparing plugin versions)
- `--feature <name>`: isolate metrics and turn breakdowns to a single feature
- `--since <YYYY-MM-DD>`: only rows from that date on (before/after a skill change)

### Step 2 — Execute metrics script

Run the standalone telemetry aggregator:

```bash
bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/metrics.sh" $ARGUMENTS
```

### Step 3 — Interpret key indicators

When presenting or inspecting dashboard numbers:

1. **Context Reduction %**: values >50% indicate bash output filter is effectively suppressing terminal noise.
2. **Cache Read Ratio**: high percentages (>40%) indicate prompt cache reuse across consecutive turns.
3. **Pass@1 Rate**: percentages >90% indicate clean tool execution with minimal command failures.
4. **Retry Loops**: any non-zero count highlights friction points in test or build commands.
5. **Context per turn / compactions**: a command whose avg context approaches the window, or frequent auto-compactions, is loading too much — candidate for on-demand references or subagent fan-out.
6. **Injected by hooks**: tokens devflow adds to every session before any work; growth here is a fixed cost on every turn.
7. **Tool output tokens / error %**: tools that flood context or fail often point at missing filters or unclear skill instructions.
8. **Command p90 duration**: long tails on one command show where the pipeline stalls.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Treating estimated USD costs as exact invoices | Pricing tables drift and exclude provider-specific discounts | Treat telemetry costs as relative indicators between features |
| Ignoring low pass@1 rates | Hidden build or test flakes slow down pipeline execution | Inspect `.devflow-observe.jsonl` to identify failing tool calls |
| Committing local metric JSONL files | Pollutes git history with developer-specific telemetry | Keep `.devflow-metrics/` gitignored (init/setup add it) |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-metrics/` (`turns`, `timings`, `tools`, `context`, `sessions`, `prompts`, `subagents`, `filter-stats`, `model-switch` `.jsonl`), `.devflow-observe.jsonl`, `.devflow-learnings.jsonl`, `.devflow-test-summary.json` |
| Executes | `$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/metrics.sh` |
| Related | `devflow.status`, `devflow.doctor`, `stop-metrics.sh`, `metrics-collect.sh`, `observe.sh`, `post-bash-output-filter.sh`, `references/telemetry-schema.md` |
