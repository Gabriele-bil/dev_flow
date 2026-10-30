---
name: beautify
description: "Polishes devflow.implement output: readability, conventions, design tokens, layout, accessibility basics — correctness and security stay with devflow.ship. Use when user runs devflow.beautify, polishes implementation output, or fourth pipeline step."
argument-hint: "[optional-plan-path]"
disable-model-invocation: true
effort: medium
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

# Skill: devflow.beautify

## Quick Start

Run `/devflow:beautify [optional plan path]`.

- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, resolve feature with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve` (exit 1 → ask)

## Purpose

Polish `devflow.implement` output: readability/simplification, project conventions, design-token consistency, responsive layout, accessibility basics. Correctness, security and performance are `devflow.ship`'s review — not repeated here. Fourth DevFlow step; skipped in the `quick` profile.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- `devflow.implement` has not run for this feature — there is nothing to beautify
- Active adapter analyze/typecheck still has errors from `devflow.implement` — fix before beautifying
- Scope is pre-existing code not touched by this DevFlow run — open a separate task
- `plan.md` depth profile is `quick` — skip to `devflow.test` (`implemented → tested` is legal; ship's `code-reviewer` covers readability)

## Input contract

Before proceeding, verify:

- [ ] `devflow.implement` has run and its summary lists at least one file created/modified
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] Analyze clean: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify-stamp.sh" run analyze -- <adapter analyze cmd>` exits 0 (skipped while implement's stamp is fresh)

If any item fails → stop, report which check failed, do not apply changes.

## Input

Files from `devflow.implement` summary + `devflow/features/[NNN]_[feature-name]/plan.md` — if no arg, resolve feature with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve` (exit 1 → ask). Summary unavailable (new session) → `plan.md` File List `[done]` entries are the scope.

## Workflow

### Step 0 - Resolve adapter

Resolve adapter, adapter root, and app working directory per `${CLAUDE_PLUGIN_ROOT}/references/adapter-resolution.md` (reads `plan.md`'s `**App:**` field in monorepo mode). Then read `${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/ADAPTER.md` (core) plus `${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/steps/beautify.md`. Use the beautify step file's commands and stack-specific review axes (monorepo: run commands from the resolved app's working directory).

### Step 1 - Read docs

Read before starting:

- `constitution.md`
- `registry.md`

### Step 2 - Scope

Scope: only files in current `devflow.implement` summary. No scope expansion; no pre-existing code refactor.

### Step 2b - Tests first (when present)

If implement summary includes test files, skim them first — they reflect intended behavior. Missing test coverage for new behavior → **Optional** or **Nit** finding (not a blocker).

### Step 2c - Protected blocks

Skip any block wrapped in `devflow-beautify-ignore-start` / `devflow-beautify-ignore-end` markers (any comment syntax: `//`, `#`, `/* */`, `<!-- -->`, `--`). Do not raise findings inside a protected block and do not rewrite it — including for a Critical issue. If a protected block looks genuinely broken, surface it as **FYI:** naming the file and the marker's reason (if given) instead of fixing it; the user owns that code deliberately.

```js
// devflow-beautify-ignore-start: manually unrolled for perf, don't touch
result[0] = buf[0] ^ key[0];
result[1] = buf[1] ^ key[1];
// devflow-beautify-ignore-end
```

### Step 3 - Analysis areas

Beautify polishes; it does not review. Correctness, security and performance belong to `devflow.ship` (`code-reviewer`, `security-auditor`) — no axis here for them. A Critical correctness or security problem you happen to see is still fixed (Step 4), not hunted for.

Stack-specific checks: adapter beautify step file and technology skills. Review **every** in-scope file against all axes; collect all findings before applying changes.

Axes: readability/simplification · conventions (naming, imports, layering per `constitution.md`) · UI consistency · responsiveness/layout · accessibility basics (labels, alt text, focus, semantics — the full WCAG audit is ship's `accessibility-auditor`, `thorough` only).

**UI consistency source:** `DESIGN.md` (or `docs/design.md`) present in project root → axis checks token compliance (palette, typography, spacing) against it instead of generic guidelines; hardcoded value with a DESIGN.md token equivalent = Required finding. Absent → generic guidelines, zero behavior change.

**Depth profile:** read `**Complexity:**` from `plan.md` (per `${CLAUDE_PLUGIN_ROOT}/references/complexity-scoring.md`; missing → `standard`). `quick` → beautify does not run (When NOT to Use). `standard` / `thorough` → all 5 axes.

Full per-axis checklist: `references/analysis-axes.md`.

### Step 4 - Apply changes

Before applying edits: save git checkpoint tag (`git tag -f "devflow-checkpoint/$(git branch --show-current 2>/dev/null)/beautify" HEAD 2>/dev/null || true`).

#### Severity labels

Tag all findings:

| Prefix | Meaning | Action |
| -------- | --------- | -------- |
| **Critical:** | Security risk, wrong behavior vs plan, data loss risk | Must fix before treating beautify as done |
| *(none)* | Required | Fix before merge / next pipeline step |
| **Nit:** | Minor style preference | Optional |
| **Optional:** / **Consider:** | Suggestion | Worth doing; not required |
| **FYI:** | Context only | No code change required |

#### Certain improvements

Apply directly without asking:

- Deterministic low-risk style fixes defined by constitution/adapter conventions
- Hardcoded visual styles that have a design-system equivalent
- Imports violating repo import conventions
- Naming violations against project conventions
- Obvious logic leaking into the presentation layer
- **Silent catch (`silent-catch`):** empty/swallowed `catch` or `.catch()` blocks without rethrow, typed error return, or subject-specific log
- **Critical** issues uncovered in correctness or security (fix immediately)

#### Opinable improvements

**Run mode** (`.devflow-run.json` present): no approval channel exists — do not propose, do not apply. Log each opinable candidate as an entry in `plan.md` `## Decision flags` per `${CLAUDE_PLUGIN_ROOT}/references/run-mode.md` → **Decision flags** (decision: "not applied"), continue. Interactive mode below.

Propose before applying:

- Structural refactors (for example extracting components/files)
- Provider scope changes that can affect behavior
- Subjective naming changes
- Any change that modifies public API signatures
- Simplifications where behavior preservation is not obvious

**One question for all proposals:** collect every opinable proposal first, then ask once with `AskUserQuestion`, `multiSelect: true` — one question per proposal type (structural, naming, API, simplification), up to 4 questions in the one call, each option `[file] — change — why the code is as it is today` (Chesterton). Apply exactly the selected options; unselected ones are listed as skipped in the notify block. No per-proposal rounds, no stall-out loop. If tests exist for the feature, run the relevant test command after substantive refactors when feasible.

#### Dead code (scope-limited)

After edits, check **only** implement-touched files for unused imports, unreachable branches, or clearly orphaned symbols.

- Remove directly when obviously safe (unused import, dead branch after a deterministic refactor)
- If removal affects callers outside the summary, list explicitly and ask: `Dead code candidates: … — remove now?`
- **Barrel file exception:** never remove an import from a barrel/re-export file (`index.ts`, `_domain.dart`, `_data.dart`, or files matching `*_*.dart` / `*.barrel.ts`) based on local scope analysis alone — barrel imports serve external consumers outside the implement summary. List locally unused barrel imports as candidates and ask; never remove directly.

### Step 5 - Run commands

After all approved and certain changes are applied, run the **format**, **analyze/typecheck**, and conditional **codegen** commands from the adapter beautify step file, in the order specified there, each as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify-stamp.sh" run <format|analyze|codegen> -- <cmd>` (monorepo: `--cwd <app dir>`, `@<app>` suffix).

On error: resolve autonomously; max 3 attempts; then escalate per `${CLAUDE_PLUGIN_ROOT}/references/escalation-ladder.md` (debug mode → re-approach → block).

### Step 6 - Notify user

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" set plan beautified`.

**Run mode** (`.devflow-run.json` present): emit the block below but do not wait — control returns to the orchestrator (`${CLAUDE_PLUGIN_ROOT}/references/run-mode.md`).

Respond with:

```text
✅ Beautify complete: [type]/[NNN]_[feature-name]

### Files modified
- `path/to/file.ext`
- ...

### Improvements by area
- **Readability / simplification**: [brief summary, or "no changes"]
- **Conventions**: [brief summary, or "no changes"]
- **UI consistency**: [brief summary, or "no changes"]
- **Responsive layout**: [brief summary, or "no changes"]
- **Accessibility basics**: [brief summary, or "no changes"]
- **Proposals**: [N applied · N skipped — omit if none]

### Findings by severity (if any)
- **Critical**: [list or "none"]
- **Required**: [list or "none"]
- **Nit / Optional / FYI**: [short list or "none"]
- **Protected blocks skipped**: [N — omit line if 0]

### Commands run
- format (per adapter): ✅ / ❌ (resolved after [N] attempts)
- analyze/typecheck (per adapter): ✅ / ❌ (resolved after [N] attempts)
- codegen (per adapter): [yes | no]

Continue to testing? -> devflow.test
```

**Run mode** (`.devflow-run.json` present): emit the notify block but do not wait for user — control returns to the orchestrator (`devflow.run` or `devflow.auto`).

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Adding features during beautify ("while I'm here") | Log as new subtask; implement in next cycle |
| Format/analyze only on new files | Run on the full changed set |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## Completion checklist

- [ ] Scope stayed within `devflow.implement` touched files
- [ ] `plan.md` behavior and acceptance criteria were checked for obvious gaps
- [ ] Security boundaries (input, secrets, auth/data-access usage) sanity-checked on changed code
- [ ] Performance: heuristics applied; profiling only when warranted
- [ ] **Critical** and required issues fixed or explicitly escalated to the user
- [ ] Dead code in scope handled or listed for user decision
- [ ] Format and analyze/typecheck stamped pass on the final tree (`verify-stamp.sh check analyze`), or failure reported after retries
- [ ] Codegen run only when the adapter beautify step file says to and annotations changed

## I/O Reference

| | |
| --- | --- |
| Reads | files from `devflow.implement` summary |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md`, `registry.md` |
| Reads | `${CLAUDE_PLUGIN_ROOT}/references/escalation-ladder.md` (failure handling), `${CLAUDE_PLUGIN_ROOT}/references/complexity-scoring.md` (depth profile) |
| Reads (conditional) | `DESIGN.md` / `docs/design.md` — token source for UI consistency axis; `.devflow-run.json` (existence — run-mode switch, contract `${CLAUDE_PLUGIN_ROOT}/references/run-mode.md`); `references/anti-patterns.md` (when unsure / retry) |
| Writes | improvements to existing files only (no new files) |
| Writes | `plan.md` — `**Status:** beautified`, `## Decision flags` (run mode — opinable candidates) |
| Next step | `devflow.test` |
| Reads (adapter) | `${CLAUDE_PLUGIN_ROOT}/references/adapter-resolution.md`, `${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/ADAPTER.md` (core) + `steps/beautify.md` |
| Related skills | Per active `ADAPTER.md` → **Technology skills** |
