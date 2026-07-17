---
name: devflow-task
description: Transforms raw idea into DevFlow task.md with HMW framing, scope, assumptions, subtasks. Use when user asks to create a task, start the pipeline, run devflow.task, or provides a feature idea.
---

# Skill: devflow.task

## Purpose

Turn raw idea into structured task. Read product context, output user story + subtasks. First DevFlow step.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- A `task.md` already exists for this feature and its status is not `done` — edit the existing file instead
- The idea matches a feature already marked **implemented** in `docs/product.md` — clarify scope first
- The user provides a plan or implementation detail directly — go to `devflow.plan` instead

## Input

- Free text in the user message, OR
- File provided by the user (markdown, text, pdf)

## Workflow

### Step 1 - Read context

Read in order:

| Source                            | Role                                                                             |
| --------------------------------- | -------------------------------------------------------------------------------- |
| **`docs/product.md`** (always)    | Domain, actors, features, **implemented** vs **not implemented**, overlap checks |
| **`constitution.md`** (as needed) | Stack, `lib/` layout, layering (UI → domain → data), engineering conventions     |
| **`registry.md`** (as needed)     | Shared patterns: breakpoints, dashboard shell, navigation, reusable recipes      |
| **`DESIGN.md`** (if present)      | Design system (or `docs/design.md`) — UI ideas inherit its tokens; plan tags UI  |

Optional: use `Glob`, `Grep`, and `Read` on the codebase to ground the task in existing modules and avoid silent duplication of behavior.

### Step 2 - Classify input

- **Clear enough** — skip to Step 4 unless material unknowns remain.
- **Ambiguous or multi-directional** — before subtasks: produce **one** crisp **How Might We** line and use Step 3 to nail actor, success, and boundaries (no full ideation pass).
- **Brainstorm-scale** (no concrete problem or user) — stop and point the user to **`ce-brainstorm`** or **`idea-refine`**; resume `devflow-task` when they have a single direction.

### Step 3 - Clarification questions (optional)

Stop and ask before writing the task if:

- The idea is vague or has multiple valid interpretations
- Key actors, edge cases, success criteria, or expected behaviors are undefined
- The idea overlaps with an existing feature in `docs/product.md`

Rules:

- Max 5 questions, numbered, concise
- Use **`AskQuestion`** tool if available; otherwise ask in chat
- Skip entirely if the idea is already clear enough

### Step 4 - Quick stress-test

Read **`refinement-hints.md`**, run 8D pass (user value, feasibility, overlap, scope honesty, riskiest assumption, edge cases, integration, terminology); push back if scope too large.

### Step 5 - Propose feature name

Propose 3 `kebab-case` names:

- 1-3 words, feature-oriented
- Consistent with `devflow/features/` names

Use **`AskQuestion`** with three options if available; otherwise list names and wait.

### Step 6 - Determine incremental number

**Fast path:** Read `.devflow-state.json` in project root.
If `next_feature_number` present, use it — no further lookup.

**Fallback:** Read `devflow/features/`, find highest prefix, use next 3-digit number. Start `001` if empty or absent.

Critical rule:

- Never reuse an existing prefix.
- `.devflow-state.json` updated by hook on each `task.md` write — always current.

### Step 7 - Verification checklist (before write)

- [ ] **How Might We** line is present and neither too broad nor solution-embedded
- [ ] Target **user** matches product actors; **user story** matches Summary
- [ ] **Subtasks** are atomic, verifiable, and free of implementation detail
- [ ] **`NNN` prefix** matches `next_feature_number` from `.devflow-state.json` (or verified unique via directory scan if state absent)
- [ ] **In scope / Out of scope** are honest for non-trivial ideas; **Key assumptions** filled when risks exist
- [ ] No duplicate of an **implemented** feature unless explicitly framed as extension
- [ ] No unresolved `[NEEDS CLARIFICATION: ...]` markers remain (or each is documented as an explicit accepted risk in Notes)

If any item fails, fix the task content before writing the file.

### Step 8 - Write task file

Create `devflow/features/[NNN]_[feature-name]/task.md` using template + format rules in `references/task-template.md`. See **`examples.md`** in this skill directory for full worked examples.

### Step 9 - Update docs/product.md feature status

After writing `task.md`, update `docs/product.md` **Feature status** table:

- New feature: add row, status `in-progress`, short note
- Existing `planned`: update to `in-progress`
- Do not touch rows/sections outside `devflow-managed:feature-status` block

If `docs/product.md` absent, skip and note in notify.

### Step 10 - Notify user

Respond using template in `references/notify-template.md`.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Copying raw user wording into Summary or HMW | Rewrite and enrich from `product.md` |
| Vague subtasks (“improve UX”) or implementation tickets (“add `FooRepository`”) | Atomic, outcome-level; no file/class names |
| Empty Out-of-scope on large/ambiguous idea | Explicit trade-offs — reduces plan creep |
| Skipping clarification because task “seems clear” | Ask when material unknowns exist |
| Skipping stress-test (Step 4) on small features | 8D pass; scope creep starts small |
| Assuming NNN prefix is unique without reading state | Read `.devflow-state.json`; never reuse prefix |
| Running idea-refine work inside this skill | Route to `ce-brainstorm` / `idea-refine` early |
| Filling unknown values with guesses | Use `[NEEDS CLARIFICATION: ...]` inline |

## Relationship to `plan.md`

`devflow.plan` → `plan.md`: file-ordered plan with traceability, decisions, risks, checkpoints. Keep Subtasks outcome-level; paths/names go in `plan.md`.

## I/O Reference

|           |                                                                                                                                               |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Reads     | `docs/product.md` (required); `constitution.md`, `registry.md` (as needed); `DESIGN.md` / `docs/design.md` (if present); `refinement-hints.md` (Step 4); `examples.md` (optional guidance); `references/task-template.md`, `references/notify-template.md` |
| Writes    | `devflow/features/[NNN]_[feature-name]/task.md`                                                                                               |
| Next step | `devflow.plan` → `plan.md` (full template in `devflow/skills/devflow-plan/SKILL.md`)                                                          |
