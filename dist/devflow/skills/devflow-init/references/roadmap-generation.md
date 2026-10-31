# Topological Roadmap & Batch `task.md` Generation (`devflow.init`)

Used by `devflow.init` Step 4 — rules for decomposing a greenfield project into a verified Dependency DAG, generating `devflow/plans/project-blueprint.md`, batch-writing `001..NNN` `task.md` specifications on `main`, and initializing `.devflow-state.json`.

---

## 1. Full Project Decomposition Rules (`001` to `NNN`)

1. **INVEST & Vertical Slice Discipline:**
   - Every task `001..NNN` must satisfy INVEST criteria (`@devflow/skills/devflow-task/references/invest-criteria.md`) and deliver an observable, testable increment (`@devflow/skills/devflow-task/references/story-splitting.md`).
   - Isolate Read/View flows from Write/Mutation flows where complexity warrants separate PRs.
2. **Contracts & Foundation First (`001`):**
   - Task `001` MUST establish shared foundations: core domain contracts, authentication/session boundaries, base database schema/migrations, or app shell routing required by downstream tasks.
   - If two candidate tasks mutually depend on a shared data model or API contract, extract that shared contract into `001` (or an earlier dedicated blocking task) so no two tasks have circular dependencies.
3. **Strict 3-Digit Sequential Numbering:**
   - Format directories as `devflow/features/[NNN]_[feature-slug]/task.md` (`001_...`, `002_...`, ..., `NNN_...`) ordered by topological dependency rank.

---

## 2. Dependency DAG Verification & Parallelism Rules

Before writing any `task.md` file, construct and verify the inter-task Directed Acyclic Graph (DAG):

1. **Acyclic Check (Zero Cycles):**
   - Verify topological sort succeeds across `001..NNN`. For every task `TASK-K`, all entries in its `**Blockers:**` list must have a strictly lower index (`TASK-J` where `J < K`).
   - If a cycle exists (`A → B → A`), split the shared dependency into an earlier task before writing files.
2. **Explicit Inter-Task Metadata:**
   - **`**Blockers:**`**: comma-separated list of prerequisite task IDs (`TASK-001`, `TASK-002`) that must reach `done` before this task enters `devflow.plan` / `devflow.implement`, or `none` for root tasks (`001`).
   - **`**Unlocks:**`**: comma-separated list of downstream task IDs (`TASK-003`, `TASK-004`) directly unblocked when this task completes, or `none` for leaf tasks.
3. **Parallel-Safe Flagging (`[parallel-safe: yes | no]`):**
   - Default is `no`.
   - Mark two or more tasks `parallel-safe: yes` ONLY when:
     1. They share the exact same satisfied blocker set, AND
     2. They own disjoint directory lanes (`lane: <name>`) with zero overlapping files, AND
     3. Neither task mutates a shared contract, global router table, or database migration consumed by the other.

---

## 3. Master Roadmap Artifact (`devflow/plans/project-blueprint.md`)

Write `devflow/plans/project-blueprint.md` using this structure (adapted from `@devflow/skills/devflow-blueprint/references/blueprint-template.md`):

```markdown
# Project Blueprint — [Project Name]

**ID:** BLUEPRINT-INIT
**Date:** [YYYY-MM-DD]
**Status:** approved
**ADRs:** docs/adr/ADR-001-initial-architecture.md
**Tasks:** [N] total · [P] parallel-safe

---

## Objective

[2-3 sentences summarizing the product domain, target personas, chosen stack/workspace topology, and end-state capability.]

---

## Parallel Workstreams

- Foundation: `TASK-001` (`001_[slug]`) — must complete first
- Wave 1 (after `TASK-001`): `TASK-002` and `TASK-003` [parallel-safe]
- Wave 2 (after `TASK-002`, `TASK-003`): `TASK-004`

---

## Dependency Graph (DAG)

```text
[001] Foundation & Auth
  ├── [002] Core Catalog Read (parallel-safe with [003])
  └── [003] User Profile Settings (parallel-safe with [002])
        └── [004] Checkout & Order Mutation
