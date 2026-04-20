---
name: devflow-task
description: Transforms a raw idea into a structured DevFlow task by reading product and architecture context, optionally stress-testing scope, and generating a user story with HMW framing, scope boundaries, key assumptions, and verifiable subtasks. Use when the user asks to create a task, start the DevFlow pipeline, run devflow.task, or provides a feature idea in text/file form.
---

# Skill: devflow.task

## Purpose

Turn raw idea into structured task. Read product context, output user story + subtasks. First DevFlow step.

## When NOT to Use

- A `task.md` already exists for this feature and its status is not `done` — edit the existing file instead
- The idea matches a feature already marked **implemented** in `docs/product.md` — clarify scope first
- The user provides a plan or implementation detail directly — go to `devflow.plan` instead

## Input

- Free text in the user message, OR
- File provided by the user (markdown, text, pdf)

## Workflow

### Step 1 - Read context

Read sources in this order and use each for its role:

| Source | Role |
|--------|------|
| **`docs/product.md`** (always) | Domain, actors, features, **implemented** vs **not implemented**, overlap checks |
| **`constitution.md`** (as needed) | Stack, `lib/` layout, layering (UI → domain → data), engineering conventions |
| **`registry.md`** (as needed) | Shared patterns: breakpoints, dashboard shell, navigation, reusable recipes |

Optional: use `Glob`, `Grep`, and `Read` on the codebase to ground the task in existing modules and avoid silent duplication of behavior.

### Step 2 - Classify input

- **Clear enough** — proceed to clarification (Step 3) only if something material is still unknown; otherwise skip to Step 4.
- **Ambiguous or multi-directional** — before subtasks: produce **one** crisp **How Might We** line and use Step 3 to nail actor, success, and boundaries (no full ideation pass).
- **Brainstorm-scale** (no concrete problem or user) — stop and point the user to **`ce-brainstorm`** or **`idea-refine`**; resume `devflow-task` when they have a single direction.

### Step 3 - Clarification questions (optional)

Stop and ask before writing the task if:

- The idea is vague or has multiple valid interpretations
- Key actors, edge cases, success criteria, or expected behaviors are undefined
- The idea overlaps with an existing feature in `docs/product.md`

Rules:

- Max 5 questions, numbered, concise
- Prefer the **`AskQuestion`** tool when the environment provides it (e.g. multiple-choice); otherwise ask in chat and wait for answers
- Skip entirely if the idea is already clear enough

### Step 4 - Quick stress-test

Before locking Summary/scope, read **`refinement-hints.md`** and run short pass: user value, feasibility, overlap, scope honesty, riskiest assumption. Push back if scope too large.

### Step 5 - Propose feature name

Propose 3 `kebab-case` name options derived from the idea. Names must be:

- Short (1-3 words)
- Feature-oriented, not implementation-oriented
- Consistent with existing names in `devflow/features/` (if any)

Prefer **`AskQuestion`** with the three names as options (plus “Other — specify in chat” if the tool allows). Otherwise list the three names and wait for confirmation before continuing.

### Step 6 - Determine incremental number

Read the `devflow/features/` directory and detect existing feature prefixes (`001_`, `002_`, ...).
You MUST use the next available 3-digit number greater than the highest existing one.
Never reuse an existing number, even if a similarly named feature already exists.
If `devflow/features/` does not exist or is empty, start from `001`.

Critical rule:

- Before creating `devflow/features/[NNN]_[feature-name]/`, verify that no directory with prefix `[NNN]_` already exists.
- If it exists, increment to the next number and re-check until the prefix is unique.

Example:

- Existing directories: `001_login`, `002_profile`, `004_notifications`
- Next feature directory MUST be: `005_[feature-name]` (not `003`, not any reused prefix)

### Step 7 - Verification checklist (before write)

Confirm:

- [ ] **How Might We** line is present and neither too broad nor solution-embedded
- [ ] Target **user** matches product actors; **user story** matches Summary
- [ ] **Subtasks** are atomic, verifiable, and free of implementation detail
- [ ] **`NNN` prefix** is unique under `devflow/features/`
- [ ] **In scope / Out of scope** are honest for non-trivial ideas; **Key assumptions** filled when risks exist
- [ ] No duplicate of an **implemented** feature unless explicitly framed as extension

If any item fails, fix the task content before writing the file.

### Step 8 - Write task file

Create `devflow/features/[NNN]_[feature-name]/task.md` using this format:

```markdown
# Task - [Feature Name]

**ID:** TASK-[NNN]
**Date:** [YYYY-MM-DD]
**Status:** draft

---

## Summary

[2-4 sentences. Rewrite and clarify the original idea. Remove ambiguity.
Add implicit context from product.md. Never copy the raw input verbatim.]

---

## Problem framing (HMW)

[Single sentence: "How might we ..." — actionable, user-centered, not a solution disguised as a question.]

---

## Scope boundaries

**In scope**

- [Bullet: what this task commits to at product/outcome level]

**Out of scope (Not doing)**

- [Bullet: explicit non-goals with short reason — not a second subtask checklist]

---

## Key assumptions

- [ ] [Assumption — optional brief hint how to validate if non-obvious]
- [ ] [Use "None — well-understood feature" only when truly trivial]

---

## User Story

**As a** [user type]
**I want to** [desired action or capability]
**So that** [benefit or goal]

---

## Subtasks

- [ ] [Subtask 1 - clear, atomic, verifiable]
- [ ] [Subtask 2]
- [ ] [Subtask N]

---

## Notes

[Assumptions made, edge cases identified, decisions taken during analysis.
Leave empty if none.]
```

Format rules:

- **Summary**: rewritten from scratch, clear, unambiguous, enriched with product context, never copied from raw input.
- **Problem framing (HMW)**: one line; narrow enough to plan, broad enough for real design choices.
- **Scope boundaries**: **In scope** / **Out of scope** reduce plan creep; out-of-scope items are explicit trade-offs, not TODOs.
- **Key assumptions**: omit only for trivial, low-risk tasks; otherwise include the riskiest beliefs and validation hints.
- **User story**: always `As a / I want to / So that`.
- **Subtasks**: atomic and verifiable, no implementation details (no class names, methods, file paths).
- **Notes**: analysis decisions only, not TODOs.
- **Language**: English throughout.
- **Style**: optimized for LLM consumption, concise, no filler words.
- **Compression**: caveman-compress style — drop articles/filler/hedging; fragments OK; keep technical terms, paths, commands exact.

See **`examples.md`** in this skill directory for full worked examples.

### Step 9 - Notify user

After writing the file, respond with:

```text
✅ Task created: devflow/features/[NNN]_[feature-name]/task.md

[User story in 1 line]

Continue to planning? → devflow.plan
```

## Anti-patterns

- Copy-pasting the user’s raw wording into **Summary** or **HMW**
- **Subtasks** that are vague (“improve UX”), huge (“build notifications”), or implementation tickets (“add `FooRepository`”)
- **Out of scope** that is empty on a large or ambiguous idea
- Ignoring **`docs/product.md`** implementation status and duplicating shipped work
- Skipping the **verification checklist** or the **unique `NNN`** rule
- Running a full **idea-refine** session inside this skill instead of routing out early

## Relationship to `plan.md`

`devflow.plan` turns this task into `plan.md`: file-ordered plan with traceability, decisions, risks, checkpoints, pre-implement checklist. Keep **Subtasks** outcome-level; put paths/provider names in `plan.md`, not here.

## I/O Reference

| | |
|---|---|
| Reads | `docs/product.md` (required); `constitution.md`, `registry.md` (as needed); `refinement-hints.md` (Step 4); `examples.md` (optional guidance) |
| Writes | `devflow/features/[NNN]_[feature-name]/task.md` |
| Next step | `devflow.plan` → `plan.md` (full template in `devflow/skills/devflow-plan/SKILL.md`) |
