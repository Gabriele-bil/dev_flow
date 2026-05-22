# AGENTS.md

> **Scope:** This file is a template bundled with the devflow plugin. It is copied into **consumer projects** by `devflow.setup`. If you are reading this inside `devflow/`, you are in the plugin source repo — use `CLAUDE.md` at the repo root for contributor context instead.

Guidance for AI agents using dev-flow. Read before invoking any devflow command.

## What is dev-flow

Six-step sequential pipeline: task → plan → implement → beautify → test → pr. Each step has strict input/output contracts. Adapters (Flutter, Angular) extend steps with stack-specific rules.

## Intent → Command Mapping

| Intent | Entry point | Condition |
|--------|-------------|-----------|
| Raw feature idea | `devflow.task` | No `task.md` for this feature |
| `task.md` ready, no `plan.md` | `devflow.plan` | `task.md` Status not `draft` with unresolved questions |
| `plan.md` ready, not implemented | `devflow.implement` | `plan.md` Status == `ready` |
| Implementation done, needs review | `devflow.beautify` | `devflow.implement` summary exists, analyze passes |
| Beautify done, needs tests | `devflow.test` | `devflow.beautify` complete |
| Tests pass, ready to merge | `devflow.pr` | All pipeline steps complete |
| No context files in consumer root | `devflow.setup` | No `AGENTS.md`, `REGISTRY.md`, or `docs/product.md` |

Never start mid-pipeline without verifying entry-point skill's input contract.

## Execution Model

1. Identify pipeline step (table above)
2. Run slash command
3. Skill verifies input contract — do not bypass
4. Follow skill exactly; do not skip or merge steps
5. User is orchestrator — skills do not invoke other skills

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "Feature is small — skip task.md, plan directly" | `task.md` HMW + scope + assumptions prevent plan rework. Start at correct entry point |
| "I know what to build — skip plan.md" | `plan.md` traceability table is only guarantee `devflow.implement` covers all subtasks |
| "Merge beautify and test to save time" | Each step has strict contracts. Merging → silent gaps and untraceable deviations |
| "Fix architecture during beautify" | Architecture decisions belong in `plan.md`. Post-implement fixes are rework |
| "Context files exist — skip devflow.setup" | Incomplete context files → silent gaps in adapter resolution. Run `devflow.setup --force` to regenerate |

## Adapter Resolution

Every pipeline step (except `devflow.task` and `devflow.setup`) requires adapter resolution first:

1. Read `@devflow/config.md` — get active adapter name
2. Read `@devflow/adapters/<adapter>/ADAPTER.md` — authoritative for stack-specific rules

**Common skills** (`@devflow/adapters/common/skills/`) apply to all adapters unless ADAPTER.md overrides.

## Orchestration Rules

- User is orchestrator. Skills do not invoke other skills.
- Each step reads previous step's output: `task.md` → `plan.md` → implement summary → beautify summary → test results.
- Active adapter is singular per project (`config.md`). Adapters do not invoke each other.
- Common skills are stack-agnostic baselines. ADAPTER.md overrides or extends for active stack.

## Creating a New Adapter

1. Copy `adapters/flutter/` as template
2. Rename to `adapters/<name>/`
3. Rewrite `ADAPTER.md` with stack rules (Technology skills table, MCP, commands, pre-handoff checklists)
4. Add technology skills under `adapters/<name>/skills/<name>-<domain>/SKILL.md`
5. Add setup templates under `adapters/<name>/templates/`
6. Set `config.md` in consumer project to new adapter name
7. Run `devflow.setup --force` to regenerate consumer context files

## Creating a New Skill

See `CONTRIBUTING.md` for quality bar, naming conventions, required sections, style rules.
