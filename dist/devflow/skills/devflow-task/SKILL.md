---
name: devflow-task
description: Transforms raw idea into Agile product task.md with goal, user story, structured use cases (happy path + edge cases), acceptance criteria, and scope boundaries. Use when user asks to create a task, start the pipeline, run devflow.task, or provides a feature idea.
argument-hint: [--app <name>]
---

# Skill: devflow.task

## Purpose

Turn raw idea into a lean, product-focused Agile task. Capture objective, user story, and concrete use cases. First DevFlow step and primary entry point for devflow.plan.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **product-only** — focus on user value, use cases, and behavior; zero technical implementation or file/class names
- **traceability** — use case / scenario → acceptance criterion → file(s) in `plan.md`
- **vertical slices** — end-to-end increments derived from use cases, never architectural layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- A `task.md` already exists for this feature and its status is not `done` — edit the existing file instead
- The idea matches a feature already marked **implemented** in `docs/product.md` — clarify scope first
- The user provides a plan or implementation detail directly — go to `devflow.plan` instead

## Input

- Free text in the user message, OR
- File provided by the user (markdown, text, pdf)

## Workflow

### Step 1 - Resolve target app (monorepo only)

1. Read `@devflow/config.md`.
2. No `## Apps` heading → single-app repo. Skip this step entirely — no app question, no `**App:**` field anywhere downstream. This is the zero-migration path; do not add any monorepo behavior here.
3. `## Apps` heading present:
   - `--app <name>` in `$ARGUMENTS` → validate against the table's App column. Unknown name → list valid names from the table, ask again — never guess.
   - No `--app` → ask ("Which app is this feature for?") using **`AskQuestion`** with the table's App names as options, or list them in chat if unavailable.
   - Keep the resolved app name for Step 2 (constitution scoping), Step 9 (task.md write), and Step 10 (`docs/product.md` write).

### Step 2 - Read context

Read in order:

| Source                            | Role                                                                                                                                           |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **`docs/product.md`** (always)    | Domain, actors, features, **implemented** vs **not implemented**, overlap checks                                                               |
| **`constitution.md`** (as needed) | Stack, `lib/` layout, layering (UI → domain → data), engineering conventions                                                                   |
| **`registry.md`** (as needed)     | Shared patterns: breakpoints, dashboard shell, navigation, reusable recipes                                                                    |
| **`docs/adr/`** (if present)      | Architecture Decision Records — check `docs/adr/README.md` or active ADRs; bind task scope to accepted architectural decisions and constraints |
| **`DESIGN.md`** (if present)      | Design system (or `docs/design.md`) — UI ideas inherit its tokens; plan tags UI                                                                |

Monorepo (`## Apps` present in `config.md`): scope `constitution.md` to the shared managed block plus the resolved app's `constitution-<app-name>` managed block only — not the whole file.

Optional: use `Glob`, `Grep`, and `Read` on the codebase to ground the task in existing modules and avoid silent duplication of behavior.

### Step 3 - Classify input

- **Clear enough** — skip to Step 4 unless material unknowns remain.
- **Ambiguous or multi-directional** — clarify actor, primary goal, and core user flow before writing use cases.
- **Brainstorm-scale** (no concrete problem or user) — stop and point the user to **`ce-brainstorm`** or **`idea-refine`**; resume `devflow-task` when they have a single direction.

### Step 4 - Clarification questions (optional)

Stop and ask before writing the task if:

- The idea is vague or has multiple valid interpretations
- Key actors, edge cases, success criteria, or expected behaviors are undefined
- The idea overlaps with an existing feature in `docs/product.md`

Structured elicitation rules (per `@devflow/skills/devflow-clarify/references/interactive-interview.md`):

- Max 5 questions, asked sequentially one at a time
- Use **`AskQuestion`** / **`ask_question`**: offer 2–4 distinct options with first option marked `(Recommended)` and a 1-sentence technical rationale; fallback to structured markdown in chat if tool unavailable
- Skip entirely if the idea is already clear enough

**Run mode** (`.devflow-run.json` present): do not stop or ask — pick defensible default per unresolved point (the recommended option: repo precedent > `docs/product.md` > most conservative/fail-closed reading), record each as a one-line assumption in `task.md` **`## Notes`**; never leave a raw `[NEEDS CLARIFICATION: ...]` marker unresolved. Missing **App** on a monorepo feature still hard-stops — never guessed, run mode or not.

### Step 5 - Quick stress-test

Read **`refinement-hints.md`**, run 8D pass (user value, feasibility, overlap, scope honesty, riskiest assumption, edge cases, integration, terminology). Ensure happy path and at least one alternative/error flow are captured; push back if scope too large.

### Step 6 - Propose feature name

Propose 3 `kebab-case` names:

- 1-3 words, feature-oriented
- Consistent with `devflow/features/` names

Ask via **`AskQuestion`** / **`ask_question`** with three options (mark option 1 as `(Recommended)`); fallback to chat prompt if tool unavailable.

