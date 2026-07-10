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

Until `plan.md` written and saved: no code/test/asset changes. Read `task.md`, `constitution.md`, `registry.md`, sources, MCP docs as needed.

Deliverable: `plan.md` only.

## Vertical slicing (mandatory for plans with > 5 files)

For plans >5 files: define ≥2 vertical slice increments in **Architecture decisions** — each slice is one end-to-end user-visible increment (not a layer). Group **File List** entries under slice headings.

Example in Architecture decisions:

```text
- **Slice 1 — data contract + shell**: DB migration + domain model + empty UI scaffold; compiles and renders blank screen
- **Slice 2 — state + data flow**: provider + repository impl + loading/error states wired to UI
- **Slice 3 — full UI + i18n**: complete widget tree + localization keys + responsive layout
```

For plans with 5 or fewer files, slicing is optional — note in Overview if sequential layer ordering is clearer. Do **not** rewrite subtask wording. The **Traceability** table must still map **each original subtask** to file path(s).

## Dependency ordering (reflect in File List)

Order **File list** bottom-up per `constitution.md` and `ADAPTER.md` → **Dependency ordering**. `constitution.md` wins for layout; adapter wins for stack tooling. Deviations for vertical slices → note in **Architecture decisions**.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **reuse-first** — always check `registry.md` and shared folders before planning new components; reuse or extend over duplicate
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- No `task.md` exists for the feature — run `devflow.task` first
- The `task.md` is still in `draft` status with unresolved questions — finalize the task first
- A `plan.md` already exists with status `ready` and no task subtasks have changed — re-run only if the plan needs updating

## Input contract

Before proceeding, verify:

- [ ] `task.md` exists at `devflow/features/[NNN]_[feature-name]/task.md`
- [ ] `task.md` has non-empty `## Summary` and `## Subtasks` sections
- [ ] `task.md` Status is `draft` (no `[NEEDS CLARIFICATION: ...]` markers) or `clarified` — if unresolved markers exist → stop, suggest `devflow.clarify`

If any item fails → stop, report which check failed, do not write `plan.md`.

## Input

Path: `devflow/features/[NNN]_[feature-name]/task.md` — if no arg, resolve latest.

Feature numbering: IDs strictly incremental; never reuse prefix. Next = highest existing + 1.

## Workflow

### Step 0 - Resolve adapter

1. Read `@devflow/config.md` — note Adapter id and root.
2. Read `@devflow/adapters/<adapter>/ADAPTER.md` in full (authoritative for: technology skills, MCP, extra sections, localization, stack analysis).

### Step 0b - Constitution Gate

Before Step 1:

1. Read `constitution.md` in full.
2. Extract each `MUST` / `MUST NOT` rule.
3. Evaluate each against the planned approach.
4. Violation → **Constitution Violation Report**:

| Rule | Violation | Required Fix |
|------|-----------|--------------|
| ...  | ...       | ...          |

**Severity:**

- **Critical violations** → stop before Step 1.
- **Required violations** → document in Open questions; stop before Step 5 (Write plan file).

### Step 1 - Read docs

Always read:

- `constitution.md` (architecture rules, conventions, stack)
- `registry.md` (existing patterns and shared utilities)
- `@devflow/adapters/common/skills/common-clean-code/SKILL.md` (clean code, SOLID rules)

Then apply the **Technology skills** table in the active `ADAPTER.md`: load each listed `@devflow/adapters/.../SKILL.md` when its trigger matches the feature (DB, UI, forms, etc.).

### Step 2 - MCP usage

Follow the **MCP** section of the active `ADAPTER.md` (tooling order and when to add optional servers).

### Step 3 - Reuse audit (mandatory before analysis)

Before planning any file:

1. **Read `registry.md`** in full — note every shared component, widget, utility, and pattern relevant to this feature.
2. **Scan the project's shared folder** (e.g. `lib/shared/`, `src/shared/`, `components/shared/`) — list components that partially or fully cover any UI need in this feature.
3. **Decide for each candidate:** reuse as-is / extend / parameterise / create new. Document the decision under **Architecture decisions** in `plan.md`.
4. **Plan new shared components:** if this feature introduces a UI pattern generic enough for reuse elsewhere, list it under its shared path in the **File List** from the start — not as an afterthought.

