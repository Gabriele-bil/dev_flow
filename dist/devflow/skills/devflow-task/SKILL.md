---
name: devflow-task
description: Transforms raw idea into Agile product task.md with goal, Connextra user story, INVEST-checked vertical use cases (Read/Write separated), BDD Gherkin acceptance criteria, and explicit async states. Use when user asks to create a task, start the pipeline, run devflow.task, or provides a feature idea.
argument-hint: "[--app <name>]"
---

# Skill: devflow.task

## Purpose

Turn raw idea into a lean, product-focused Agile task. Acts as Requirements Architect: applies INVEST criteria, Connextra user story format, vertical splitting (Read vs Write isolation), and BDD Gherkin acceptance criteria. First DevFlow step and primary entry point for `devflow.plan`.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **product-only** — focus on user value, use cases, and behavior; zero technical implementation or file/class names
- **invest-discipline** — Independent, Negotiable, Valuable, Estimable, Small, Testable per `references/invest-criteria.md`
- **read-write-isolation** — separate view/list flows from transactional mutations per `references/story-splitting.md`
- **explicit-async** — specify loading indicator, double-submit protection, error recovery, and empty states
- **bdd-gherkin** — Given/When/Then with exactly one `When` per scenario per `references/bdd-acceptance-criteria.md`
- **traceability** — use case (`UC-N`) → BDD acceptance criterion (`AC-N (UC-N)`) → file(s) in `plan.md`
- **vertical slices** — end-to-end increments; strictly NO "Ghost UI" (dead placeholder elements)
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- A `task.md` already exists for this feature and its status is not `done` — edit existing file instead
- The idea matches a feature already marked **implemented** in `docs/product.md` — clarify scope first
- The user provides a plan or implementation detail directly — go to `devflow.plan` instead

## Input

- Free text in user message, OR
- File provided by user (markdown, text, pdf)

## Workflow

### Step 1 - Resolve target app (monorepo only)

1. Read `@devflow/config.md`.
2. No `## Apps` heading → single-app repo. Skip step entirely — no app question, no `**App:**` field anywhere downstream.
3. `## Apps` heading present:
   - `--app <name>` in `$ARGUMENTS` → validate against table's App column. Unknown name → list valid names, ask again — never guess.
   - No `--app` → ask ("Which app is this feature for?") using **`AskQuestion`** with table App names as options.
   - Keep resolved app name for Step 2, Step 9 (`task.md`), and Step 10 (`docs/product.md`).

### Step 2 - Read context

Read in order:

| Source | Role |
| --- | --- |
| **`docs/product.md`** (always) | Domain, actors, features, **implemented** vs **not implemented**, overlap checks |
| **`constitution.md`** (as needed) | Stack, `lib/` layout, layering (UI → domain → data), engineering conventions |
| **`registry.md`** (as needed) | Shared patterns: breakpoints, shell, navigation, reusable recipes |
| **`docs/adr/`** (if present) | Architecture Decision Records — check active ADRs; bind task scope to accepted decisions |
| **`DESIGN.md`** (if present) | Design system (or `docs/design.md`) — UI ideas inherit tokens |

Monorepo (`## Apps` present): scope `constitution.md` to shared managed block plus resolved app's `constitution-<app-name>` block only.

### Step 3 - Classify input & Anti-hallucination check

- **Clear enough** — proceed to Step 5 unless material unknowns remain.
- **Missing critical context (Constraint 0 — Anti-Hallucination):** If actor/persona, core business rules, or boundaries are missing, DO NOT assume or invent them. Proceed to Step 4 to clarify.
- **Brainstorm-scale** (no concrete problem or user) — stop and point user to **`ce-brainstorm`** or **`idea-refine`**; resume when direction chosen.

### Step 4 - Clarification questions (optional)

Stop and ask before writing task if:

- Persona or actor is undefined (must be real human or external actor, never technical role)
- Core workflow trigger or output format is ambiguous
- Idea overlaps with existing feature in `docs/product.md`

Structured elicitation rules (per `@devflow/skills/devflow-clarify/references/interactive-interview.md`):

- Max 5 questions, asked sequentially one at a time
- Use **`AskQuestion`** / **`ask_question`**: offer 2–4 options with first option marked `(Recommended)` and a 1-sentence rationale; fallback to chat prompt if tool unavailable
- Skip entirely if idea is already clear enough

**Run mode** (`.devflow-run.json` present): do not stop — pick defensible default (repo precedent > `docs/product.md` > conservative reading), record each as bullet in `task.md` **`## Assumptions & Risks`**; never leave raw `[NEEDS CLARIFICATION]` marker. Missing **App** on monorepo still hard-stops.

### Step 5 - Quick stress-test

Read **`refinement-hints.md`**, run pass:

1. **INVEST check:** ensure story is Independent, Negotiable, Valuable, Estimable, Small, Testable.
2. **Vertical slice check:** isolate Read/View flows from Action/Mutation flows. Ensure Alien Test passes (atomic value; strictly NO Ghost UI).
3. **Async lifecycle check:** verify loading indicators, double-submit protection, error recovery, and empty states.
4. **BDD formulation check:** verify single `When` rule and intent over mechanics.

### Step 6 - Propose feature name

Propose 3 `kebab-case` names:

- 1-3 words, feature-oriented
- Consistent with `devflow/features/` names

Ask via **`AskQuestion`** / **`ask_question`** with three options (mark option 1 as `(Recommended)`).

