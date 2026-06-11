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

## Vertical slicing (mandatory for plans with > 5 files)

`task.md` subtasks stay outcome-level (see `devflow-task`). When a plan has more than 5 files, define at least **2 vertical slice increments** in the **Architecture decisions** section — each slice is one end-to-end user-visible increment (not a layer). Group **File List** entries under slice headings.

Example in Architecture decisions:
```
- **Slice 1 — data contract + shell**: DB migration + domain model + empty UI scaffold; compiles and renders blank screen
- **Slice 2 — state + data flow**: provider + repository impl + loading/error states wired to UI
- **Slice 3 — full UI + i18n**: complete widget tree + localization keys + responsive layout
```

For plans with 5 or fewer files, slicing is optional — note in Overview if sequential layer ordering is clearer. Do **not** rewrite subtask wording. The **Traceability** table must still map **each original subtask** to file path(s).

## Dependency ordering (reflect in File List)

Order the **File list** bottom-up per `constitution.md` **and** the active adapter’s `@devflow/adapters/<adapter>/ADAPTER.md` (section **Plan: extra sections → Dependency ordering** when present). If the two differ, prefer `constitution.md` for repo-specific layout and use the adapter for stack tooling (codegen, i18n, data layer).

If order must deviate for a vertical slice, note the exception in **Architecture decisions**.

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
- [ ] `task.md` Status is `draft` (Key assumptions resolved, no `[NEEDS CLARIFICATION: ...]` markers) or `clarified` — Status `draft` with unresolved markers → stop, suggest `devflow.clarify`
- [ ] `task.md` contains no `[NEEDS CLARIFICATION: ...]` markers (if present: stop, report locations, suggest `devflow.clarify` or manual resolution)

If any item fails → stop, report which check failed, do not write `plan.md`.

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

### Step 0b - Constitution Gate

Before reading any other doc:
1. Read `constitution.md` in full.
2. Extract each `MUST` / `MUST NOT` rule as a separate item.
3. Evaluate each rule against the planned approach for this feature.
4. If any `MUST` or `MUST NOT` is violated → output **Constitution Violation Report**:

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

Before planning any file, scan for existing project elements that can be reused or extended:

1. **Read `registry.md`** in full — note every shared component, widget, utility, and pattern relevant to this feature.
2. **Scan the project's shared folder** (e.g. `lib/shared/`, `src/shared/`, `components/shared/`) — list components that partially or fully cover any UI need in this feature.
3. **Decide for each candidate:** reuse as-is / extend / parameterise / create new. Document the decision under **Architecture decisions** in `plan.md`.
4. **Plan new shared components:** if this feature introduces a UI pattern generic enough for reuse elsewhere, list it under its shared path in the **File List** from the start — not as an afterthought.

> **Rule:** A new feature-specific component is only justified when no shared component covers ≥70% of the need. When in doubt, extend the existing one.

### Step 4 - Analysis

After the reuse audit, analyze:

- Which subtasks in `task.md` require new files vs existing file changes
- All bullets under **Plan** / **Implement** / **Test** in `ADAPTER.md` that apply to this feature (state management, UI, DB, i18n, responsive layout, etc.) — use `registry.md` and `constitution.md` to ground them
- Edge cases and error states that must be handled
- Any required database or external-system edits called out by the adapter

### Step 4b - Dependency pass

Re-check the planned **File list** order against **Dependency ordering** above. Migrations and shared contracts must precede consumers unless an exception is documented under **Architecture decisions**. Shared components must be listed before the feature files that consume them.

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
- **No implementation detail** — no class names, annotations, or framework-specific types (no `Freezed`, `@JsonSerializable`, `z.object`, TypeScript `interface`). Technology-agnostic only.
- Each row is a single domain concept; split if two concepts are conflated.
- Adapter skills read `data-model.md` to derive stack-specific types (Freezed → Flutter; TypeScript interfaces → Angular; Zod schemas → Next.js).

If not triggered: skip this step entirely; do not create `data-model.md`.

### Step 5 - Write plan file

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

| Subtask | Acceptance criteria | File(s) |
|---------|---------------------|---------|
| [Subtask description from task.md] | [acceptance criterion from task.md] | [file path(s)] |
| ... | ... | ... |

---

## File List

Ordered by implementation sequence. Each file must be implemented
in this order to respect dependencies.

**Batch hints (optional):** Before the first `###` of a dependency group, add one line:
`**Batch:** S | M | L` (S ≈ 1-2 files, M ≈ 3-5, L ≈ 6+). For `L`, add `— split across `devflow.implement` sessions if needed`.

**Parallelism markers (optional):** Mark parallelizable leaf files with a `[P]` prefix on the entry line. A file is `[P]`-eligible only when: (1) no other `[P]` file in the same batch touches it, and (2) it does not modify shared contracts, migrations, or state-management contracts. `[P]` coexists with `[pending]`/`[done]` — `[P]` = parallelism potential, status markers = completion state. Do not mark files that touch shared contracts, migrations, or state-management contracts.

### [NNN]. `[path/to/file.ext]` - [create | modify] [pending]
[1-2 sentences on what this file contains and why it exists.]

### [NNN]. [P] `[path/to/file.ext]` - [create | modify] [pending]
[`[P]` present: file is eligible for parallel implementation by a separate agent or session.]
...

---

## Implementation checkpoints

[For trivial 1-2 file plans, omit this section or use a single checkpoint.]

- **After [milestone / batch]:** use verification commands from `ADAPTER.md` (e.g. analyze / test); add short manual smoke if relevant
- [2-4 checkpoints for larger plans]

---

## Adapter-specific sections

