# DevFlow

**Spec-driven development pipeline for AI coding agents — with technology adapters and explicit quality gates.**

AI agents write code fast and forget faster. Ask for a feature and you get files with no spec, no traceability, tests that prove nothing, and a review that happens in your head at merge time. Every session restarts from zero; every stack gets generic advice.

DevFlow turns that into a pipeline. Every feature starts as a **spec** (`task.md`), becomes a **file-ordered plan** with a traceability table (every subtask → acceptance criterion → file), gets implemented in **vertical slices**, then passes **explicit gates**: multi-axis review, tests, goal-backward verification of every acceptance criterion, and a parallel multi-agent ship gate — before a PR is opened. **You stay the orchestrator**: each step is a command you invoke, with an input contract that refuses to run on bad state. Stack knowledge comes from **adapters** (Flutter, Angular, Next.js, NestJS) so the agent follows *your* stack's rules, not generic ones.

This directory is the installable package: core pipeline skills (the slash commands), hooks, references, and adapters.

## Quick start

Three commands from idea to reviewed plan (`/devflow:<step>` on Claude Code, `/devflow-<step>` on Antigravity CLI):

```text
you>  /devflow:setup
      ✅ AGENTS.md + REGISTRY.md + constitution.md + docs/product.md generated (adapter: flutter)

you>  /devflow:task users can archive old projects
      ✅ Task created: devflow/features/007_archive-projects/task.md
      HMW: How might we let users declutter without deleting history?
      5 subtasks · 6 acceptance criteria · 1 [NEEDS CLARIFICATION] marker

you>  /devflow:plan
      ✅ Plan created: devflow/features/007_archive-projects/plan.md
      8 files (2 create, 6 modify) · 3 vertical slices · traceability complete
      Continue to implementation? -> devflow.implement
```

Then `devflow.implement` (offers the optional beautify step at exit) → `devflow.test` (tests + per-AC verification) → `devflow.ship` (parallel agent fan-out) → `devflow.pr`. Interrupted or blocked? `devflow.resume`. Bug escaped? `devflow.backprop` fixes the spec, not just the code. Want the middle unattended? `devflow.run` chains implement → beautify → test with decision flags and stops before ship.

Full setup:

1. **Active stack** — edit [`config.md`](config.md); set **Adapter** to `flutter`, `angular`, `nextjs`, or `nestjs`.
2. **Run setup once** — execute `devflow.setup` to generate root `AGENTS.md` and `REGISTRY.md` for the consumer project.
3. **Run the pipeline** — each step is a skill: `/devflow:<step>` on Claude Code (e.g. `/devflow:task`), `/devflow-<step>` on Antigravity CLI.
4. **Enable code-review-graph** — install and configure once for all detected hosts:
   - `pipx install code-review-graph` (or `pip install code-review-graph`)
   - `code-review-graph install`
   - `code-review-graph build`
5. **Ensure required MCP baseline**:
   - `context7`
   - `sequential-thinking` ([server reference](https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking))
   - `dart` for Flutter adapters/projects

Architecture and design rationale: [`docs/architecture.md`](../../docs/architecture.md) · honest comparison with Forge, spec-kit, and vanilla agents: [`docs/comparison.md`](../../docs/comparison.md).

## Adapters

Four adapters ship out of the box (plus shared common utilities):

| Adapter | Commands | Stack |
| --------- | ---------- | ------- |
| `flutter` | `flutter analyze`, `flutter test` | Flutter 3.47+ · Riverpod 3 · Supabase |
| `angular` | `pnpm run lint`, `pnpm run test`, `pnpm run build` | Angular v22+ · NgRx Signal Store · Vitest |
| `nextjs` | `pnpm lint`, `pnpm test`, `pnpm build` | Next.js 16+ · Zustand 5 · Tailwind v4 · shadcn/ui |
| `nestjs` | `pnpm lint`, `pnpm test`, `pnpm build` | NestJS 11+/12+ · Express v5 · TypeORM · class-validator / Standard Schema · Swagger |

Each adapter folder contains `ADAPTER.md` (core: technology skills table + MCP hints), `steps/` (per-step contract files — `setup.md`, `plan.md`, `implement.md`, `beautify.md`, `test.md`, `pr.md` — each pipeline skill loads only its own), `skills/` (technology skills), and `templates/` (setup templates for `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md`).

**Add a stack:** copy `adapters/flutter/` to `adapters/<name>/`, replace `ADAPTER.md`, `steps/`, and `skills/`, then point `config.md` at `<name>`.

## Setup command

`devflow.setup` is a standalone pre-pipeline command.

- Target output (consumer root): `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md`
- Default behavior: update only `devflow-managed` blocks and preserve user content outside those blocks
- Force rewrite: pass `--force` to overwrite full file contents
- Template resolution: adapter `templates/` first, then `skills/devflow-setup/templates/` fallback
- Generated `AGENTS.md` includes `code-review-graph` skill reference for graph-aware reviews.

## Claude Code

