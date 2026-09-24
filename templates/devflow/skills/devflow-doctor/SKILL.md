---
name: devflow-doctor
description: Pre-flight diagnostic tool for DevFlow. Checks MCP server reachability, CLI toolchains, active adapter configuration, and pipeline state integrity. Supports --json and --fix. Use when user runs devflow.doctor, asks to diagnose the environment, check MCP servers, or troubleshoot pipeline prerequisites.
argument-hint: [--json] [--fix]
disable-model-invocation: true
---

# Skill: devflow.doctor

Pre-flight diagnostic health check for DevFlow. Assesses environment readiness across MCP servers, CLI toolchains, project configuration, and pipeline state.

## Purpose

Validate that the consumer environment satisfies all DevFlow operational prerequisites before or during pipeline execution. Detects absent MCP servers, missing compilers/linters, and corrupted pipeline state, providing immediate remediation instructions.

## Core Principles

- **zero-hard-dependency** — all MCP absences degrade cleanly to CLI fallback; doctor identifies degradation levels without blocking progress unless a critical tool is missing
- **actionable-remediation** — every detected warning or failure must be accompanied by an exact copy-paste command or config snippet
- **idempotent-and-safe** — diagnostic inspections never mutate workspace state unless explicit `--fix` flag is supplied
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- User wants to resume an interrupted feature — use `devflow.resume`
- User wants to diagnose a failing test or pipeline step — use `devflow.recovery` or `devflow.backprop`

## Workflow

### Step 1 - Parse Arguments

Inspect `$ARGUMENTS`:

- If `--json` is present: run `bash templates/devflow/scripts/doctor.sh --json` directly and emit only the raw JSON payload with its exit code. Stop here.
- If `--fix` is present: pass `--fix` to the diagnostic script to automatically repair safe runtime files (e.g. `.gitignore`, resetting corrupted `.devflow-state.json`).

### Step 2 - Execute Environment Diagnostics

Run `bash templates/devflow/scripts/doctor.sh` and capture its structured report across the 4 core inspection axes:

1. **MCP Baseline Verification**:
   - Universal baseline: `context7`, `sequential-thinking`, code index (`serena` / LSP).
   - Stack-specific core: `dart` (Flutter), `angular-cli` + `playwright` (Angular), `next-devtools` + `playwright` (Next.js), `openapi` (NestJS).
   - Conditional infrastructure: `supabase`, `postgres`, `sentry` (checked against project dependencies).
2. **CLI Toolchain Availability**:
   - Universal binaries: `git`, `gh`, `jq`.
   - Active adapter binaries: `flutter`/`dart`, `node`/`pnpm`/`npm`/`ng`/`nest`.
3. **Pipeline & State Integrity**:
   - `config.md` validity and adapter resolution.
   - `.devflow-state.json` syntax and active feature synchronization.
   - Git working tree status (clean vs dirty) and active branch.
   - Project instincts count in `.devflow-instincts.yaml`.

### Step 3 - Present Diagnostic Dashboard

Emit the human-readable dashboard with severity indicators:

- `✓ [OK]`: Prerequisite fully met.
- `⚠ [DEGRADED]`: MCP or optional tool absent; pipeline functions using native CLI fallbacks.
- `✗ [CRITICAL]`: Required compiler/CLI or valid git state missing; execution blocked.

### Step 4 - Provide Remediation Plan

If any warnings or errors are found:

- Display specific copy-paste terminal commands to install missing binaries.
- Output ready-to-copy MCP configuration blocks for the detected client (Antigravity `mcp_config.json`, Claude Code `.mcp.json`, or Cursor).
- Suggest running `devflow.setup --mcp` to automatically configure MCP servers for the project.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Treating absent MCP servers as fatal errors | Mark as `DEGRADED (CLI fallback active)`; DevFlow is designed to degrade cleanly. |
| Mutating files during diagnostic check without `--fix` | Read-only inspection by default; require explicit `--fix` flag for automatic repairs. |
| Emitting vague error messages like "CLI missing" | Provide exact binary name, package manager install command, and documentation link. |

## I/O Reference

| | |
| --- | --- |
| Reads | Client MCP configs (`mcp_config.json`, `.mcp.json`, `~/.claude.json`), project `config.md`, `.devflow-state.json`, `.devflow-instincts.yaml`, system `PATH` |
| Writes | None (or non-destructive repairs to `.devflow-state.json` and `.gitignore` when `--fix` passed) |
| Next step | If healthy: proceed to current pipeline step (`devflow.task`, `devflow.implement`, etc.). If degraded: apply recommended MCP configurations. |