After **Implementation checkpoints**, append **every extra plan section** required by the active `ADAPTER.md` (see its heading **Plan: extra sections and templates**). Use the exact headings and table formats from that file. Omit adapter sections only when `ADAPTER.md` says they do not apply.

---

## Edge Cases & Error Handling

- **[Scenario]**: [how it is handled]
- **[Scenario]**: [how it is handled]

---

## Pre-implement checklist

- [ ] Constitution Gate passed (Step 0b) — no Critical violations
- [ ] Every `task.md` subtask appears in **Traceability** with its acceptance criterion
- [ ] **File list** order respects **Dependency ordering** (and any stated exceptions)
- [ ] All **adapter-specific sections** from `ADAPTER.md` are present or correctly omitted per adapter rules (e.g. i18n keys for UI)
- [ ] **Implementation checkpoints** are actionable (commands per `ADAPTER.md` — analyze / tests / smoke)
- [ ] **Open questions** are empty or resolved if **Status** is `ready`
- [ ] Existing shared components checked; no duplication of a component already in `shared/`
- [ ] New reusable components identified in this plan are listed under their `shared/` path in the **File List**
- [ ] `devflow.analyze` run (or explicitly waived) — no Critical findings
- [ ] If feature touches persistent entities → `data-model.md` exists and is non-empty
```

Format rules:

- File list is the core of the plan; it must be complete and ordered
- Mark parallelizable leaf files with `[P]` prefix on the `###` entry line. Do not mark files that touch shared contracts, migrations, or state-management contracts.
- Traceability maps every subtask in `task.md` to at least one file
- Adapter-specific sections: follow formatting rules in `ADAPTER.md` (for example section layout, optional/required blocks, and localization/data rules per adapter)
- Language: English
- Style: concise and optimized for LLM consumption (no filler)
- Compression: caveman-compress style — drop articles/filler/hedging; fragments OK; keep technical terms, paths, commands exact.

### Step 6 - Notify user

After writing the file, respond with:

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

### Per-file `[P]` markers

A file is `[P]`-eligible only when:
1. No other `[P]` file in the same batch touches it.
2. It does not modify shared contracts, migrations, or state-management contracts.

Mark eligible files with a `[P]` prefix on the `###` entry line in the **File List** (e.g. `### 003. [P] \`path/to/file.dart\` - create [pending]`).

`[P]` coexists with `[pending]`/`[done]` on the same line — `[P]` = parallelism potential, status markers = completion state. S/M/L batch labels remain for coarse grouping; `[P]` adds per-file precision for multi-agent `devflow.implement` sessions.

## Common Rationalizations

| Thought | Reality |
|---------|---------|
| "Traceability optional for small plans" | `devflow.implement` can't prove subtask coverage without it. Always include |
| "Skip vertical slices — implement figures out order" | >5 files without slices → big-bang implement, no checkpoints, no early validation |
| "File order doesn't matter much" | Wrong dependency order (e.g. UI before migration) → compile/runtime failures in implement |
| "Leave Open questions, mark Status ready" | `devflow.implement` works from what's written. Unresolved questions → silent bugs |
| "Adapter sections don't apply here" | Omitting required `ADAPTER.md` sections → `devflow.beautify` and `devflow.test` flag missing patterns |
| "Architecture decisions during implement" | Mid-implement decisions not in `plan.md` → silent deviations, no traceability |
| "The shared component doesn't fit exactly — I'll create a new one" | Extend or parameterise the existing one first; duplication fragments the component inventory |
| "I'll check shared components during implement" | Reuse audit belongs in **plan** — implement must not discover shared components mid-flight and redesign |

## Red flags

| Symptom | Why it fails |
|---------|----------------|
| Missing **Traceability** row for a subtask | `devflow.implement` cannot prove coverage |
| **File list** out of dependency order (e.g. UI before migrations) | Broken or misleading implementation order |
| UI without planned localization keys | Violates project conventions |
| Data/schema/security sections omitted when feature mutates backend contracts | Schema or access-control drift |
| **Status `ready`** with unresolved **Open questions** | Implements guesses |
| No **Implementation checkpoints** on long file lists | Hard to verify incrementally |
| New UI component planned without **Step 3 reuse audit** | May duplicate a shared component; `devflow.beautify` will flag it |
| Reuse decision not documented in **Architecture decisions** | Implement loses context; reviewer can't tell if duplication was intentional |

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Writing `plan.md` from memory without reading `task.md` | Subtask drift; plan covers work not in task | Always read `task.md` as first step |
| File list in layer order (all models → all services → all UI) | No vertical slice; no checkpoint; big-bang implement | Order by user-visible increment; checkpoint at each slice |
| Open questions marked resolved without user answer | Silent assumption baked into plan | Leave open; route to user; do not guess |
| Traceability rows with no acceptance criteria | `devflow.implement` cannot prove coverage | Every subtask row must have at least one verifiable criterion |
| Reuse audit skipped ("implement will figure it out") | Duplicate shared components discovered mid-implement → rework | Run reuse audit in Step 3; document decision in Architecture decisions |
| Dependencies listed without explicit ordering | Broken compile/runtime order during implement | Sort file list by dependency; document ordering rationale |

## I/O Reference

| | |
|---|---|
| Reads | `devflow/features/[NNN]_[feature-name]/task.md` |
| Reads | `constitution.md`, `registry.md`, `@devflow/adapters/common/skills/common-clean-code/SKILL.md` |
| Reads (adapter) | `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md`; technology skills per ADAPTER table |
| Writes | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Writes (optional) | `devflow/features/[NNN]_[feature-name]/data-model.md` (Step 4c — triggered when feature touches persistent entities) |
| Next step | `devflow.implement` |
| Related skills | Per active `ADAPTER.md` → **Technology skills** |
