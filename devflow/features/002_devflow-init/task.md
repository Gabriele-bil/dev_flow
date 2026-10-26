# Task - Greenfield Project Bootstrap & Multi-Task Roadmap Initialization

**ID:** TASK-002
**Date:** 2026-10-26
**Status:** done
**Branch:** feat/002_devflow-init
**ADRs:** none

---

## Goal & Value

- **Problem:** Starting a new project from scratch requires manually creating directories, running stack CLI generators, verifying current package versions and configuration formats, invoking discovery, setup, and blueprint commands separately, and manually drafting individual task specifications for every feature. Furthermore, when multiple tasks are pre-generated upfront, the planning step selects the highest-numbered directory instead of the first un-planned task (`001`).
- **Objective:** Deliver a unified greenfield initialization command (`devflow.init`) and core skill (`devflow-init`) that displays an upfront long-process notice, conducts a structured multi-phase interview, optionally scaffolds evergreen technology workspaces (Nx, Angular, Next.js, Flutter, NestJS) verified against live documentation and package registries, generates DevFlow context and ADR files, decomposes the full project into ordered `task.md` specifications with inter-task dependencies on `main`, and updates `devflow.plan` to resolve the first unblocked un-planned task.

---

## User Story

**As a** developer starting a greenfield software project with DevFlow  
**I want to** initialize the project architecture, live technology scaffold, plugin context files, and ordered feature roadmap through a single guided workflow  
**So that** I can move from a raw project brief to a buildable repository with dependency-ordered specifications ready for sequential or parallel execution  

---

## Use Cases & Scenarios

### UC-1: Upfront Long-Process Notice & Multi-Phase Interactive Interview (Happy Path — Read/Elicitation)
- **Preconditions:** User invokes `/devflow.init` in an empty directory or parent workspace with an optional project name/brief and optional `--mcp` flag.
- **User Flow:**
  1. System immediately displays a prominent banner explaining that initialization is a multi-phase workflow that persists progress incrementally at each phase boundary.
  2. System asks one bounded question at a time (2-4 options, `(Recommended)` first with rationale) across Phase A (product, personas, feature inventory), Phase B (single-app vs monorepo/Nx, stack selection per app across Angular/Next.js/Flutter/NestJS, technology scaffolding toggle, 6 discovery axes), and Phase C (conventions, coverage threshold, MCP config).
  3. User confirms architectural direction and target directory.
- **Outcome:** Confirmed product scope, workspace topology, stack selections, and scaffolding preferences are captured for generation.

### UC-2: Evergreen Technology Workspace Scaffolding (Write — Optional Stack Generation)
- **Preconditions:** User opted into full technology file scaffolding during Phase B.
- **User Flow:**
  1. System initializes `<project-slug>/`, runs `git init -b main`, and writes `.gitignore` and DevFlow folders (`devflow/features/`, `devflow/plans/`, `docs/adr/`).
  2. System queries live documentation and package registries to verify current latest stable versions and configuration formats for selected stacks (Nx, Angular, Next.js, Flutter, NestJS).
  3. System runs non-interactive `@latest` CLI generators, creates architectural layer directories and barrel files, installs adapter setup dependencies, and runs initial static analysis verification.
- **Outcome:** Project directory contains an up-to-date, cleanly analyzing technology workspace matching declared architecture layers.

### UC-3: DevFlow Context, ADR & Ordered Multi-Task Roadmap Generation (Write — Artifact Batch)
- **Preconditions:** Interview answers are finalized and directory structure is initialized on `main`.
- **User Flow:**
  1. System generates `devflow/config.md`, `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md`, and `docs/adr/ADR-001-initial-architecture.md` (plus `docs/adr/README.md` and optional MCP config).
  2. System decomposes project scope into INVEST-compliant vertical tasks (`001` to `NNN`), verifies an acyclic dependency graph (DAG), and writes `devflow/plans/project-blueprint.md`.
  3. Staying on `main`, system generates `devflow/features/[NNN]_[slug]/task.md` in ascending topological order with `**Blockers:**` and `**Unlocks:**` fields, populates `docs/product.md`, and writes `.devflow-state.json` pointing to `001_<first-feature>` and `next_step: devflow.plan`.
- **Outcome:** All project context files, initial ADR, master blueprint, and ordered `task.md` files exist on `main` with active state set to task `001`.

### UC-4: Downstream Multi-Task Resolution in Planning (Read/Write — Plan Target Selection)
- **Preconditions:** Repository contains multiple pre-generated `devflow/features/[NNN]_*/task.md` directories and user runs `/devflow.plan` without an explicit path argument.
- **User Flow:**
  1. System inspects `.devflow-state.json` (`active_feature` / `feature_path` if un-planned) and scans `devflow/features/[NNN]_*/` in ascending numerical order.
  2. System selects the first task that does not yet have a `plan.md` and whose declared `**Blockers:**` are satisfied (`done` / merged).
  3. System generates `plan.md` in that resolved feature directory.
- **Outcome:** `/devflow.plan` plans `001_<first-feature>` first rather than jumping to the highest-numbered task directory.

