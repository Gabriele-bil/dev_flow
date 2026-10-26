# Plan - Greenfield Project Bootstrap & Multi-Task Roadmap Initialization

**ID:** PLAN-002
**Task:** [task.md](file:///Users/gabrielebilello/Developer/dev_flow/devflow/features/002_devflow-init/task.md)
**ADRs:** none
**Date:** 2026-10-26
**Status:** pr-opened
**Complexity:** 13 (standard)

---

## Overview

Introduces `/devflow.init` command and `devflow-init` core skill to bootstrap greenfield projects end-to-end: upfront long-running process banner, 3-phase interactive interview, evergreen live-verified technology scaffolding (Nx, Angular, Next.js, Flutter, NestJS), DevFlow context + initial ADR generation, and full topological task decomposition (`001..NNN`) with `project-blueprint.md` on `main`. Updates `devflow-task/references/task-template.md` with optional `**Blockers:**` and `**Unlocks:**` fields, and updates `devflow-plan/SKILL.md` so no-arg `/devflow.plan` resolves the first un-planned unblocked task (`001`) instead of the highest-numbered directory. Registers `devflow.init` across `devflow-discovery`, `agent.yaml`, `README.md`, `templates/devflow/README.md`, and `scripts/build-plugin.sh`.

---

## Architecture decisions

- **ADR alignment:** None / adheres to `ETHOS.md` and `CONTRIBUTING.md` core skill structure (<250 lines in `SKILL.md`, detailed tables extracted to `references/`).
- **Vertical slicing:** 3 vertical slices — Slice 1 delivers the `devflow.init` command, `devflow-init` skill, and its 3 reference modules; Slice 2 updates downstream `devflow-plan` multi-task resolution and `task-template.md` inter-task metadata; Slice 3 wires discovery routing, `agent.yaml` catalog registration, documentation tables, and build baseline.
- **Evergreen scaffolding without stale templates:** `scaffolding-matrix.md` forbids hardcoded package versions; requires live version queries via `context7` MCP / package registries (`npm view <pkg> version`, `flutter pub outdated`) and official `@latest` non-interactive CLI flags (`npx create-nx-workspace@latest`, `npx @angular/cli@latest new`, `npx create-next-app@latest`, `npx @nestjs/cli@latest new`, `flutter create`). Trade-off: requires network + local CLI toolchain when technology scaffolding is enabled; degrades cleanly to DevFlow-only context initialization when declined or offline.
- **Hook-safe batch task generation on `main`:** `devflow-init` stays on `main` while writing `001..NNN` `task.md` files (recording `**Branch:** feat/[NNN]_[slug]` in frontmatter for later creation by `devflow.implement`). Because `post-task-create.sh` overwrites `next_feature_number` on each `task.md` write, `devflow-init` writes the final `.devflow-state.json` (`active_feature: "001_<first-feature>"`, `next_feature_number: "<NNN+1>"`) strictly after all `task.md` writes complete.
- **First-unplanned task resolution in `devflow-plan`:** When invoked without an explicit path, `devflow.plan` checks `.devflow-state.json` (`active_feature` / `feature_path` if `plan.md` does not yet exist) or selects the lowest-numbered `devflow/features/[NNN]_*/task.md` lacking `plan.md` whose `**Blockers:**` are `done`, preserving single-task repo compatibility while supporting multi-task roadmaps.

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `post-task-create.sh` hook clobbers `.devflow-state.json` during batch `task.md` creation | High | Write `.devflow-state.json` as the final step after all `001..NNN` `task.md` files are written, setting `active_feature` to `001_<first>` and `next_feature_number` to `NNN+1` |
| `pre-config-protect.sh` blocks `Write`/`Edit` on `tsconfig*.json`, `eslint.config.*`, `analysis_options.yaml` | High | Generate linter/compiler configs via CLI commands (`npx`, `flutter create`) in Bash rather than `Write`/`Edit` tool calls, or prompt user when manual edit is required |
| `SKILL.md` exceeds 250-line strict validation limit | Med | Keep `templates/devflow/skills/devflow-init/SKILL.md` compact (<220 lines) and extract interview questions, CLI scaffolding matrix, and DAG roadmap templates into `references/*.md` |
| Skill description Jaccard similarity >=50% with `devflow-setup`, `devflow-discover`, or `devflow-blueprint` in `run-evals.sh` | Med | Craft distinct vocabulary in `devflow-init` frontmatter `description` and set `disable-model-invocation: true`; verify with `bash templates/devflow/scripts/run-evals.sh` |

---

## Traceability

| Use Case / Subtask | Acceptance criteria | File(s) |
|---------------------|---------------------|---------|
| UC-1: Upfront Long-Process Notice & Multi-Phase Interactive Interview | AC-1: GIVEN user invokes `devflow.init` WHEN initialization starts THEN system displays explicit long-running process notice AND persists phase progress incrementally | `templates/devflow/commands/devflow.init.md`, `templates/devflow/skills/devflow-init/SKILL.md`, `templates/devflow/skills/devflow-init/references/interview-protocol.md` |
| UC-1: Upfront Long-Process Notice & Multi-Phase Interactive Interview | AC-2: GIVEN `devflow.init` runs discovery interview WHEN gathering product, topology, stack, and convention inputs THEN system asks one question at a time with 2-4 options and `(Recommended)` first | `templates/devflow/skills/devflow-init/SKILL.md`, `templates/devflow/skills/devflow-init/references/interview-protocol.md` |
| UC-2: Evergreen Technology Workspace Scaffolding | AC-3: GIVEN user selects technology scaffolding for Nx, Angular, Next.js, Flutter, or NestJS WHEN scaffolding executes THEN system queries live versions, invokes `@latest` CLI generators, creates layer directories/barrels, and installs latest adapter dependencies | `templates/devflow/skills/devflow-init/SKILL.md`, `templates/devflow/skills/devflow-init/references/scaffolding-matrix.md` |
| UC-3: DevFlow Context, ADR & Ordered Multi-Task Roadmap Generation | AC-4: GIVEN interview and optional scaffolding complete WHEN roadmap generation runs THEN system stays on `main`, writes context files, `ADR-001`, `project-blueprint.md`, and `001..NNN` `task.md` files with `**Blockers:**`/`**Unlocks:**`, and sets `.devflow-state.json` to `001` | `templates/devflow/skills/devflow-init/SKILL.md`, `templates/devflow/skills/devflow-init/references/roadmap-generation.md`, `templates/devflow/skills/devflow-task/references/task-template.md`, `templates/devflow/skills/devflow-discovery/SKILL.md`, `templates/devflow/agent.yaml`, `README.md`, `templates/devflow/README.md`, `scripts/build-plugin.sh` |
| UC-4: Downstream Multi-Task Resolution in Planning | AC-5: GIVEN multiple `devflow/features/[NNN]_*/task.md` files exist without `plan.md` WHEN user invokes `devflow.plan` with no argument THEN system resolves `.devflow-state.json` active un-planned task or selects lowest-numbered unblocked task lacking `plan.md` | `templates/devflow/skills/devflow-plan/SKILL.md` |
| UC-5: DevFlow-Only Initialization Bypassing Technology CLI Generators | AC-4: GIVEN interview and optional scaffolding complete WHEN roadmap generation runs THEN system writes context files, `ADR-001`, `project-blueprint.md`, and `001..NNN` `task.md` files on `main` | `templates/devflow/skills/devflow-init/SKILL.md`, `templates/devflow/skills/devflow-init/references/scaffolding-matrix.md` |
| UC-6: Cyclic Dependency or CLI Scaffold Failure Recovery | AC-6: GIVEN task decomposition or CLI execution encounters a dependency cycle or command failure WHEN validating roadmap or running generators THEN system resolves cycles into foundation task `001` AND halts cleanly on CLI error preserving prior artifacts | `templates/devflow/skills/devflow-init/SKILL.md`, `templates/devflow/skills/devflow-init/references/roadmap-generation.md`, `templates/devflow/skills/devflow-init/references/scaffolding-matrix.md` |

---

## File List

Ordered by implementation sequence.

**Batch:** M

**Slice 1 — Core `devflow.init` Command, Skill & Reference Protocols** (deps: none) [route: strong]

### 001. `templates/devflow/commands/devflow.init.md` - create [done]
- **Change:** Create slash command entry point for `/devflow.init` with `model: opus`, `effort: high`, `disable-model-invocation: true`, and mandatory execution anchors.
- **Contract:** Dispatches `@devflow/skills/devflow-init/SKILL.md` with `$ARGUMENTS` (`[optional-project-name-or-brief] [--mcp]`).
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` and `bash templates/devflow/scripts/run-evals.sh`.
- **Out of scope:** Inline workflow implementation (belongs in `SKILL.md` and `references/`).

### 002. `templates/devflow/skills/devflow-init/SKILL.md` - create [done]
- **Change:** Create core pipeline skill (<250 lines) defining upfront long-process notice, 5-phase workflow (Pre-flight, Interview, Evergreen Scaffolding, Plugin Context + ADR, DAG Roadmap + Batch `task.md` Generation), Common Rationalizations, Anti-Patterns, and I/O Reference.
- **Contract:** References `@devflow/skills/devflow-init/references/interview-protocol.md`, `scaffolding-matrix.md`, and `roadmap-generation.md`.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` (0 errors, 0 warnings, <250 lines) and `bash templates/devflow/scripts/run-evals.sh` (<50% collision).
- **Out of scope:** Modifying adapter contracts under `templates/devflow/adapters/`.

### 003. [P] `templates/devflow/skills/devflow-init/references/interview-protocol.md` - create [done]
- **Change:** Define structured 3-phase interview protocol (Phase A: Product & Scope, Phase B: Workspace Topology including Nx + Stack Selection + Technology Scaffolding Toggle + 6 Discovery Axes, Phase C: Conventions, Coverage & `--mcp`).
- **Contract:** Referenced by `devflow-init/SKILL.md` Step 1.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` (dead-reference check passes).
- **Out of scope:** CLI generator flags (owned by `scaffolding-matrix.md`).

### 004. [P] `templates/devflow/skills/devflow-init/references/scaffolding-matrix.md` - create [done]
- **Change:** Define evergreen technology scaffolding rules for Nx, Angular, Next.js, Flutter, and NestJS: live version lookup (`context7` MCP, `npm view`, `flutter pub outdated`), `@latest` non-interactive CLI commands, `pre-config-protect.sh` compatibility, architectural layer folders + barrel files, and adapter dependency installation/upgrade.
- **Contract:** Referenced by `devflow-init/SKILL.md` Step 2.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` (dead-reference check passes).
- **Out of scope:** Task decomposition rules (owned by `roadmap-generation.md`).

### 005. [P] `templates/devflow/skills/devflow-init/references/roadmap-generation.md` - create [done]
- **Change:** Define full project task decomposition, topological DAG verification, cycle breaking via foundation task `001`, `devflow/plans/project-blueprint.md` format, stay-on-main batch `task.md` generation with `**Blockers:**`/`**Unlocks:**`, `docs/product.md` table population, and final `.devflow-state.json` initialization.
- **Contract:** Referenced by `devflow-init/SKILL.md` Step 4.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` (dead-reference check passes).
- **Out of scope:** Modifying `post-task-create.sh` hook script.

**Batch:** S

**Slice 2 — Downstream Multi-Task Resolution & Task Template Metadata** (deps: 1) [route: mid]

### 006. [P] `templates/devflow/skills/devflow-plan/SKILL.md` - modify [done]
- **Change:** Update Quick Start and Input sections so when `/devflow.plan` runs without an argument, it checks `.devflow-state.json` (`active_feature` / `feature_path` if un-planned) or resolves the first `devflow/features/[NNN]_*/task.md` in ascending numerical order without a `plan.md` whose `**Blockers:**` are satisfied (`done`), falling back to latest `task.md` only when single-task.
- **Contract:** Preserves single-task behavior while enabling `001 → 002 → ... → NNN` multi-task roadmap progression.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` (0 errors, 0 warnings, ≤250 lines).
- **Out of scope:** Changing `plan.md` output sections or Complexity scoring.

### 007. [P] `templates/devflow/skills/devflow-task/references/task-template.md` - modify [done]
- **Change:** Document optional `**Blockers:** [TASK-NNN, ... or "none"]` and `**Unlocks:** [TASK-MMM, ... or "none"]` header fields and format rules for multi-task roadmaps generated by `devflow.init`.
- **Contract:** Consumed by `devflow-init` Step 4 and checked by `devflow-plan` task resolution.
- **Test:** `bash templates/devflow/scripts/validate-doc-links.sh`.
- **Out of scope:** Requiring `Blockers`/`Unlocks` on standalone single-feature `devflow.task` runs.

**Batch:** M

**Slice 3 — Discovery Orientation, Catalog Registration, Docs & Plugin Build** (deps: 1, 2) [route: mid]

### 008. [P] `templates/devflow/skills/devflow-discovery/SKILL.md` - modify [done]
- **Change:** Add `devflow.init` to Pipeline Overview, Entry Point Decision Tree (brand-new greenfield repo from scratch), and Quick Intent Mapping table.
- **Contract:** SessionStart orientation routes greenfield project bootstrap requests to `devflow.init`.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict`.
- **Out of scope:** Changing SessionStart hook scripts.

### 009. [P] `templates/devflow/agent.yaml` - modify [done]
- **Change:** Register `init` step (`/devflow.init`) under `pipeline.steps` and `devflow-init` (`skills/devflow-init/SKILL.md`) under `skills.core`, plus add `devflow.init` to `research` context `suggested_for`.
- **Contract:** Satisfies `run-evals.sh` Check 3 (catalog drift check between `agent.yaml` and filesystem).
- **Test:** `bash templates/devflow/scripts/run-evals.sh` (0 drift errors).
- **Out of scope:** Modifying adapter or agent entries in `agent.yaml`.

### 010. [P] `README.md` - modify [done]
- **Change:** Add `devflow.init` to Pipeline diagram, Commands table, and Repository layout skills list.
- **Contract:** Root documentation accurately reflects `/devflow.init` entry point and skill path.
- **Test:** `bash templates/devflow/scripts/validate-doc-links.sh`.
- **Out of scope:** Editing adapter documentation sections.

### 011. [P] `templates/devflow/README.md` - modify [done]
- **Change:** Add `devflow.init` to Commands table in plugin README.
- **Contract:** Shipped `dist/devflow/README.md` documents `devflow.init`.
- **Test:** `bash templates/devflow/scripts/validate-doc-links.sh`.
- **Out of scope:** Changing hook or context tables.

### 012. `scripts/build-plugin.sh` - modify [done]
- **Change:** Increment `SKILLS_MIN` baseline from `43` to `44` and run `bash scripts/build-plugin.sh` to regenerate `dist/devflow/`.
- **Contract:** Ensures catalog integrity gate accounts for `devflow-init` and syncs `dist/devflow/`.
- **Test:** `bash scripts/build-plugin.sh` exits 0 with 44 skills built.
- **Out of scope:** Modifying builder scripts in `scripts/builders/`.

---

## Implementation checkpoints

- **After Slice 1:** Run `bash templates/devflow/scripts/validate-skills.sh --strict` to verify `devflow-init/SKILL.md` structure, line count (<250), and reference resolution.
- **After Slice 2:** Run `bash templates/devflow/scripts/validate-skills.sh --strict` to verify `devflow-plan/SKILL.md` remains under 250 lines with 0 warnings.
- **After Slice 3:** Run `bash templates/devflow/scripts/run-evals.sh`, `bash templates/devflow/scripts/validate-doc-links.sh`, `bash templates/devflow/scripts/run-hook-tests.sh`, and `bash scripts/build-plugin.sh`.

---

## Edge Cases & Error Handling

- **Pre-existing non-empty directory:** `devflow-init` checks whether target directory already contains `AGENTS.md`/`constitution.md`; if present, warns user and asks whether to run DevFlow-only roadmap/context refresh or abort to `devflow.setup`/`devflow.task`.
- **Single-app vs Nx/Monorepo:** When user selects single-app, `config.md` uses standard 2-field format; when user selects Nx or multi-app monorepo, `config.md` writes `**Mode:** monorepo` + `## Apps` table and each generated `task.md` includes `**App:** <app-name>`.
- **Blocked task in `devflow.plan`:** If `001` has `plan.md` and `002` is blocked by `001` (whose `task.md` Status is not `done`), `devflow.plan` selects the next unblocked task or warns user that `002`'s blocker `TASK-001` is not yet `done`.

---

## Pre-implement checklist

- [x] Constitution Gate passed (Step 0b) — no Critical violations
- [x] Every `task.md` use case / subtask appears in **Traceability** with its acceptance criterion
- [x] Every **File List** entry maps to ≥1 **Traceability** row — no orphan/gold-plated files
- [x] **File list** order respects **Dependency ordering** (and any stated exceptions)
- [x] All **adapter-specific sections** from `ADAPTER.md` are present or correctly omitted per adapter rules
- [x] **Implementation checkpoints** are actionable
- [x] **Open questions** are empty or resolved if **Status** is `ready`
- [x] Existing shared components checked; no duplication of a component already in `shared/`
- [x] New reusable components identified in this plan are listed under their `shared/` path in the **File List**
- [x] `devflow.analyze` run (or explicitly waived) — no Critical findings
- [x] If feature touches persistent entities → `data-model.md` exists and is non-empty (N/A)
- [x] `**Complexity:**` recorded per `references/complexity-scoring.md` — profile floor applied
