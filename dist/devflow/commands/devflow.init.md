---
name: devflow.init
description: Bootstrap a greenfield project end-to-end — upfront long-running process notice, multi-phase interview, evergreen technology scaffolding (Nx, Angular, Next.js, Flutter, NestJS), DevFlow context + ADR-001 generation, and ordered multi-task roadmap generation with inter-task dependencies.
argument-hint: "[optional-project-name-or-brief] [--mcp]"
disable-model-invocation: true
model: opus
effort: high
---

Use `@devflow/skills/devflow-init/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Immediately emit the upfront long-process notice informing the user that `devflow.init` is a deep, multi-phase architectural and planning workflow that takes all necessary time to execute thoroughly without rushing and persists progress incrementally at each phase boundary.
- Ask or detect target directory (`<project-slug>/` vs current directory) and explicitly ask whether to scaffold full technology files (**Nx, Angular, Next.js, Flutter, NestJS**) alongside DevFlow plugin context files.
- Run the structured 3-phase interview (`@devflow/skills/devflow-init/references/interview-protocol.md`) one question at a time via `AskQuestion` / `ask_question` with 2–4 options and `(Recommended)` first.
- When technology scaffolding is enabled, enforce the **Always Up-to-Date** guarantee (`@devflow/skills/devflow-init/references/scaffolding-matrix.md`): query live docs/registries (`context7` MCP, `npm view`, `flutter pub outdated`), invoke official `@latest` non-interactive CLIs, create architectural layer directories + barrel files, and install latest adapter setup dependencies. Never hardcode stale package versions or obsolete config schemas.
- Generate `@devflow/config.md`, `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md` (with `devflow-managed` markers), `docs/adr/ADR-001-initial-architecture.md`, `docs/adr/README.md`, and optional MCP config (`--mcp`).
- Decompose the entire project into a validated topological DAG, write `devflow/plans/project-blueprint.md`, stay on `main` branch while batch-generating `devflow/features/[NNN]_[feature-name]/task.md` (`001` to `NNN`) with `**Blockers:**` and `**Unlocks:**` fields, populate `docs/product.md`, and write `.devflow-state.json` last with `active_feature: "001_<first-feature>"` and `next_step: "devflow.plan"` (`@devflow/skills/devflow-init/references/roadmap-generation.md`).

User input (optional project name/brief, plus optional `--mcp`):
`$ARGUMENTS`