**Run mode** (`.devflow-run.json` present): do not wait — take the first proposed name, note the other two as alternatives in `task.md` **`## Notes`**.

### Step 7 - Determine incremental number

**Fast path:** Read `.devflow-state.json` in project root.
If `next_feature_number` present, use it — no further lookup.

**Fallback:** Read `devflow/features/`, find highest prefix, use next 3-digit number. Start `001` if empty or absent.

Critical rule:

- Never reuse an existing prefix.
- `.devflow-state.json` updated by hook on each `task.md` write — always current.

### Step 8 - Verification checklist (before write)

- [ ] **Goal & Value** states clear user/business problem and concrete objective (no vague adjectives)
- [ ] Target **user** matches product actors; **user story** aligns with stated goal
- [ ] **Use Cases** are structured with at least 1 Happy Path (`UC-1`) and 1-2 Alternative/Error/Edge cases (`UC-2`, `UC-3`)
- [ ] **Acceptance criteria** are observable, falsifiable, and map directly to use cases (e.g. `AC-1 (UC-1)`)
- [ ] Strictly **product-only**: zero technical details (no class names, file paths, database schemas, or API endpoints)
- [ ] **`NNN` prefix** matches `next_feature_number` from `.devflow-state.json` (or verified unique via directory scan if state absent)
- [ ] **In scope / Out of scope** are honest; non-goals prevent plan creep
- [ ] **Referenced ADRs**: if task touches `docs/adr/`, boundaries and constraints from accepted ADRs are respected in scope and ACs
- [ ] Criteria with a trigger/precondition use EARS phrasing (`WHEN`/`IF ... THEN THE SYSTEM SHALL ...`) per `refinement-hints.md` dimension 4
- [ ] No duplicate of an **implemented** feature unless explicitly framed as extension
- [ ] No unresolved `[NEEDS CLARIFICATION: ...]` markers remain (or each is documented as an explicit accepted risk in Notes)
- [ ] `config.md` has `## Apps` → **App** resolved (Step 1) and will be written; absent → no App field anywhere in the output

If any item fails, fix the task content before writing the file.

### Step 9 - Write task file

Create `devflow/features/[NNN]_[feature-name]/task.md` using template + format rules in `references/task-template.md`. Write the `**App:**` frontmatter field with the Step 1 resolution when `config.md` has `## Apps`; include `**ADRs:**` with referenced ADR path(s) if applicable; omit when absent. See **`examples.md`** in this skill directory for full worked examples.

### Step 10 - Update docs/product.md feature status

After writing `task.md`, update `docs/product.md` **Feature status** table:

- New feature: add row, status `in-progress`, short note; when monorepo, fill the **App** column with the Step 1 resolution
- Existing `planned`: update to `in-progress`
- Do not touch rows/sections outside `devflow-managed:feature-status` block

If `docs/product.md` absent, skip and note in notify.

### Step 11 - Notify user

Respond using template in `references/notify-template.md`.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Technical details in task (classes, DB schemas, endpoints) | Product-only; technical decisions belong in `devflow.plan` |
| Copying raw user wording into Goal or Problem | Rewrite and enrich from `product.md` |
| Missing alternative/error use cases (only Happy Path defined) | Always define edge cases and error handling paths (`UC-2`, `UC-3`) |
| Vague narrative paragraphs instead of structured flows | Structured user flows (Preconditions → Steps → Outcome) |
| Empty Out-of-scope on large/ambiguous idea | Explicit trade-offs and non-goals — prevents plan creep |
| Skipping clarification because task “seems clear” | Ask when material unknowns exist |
| Assuming NNN prefix is unique without reading state | Read `.devflow-state.json`; never reuse prefix |
| Filling unknown values with guesses | Use `[NEEDS CLARIFICATION: ...]` inline |

## Relationship to `plan.md`

`devflow.plan` consumes `task.md` to produce `plan.md`: maps each Use Case (`UC-N`) and Acceptance Criterion (`AC-N`) to file changes, architectural decisions, and verification tests. Keep `task.md` strictly functional; file paths, algorithms, and dependencies belong in `plan.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/config.md` (Apps table, monorepo only); `docs/product.md` (required); `constitution.md`, `registry.md` (as needed); `DESIGN.md` / `docs/design.md` (if present); `refinement-hints.md` (Step 4); `@devflow/skills/devflow-clarify/references/interactive-interview.md` (Step 4 & 6); `examples.md` (optional guidance); `references/task-template.md`, `references/notify-template.md` |
| Reads (conditional) | `docs/adr/` (if present — active ADRs for architectural context); `.devflow-run.json` (existence — run-mode switch, per `devflow-auto`) |
| Writes | `devflow/features/[NNN]_[feature-name]/task.md` |
| Next step | `devflow.plan` → `plan.md` (full template in `devflow/skills/devflow-plan/SKILL.md`) |
