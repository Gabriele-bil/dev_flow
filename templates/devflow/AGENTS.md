# AGENTS.md — DevFlow plugin

> **Scope:** agent guide for the DevFlow plugin itself (shipped in the plugin bundle). Consumer projects get their own `AGENTS.md` rendered by `devflow.setup` from `adapters/<adapter>/templates/AGENTS.template.md` — this file is never copied there. Plugin contributors: read `CONTRIBUTING.md` + root `CLAUDE.md`.

Read before invoking any devflow command.

## Pipeline

```text
task → [clarify] → plan → [analyze] → implement → beautify → test → ship → pr
```

Bracketed steps optional. Each step has a strict input contract; status lives in `plan.md` (`references/state-machine.md`). Hotfix fast-track: compact task+plan → implement → test → quick ship → pr.

## Intent → Command

| Intent | Command | Condition |
| --- | --- | --- |
| No context files in consumer root | `devflow.setup` | No `devflow/config.md` |
| Greenfield project, full roadmap | `devflow.init` | Empty repo |
| Architectural choice / ADR | `devflow.discover` | Trade-offs unresolved |
| Large objective, multiple PRs | `devflow.blueprint` | Before task |
| Raw feature idea | `devflow.task` | No `task.md` yet |
| `task.md` has `[NEEDS CLARIFICATION]` | `devflow.clarify` | task `draft` |
| `task.md` ready | `devflow.plan` | task `draft` (no markers) / `clarified` |
| Plan ready / implement interrupted | `devflow.implement` | plan `ready` / `implementing` |
| Implementation done | `devflow.beautify` | plan `implemented` |
| Review done | `devflow.test` | plan `beautified` |
| Tests + verification pass | `devflow.ship` | plan `tested` |
| Ship gate passed | `devflow.pr` | plan `shipped` |
| Where am I / what next | `devflow.status` | any |
| Session interrupted | `devflow.resume` | state consistent |
| Stuck, `blocked`, or inconsistent state | `devflow.recovery` | — |
| Urgent bugfix | `devflow.hotfix` | small, root cause known |

Active feature without explicit argument → `references/state-machine.md` → **Active feature resolution**. Session orientation → `references/orientation.md`.

## Orchestration

- User orchestrates by default: one command per step, contracts verified at each entry — never bypass.
- Orchestrator skills chain other skills explicitly and only them: `devflow.ship` (→ `devflow.pr`; fix loop → implement/beautify/test), `devflow.run` (implement → beautify → test [→ ship]), `devflow.auto` (task → … → pr), `devflow.hotfix` (→ `devflow.pr`). Run-mode contract: `references/run-mode.md`.
- Each step writes its status boundary to `plan.md` — never skip or merge steps.

## Adapters

Four stacks: `angular`, `flutter`, `nestjs`, `nextjs` (+ stack-agnostic `common` skills). Resolve adapter + app per `references/adapter-resolution.md` (single-app or monorepo `## Apps` table) — never inline a `config.md` read. `ADAPTER.md` + `steps/<step>.md` = authoritative stack rules; common skills apply unless `ADAPTER.md` overrides.

## Anti-Rationalization

| Thought | Reality |
| --- | --- |
| "Feature is small — skip task.md" | Scope + assumptions in `task.md` prevent plan rework |
| "I know what to build — skip plan.md" | Traceability table is the only guarantee implement covers every AC |
| "Merge beautify and test" | Each boundary writes its status; resume, ship, hooks depend on it |
| "Tests passed — skip ship" | Ship gate = independent multi-agent review before PR |
| "Context files exist — skip setup" | Incomplete context → silent adapter-resolution gaps; `devflow.setup --force` |

## Extending

New skill or adapter → `CONTRIBUTING.md` (quality bar, required sections, naming, 100-line rule).
