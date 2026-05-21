---
name: devflow-beautify
description: Reviews and improves devflow.implement output across correctness, readability, security, performance, architecture compliance, and UI consistency. Use when the user asks to run devflow.beautify, review implementation output, or execute the fourth step of the DevFlow pipeline.
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
- The stack’s analyze/typecheck command (per active `ADAPTER.md`) still reports errors from the implement step — fix those before beautifying
- The intent is to refactor pre-existing code not touched by this DevFlow run — that is out of scope; open a separate task instead

## Input contract

Before proceeding, verify:

- [ ] `devflow.implement` has run and its summary lists at least one file created/modified
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] Active adapter analyze/typecheck reports no unresolved errors

If any item fails → stop, report which check failed, do not apply changes.

## Input

- List of files created/modified by `devflow.implement` (from its summary)
- `devflow/features/[NNN]_[feature-name]/plan.md`
- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, use the current file modified in git

## Workflow

### Step 0 - Resolve adapter

Read `@devflow/config.md` and `@devflow/adapters/<adapter>/ADAPTER.md`. Use its **Beautify** commands and stack-specific review axes.

### Step 1 - Read docs

Always read before starting:

- `constitution.md`
- `registry.md`

### Step 2 - Scope

Analyze only files touched by current `devflow.implement` run.

- Do not expand scope to unrelated files
- Do not refactor pre-existing code outside the implement summary

### Step 2b - Tests first (when present)

If the implement summary includes test files, skim them **before** deep-diving production code:

- Tests reflect intended behavior and edge cases, not brittle implementation coupling
- Missing coverage for new behavior is an **Optional** or **Nit** finding — do not block beautify on writing new tests unless the user asks (out of scope for “no new files” unless explicitly allowed)

### Step 3 - Analysis areas (multi-axis review)

The axes below are stack-agnostic defaults. For stack-specific checks, follow the active adapter `ADAPTER.md` and any technology skills it requires.

Review each in-scope file against **every** axis below. Collect findings across all files before applying changes.

#### Correctness

- Implementation matches each acceptance criterion listed in `task.md` **Acceptance criteria** section (not just plan.md behavior)
- Edge cases and error paths are handled (null, empty, loading/error UI, async failure)
- State updates are consistent (no obvious races or stale UI assumptions)

#### Readability and simplification

- Naming follows project conventions and constitution rules; names carry intent (avoid vague `data`, `result`, `temp` without context)
- Readability is clear: avoid unnecessary nesting, overly long methods, nested ternaries when an early return or small helper reads better
- Responsibilities are separated (no domain/data logic leaking into presentation components)
- **Preserve behavior:** simplifications must not change outputs, errors, side effects, or ordering. If unsure, treat as opinionated and propose first
- **Chesterton’s fence:** before removing or inlining code, understand why it exists (performance, platform constraint, history). If unclear, propose rather than delete
- Duplication: repeated blocks that should share a helper per `registry.md` patterns (optional extraction if it touches public API — propose first)
- Abstractions should earn their complexity; avoid speculative generalization

#### Architecture compliance

- Imports are relative and point to the nearest barrel file
- No feature imports another feature directly
- Implemented patterns match `registry.md`
- File placement respects `constitution.md`
- Dependencies flow in the right direction (no new circular patterns)

#### Security

- User and external input validated or normalized at boundaries before use in logic, storage, or queries
- No secrets, tokens, or private keys committed in client code or logs
- Auth-sensitive operations align with project data-layer patterns. For deep review, load adapter data/auth skill from `ADAPTER.md`.
- Full checklist: `@devflow/references/security-checklist.md`

#### Performance (heuristics - default pass)

- Avoid unnecessary object recreation in hot paths where immutable/static alternatives exist
- Reactive subscriptions are not broader than needed
- Expensive operations are not executed in render loops or high-frequency callbacks
- Prefer lazy/streamed collection rendering over eager full rendering for large or unbounded datasets when applicable

##### Performance: measure when needed

Default beautify relies on the checks above. **Profile only when** the plan calls out performance or you flag a **Critical** / high-risk hotspot.

- Use profiling tools defined by the active adapter before large refactors
- Investigate user-visible latency/jank by checking render/update scope before micro-optimizations
- Heavy CPU work should not run on critical UI/request paths when adapter guidance suggests background/off-main execution

Do not add blanket memoization or rendering boundaries everywhere - overuse hurts as much as underuse.

#### UI consistency

- Spacing and padding use design-system tokens/theme values, not arbitrary literals
- Typography uses shared style tokens, not repeated local style objects
- Colors use semantic theme tokens/palette entries, not hardcoded values
- Avoid local style overrides that duplicate global design-system definitions

#### Responsiveness and layout

- Required breakpoints/form factors are handled for each affected UI view
- Adaptive branching follows adapter conventions
- Avoid raw viewport/layout literals when shared breakpoint tokens exist

#### Accessibility

- Interactive elements have descriptive labels (button text, icon semantics, ARIA roles)
- Custom interactive widgets expose accessibility metadata per adapter conventions (see active `ADAPTER.md`)
- Color-only communication has a non-color fallback
- Focus traversal order is logical for keyboard and assistive-technology navigation
- Modal/overlay components manage focus correctly (trap on open, restore on close)

For stack-specific checks, follow **Beautify: accessibility** section of active `ADAPTER.md`.
Full checklist: `@devflow/references/accessibility-checklist.md`

### Step 4 - Apply changes

#### Severity labels

Tag every finding (including in the completion summary) so the user knows what blocks progress:

| Prefix | Meaning | Action |
|--------|---------|--------|
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

If errors occur:

- Resolve autonomously
- Retry up to 3 attempts per command
- If still failing after 3 attempts, stop and report full output to the user

### Step 6 - Notify user

After completion, respond with:

```text
✅ Beautify complete: feature/[NNN]-[feature-name]

### Files modified
- `path/to/file.ext`
- ...

### Improvements by area
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

## Completion checklist

Before sending Step 6:

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
|---|---|
| Reads | files from `devflow.implement` summary |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md`, `registry.md` |
| Writes | improvements to existing files only (no new files) |
| Next step | `devflow.test` |
| Reads (adapter) | `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Related skills | Per active `ADAPTER.md` → **Technology skills** |