### UC-5: DevFlow-Only Initialization Bypassing Technology CLI Generators (Alternative Flow)
- **Trigger:** User declines technology file scaffolding during Phase B (or initializes DevFlow inside an existing code repository).
- **Expected Behavior:** System skips CLI stack scaffolding and package installation, creates only DevFlow directories, context files (`AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md`), `ADR-001`, `project-blueprint.md`, and ordered `task.md` files, and sets `.devflow-state.json` to task `001`.

### UC-6: Cyclic Dependency or CLI Scaffold Failure Recovery (Error Handling)
- **Trigger:** Task decomposition detects a circular blocker cycle, or a stack CLI generator / package install command fails during scaffolding.
- **Expected Behavior:** For circular dependencies, system splits shared contracts into an earlier foundation task (`001`) before writing task files; for CLI/network failures, system logs exact failing command and stderr, preserves completed phase artifacts on disk, and halts with recovery instructions instead of writing partial state.

---

## Acceptance Criteria

- [ ] **AC-1 (UC-1) — Upfront Notice & Phase Progress:** GIVEN user invokes `devflow.init` WHEN initialization starts THEN system displays an explicit long-running process notice before asking questions AND persists phase progress incrementally to disk after each completed phase
- [ ] **AC-2 (UC-1) — Structured Multi-Phase Elicitation:** GIVEN `devflow.init` runs the discovery interview WHEN gathering product, topology (single-app vs monorepo/Nx), stack (Angular, Next.js, Flutter, NestJS), and convention inputs THEN system asks one question at a time with 2-4 options and `(Recommended)` first
- [ ] **AC-3 (UC-2) — Evergreen Stack Scaffolding:** GIVEN user selects technology scaffolding for Nx, Angular, Next.js, Flutter, or NestJS WHEN scaffolding executes THEN system queries live registry/documentation versions, invokes non-interactive `@latest` CLI generators, creates layer directories and barrel files, and installs latest adapter dependencies without hardcoded stale versions
- [ ] **AC-4 (UC-3, UC-5) — Context, ADR & Batch Task Generation on Main:** GIVEN interview and optional scaffolding complete WHEN roadmap generation runs THEN system stays on `main` branch, writes `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md`, `docs/adr/ADR-001-initial-architecture.md`, `devflow/plans/project-blueprint.md`, and every `devflow/features/[NNN]_[slug]/task.md` with `**Blockers:**` and `**Unlocks:**` fields, and sets `.devflow-state.json` `active_feature` to `001_<first-feature>`
- [ ] **AC-5 (UC-4) — First Unplanned Task Resolution:** GIVEN multiple `devflow/features/[NNN]_*/task.md` files exist without `plan.md` WHEN user invokes `devflow.plan` with no argument THEN system resolves `.devflow-state.json` active un-planned task or selects the lowest-numbered `NNN` task lacking `plan.md` whose blockers are satisfied
- [ ] **AC-6 (UC-6) — DAG Validation & Error Recovery:** GIVEN task decomposition or CLI execution encounters a dependency cycle or command failure WHEN validating roadmap or running generators THEN system resolves cycles by extracting shared contracts into foundation task `001` AND halts cleanly on CLI error while preserving prior phase artifacts

---

## Scope Boundaries

**In scope**

- Slash command `templates/devflow/commands/devflow.init.md` and core skill `templates/devflow/skills/devflow-init/SKILL.md` (<250 lines).
- Reference guides: `interview-protocol.md`, `scaffolding-matrix.md` (Nx, Angular, Next.js, Flutter, NestJS live version lookup & CLI flags), and `roadmap-generation.md` (DAG rules, batch generation on `main`, state initialization).
- Updates to `devflow-plan/SKILL.md` (first unblocked un-planned task resolution), `devflow-task/references/task-template.md` (`**Blockers:**` and `**Unlocks:**` fields), `devflow-discovery/SKILL.md`, `agent.yaml`, `README.md`, `templates/devflow/README.md`, `scripts/build-plugin.sh`, and `dist/devflow/`.

**Out of scope (Not doing)**

- Implementing application business logic for every generated `task.md` during `devflow.init` (implementation happens per task via `devflow.implement` / `devflow.run` / `devflow.auto`).
- Adding new technology adapters outside the supported adapter catalog (`angular`, `nextjs`, `flutter`, `nestjs`, plus `nx` workspace orchestration).

---

## Assumptions & Risks

### Assumptions

- Host environment has network access and relevant runtime CLIs (`node`/`npx`/`pnpm`, `flutter`/`dart`, `git`) when user opts into live technology scaffolding.
- Pre-generated `task.md` files remain on `main` during initialization; feature branches (`feat/NNN_slug`) are created when each task enters implementation.

### Risks

- `post-task-create.sh` hook updates `.devflow-state.json` on each `task.md` write, which during batch generation of `001..NNN` would leave state pointing only to `NNN+1` without active feature `001`; mitigated by writing final `.devflow-state.json` after all `task.md` writes complete.
- `pre-config-protect.sh` blocks `Write`/`Edit` tool calls on protected linter/tsconfig files (`tsconfig*.json`, `eslint.config.*`, `analysis_options.yaml`); mitigated by generating config files via official CLI scaffolding commands in Bash or asking user when manual override is required.

---

## Notes

- Autonomous run (`devflow.auto`): requirements provided in full detail in user prompt; no unresolved ambiguities remain.
