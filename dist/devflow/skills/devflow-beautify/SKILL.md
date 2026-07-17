---
name: devflow-beautify
description: Reviews devflow.implement output: correctness, readability, security, performance, architecture, UI. Use when user runs devflow.beautify, reviews implementation output, or fourth pipeline step.
argument-hint: [optional-plan-path]
disable-model-invocation: true
---

# Skill: devflow.beautify

## Quick Start

Run `/devflow.beautify [optional plan path]`.

- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, use the current file modified in git

## Purpose

Review/improve `devflow.implement` output with **multi-axis** lens: correctness, readability/simplification, architecture, security, performance, UI consistency, responsive layout. Fourth DevFlow step.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- `devflow.implement` has not run for this feature — there is nothing to beautify
- Active adapter analyze/typecheck still has errors from `devflow.implement` — fix before beautifying
- Scope is pre-existing code not touched by this DevFlow run — open a separate task

## Input contract

Before proceeding, verify:

- [ ] `devflow.implement` has run and its summary lists at least one file created/modified
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] Active adapter analyze/typecheck reports no unresolved errors

If any item fails → stop, report which check failed, do not apply changes.

## Input

Files from `devflow.implement` summary + `devflow/features/[NNN]_[feature-name]/plan.md` — if no arg, use current git-modified file.

## Workflow

### Step 0 - Resolve adapter

Read `@devflow/config.md` and `@devflow/adapters/<adapter>/ADAPTER.md`. Use its **Beautify** commands and stack-specific review axes.

### Step 1 - Read docs

Read before starting:

- `constitution.md`
- `registry.md`

### Step 2 - Scope

Scope: only files in current `devflow.implement` summary. No scope expansion; no pre-existing code refactor.

### Step 2b - Tests first (when present)

If implement summary includes test files, skim them first — they reflect intended behavior. Missing test coverage for new behavior → **Optional** or **Nit** finding (not a blocker).

### Step 3 - Analysis areas (multi-axis review)

Stack-agnostic defaults below. For stack-specific checks follow `ADAPTER.md` and technology skills. Review **every** in-scope file against all axes; collect all findings before applying changes.

Axes: correctness · readability/simplification · architecture compliance · security · performance · UI consistency · responsiveness/layout · accessibility.

**UI consistency source:** `DESIGN.md` (or `docs/design.md`) present in project root → axis checks token compliance (palette, typography, spacing) against it instead of generic guidelines; hardcoded value with a DESIGN.md token equivalent = Required finding. Absent → generic guidelines, zero behavior change.

**Depth profile:** read `**Complexity:**` from `plan.md` (per `@devflow/references/complexity-scoring.md`; missing → `standard`). `quick` → review only correctness + readability/simplification axes. `standard` / `thorough` → all 8 axes.

Full per-axis checklist: `references/analysis-axes.md`.

### Step 4 - Apply changes

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
- **Critical** issues uncovered in correctness or security (fix immediately)

#### Opinable improvements

**Run mode** (`.devflow-run.json` present): no approval channel exists — do not propose, do not apply. Log each opinable candidate as an entry in `plan.md` `## Decision flags` per `@devflow/skills/devflow-run/SKILL.md` Step 2 (decision: "not applied"), continue. Interactive mode below.

Propose before applying:

- Structural refactors (for example extracting components/files)
- Provider scope changes that can affect behavior
- Subjective naming changes
- Any change that modifies public API signatures
- Simplifications where behavior preservation is not obvious

**Proposal grouping:** group proposals by type before presenting them. Same-type proposals (all naming changes together, all structural refactors together, all extract-component proposals together) share one approval request. Different types each get their own request.

**Stall-out rule:** after 3 consecutive proposal rounds with no user approval on any item, stop proposing and emit:

```text
⚠️ Beautify stalled: [N] proposals pending without approval.
Options: (1) approve all remaining, (2) skip all remaining, (3) continue one by one
```

Wait for user choice before continuing.

**Chesterton + incrementality:** for structural or simplification proposals, state briefly why the code might exist as-is, then the proposed change. If tests exist for the feature, run adapter test commands relevant to touched scope after substantive refactors when feasible.

Use this format and wait for user response before each grouped proposal round:

```text
💡 [Optional: Nit / Optional / Consider] Proposed improvement: [file path]
[Description of the change and why it improves the code.]
Apply? [yes / no]
```

#### Dead code (scope-limited)

After edits, check **only** implement-touched files for unused imports, unreachable branches, or clearly orphaned symbols.