- Source manifest: [`manifest.json`](manifest.json) (built to `.claude-plugin/plugin.json` in `dist/devflow/`)
- Local run: `claude --plugin-dir /path/to/dev_flow/dist/devflow`
- Docs: [Create plugins](https://code.claude.com/docs/en/plugins)

## Antigravity CLI (agy)

- Build: `dist/devflow-antigravity/` in the DevFlow repo (manifest under .antigravity-plugin/, hooks in the root hooks.json)
- Local install: `agy plugin install /path/to/dev_flow/dist/devflow-antigravity`
- Validate: `agy plugin validate /path/to/dev_flow/dist/devflow-antigravity`

## Commands

| Command | What it does |
| --- | --- |
| `devflow.init` | Bootstrap a greenfield project end-to-end: multi-phase interview → evergreen tech scaffolding (Nx, Angular, Next.js, Flutter, NestJS) → DevFlow context + `ADR-001` → `project-blueprint.md` + ordered `001..NNN` `task.md` roadmap |
| `devflow.discover` | Explore architectural choices for app creation or complex features → comparative trade-offs + formal ADR |
| `devflow.setup` | Generate `AGENTS.md`, `REGISTRY.md`, `constitution.md`, and `docs/product.md` from adapter templates |
| `devflow.task` | Raw idea → structured task with HMW framing and verifiable subtasks |
| `devflow.plan` | `task.md` → file-ordered implementation plan with traceability; `plan-reviewer` lead review from `standard` up; optional consistency check (traceability, AC testability, terminology, constitution/ADR alignment) |
| `devflow.blueprint` | Large idea → multi-PR blueprint with dependency graph + adversarial review |
| `devflow.implement` | Execute `plan.md` step by step, vertical slice by slice; at exit offers the optional beautify step (readability, conventions, design tokens, layout, a11y basics — not a slash command; default off in `quick` profile) |
| `devflow.test` | Write and run unit + integration tests; bounded retry; goal-backward per-AC verification (`verification.md`) |
| `devflow.ship` | Pre-merge gate: `code-reviewer` (+ `security-auditor` from `standard` up) in parallel → `finding-validator` on blocking findings → Ship Gate Report → route to PR |
| `devflow.pr` | Commit, push branch, open PR to main |
| `devflow.status` | Show current pipeline state (active feature, next step, progress) |
| `devflow.doctor` | Diagnose environment readiness, MCP servers reachability, CLI toolchains, and pipeline state integrity |
| `devflow.hotfix` | Fast-track bugfix: compact task+plan → failing regression test → fix → full suite + verification → PR (no beautify, no ship review) |
| `devflow.resume` | Resume interrupted or blocked session — read state, cross-check plan.md, resync drift / unblock (user-confirmed), re-enter correct step |
| `devflow.auto` | Full autonomy from raw idea to opened PR: task → plan (+ consistency check, one step-runner) → implement → [beautify, `--beautify` only] → test → ship → pr; halts only on Critical discrepancies |
| `devflow.run` | Opt-in autonomy: chain implement → beautify → test unattended; decision flags; stop before ship |
| `devflow.backprop` | Backpropagate escaped bug into spec — classify gap, tighten AC, add regression test |
| `devflow.worktree` | Create / list / remove isolated git worktrees for parallel features, with dev-server port offset and overlap detection |
| `devflow.learn` | Manage instincts — log / search / list / prune / boost / promote to team store |
| `devflow.metrics` | Local telemetry dashboard (`.devflow-metrics/`, gitignored) — tokens, cost, command durations, context window and compactions, hook-injected context, tool/skill/subagent usage, pass@1 |
| `devflow.board` | Static, read-only, auto-updating HTML project board (`devflow/board/index.html`) — Kanban pipeline, dependency DAG critical path, Markdown viewer, and command timings |

## Hooks

Hook registrations (`hooks/hooks.json`) activate automatically — no user invocation required. Behavioral tests: `hooks/tests/`, run via `scripts/run-hook-tests.sh`.

| Event | Script | What it does |
| --- | --- | --- |
| SessionStart | `session-start.sh` | Injects discovery skill + suggests context file based on active pipeline step |
| SessionStart | `session-start-learnings.sh` | Injects past learnings from `.devflow-learnings.jsonl` into session context |
| PreToolUse | `pre-config-protect.sh` | Blocks edits to linter/analyzer config files |
| PreToolUse | `pre-scope-guard.sh` | Soft-warns when writing/editing a file not listed in active `plan.md` |
| PreToolUse | `pre-bash-destructive-guard.sh` | Blocks catastrophic `rm -rf`, hard-reset/clean/discard, force-push to main/master, `commit --no-verify`/`--no-gpg-sign` |
| PreToolUse | `pre-bash-stamp-guard.sh` | Run mode only: denies test/lint/analyze/format/e2e/build commands not wrapped by `verify-stamp.sh` |
| PreToolUse | `pre-fetch-cache.sh` | Serves cached `WebFetch` responses when fresh |
| PreToolUse | `pre-agent-fanout-cap.sh` | Caps concurrent subagent fan-out per turn |
| PreToolUse | `observe.sh pre` | Logs tool calls to `.devflow-observe.jsonl`; marks tool-call start for timing |
| PostToolUse / PostToolUseFailure | `observe.sh post` | Logs tool results to `.devflow-observe.jsonl`; one telemetry row per call (duration, output size, skill/MCP/subagent) to `.devflow-metrics/tools.jsonl` |
| PostToolUse | `post-bash-output-filter.sh` | Compresses verbose adapter command output (flutter/dart/pnpm/ng/git diff) past 2k chars: head + error/warning lines + tail |
| PostToolUse | `post-edit-accumulate.sh` | Tracks modified files for batch format check |
| PostToolUse | `post-edit-instinct-context.sh` | Injects matching domain instincts once per session when editing files |
| PostToolUse | `post-task-create.sh` | Updates `next_feature_number` in `.devflow-state.json` after `task.md` writes |
| PostToolUse | `post-fetch-cache.sh` | Caches `WebFetch` responses for reuse |
| PreModelSwitch / PostModelSwitch | `pre-model-switch.sh` · `post-model-switch.sh` | Guards and logs mid-session model switches (Claude Code) |
| PreCompact | `pre-compact.sh` | Snapshots `plan.md` progress to `.devflow-state.json` |
| Stop | `stop-format-typecheck.sh` | Runs adapter format+analyze after each response |
| Stop | `stop-notify.sh` | Sends macOS desktop notification on response complete |
| Stop | `stop-debug-check.sh` | Warns about `print()` / `console.log` in modified files |
| Stop | `stop-learn-distill.sh` | Detects file churn (≥4 edits) in `.devflow-observe.jsonl`; appends to `.devflow-learnings.jsonl` |
| Stop | `observe.sh stop` | Logs response-boundary events to `.devflow-observe.jsonl` |
| Stop | `stop-metrics.sh` | Per-turn tokens, cost, context window, tool mix, duration → `.devflow-metrics/turns.jsonl`, `timings.jsonl` |
| SessionStart · UserPromptSubmit · PreCompact · SubagentStop · SessionEnd | `metrics-collect.sh` | Lifecycle telemetry (sessions, prompt size + slash command, compactions, subagent cost) → `.devflow-metrics/` |

All telemetry is local, under the gitignored `.devflow-metrics/` folder (`DEVFLOW_METRICS_DIR=off` disables it). Schema: `skills/devflow-metrics/references/telemetry-schema.md`; dashboard: `devflow.metrics`.

## Core Principles

`ETHOS.md` defines the four non-negotiable principles injected into every skill:

| Principle | Rule |
| --- | --- |
| `spec-first` | No code before `task.md` + `plan.md` approved |
| `traceability` | Every subtask → acceptance criterion → file(s) |
| `vertical slices` | End-to-end increments, never layers |
| `token-lean` | Caveman-compress: drop articles/hedging/filler; keep precision |

## References

Stack-agnostic checklists and guides in `references/`:

| File | Purpose |
| ------ | --------- |
| `accessibility-checklist.md` | WCAG 2.1 AA — keyboard, screen readers, touch targets |
| `adapter-resolution.md` | Single-app and monorepo adapter/app resolution and working-directory scoping |
| `complexity-scoring.md` | Feature complexity score (0–20) → quick/standard/thorough depth profiles scaling beautify/test/ship rigor |
| `escalation-ladder.md` | Bounded failure handling: retry → debug mode → re-approach → decompose → block |
| `mcp-catalog.md` | Authoritative MCP server catalog across adapters and client configs |
| `model-selection.md` | Haiku / Sonnet / Opus guide per pipeline step |
| `orientation.md` | Session-start routing tree mapping project state to the active entry point |
| `run-mode.md` | Run-mode contract shared by `devflow.run` and `devflow.auto` |
| `security-checklist.md` | OWASP Top 10, auth, input validation, secrets baseline |
| `security-threat-model.md` | AI agent threat model — prompt injection, state corruption, supply chain |
| `state-machine.md` | Canonical pipeline statuses + legal transitions — SSOT for status/resume/recovery/hooks |
| `status-schema.md` | `devflow.status --json` output schema + stable exit codes for CI/scripts |
| `testing-patterns.md` | AAA, Beyonce Rule, Prove-It Pattern, pass@k vs pass^k, coverage signals |
| `token-economy.md` | Index-first exploration and derive-don't-dump output discipline |
| `verification-levels.md` | Goal-backward per-AC verification: existence → substantive → wired → runtime |

## Common Skills

Cross-adapter skills in `adapters/common/`:

| Skill | Purpose |
| ------- | --------- |
| `common-clean-code` | SOLID, DRY, design principles across all stacks |
| `common-web-interface-guidelines` | UI/UX quality rules for all web adapters |
| `common-caveman` | Token-lean, filler-free response style |
| `common-state-patterns` | Riverpod / Signal Store / Zustand comparison, scope decision tree |

## Plugin Catalog

`agent.yaml` at the plugin root is a machine-readable index of all pipeline components — steps, agents, skills, adapters, hooks, references. Use it for tooling, automation, or quick reference.

## Features output

`features/[NNN]_[name]/` holds `task.md` and `plan.md`. In a **consumer app repo**, this folder can be symlinked or copied; paths in skills assume `devflow/features/` relative to the plugin root unless you fork the skills.
