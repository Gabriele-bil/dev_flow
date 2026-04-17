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

Review and improve implementation output produced by `devflow.implement` using a **multi-axis** lens: correctness, readability and simplification, architecture, security, performance, UI consistency, and responsive layout. This is the fourth step of the DevFlow pipeline.

## When NOT to Use

- `devflow.implement` has not run for this feature — there is nothing to beautify
- The stack’s analyze/typecheck command (per active `ADAPTER.md`) still reports errors from the implement step — fix those before beautifying
- The intent is to refactor pre-existing code not touched by this DevFlow run — that is out of scope; open a separate task instead

## Input

- List of files created/modified by `devflow.implement` (from its summary)
- `devflow/features/[NNN]_[feature-name]/plan.md`
- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, use the current file modified in git

## Workflow

### Step 0 - Resolve adapter

Read `@devflow/config.md` and `@devflow/adapters/<adapter>/ADAPTER.md`. Use its **Beautify** commands and any stack-specific review axes (e.g. Flutter performance, theme, layout).

### Step 1 - Read docs

Always read before starting:

- `constitution.md`
- `registry.md`

### Step 2 - Scope

Analyze only files touched by the current `devflow.implement` run.

- Do not expand scope to unrelated files
- Do not refactor pre-existing code outside the implement summary

### Step 2b - Tests first (when present)

If the implement summary includes test files, skim them **before** deep-diving production code:

- Tests reflect intended behavior and edge cases, not brittle implementation coupling
- Missing coverage for new behavior is an **Optional** or **Nit** finding — do not block beautify on writing new tests unless the user asks (out of scope for “no new files” unless explicitly allowed)

### Step 3 - Analysis areas (multi-axis review)

The axes below are written for the **Flutter** stack (the default adapter). If `config.md` points at another adapter, follow that adapter’s `ADAPTER.md` for stack-specific axes and use these sections only where they still apply.

Review each in-scope file against **every** axis below. Collect findings across all files before applying changes.

#### Correctness

- Implementation matches `plan.md` acceptance criteria and stated behavior
- Edge cases and error paths are handled (null, empty, loading/error UI, async failure)
- State updates are consistent (no obvious races or stale UI assumptions)

#### Readability and simplification

- Naming follows Dart conventions and constitution rules; names carry intent (avoid vague `data`, `result`, `temp` without context)
- Readability is clear: avoid unnecessary nesting, overly long methods, nested ternaries when an early return or small helper reads better
- Responsibilities are separated (no domain/data logic leaking into widgets)
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

#### Security (Flutter + Supabase)

- User and external input validated or normalized at boundaries before use in logic, storage, or queries
- No secrets, tokens, or private keys committed in client code or logs
- Auth-sensitive operations align with project data-layer patterns (RLS assumptions, client usage). For deep review, load the adapter’s data/auth skill (e.g. `@devflow/adapters/flutter/skills/flutter-supabase/SKILL.md` when adapter is `flutter`)

#### Performance (heuristics — default pass)

- Missing `const` constructors are added where possible
- Provider scope is not broader than needed
- `.select()` is used when a widget reads only part of a provider state
- No expensive operations are executed inside `build()`
- Prefer lazy list construction (`ListView.builder` / slivers) for large or unbounded lists instead of eager `children: [...]` when the feature warrants it

##### Performance: measure when needed

Default beautify relies on the checks above. **Profile only when** the plan calls out performance, the UI is list-heavy or animation-heavy, or you flag a **Critical** / high-risk hotspot.

- Use **Flutter DevTools** (Performance / CPU profiler, Timeline) to confirm jank or long frames before large refactors
- Symptom hints: dropped frames, scroll lag, jank on rebuild — inspect rebuild scope (widgets, `Provider`/`Consumer` granularity), not just micro-optimizations
- Images: consider `cacheWidth` / `cacheHeight` (or project image patterns) when decoding large bitmaps in lists
- Heavy CPU work should not run synchronously in `build()`; consider isolates or existing project patterns only when measurement or plan justifies it

Do not add blanket `RepaintBoundary` / `memo`-style patterns everywhere — overuse hurts as much as underuse.

#### UI consistency

- Spacing and padding use theme values or `AppLayout`, not hardcoded numbers
- Typography uses `Theme.of(context).textTheme`, not manual `TextStyle`
- Colors use `Theme.of(context).colorScheme` or `AppColors`, not hardcoded hex
- No local `TextStyle` or `Color` overrides that duplicate theme definitions

#### Responsive layout

- All three breakpoints are handled (compact / medium / expanded) for every UI screen
- `LayoutBuilder` is used for adaptive branching, not `MediaQuery.of(context).size`
- Prefer `AppBreakpointWidth` / `AppBreakpointConstraints` (`lib/core/layout/app_breakpoints.dart`) over raw width literals

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

- Missing `const` constructors
- Hardcoded colors or text styles that have a theme equivalent
- Imports not pointing to barrel files
- Naming violations against Dart or constitution conventions
- Obvious logic leaking into the widget layer
- **Critical** issues uncovered in correctness or security (fix immediately)

#### Opinable improvements

Propose before applying:

- Structural refactors (for example extracting widgets/files)
- Provider scope changes that can affect behavior
- Subjective naming changes
- Any change that modifies public API signatures
- Simplifications where behavior preservation is not obvious

**Chesterton + incrementality:** for structural or simplification proposals, state briefly why the code might exist as-is, then the proposed change. Prefer **one logical change per proposal** (or per user approval round). If tests exist for the feature, run the adapter’s unit-test command (see `ADAPTER.md` → **Test**) with a relevant path after substantive refactors when feasible.

Use this format and wait for user response before each proposed change:

```text
💡 [Optional: Nit / Optional / Consider] Proposed improvement: [file path]
[Description of the change and why it improves the code.]
Apply? [yes / no]
```

#### Dead code (scope-limited)

After edits, check **only** implement-touched files for unused imports, unreachable branches, or clearly orphaned symbols.

- Remove directly when obviously safe (unused import, dead branch after a certain refactor you just made)
- If removal might affect callers outside the summary, list explicitly and ask: `Dead code candidates: … — remove now?`

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
- `path/to/file.dart`
- ...

### Improvements by area
- **Correctness**: [brief summary, or "no changes"]
- **Readability / simplification**: [brief summary, or "no changes"]
- **Security**: [brief summary, or "no changes"]
- **Performance**: [brief summary, or "no changes"]
- **Architecture**: [brief summary, or "no changes"]
- **UI consistency**: [brief summary, or "no changes"]
- **Responsive layout**: [brief summary, or "no changes"]

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
- [ ] Security boundaries (input, secrets, Supabase usage) sanity-checked on changed code
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
