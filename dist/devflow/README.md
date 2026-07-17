# DevFlow

**Spec-driven development pipeline for AI coding agents — with technology adapters and explicit quality gates.**

AI agents write code fast and forget faster. Ask for a feature and you get files with no spec, no traceability, tests that prove nothing, and a review that happens in your head at merge time. Every session restarts from zero; every stack gets generic advice.

DevFlow turns that into a pipeline. Every feature starts as a **spec** (`task.md`), becomes a **file-ordered plan** with a traceability table (every subtask → acceptance criterion → file), gets implemented in **vertical slices**, then passes **explicit gates**: multi-axis review, tests, goal-backward verification of every acceptance criterion, and a parallel multi-agent ship gate — before a PR is opened. **You stay the orchestrator**: each step is a command you invoke, with an input contract that refuses to run on bad state. Stack knowledge comes from **adapters** (Flutter, Angular, Next.js) so the agent follows *your* stack's rules, not generic ones.

This directory is the installable package: core pipeline skills, slash commands, hooks, references, and adapters.

## Quick start

Three commands from idea to reviewed plan:

```text
you>  /devflow.setup
      ✅ AGENTS.md + REGISTRY.md generated (adapter: flutter)

you>  /devflow.task users can archive old projects
      ✅ Task created: devflow/features/007_archive-projects/task.md
      HMW: How might we let users declutter without deleting history?
      5 subtasks · 6 acceptance criteria · 1 [NEEDS CLARIFICATION] marker

you>  /devflow.plan
      ✅ Plan created: devflow/features/007_archive-projects/plan.md
      8 files (2 create, 6 modify) · 3 vertical slices · traceability complete
      Continue to implementation? -> devflow.implement
```

Then `devflow.implement` → `devflow.beautify` → `devflow.test` (tests + per-AC verification) → `devflow.ship` (parallel agent fan-out) → `devflow.pr`. Interrupted? `devflow.resume`. Bug escaped? `devflow.backprop` fixes the spec, not just the code. Want the middle unattended? `devflow.run` chains implement → beautify → test with decision flags and stops before ship.

Full setup:

1. **Active stack** — edit [`config.md`](config.md); set **Adapter** to `flutter`, `angular`, or `nextjs`.
2. **Run setup once** — execute `devflow.setup` to generate root `AGENTS.md` and `REGISTRY.md` for the consumer project.
3. **Run the pipeline** — invoke commands under [`commands/`](commands/) (e.g. `devflow.task`) or load as a plugin and use your host’s namespaced invocations.
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

Three adapters ship out of the box:

| Adapter | Commands | Stack |
| --------- | ---------- | ------- |
| `flutter` | `flutter analyze`, `flutter test` | Flutter · Riverpod · Supabase |
| `angular` | `pnpm run lint`, `pnpm run test`, `pnpm run build` | Angular v20+ · NgRx Signal Store · Tailwind |
| `nextjs` | `pnpm lint`, `pnpm test`, `pnpm build` | Next.js 15+ · Zustand · Tailwind · shadcn/ui |

Each adapter folder contains `ADAPTER.md` (core: technology skills table + MCP hints), `steps/` (per-step contract files — `setup.md`, `plan.md`, `implement.md`, `beautify.md`, `test.md`, `pr.md` — each pipeline skill loads only its own), `skills/` (technology skills), and `templates/` (setup templates for `AGENTS.md`, `REGISTRY.md`, `docs/product.md`).

**Add a stack:** copy `adapters/flutter/` to `adapters/<name>/`, replace `ADAPTER.md`, `steps/`, and `skills/`, then point `config.md` at `<name>`.

## Setup command

`devflow.setup` is a standalone pre-pipeline command.

- Target output (consumer root): `AGENTS.md`, `REGISTRY.md`
- Default behavior: update only `devflow-managed` blocks and preserve user content outside those blocks
- Force rewrite: pass `--force` to overwrite full file contents
- Template resolution: adapter `templates/` first, then `skills/devflow-setup/templates/` fallback
- Generated `AGENTS.md` includes `code-review-graph` skill reference for graph-aware reviews.

## Claude Code

