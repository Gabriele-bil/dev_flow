# Adapter Resolution

Shared algorithm for resolving "the active adapter" (+ its working directory). Every skill/command that previously read `@devflow/config.md` inline for adapter identity points here instead — one place to change monorepo behavior, not sixteen.

## Mode detection

Read `@devflow/config.md`.

- `## Apps` heading present → **monorepo mode**.
- Absent, `**Adapter:**` field present → **single-app mode** (today's shape, unchanged).

## Single-app mode

- `adapter` = `**Adapter:**` field value.
- `adapter_root` = `**Adapter root:**` field value.
- `app_path` = consumer project root (`.`).

Identical to pre-monorepo behavior — no new reads, no new questions.

## Monorepo mode

1. Resolve `app` = the current feature's `**App:**` field, read from its `plan.md` header (propagated there from `task.md` by `devflow.plan` — see that skill's Step 0). Do not re-read `task.md` for this; `plan.md` already carries it once written.
2. `plan.md` missing the `**App:**` field while `config.md` is in monorepo mode → **hard stop**. Ask the user which app this feature targets; never guess, never default to the first row.
3. Look up `app` in the `## Apps` table of `config.md` for that row's `Adapter`, `Adapter root`, and `Path` columns.
4. `app` not found in the table → hard stop, list valid app names from the table, ask again.

## Load adapter contract (both modes, once `adapter`/`adapter_root` known)

- `@devflow/adapters/<adapter>/ADAPTER.md` (core: technology skills, MCP).
- `@devflow/adapters/<adapter>/steps/<step>.md` for the active step's commands, plan sections, checklists.
- Legacy adapters without `steps/`: all sections live in `ADAPTER.md` — read it in full.

## Working-directory scoping (monorepo only)

Every shell command sourced from an adapter's `ADAPTER.md`/`steps/*.md` (format, lint, analyze, build, test, codegen) runs with working directory = the resolved app's `Path`, not the repo root. Run it as a subshell — `(cd "<path>" && <command>)` — so the skill's own shell cwd is never mutated across steps. Single-app mode: `app_path` is `.`, so this is a no-op — commands run exactly as before.

## Per-skill: where "the active feature" (and its App) comes from

| Skill/command | Finds active feature via | App source |
| --- | --- | --- |
| `devflow-task` | creating a new feature (no file yet) | asks, or `--app` argument (monorepo only) |
| `devflow-plan` | `task.md` at Input path | reads that `task.md`'s `**App:**`; copies into new `plan.md` header |
| `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-ship`, `devflow-pr`, `devflow-run` | `plan.md` at Input/resolved path | that `plan.md`'s own `**App:**` header field |
| `devflow-recovery`, `devflow-resume` | `active_feature` from `.devflow-state.json` or latest `plan.md` | same `plan.md` header |
| `devflow-status` | enumerates all features in `devflow/features/` | shows App per row, from each feature's `plan.md` header — no single resolution |
| `devflow-discovery` | active feature if one exists, else session orientation | resolves active feature's app if known; else lists the Apps table |
| `devflow-setup` | none — writes/owns the Apps table itself | N/A |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Inlining a fresh `config.md`-read explanation in a new skill | Point here instead — one line: "Resolve adapter + app root per `@devflow/references/adapter-resolution.md`" |
| Guessing the app when `**App:**` is missing in monorepo mode | Hard stop, ask the user — App is the declared source of truth |
| Running adapter shell commands at repo-root cwd in monorepo mode | Scope via `(cd "<path>" && <command>)` per app |
| Re-reading `task.md` from every downstream skill to find App | `plan.md` already carries it once `devflow.plan` propagates it — read that instead |
