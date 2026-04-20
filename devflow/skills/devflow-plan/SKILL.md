---
name: devflow-plan
description: Transforms a structured DevFlow task into a detailed, file-oriented implementation plan for devflow.implement. Use when the user asks to run devflow.plan, create a planning artifact from devflow task output, or produce plan.md for a DevFlow feature.
argument-hint: [optional-task-path]
disable-model-invocation: true
---

# Skill: devflow.plan

## Quick Start

Run `/devflow.plan [optional task path]`.

- If an argument is passed, use it as the `task.md` path
- If no argument is passed, resolve the latest `devflow/features/*/task.md`
- Produce `plan.md` in the same feature directory

## Purpose

Turn structured task into detailed implementation plan. Read required docs, output file-oriented plan for `devflow.implement`. Second DevFlow step.

## Planning discipline (read-only until `plan.md` is written)

Until `plan.md` is complete and saved:

- **Do not** modify application code, tests, or assets except for read-only inspection.
- **Do** read `task.md`, `constitution.md`, `registry.md`, relevant sources, and MCP docs as needed.

Deliverable is **`plan.md`**, not implementation.

## Vertical slicing (guidance)

`task.md` subtasks stay outcome-level (see `devflow-task`). When subtasks read like **horizontal layers** (all data, then all UI), state in **Overview** how implementation should proceed in **vertical slices** (one end-to-end user-visible increment at a time) if that improves integrability. Do **not** rewrite subtask wording. The **Traceability** table must still map **each original subtask** to file path(s).

## Dependency ordering (reflect in File List)

Order the **File list** bottom-up per `constitution.md` **and** the active adapter’s `@devflow/adapters/<adapter>/ADAPTER.md` (section **Plan: extra sections → Dependency ordering** when present). If the two differ, prefer `constitution.md` for repo-specific layout and use the adapter for stack tooling (codegen, i18n, data layer).

If order must deviate for a vertical slice, note the exception in **Architecture decisions**.

## When NOT to Use

- No `task.md` exists for the feature — run `devflow.task` first
- The `task.md` is still in `draft` status with unresolved questions — finalize the task first
- A `plan.md` already exists with status `ready` and no task subtasks have changed — re-run only if the plan needs updating

## Input

- `devflow/features/[NNN]_[feature-name]/task.md`
- If no path is provided, read `devflow/features/[last_feature]/task.md` from the most recent feature directory.

Feature numbering convention:

- Feature IDs are strictly incremental and unique across `devflow/features/`.
- Never create or reference a new feature directory reusing an existing `[NNN]_` prefix.
- The correct next feature number is always the next available 3-digit value after the highest existing prefix.

Example:

- Existing directories: `001_login`, `002_profile`, `004_notifications`
- Next feature number is `005`.

## Workflow

### Step 0 - Resolve adapter

1. Read `@devflow/config.md` and note the **Adapter** id and **Adapter root**.
2. Read `@devflow/adapters/<adapter>/ADAPTER.md` in full. Treat it as authoritative for: which technology skills to load, MCP usage, extra `plan.md` sections/templates, localization rules, and stack-specific analysis bullets.

### Step 1 - Read docs

Always read:

- `constitution.md` (architecture rules, conventions, stack)
- `registry.md` (existing patterns and shared utilities)

Then apply the **Technology skills** table in the active `ADAPTER.md`: load each listed `@devflow/adapters/.../SKILL.md` when its trigger matches the feature (DB, UI, forms, etc.).

### Step 2 - MCP usage

Follow the **MCP** section of the active `ADAPTER.md` (tooling order and when to add optional servers).

### Step 3 - Analysis

Before writing the plan, analyze:

- Which subtasks in `task.md` require new files vs existing file changes
- All bullets under **Plan** / **Implement** / **Test** in `ADAPTER.md` that apply to this feature (state management, UI, DB, i18n, responsive layout, etc.) — use `registry.md` and `constitution.md` to ground them
- Edge cases and error states that must be handled
- Any required database or external-system edits called out by the adapter

### Step 3b - Dependency pass

Re-check the planned **File list** order against **Dependency ordering** above. Migrations and shared contracts must precede consumers unless an exception is documented under **Architecture decisions**.

### Step 4 - Write plan file

Create `devflow/features/[NNN]_[feature-name]/plan.md` with this format:

```markdown
# Plan - [Feature Name]

**ID:** PLAN-[NNN]
**Task:** [link to task.md]
**Date:** [YYYY-MM-DD]
**Status:** ready

---

## Overview

[3-5 sentences. What this feature does, how it fits the architecture,
and any non-obvious implementation decisions. If subtasks are layer-shaped,
state the vertical-slice execution order here.]

---

## Architecture decisions

- **[Decision title]**: [One-line rationale.]
- [2-5 bullets total; omit only if truly trivial]

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk] | High / Med / Low | [Concrete mitigation] |

[Use 2-4 rows for non-trivial work; one row acceptable for small plans.]

---

## Open questions

[Omit this entire section if `task.md` is `ready` and there are no planning blockers.]

- [ ] [Question — resolve before `devflow.implement` or update `task.md`.]

---

## Traceability

| Subtask | File(s) |
|---------|---------|
| [Subtask description from task.md] | [file path(s)] |
| ... | ... |

---

## File List

Ordered by implementation sequence. Each file must be implemented
in this order to respect dependencies.

**Batch hints (optional):** Before the first `###` of a dependency group, add one line:
`**Batch:** S | M | L` (S ≈ 1-2 files, M ≈ 3-5, L ≈ 6+). For `L`, add `— split across `devflow.implement` sessions if needed`.

### [NNN]. `[path/to/file.dart]` - [create | modify]
[1-2 sentences on what this file contains and why it exists.]

### [NNN]. `[path/to/file.dart]` - [create | modify]
...

---

## Implementation checkpoints

[For trivial 1-2 file plans, omit this section or use a single checkpoint.]

- **After [milestone / batch]:** use verification commands from `ADAPTER.md` (e.g. analyze / test); add short manual smoke if relevant
- [2-4 checkpoints for larger plans]

---

## Adapter-specific sections

After **Implementation checkpoints**, append **every extra plan section** required by the active `ADAPTER.md` (see its heading **Plan: extra sections and templates**). Use the exact headings and table formats from that file — e.g. for `flutter`, include **Riverpod Providers**, **Widget Tree** (if UI), **Supabase Schema** (if DB). Omit adapter sections only when `ADAPTER.md` says they do not apply.

---

## Edge Cases & Error Handling

- **[Scenario]**: [how it is handled]
- **[Scenario]**: [how it is handled]

---

## Pre-implement checklist

- [ ] Every `task.md` subtask appears in **Traceability**
- [ ] **File list** order respects **Dependency ordering** (and any stated exceptions)
- [ ] All **adapter-specific sections** from `ADAPTER.md` are present or correctly omitted per adapter rules (e.g. i18n keys for UI)
- [ ] **Implementation checkpoints** are actionable (commands per `ADAPTER.md` — analyze / tests / smoke)
- [ ] **Open questions** are empty or resolved if **Status** is `ready`
```

Format rules:

- File list is the core of the plan; it must be complete and ordered
- Traceability maps every subtask in `task.md` to at least one file
- Adapter-specific sections: follow formatting rules in `ADAPTER.md` (e.g. widget tree as indented list, not a diagram; DB sections only when applicable; localization per adapter)
- Language: English
- Style: concise and optimized for LLM consumption (no filler)
- Compression: caveman-compress style — drop articles/filler/hedging; fragments OK; keep technical terms, paths, commands exact.

### Step 5 - Notify user

After writing the file, respond with:

```text
✅ Plan created: devflow/features/[NNN]_[feature-name]/plan.md

[Feature summary in 1-2 lines]
[N] files to create, [M] files to modify

Continue to implementation? -> devflow.implement
```

## Parallelization (multi-session / multi-agent)

- **Usually sequential:** Supabase migrations, shared Riverpod surface changes, router redirects with wide blast radius.
- **Often parallelizable once contracts exist:** Focused widget tests, copy-only `slang` updates, isolated components that do not change shared providers or routes.
- **Rule:** Lock shared types, route names, and provider signatures first; then parallelize leaf work.

## Red flags

| Symptom | Why it fails |
|---------|----------------|
| Missing **Traceability** row for a subtask | `devflow.implement` cannot prove coverage |
| **File list** out of dependency order (e.g. UI before migrations) | Broken or misleading implementation order |
| UI without planned **slang** keys | Violates project conventions |
| **Supabase** omitted when the feature mutates schema or RLS | Schema / security drift |
| **Status `ready`** with unresolved **Open questions** | Implements guesses |
| No **Implementation checkpoints** on long file lists | Hard to verify incrementally |

## I/O Reference

| | |
|---|---|
| Reads | `devflow/features/[NNN]_[feature-name]/task.md` |
| Reads | `constitution.md`, `registry.md` |
| Reads (adapter) | `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md`; technology skills per ADAPTER table |
| Writes | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Next step | `devflow.implement` |
| Related skills | Per active `ADAPTER.md` → **Technology skills** (e.g. `flutter-*` under `adapters/flutter/skills/`) |