- Manifest: [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json)
- Local run: `claude --plugin-dir /path/to/devflow`
- Docs: [Create plugins](https://code.claude.com/docs/en/plugins)

## Cursor

- Manifest: [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json)
- Local install: `ln -s /path/to/devflow ~/.cursor/plugins/local/devflow` then reload the window.
- Docs: [Plugins](https://cursor.com/docs/plugins)

## Antigravity CLI (agy)

- Manifests: [`plugin.json`](plugin.json) (root) and [`.antigravity-plugin/plugin.json`](.antigravity-plugin/plugin.json)
- Local install: `agy plugin install /path/to/devflow`
- Validate: `agy plugin validate /path/to/devflow`

## Commands

| Command | What it does |
| --- | --- |
| `devflow.setup` | Generate `AGENTS.md`, `REGISTRY.md`, and `docs/product.md` from adapter templates |
| `devflow.task` | Raw idea → structured task with HMW framing and verifiable subtasks |
| `devflow.plan` | `task.md` → file-ordered implementation plan with traceability |
| `devflow.clarify` | `task.md` (with markers) → resolved `task.md` (Status: clarified) — optional step between task and plan |
| `devflow.analyze` | `task.md` + `plan.md` → consistency report (traceability, AC testability, terminology, constitution alignment, coverage balance) |
| `devflow.blueprint` | Large idea → multi-PR blueprint with dependency graph + adversarial review |
| `devflow.implement` | Execute `plan.md` step by step, vertical slice by slice |
| `devflow.beautify` | 7-axis polish: correctness, readability, security, performance, architecture, UI, a11y |
| `devflow.test` | Write and run unit + integration tests; bounded retry; goal-backward per-AC verification (`verification.md`) |
| `devflow.ship` | Pre-merge gate: 1–5 agents in parallel per depth profile → Ship Gate Report → route to PR |
| `devflow.pr` | Commit, push branch, open PR to main |
| `devflow.status` | Show current pipeline state (active feature, next step, progress) |
| `devflow.resume` | Resume interrupted session — read state, cross-check plan.md, re-enter correct step |
| `devflow.run` | Opt-in autonomy: chain implement → beautify → test unattended; decision flags; stop before ship |
| `devflow.backprop` | Backpropagate escaped bug into spec — classify gap, tighten AC, add regression test |
| `devflow.learn` | Manage learnings log — log / search / list / prune / boost |
| `devflow.recovery` | Diagnose + recover a stuck or corrupted pipeline |

## Hooks

Fourteen hook registrations activate automatically — no user invocation required. Behavioral tests: `hooks/tests/`, run via `scripts/run-hook-tests.sh`.

| Event | Script | What it does |
| --- | --- | --- |
| SessionStart | `session-start.sh` | Injects discovery skill + suggests context file based on active pipeline step |
| SessionStart | `session-start-learnings.sh` | Injects past learnings from `.devflow-learnings.jsonl` into session context |
| PreToolUse | `pre-config-protect.sh` | Blocks edits to linter/analyzer config files |
| PreToolUse | `observe.sh pre` | Logs tool calls to `.devflow-observe.jsonl` |
| PostToolUse | `observe.sh post` | Logs tool results to `.devflow-observe.jsonl` |
| PostToolUse | `post-bash-output-filter.sh` | Compresses verbose adapter command output (flutter/dart/pnpm/ng/git diff) past 2k chars: head + error/warning lines + tail |
| PostToolUse | `post-edit-accumulate.sh` | Tracks modified files for batch format check |
| PostToolUse | `post-task-create.sh` | Updates `next_feature_number` in `.devflow-state.json` after task.md writes |
| PreCompact | `pre-compact.sh` | Snapshots `plan.md` progress to `.devflow-state.json` |
| Stop | `stop-format-typecheck.sh` | Runs adapter format+analyze after each response |
| Stop | `stop-notify.sh` | Sends macOS desktop notification on response complete |
| Stop | `stop-debug-check.sh` | Warns about `print()` / `console.log` in modified files |
| Stop | `stop-learn-distill.sh` | Detects file churn (≥4 edits) in `.devflow-observe.jsonl`; appends to `.devflow-learnings.jsonl` |
| Stop | `observe.sh stop` | Logs response-boundary events to `.devflow-observe.jsonl` |

## Contexts

Three context files in `devflow/contexts/` tune Claude's behavior per pipeline phase. The SessionStart hook suggests which one to load based on the active step.

| Context | Suggested for | Focus |
| --- | --- | --- |
| `contexts/implement.md` | devflow.implement, devflow.beautify | Code-first, follow plan.md order, mark [done] |
| `contexts/review.md` | devflow.ship | 7-axis review, severity-ordered findings |
| `contexts/research.md` | devflow.task, devflow.plan | Explore before acting, no application code |

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
| `complexity-scoring.md` | Feature complexity score (0–20) → quick/standard/thorough depth profiles scaling beautify/test/ship rigor |
| `escalation-ladder.md` | Bounded failure handling: retry → debug mode → re-approach → decompose → block |
| `model-selection.md` | Haiku / Sonnet / Opus guide per pipeline step |
| `security-checklist.md` | OWASP Top 10, auth, input validation, secrets baseline |
| `security-threat-model.md` | AI agent threat model — prompt injection, state corruption, supply chain |
| `state-machine.md` | Canonical pipeline statuses + legal transitions — SSOT for status/resume/recovery/hooks |
| `status-schema.md` | `devflow.status --json` output schema + stable exit codes for CI/scripts |
| `testing-patterns.md` | AAA, Beyonce Rule, Prove-It Pattern, pass@k vs pass^k, coverage signals |
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

`agent.yaml` at the plugin root is a machine-readable index of all pipeline components — steps, agents, skills, adapters, hooks, contexts, references. Use it for tooling, automation, or quick reference.

## Features output

`features/[NNN]_[name]/` holds `task.md` and `plan.md`. In a **consumer app repo**, this folder can be symlinked or copied; paths in skills assume `devflow/features/` relative to the plugin root unless you fork the skills.
