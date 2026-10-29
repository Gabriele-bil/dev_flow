---
name: devflow-init
description: "Bootstraps greenfield projects end-to-end: conducts a multi-phase interview, scaffolds evergreen workspaces (Nx, Angular, Next.js, Flutter, NestJS), generates plugin context and ADR-001, and writes an ordered multi-task roadmap with inter-task dependencies. Use when user runs devflow.init or starts a brand-new project from scratch."
argument-hint: "[optional-project-name-or-brief] [--mcp]"
disable-model-invocation: true
---


# Skill: devflow.init

## Quick Start

Run `/devflow.init [optional-project-name-or-brief] [--mcp]`.

- Emits upfront long-process notice and runs 3-phase interview (Product → Topology/Stack → Conventions)
- Optionally scaffolds evergreen technology files (Nx, Angular, Next.js, Flutter, NestJS) via live registry lookup + `@latest` CLIs
- Writes DevFlow context (`AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md`), `ADR-001`, `devflow/plans/project-blueprint.md`, and ordered `devflow/features/[NNN]_[slug]/task.md` (`001..NNN`) on `main`

## Purpose

Bootstrap greenfield software projects end-to-end: structured discovery interview, initial ADR, live-verified technology workspace scaffolding, DevFlow context setup, and topological multi-task roadmap generation. Zero-to-roadmap entry point preceding `devflow.plan`.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` are written and approved
- **traceability** — every subtask maps to an acceptance criterion; every acceptance criterion maps to one or more files
- **vertical slices** — for plans with >5 files: implement end-to-end user-visible increments, never layers
- **token-lean** — caveman-compress all written output: drop articles, hedging, filler, linking phrases; keep technical terms, file paths, commands, verbs, negations, conditions exact

## When NOT to Use

- Repository already has `AGENTS.md`, `constitution.md`, and active features — use `devflow.task` or `devflow.blueprint` for new work, or `devflow.setup` to refresh context files
- Exploring a single feature's technical trade-offs inside an existing app — use `devflow.discover`
- Adding one standalone feature idea and shipping straight to PR — use `devflow.task` or `devflow.auto`
- Resuming an interrupted session — use `devflow.resume`

## Input contract

Before proceeding, verify:

- [ ] Target directory is accessible and writable (current working directory or parent of `<project-slug>/`)
- [ ] No active `.devflow-run.json` from a crashed autonomous session (if present, confirm cleanup or route `devflow.recovery`)
- [ ] If target directory already contains `constitution.md` or `devflow/features/`, ask user whether to run DevFlow-only roadmap/context initialization or stop and route to `devflow.setup` / `devflow.task`

If any item fails → stop, report which check failed, do not write files.

## Workflow

### Step 0 — Upfront Long-Process Notice & Pre-Flight

1. Immediately display this banner before asking questions:

```text
🏗️ devflow.init — End-to-End Greenfield Project Bootstrap
Phases: 1. Multi-Phase Interview → 2. Evergreen Tech Scaffolding → 3. Context & ADR-001 → 4. Topological Roadmap & Batch task.md (001..NNN)
Notice: Deep architectural and planning workflow. Takes all necessary time to execute thoroughly without rushing. Progress is persisted to disk after each phase boundary.
```

2. Parse `$ARGUMENTS` for optional project name/brief and `--mcp` flag.
3. Ask target directory mode via `AskQuestion` / `ask_question` (create `<project-slug>/` subfolder vs initialize in current directory) and whether to run **full technology file scaffolding** (Nx, Angular, Next.js, Flutter, NestJS) in addition to DevFlow plugin files.

### Step 1 — Multi-Phase Structured Interview

Execute the 3-phase interview per `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/interview-protocol.md`:

- Ask **one question at a time** via `AskQuestion` / `ask_question` (2–4 options, first option prefixed `(Recommended)` with 1-sentence technical rationale).
- **Phase A (Product & Scope):** Project name/slug, domain, target personas (real human/external actors, never technical roles), primary outcome, complete feature inventory (core + secondary flows), async/edge expectations.
- **Phase B (Architecture, Workspace & Technology Stack):**
  - Workspace topology: Single-app vs Monorepo (explicitly supporting **Nx workspace** orchestration alongside standard multi-app folders).
  - Stack per app: **Angular**, **Next.js**, **Flutter**, **NestJS** (+ **Nx** when selected).
  - Technology scaffolding confirmation: generate live config/entry files (`nx.json`, `project.json`, `angular.json`, `next.config.ts`, `nest-cli.json`, `pubspec.yaml`, `analysis_options.yaml`, `tsconfig.base.json`, `eslint.config.mjs`, entrypoints, layer folders) vs DevFlow-only files.
  - Architectural drivers across the 6 discovery axes (`$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-discover/references/discovery-axes.md`): data/DB (`Supabase`, `PostgreSQL`, none), auth, state, observability (`Sentry`), scale.
- **Phase C (Conventions & Quality):** Layering rules, naming/import conventions, test coverage threshold, `--mcp` client target (if requested).

### Step 2 — Evergreen Technology Scaffolding (Always Up-to-Date Guarantee)

Execute directory initialization and optional technology scaffolding per `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/scaffolding-matrix.md`:

1. **Workspace & Git init:** Create `<project-slug>/` (if subfolder mode), `cd` into root, run `git init -b main` (if `.git` absent), write `.gitignore` (stack ignores + `.devflow-state.json`, `.devflow-run.json`, `.devflow-*.jsonl`, `.devflow-*.tmp`), and create `devflow/features/`, `devflow/plans/`, `docs/adr/`.
2. **If technology scaffolding is enabled, enforce the Always Up-to-Date rule:**
   - **Zero hardcoded stale versions:** Never write static templates with outdated package versions or legacy config schemas (e.g. no `.eslintrc.json`, no Angular NgModules, no Next.js Pages router).
   - **Live version & config resolution:** Query `context7` MCP (or stack MCPs: `dart`, `angular-cli`, `next-devtools`) and live registries (`npm view <pkg> version`, `flutter pub outdated`) to confirm current latest stable conventions before generating files.
   - **Official `@latest` CLI execution & hook safety:** Run non-interactive `@latest` CLI generators (`npx create-nx-workspace@latest`, `npx @angular/cli@latest new`, `npx create-next-app@latest`, `npx @nestjs/cli@latest new`, `flutter create`) in Bash so linter/compiler configs (`tsconfig*.json`, `eslint.config.mjs`, `analysis_options.yaml`) are created by official CLIs without triggering `pre-config-protect.sh` blocks.
   - **Architectural layers & barrels:** Create layer directories (`domain/`, `data/`, `ui/`, `core/`, `shared/`, `app/`) and barrel files (`index.ts`, `index.dart`, `public-api.ts`) matching `constitution.md`.
   - **Adapter setup dependencies:** Install packages from `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/steps/setup.md` (`Setup dependencies`) per app using latest compatible versions (`pnpm add <pkg>@latest` / `flutter pub add` + `flutter pub upgrade --major-versions`) and verify clean static analysis.
3. If any CLI generator or install command fails: halt immediately, report exact command and stderr, preserve completed artifacts on disk, do not claim scaffolding complete.

### Step 3 — DevFlow Plugin Context & Initial ADR Generation

1. **Write `@devflow/config.md`:** Single-app (`**Adapter:** <adapter>`) or Monorepo (`**Mode:** monorepo` + `## Apps` table) per `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-setup/references/config-template.md`.
2. **Render & write context files:** Load adapter templates (`$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/templates/` → fallback `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-setup/templates/`), resolve placeholders per `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-setup/references/placeholder-map.md`, enforce token budgets (`AGENTS.md` <300t, `REGISTRY.md` <600t, `docs/product.md` <700t, `constitution.md` <530t), and write `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md` wrapped in `<!-- devflow-managed:start:<section-id> -->` / `<!-- devflow-managed:end:<section-id> -->` markers.
3. **Write Initial ADR:** Create `docs/adr/ADR-001-initial-architecture.md` using `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-discover/references/adr-template.md` (recording multi-axis context, 2–3 considered stack/topology options with real trade-offs, chosen architecture, and component layout) and `docs/adr/README.md` index table.
4. **Optional MCP configuration (`--mcp`):** Emit or write client MCP config (`mcp_config.json` / `.mcp.json`) resolving universal baseline + active stack core + conditional servers (`supabase`, `postgres`, `sentry` ONLY when chosen) per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/mcp-catalog.md`.

### Step 4 — Full Project Task Decomposition, DAG Verification & Batch `task.md` Generation

Decompose project and generate all tasks on `main` per `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/roadmap-generation.md`:

1. **Decompose into vertical tasks (`001..NNN`):** Split feature inventory into INVEST-compliant vertical increments (`$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/invest-criteria.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/story-splitting.md`). Place foundational shared contracts/schemas/auth in `001_<foundation-slug>`.
2. **Verify Dependency DAG:** Ensure zero circular dependencies (if cycle detected, extract shared contract into `001`), assign explicit `Blockers` (`TASK-NNN` or `none`) and `Unlocks` (`TASK-MMM` or `none`), assign `lane` ownership, and mark `[parallel-safe: yes]` ONLY when blockers are identical and zero files/contracts overlap (default `no`).
3. **Write master blueprint:** Write `devflow/plans/project-blueprint.md` containing the ASCII dependency DAG, Blockers/Unlocks table, parallel workstreams, lane ownership, and execution guide.
4. **Batch-generate `task.md` files on `main` (do NOT switch branches):**
   - Stay on `main` branch throughout Step 4. Never run `git switch -c feat/...` during batch task generation.
   - Pre-populate `**Branch:** feat/[NNN]_[feature-name]` in each `task.md` header (`devflow.implement` creates/switches to the branch when that task executes).
   - For every feature `001` through `NNN` in ascending topological order, write `devflow/features/[NNN]_[feature-name]/task.md` following `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/task-template.md`, including `**ADRs:** docs/adr/ADR-001-initial-architecture.md`, `**Blockers:**`, `**Unlocks:**`, Connextra User Story, Read/Write isolated `UC-1..UC-N`, single-`When` BDD Gherkin `AC-1..AC-N` with explicit async states, Scope Boundaries, and Assumptions & Risks.
5. **Populate `docs/product.md`:** Fill the `devflow-managed:feature-status` table with all tasks `001..NNN` in topological order (`status: planned`, blocker notes, and `App` column in monorepo mode).
6. **Final State Initialization (MUST run after all `task.md` writes):** Because `post-task-create.sh` updates `.devflow-state.json` on each `task.md` write, merge into `.devflow-state.json` one final time after `NNN` finishes (schema: `$HOME/.gemini/antigravity-cli/plugins/devflow/references/state-machine.md` → **State file schema**; never write `active_feature`):
   - `feature`: `"001_<first-feature>"`
   - `feature_path`: `"devflow/features/001_<first-feature>"`
   - `branch`: `"feat/001_<first-feature>"`
   - `task_status`: `"draft"`
   - `next_feature_number`: `<NNN+1>` (int)
   - `next_step`: `"devflow.plan"`

### Step 5 — Completion Summary & Handoff

Emit consolidated initialization report: project root, topology & stack(s), scaffolded apps + analysis verdict, generated context/ADR files, total tasks (`001..NNN`) + parallel-safe count in `devflow/plans/project-blueprint.md`, and next step (`/devflow.plan` — automatically resolves `001_<first-feature>`).

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Hardcode standard package versions in package.json/pubspec.yaml to save time" | Hardcoded versions rot immediately. Query `context7` / registry and use `@latest` CLIs |
| "Generate only task 001 now and let user run devflow.task later" | `devflow.init` contract requires full project decomposition (`001..NNN`) with verified DAG upfront |
| "Create and switch git branches for each task during batch generation" | Switching branches N times leaves tasks scattered or dirty. Stay on `main` and record `**Branch:**` in `task.md` |
| "Skip final `.devflow-state.json` write since `post-task-create.sh` runs automatically" | Hook only sets `next_feature_number` from last task `NNN`; final write is required to point `feature` to `001` |
| "Write `tsconfig.json` or `eslint.config.mjs` directly via Write tool" | `pre-config-protect.sh` blocks Write/Edit on linter/tsconfig files; scaffold via official CLI commands in Bash |

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Dumping all interview questions in one wall of text | Overwhelms user and skips adaptive follow-ups | Ask one bounded question at a time via `AskQuestion` with `(Recommended)` first |
| Using legacy stack flags (`--no-standalone`, Pages router, `.eslintrc.json`) | Violates adapter rules and modern stack baselines | Follow `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/scaffolding-matrix.md` and live `context7` docs |
| Leaving circular blockers between tasks (`002` ↔ `003`) | Deadlocks planning and implementation order | Extract shared contracts/types into foundation task `001` before consumers |
| Omitting `**Blockers:**` / `**Unlocks:**` in generated `task.md` files | Downstream `devflow.plan` cannot verify unblocked execution order | Populate explicit `**Blockers:**` and `**Unlocks:**` headers in every roadmap `task.md` |
| Writing Technical Personas ("As a backend developer") in `task.md` | Violates `devflow-task` product-only spec discipline | Use real human or external system actors and functional BDD Gherkin ACs |

## I/O Reference

| | |
| --- | --- |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/interview-protocol.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/scaffolding-matrix.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/roadmap-generation.md` |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/ADAPTER.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/steps/setup.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-setup/references/config-template.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-setup/references/placeholder-map.md` |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-discover/references/discovery-axes.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-discover/references/adr-template.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/mcp-catalog.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/task-template.md` |
| Writes | `<project-slug>/` technology scaffold (optional: Nx, Angular, Next.js, Flutter, NestJS), `.gitignore`, `@devflow/config.md`, `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md` |
| Writes | `docs/adr/ADR-001-initial-architecture.md`, `docs/adr/README.md`, `devflow/plans/project-blueprint.md`, `devflow/features/[NNN]_[feature-name]/task.md` (`001..NNN`), `.devflow-state.json` |
| Next step | `devflow.plan` (resolves `001_<first-feature>`) |