- Remove directly when obviously safe (unused import, dead branch after a certain refactor you just made)
- If removal might affect callers outside the summary, list explicitly and ask: `Dead code candidates: … — remove now?`
- **Barrel file exception:** never remove an import from a barrel/re-export file (`index.ts`, `_domain.dart`, `_data.dart`, or files matching `*_*.dart` / `*.barrel.ts`) based on local scope analysis alone — barrel imports serve external consumers that are outside the implement summary. If a barrel import looks unused locally, list it as a candidate and ask; do not remove directly.

### Step 5 - Run commands

After all approved and certain changes are applied, run the **format**, **analyze/typecheck**, and conditional **codegen** commands from `ADAPTER.md` → **Beautify**, in the order specified there.

On error: resolve autonomously; max 3 attempts; then escalate per `@devflow/references/escalation-ladder.md` (debug mode → re-approach → block).

### Step 6 - Notify user

Set `plan.md` `**Status:** beautified`; refresh `.devflow-state.json` per `@devflow/references/state-machine.md` → **State update snippet**.

**Run mode** (`.devflow-run.json` present): emit the block below but do not wait — control returns to `devflow.run`.

Respond with:

```text
✅ Beautify complete: feature/[NNN]-[feature-name]

### Files modified
- `path/to/file.ext`
- ...

### Improvements by area
[`quick` profile: mark unreviewed axes as "skipped (quick profile)"]
- **Correctness**: [brief summary, or "no changes"]
- **Readability / simplification**: [brief summary, or "no changes"]
- **Security**: [brief summary, or "no changes"]
- **Performance**: [brief summary, or "no changes"]
- **Architecture**: [brief summary, or "no changes"]
- **UI consistency**: [brief summary, or "no changes"]
- **Responsive layout**: [brief summary, or "no changes"]
- **Accessibility**: [brief summary, or "no changes"]

### Findings by severity (if any)
- **Critical**: [list or "none"]
- **Required**: [list or "none"]
- **Nit / Optional / FYI**: [short list or "none"]

### Commands run
- format (per adapter): ✅ / ❌ (resolved after [N] attempts)
- analyze/typecheck (per adapter): ✅ / ❌ (resolved after [N] attempts)
- codegen (per adapter): [yes | no]

Continue to testing? -> devflow.test
```

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Expanding scope beyond `devflow.implement` summary | Limit strictly to the implement summary |
| Adding features during beautify ("while I'm here") | Log as new subtask; implement in next cycle |
| Skipping security axis ("already reviewed") | Run all axes the depth profile requires; `quick` never applies to security-touching features (profile floor) |
| Format/analyze only on new files | Run on the full changed set |
| Treating Nit as mandatory | Fix Critical/Required; user decides Nit/Optional |
| Applying opinable improvements while run mode active | Certain improvements only; opinable candidates → `## Decision flags`, not applied |
| Flagging hardcoded style as Nit when DESIGN.md defines a token | Token equivalent exists → Required finding |
| Profiling without confirmed bottleneck | Apply heuristics only; profile when benchmark confirms |

## Completion checklist

- [ ] Scope stayed within `devflow.implement` touched files
- [ ] `plan.md` behavior and acceptance criteria were checked for obvious gaps
- [ ] Security boundaries (input, secrets, auth/data-access usage) sanity-checked on changed code
- [ ] Performance: heuristics applied; profiling only when warranted
- [ ] **Critical** and required issues fixed or explicitly escalated to the user
- [ ] Dead code in scope handled or listed for user decision
- [ ] Format and analyze/typecheck from `ADAPTER.md` completed (or failure reported after retries)
- [ ] Codegen run only when `ADAPTER.md` says to and annotations changed

## I/O Reference

| | |
| --- | --- |
| Reads | files from `devflow.implement` summary |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md`, `registry.md` |
| Reads | `@devflow/references/escalation-ladder.md` (failure handling), `@devflow/references/state-machine.md` (status), `@devflow/references/complexity-scoring.md` (depth profile) |
| Reads (conditional) | `DESIGN.md` / `docs/design.md` — token source for UI consistency axis; `.devflow-run.json` (existence — run-mode switch) |
| Writes | improvements to existing files only (no new files) |
| Writes | `plan.md` — `**Status:** beautified`, `## Decision flags` (run mode — opinable candidates) |
| Next step | `devflow.test` |
| Reads (adapter) | `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Related skills | Per active `ADAPTER.md` → **Technology skills** |