**Run mode** (`.devflow-run.json` present): take first proposed name, note other two in `## Notes`.

### Step 7 - Determine incremental number

**Fast path:** Read `.devflow-state.json` in project root. If `next_feature_number` present, use it.
**Fallback:** Read `devflow/features/`, find highest prefix, use next 3-digit number. Start `001` if empty. Never reuse prefix.

### Step 8 - Verification checklist (before write)

- [ ] **Goal & Value**: states clear user pain point and concrete objective (no vague adjectives)
- [ ] **User Story**: strictly Connextra (`As a ... I want to ... So that ...`). Real human or external actor (never technical role); action has clean intent (no compound and/or); value has measurable benefit (no tautology)
- [ ] **Use Cases**: structured with at least 1 Happy Path (`UC-1`) and 1-2 Alternative/Edge/Error cases (`UC-2`, `UC-3`). Read/View flows isolated from Action/Mutation flows
- [ ] **Acceptance Criteria**: strict BDD Gherkin (`GIVEN ... WHEN ... THEN ...`), exactly one `When` per scenario. Mapped directly to use cases (e.g. `AC-1 (UC-1)`). Observable, binary pass/fail
- [ ] **Async states**: loading indicators, input disabling to prevent double submission, error recovery, and empty states explicitly specified
- [ ] **Alien test & No Ghost UI**: delivers complete, usable increment; zero placeholder buttons or unhandled elements
- [ ] Strictly **product-only**: zero technical details (no class names, file paths, database schemas, or API endpoints)
- [ ] **`NNN` prefix**: matches `next_feature_number` from `.devflow-state.json`
- [ ] **In scope / Out of scope**: honest boundaries; non-goals prevent plan creep
- [ ] **Assumptions & Risks**: structured bullets feed directly into `plan.md` risks table
- [ ] **Referenced ADRs**: respected in scope and ACs if present
- [ ] No unresolved `[NEEDS CLARIFICATION: ...]` markers remain
- [ ] `config.md` has `## Apps` → **App** resolved; absent → no App field
- [ ] **Language**: English — all documents must be written in English regardless of conversation language

If any item fails, fix task content before writing file.

### Step 9 - Write task file

Create `devflow/features/[NNN]_[feature-name]/task.md` using template + format rules in `references/task-template.md`. Write `**App:**` frontmatter field with Step 1 resolution when `config.md` has `## Apps`; include `**ADRs:**` if applicable; omit when absent. See **`examples.md`** for worked examples.

### Step 10 - Update docs/product.md feature status

After writing `task.md`, update `docs/product.md` **Feature status** table:

- New feature: add row, status `in-progress`, short note; fill **App** column if monorepo
- Existing `planned`: update to `in-progress`
- Do not touch rows/sections outside `devflow-managed:feature-status` block

If `docs/product.md` absent, skip and note in notify.

### Step 11 - Notify user

Respond using template in `references/notify-template.md`.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Technical details in task (classes, DB schemas, endpoints) | Product-only; technical decisions belong in `devflow.plan` |
| Technical persona ("As a Frontend Developer", "As a Database") | Use real human role or external system actor |
| Compound user story ("I want X and Y") | Split into separate use cases or tasks |
| Tautological value ("so that I can do action") | Articulate real business/user benefit |
| Mixing Read view and Action mutation in one flow | Isolate Read/View from Action/Write into distinct use cases |
| Missing async states (in-flight, error, empty) | Explicitly specify loading spinner, input disabling, retry, and fallback |
| Ghost UI (dead buttons or "coming soon" placeholders) | Strict Alien test: only include working, releasable functionality |
| Multiple `When` statements in a single AC scenario | Exactly one `When` per scenario; split multiple triggers |
| Vague adjectives ("fast", "intuitive", "clean") | Quantify measurable targets (e.g. "LCP < 2.0s", "inline error displayed") |
| Copying raw user wording into Goal or Problem | Rewrite and enrich from `product.md` |
| Assuming NNN prefix without reading state | Read `.devflow-state.json`; never reuse prefix |

## Relationship to `plan.md`

`devflow.plan` consumes `task.md` to produce `plan.md`:

- Maps each Use Case (`UC-N`) and BDD Acceptance Criterion (`AC-N`) directly to file changes and verification tests in **Traceability**.
- Translates explicit async states (loading, disabled inputs, error recovery) into UI state models and error handling boundaries.
- Takes `## Assumptions & Risks` from `task.md` to seed `plan.md`'s **Risks and mitigations** table and **Architecture decisions**.
- Leverages Read vs Write separation to structure vertical slice dependencies cleanly.

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/config.md` (Apps table, monorepo only); `docs/product.md` (required); `constitution.md`, `registry.md` (as needed); `DESIGN.md` / `docs/design.md` (if present); `refinement-hints.md` (Step 5); `references/invest-criteria.md`, `references/story-splitting.md`, `references/bdd-acceptance-criteria.md` (Step 5); `@devflow/skills/devflow-clarify/references/interactive-interview.md` (Step 4 & 6); `examples.md` (guidance); `references/task-template.md`, `references/notify-template.md` |
| Reads (conditional) | `docs/adr/` (if present — active ADRs); `.devflow-run.json` (run-mode switch) |
| Writes | `devflow/features/[NNN]_[feature-name]/task.md` |
| Next step | `devflow.plan` → `plan.md` (full template in `devflow/skills/devflow-plan/SKILL.md`) |