> **Rule:** New component only when no shared one covers ≥70% of the need; extend first.

### Step 4 - Analysis

Analyze:

- Which subtasks in `task.md` require new files vs existing file changes
- All bullets under **Plan** / **Implement** / **Test** in `ADAPTER.md` that apply to this feature (state management, UI, DB, i18n, responsive layout, etc.) — use `registry.md` and `constitution.md` to ground them
- Edge cases and error states that must be handled
- Any required database or external-system edits called out by the adapter

### Step 4b - Dependency pass

Verify **File list** order per Dependency ordering. Migrations and shared contracts before consumers; shared components before their consumers. Exceptions → **Architecture decisions**.

### Step 4c - Data model extraction

**Trigger:** File List contains any of: migration file, DTO, domain model, schema file, new entity type.

If triggered:

1. Extract technology-agnostic entity definitions from `task.md`, architecture analysis, and any DB or schema notes accumulated in earlier steps.
2. Write `devflow/features/[NNN]_[feature-name]/data-model.md` using this format:

```markdown
# Data Model - [Feature Name]

**Feature:** PLAN-[NNN]
**Date:** [YYYY-MM-DD]

| Entity | Fields | Relationships | Lifecycle states | Validation rules |
|--------|--------|---------------|------------------|------------------|
| [EntityName] | [field: type, ...] | [belongs to / has many / ...] | [created / active / archived / ...] | [required, max-length N, format, ...] |
```

Rules:

- No class names, annotations, or framework types — technology-agnostic only.
- One row per domain concept; split conflated concepts.
- Adapter skills derive stack-specific types from this file.

If not triggered: skip.

### Step 5 - Write plan file

Create `devflow/features/[NNN]_[feature-name]/plan.md` using the template in `references/plan-template.md`. Sections in order: Overview, Architecture decisions, Risks and mitigations, Open questions, Traceability, File List, Implementation checkpoints, Adapter-specific sections, Edge Cases & Error Handling, Pre-implement checklist.

Format rules:

- Adapter-specific sections: follow `ADAPTER.md` layout exactly (optional/required blocks, localization/data rules).
- Language: English.
- Compression: caveman-compress — drop articles/filler/hedging; keep technical terms/paths/commands exact.

### Step 6 - Notify user

Respond with:

```text
✅ Plan created: devflow/features/[NNN]_[feature-name]/plan.md

[Feature summary in 1-2 lines]
[N] files to create, [M] files to modify

Continue to implementation? -> devflow.implement
```

## Parallelization (multi-session / multi-agent)

- **Usually sequential:** Schema/migration changes, shared state-contract changes, wide router changes.
- **Often parallelizable once contracts exist:** Focused leaf tests, copy/content-only updates, isolated components/modules that do not change shared contracts.
- **Rule:** Lock shared types/contracts first; then parallelize leaf work.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Writing plan without reading `task.md` | Always start with `task.md` |
| File list in layer order (all models → services → UI) | Order by user-visible increment; checkpoint per slice |
| No Traceability row for a subtask | Every subtask → at least one file + criterion |
| Open questions with Status `ready` | Leave open; escalate to user; never guess |
| Reuse audit skipped ("implement will figure it out") | Audit in Step 3; document in Architecture decisions |
| New component without checking shared/ | ≥70% coverage rule; extend first |
| Dependencies without explicit ordering | Sort file list; document rationale in Architecture decisions |
| Architecture decisions made during implement | All decisions in `plan.md` before implement |
| Adapter sections omitted | Apply every required `ADAPTER.md` section |
| No implementation checkpoints on long plans | ≥2 checkpoints for plans >5 files |

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md` |
| Reads | `constitution.md`, `registry.md`, `@devflow/adapters/common/skills/common-clean-code/SKILL.md` |
| Reads (adapter) | `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md`; technology skills per ADAPTER table |
| Writes | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Writes (optional) | `devflow/features/[NNN]_[feature-name]/data-model.md` (Step 4c — triggered when feature touches persistent entities) |
| Next step | `devflow.implement` |
| Related skills | Per active `ADAPTER.md` → **Technology skills** |