```

| Task ID | Feature Directory | App | Lane | Blockers | Unlocks | Parallel-Safe |
|---------|-------------------|-----|------|----------|---------|---------------|
| TASK-001 | `001_[slug]` | [app or —] | `lane: core` | none | TASK-002, TASK-003 | no |
| TASK-002 | `002_[slug]` | [app or —] | `lane: catalog` | TASK-001 | TASK-004 | yes (with TASK-003) |
| TASK-003 | `003_[slug]` | [app or —] | `lane: profile` | TASK-001 | TASK-004 | yes (with TASK-002) |
| TASK-004 | `004_[slug]` | [app or —] | `lane: checkout` | TASK-002, TASK-003 | none | no |

---

## Execution Guide

1. All `task.md` specifications (`001` to `[NNN]`) are pre-generated on `main`.
2. Run `/devflow:plan` (with no arguments) to plan `TASK-001` (`001_[first-feature]`), or run `/devflow:run` / `/devflow:auto` per task.
3. When `TASK-001` merges to `main`, `/devflow:plan` automatically resolves the next unblocked un-planned task in topological order (`TASK-002`).
4. For `[parallel-safe]` waves, use `/devflow:worktree` to run concurrent sessions safely in isolated git worktrees.
```

---

## 4. Stay-on-Main Batch `task.md` Generation Rules

1. **Stay on `main` branch:**
   - Do **NOT** run `git switch -c feat/[NNN]_[slug]` while generating tasks in `devflow.init`.
   - All `devflow/features/[NNN]_[slug]/task.md` files are written on `main` so the entire project roadmap is committed and visible from the default branch.
   - Write `**Branch:** feat/[NNN]_[slug]` in each `task.md` header; `devflow.implement` Step 3 creates and switches to that branch when implementation starts for that task.
2. **Complete Specification per Task (No Stubs):**
   - Every `devflow/features/[NNN]_[slug]/task.md` MUST be a complete, self-contained specification conforming to `@devflow/skills/devflow-task/references/task-template.md`:
     - Header with `**ID:** TASK-[NNN]`, `**Date:**`, `**Status:** draft`, `**Branch:** feat/[NNN]_[slug]`, `**App:**` (monorepo only), `**ADRs:** docs/adr/ADR-001-initial-architecture.md`, `**Blockers:**`, and `**Unlocks:**`.
     - `## Goal & Value` (`Problem` + `Objective`, zero empty boosters).
     - `## User Story` (strictly Connextra format with human/external actor).
     - `## Use Cases & Scenarios` (`UC-1` Happy Path + `UC-2`/`UC-3` Edge/Error cases; Read vs Write isolated).
     - `## Acceptance Criteria` (`AC-1 (UC-1)`..`AC-N`, strict BDD Gherkin `GIVEN ... WHEN ... THEN ...`, single `When`, explicit async loading/disabled-submit/error/empty states).
     - `## Scope Boundaries` (`In scope` / `Out of scope`).
     - `## Assumptions & Risks` (`Assumptions` / `Risks`).
3. **Update `docs/product.md` Feature Status Table:**
   - Populate every generated task `001..NNN` into the `<!-- devflow-managed:start:feature-status -->` table in `docs/product.md` with status `planned` and blocker notes (e.g., `Blocked by TASK-001`).

---

## 5. Final `.devflow-state.json` Initialization (Post-Hook Override)

Because the `PostToolUse` hook `hooks/post-task-create.sh` fires on every `Write` to `devflow/features/[NNN]_*/task.md` and sets `next_feature_number` to `NNN + 1`, writing `001` through `NNN` sequentially leaves `.devflow-state.json` without `feature` pointing to `001`.

**Mandatory final step:** After ALL `task.md` files (`001..NNN`) and `docs/product.md` have been written, run `bash "@devflow/scripts/devflow-state.sh" sync 001` — sets `feature`/`feature_path`/`branch`/`task_status` to `001`, `next_step: devflow.plan`, `next_feature_number: NNN+1`; keeps keys it does not own, drops legacy `active_feature`.

Remove temporary `.devflow-init-answers.tmp` if present.
