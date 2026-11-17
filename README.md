# DevFlow

DevFlow is a **spec-driven development pipeline** that turns a raw idea into a reviewed, tested, and merged feature. Each step maps to a skill (and optional slash command) that defines inputs, steps, outputs, and success criteria.

The workflow is **technology-agnostic**: stack-specific rules live in **adapters** under [`templates/devflow/adapters/`](templates/devflow/adapters/). Today the **Flutter**, **Angular**, **Next.js**, and **NestJS** adapters ship with this repo; adding more stacks means adding a new adapter folder and switching [`templates/devflow/config.md`](templates/devflow/config.md).

---

## Pipeline

```text
idea
  └── devflow.task   (resolves [NEEDS CLARIFICATION] markers inline)
        └── devflow.plan   (optional consistency check before implement)
              └── devflow.implement
                    └── [beautify]   (optional — offered at implement exit, not a command)
                          └── devflow.test
                                └── devflow.ship
                                      └── devflow.pr
```

Each step produces an artifact that feeds the next. Do not skip steps.

**Autonomous entry point:** `devflow.auto <idea>` chains `task → plan → implement → [beautify] → test → ship → pr` (beautify only with `--beautify`) in total autonomy from a raw idea to an opened pull request (defensible defaults + decision flags instead of clarification pauses; halts only on major discrepancies like Critical blockers, and documents minor discrepancies in the PR body).

---

## Pipeline steps (entry points)

| Step | Skill | Input → Output |
| -------- | -------- | ---------------- |
| `devflow.init` | [`templates/devflow/skills/devflow-init/SKILL.md`](templates/devflow/skills/devflow-init/SKILL.md) | Project brief + interview → greenfield repo + live tech scaffold (Nx, Angular, Next.js, Flutter, NestJS) + `AGENTS.md` + `REGISTRY.md` + `constitution.md` + `ADR-001` + `project-blueprint.md` + ordered `001..NNN` `task.md` files |
| `devflow.setup` | [`templates/devflow/skills/devflow-setup/SKILL.md`](templates/devflow/skills/devflow-setup/SKILL.md) | Consumer repo context + adapter templates → root `AGENTS.md` + `REGISTRY.md` |
| `devflow.brainstorm` | [`templates/devflow/skills/devflow-brainstorm/SKILL.md`](templates/devflow/skills/devflow-brainstorm/SKILL.md) | Fuzzy idea → framed problem + distinct directions → `devflow/ideas/[slug].md` brief |
| `devflow.task` | [`templates/devflow/skills/devflow-task/SKILL.md`](templates/devflow/skills/devflow-task/SKILL.md) | Idea → `devflow/features/[NNN]_[name]/task.md` |
| `devflow.plan` | [`templates/devflow/skills/devflow-plan/SKILL.md`](templates/devflow/skills/devflow-plan/SKILL.md) | `task.md` → `plan.md` |
| `devflow.discover` | [`templates/devflow/skills/devflow-discover/SKILL.md`](templates/devflow/skills/devflow-discover/SKILL.md) | Architecture question → compared options + ADR in `docs/adr/` |
| `devflow.blueprint` | [`templates/devflow/skills/devflow-blueprint/SKILL.md`](templates/devflow/skills/devflow-blueprint/SKILL.md) | Large idea → multi-PR blueprint with dependency graph + adversarial review |
| `devflow.auto` | [`templates/devflow/skills/devflow-auto/SKILL.md`](templates/devflow/skills/devflow-auto/SKILL.md) | Raw idea → full pipeline (`task → ... → pr`) in total autonomy to opened PR |
| `devflow.implement` | [`templates/devflow/skills/devflow-implement/SKILL.md`](templates/devflow/skills/devflow-implement/SKILL.md) | `plan.md` → code on `feat \| fix \| …/[NNN]_[name]` |
| beautify (optional step, no command) | [`templates/devflow/skills/devflow-beautify/SKILL.md`](templates/devflow/skills/devflow-beautify/SKILL.md) | Implemented files → polished code; offered by `devflow.implement` at exit, chained by `devflow.run` / `devflow.auto` per profile |
| `devflow.test` | [`templates/devflow/skills/devflow-test/SKILL.md`](templates/devflow/skills/devflow-test/SKILL.md) | Feature → unit + integration tests |
| `devflow.ship` | [`templates/devflow/skills/devflow-ship/SKILL.md`](templates/devflow/skills/devflow-ship/SKILL.md) | Feature → parallel review (code-reviewer + security-auditor from `standard` up) → gate before PR |
| `devflow.pr` | [`templates/devflow/skills/devflow-pr/SKILL.md`](templates/devflow/skills/devflow-pr/SKILL.md) | Branch → PR to `main` |
| `devflow.status` | [`templates/devflow/skills/devflow-status/SKILL.md`](templates/devflow/skills/devflow-status/SKILL.md) | — → current pipeline state dashboard |
| `devflow.doctor` | [`templates/devflow/skills/devflow-doctor/SKILL.md`](templates/devflow/skills/devflow-doctor/SKILL.md) | — → pre-flight diagnostic (MCP reachability, CLI tools, pipeline state) |
| `devflow.hotfix` | [`templates/devflow/skills/devflow-hotfix/SKILL.md`](templates/devflow/skills/devflow-hotfix/SKILL.md) | Bug description → compact task+plan → failing regression test → fix → full suite + verification → PR (no beautify, no ship review) |
| `devflow.resume` | [`templates/devflow/skills/devflow-resume/SKILL.md`](templates/devflow/skills/devflow-resume/SKILL.md) | Interrupted or `blocked` feature → state resynced / unblocked (user-confirmed) → correct step re-entered |
| `devflow.run` | [`templates/devflow/skills/devflow-run/SKILL.md`](templates/devflow/skills/devflow-run/SKILL.md) | Approved plan → implement → [beautify] → test unattended, stops before ship |
| `devflow.backprop` | [`templates/devflow/skills/devflow-backprop/SKILL.md`](templates/devflow/skills/devflow-backprop/SKILL.md) | Escaped bug → spec gap classified, AC tightened, regression test |
| `devflow.worktree` | [`templates/devflow/skills/devflow-worktree/SKILL.md`](templates/devflow/skills/devflow-worktree/SKILL.md) | Feature → isolated git worktree with port offset for parallel work |
| `devflow.learn` | [`templates/devflow/skills/devflow-learn/SKILL.md`](templates/devflow/skills/devflow-learn/SKILL.md) | — → manage instincts (local vs shared team gotchas, promote to REGISTRY.md) |
| `devflow.metrics` | [`templates/devflow/skills/devflow-metrics/SKILL.md`](templates/devflow/skills/devflow-metrics/SKILL.md) | — → telemetry dashboard (tokens/cost, step duration, pass@1, error categories, feature funnel) |
| `devflow.board` | [`templates/devflow/skills/devflow-board/SKILL.md`](templates/devflow/skills/devflow-board/SKILL.md) | — → static, read-only, auto-updating HTML project board (`devflow/board/index.html`) with Kanban, Dependency DAG, Markdown viewer, and command timings |

Skills are the only entry point (2.0.0): there are no command wrappers. Each step `devflow.<step>` is invoked as:

| Host | Slash name | Example |
| --- | --- | --- |
| Claude Code | `/devflow:<step>` | `/devflow:plan 003` |
| Antigravity CLI | `/devflow-<step>` | `/devflow-plan 003` |

**Migrating from 1.x (Claude Code):** `/devflow:devflow.<step>` (command) and `/devflow:devflow-<step>` (skill) both become `/devflow:<step>` — e.g. `/devflow:devflow.ship` → `/devflow:ship`. The skill now runs with its own frontmatter (`effort`, `disable-model-invocation`) instead of being read as text by a command. Antigravity CLI names are unchanged (`/devflow-<step>`).

---

## Project docs (in your app repo)

| File | Role | Read by |
| ------ | ------ | --------- |
| `AGENTS.md` | Global agent operating rules (token-lean, setup-managed sections) | setup + all steps (as host memory/context) |
| `REGISTRY.md` | Shared patterns and conventions summary | setup + plan → pr |
| `constitution.md` | Architecture, stack, layout | setup + plan → pr |
| `docs/product.md` | Product / feature status | setup + task |

`devflow.setup` manages root `AGENTS.md`, `REGISTRY.md`, `constitution.md`, and `docs/product.md` using adapter templates. By default it updates only `devflow-managed` blocks; pass `--force` to overwrite full files.

---

## Repository layout

```text
dev_flow/
├── templates/
│   └── devflow/                     # Plugin source — edit here
│       ├── manifest.json            # Plugin metadata (name, version, author)
│       ├── config.md                # Active adapter id
│       ├── AGENTS.md                # Global agent rules
│       ├── CONTRIBUTING.md
│       ├── ETHOS.md
│       ├── hooks/
│       │   ├── hooks.json           # Lifecycle hook config
│       │   └── *.sh                 # Hook scripts
│       ├── skills/                  # Core pipeline skills (devflow-*)
│       │   ├── devflow-auto/
│       │   ├── devflow-backprop/
│       │   ├── devflow-beautify/        # optional step, no slash command
│       │   ├── devflow-blueprint/
│       │   ├── devflow-board/
│       │   ├── devflow-brainstorm/
│       │   ├── devflow-discover/
│       │   ├── devflow-doctor/
│       │   ├── devflow-hotfix/
│       │   ├── devflow-implement/
│       │   ├── devflow-init/
│       │   ├── devflow-learn/
│       │   ├── devflow-metrics/
│       │   ├── devflow-plan/
│       │   ├── devflow-pr/
│       │   ├── devflow-resume/
│       │   ├── devflow-run/
│       │   ├── devflow-setup/
│       │   ├── devflow-ship/
│       │   ├── devflow-status/
│       │   ├── devflow-task/
│       │   ├── devflow-test/
│       │   └── devflow-worktree/
│       ├── adapters/
│       │   ├── ADAPTER.schema.md
│       │   ├── angular/             # angular-animations, -architecture, -aria, -component, -forms, -http, -routing, -state, -testing, -theme
│       │   ├── flutter/             # flutter-architecture, -supabase, -migrations, -theme, -riverpod, -models, -layout, -form
│       │   ├── nextjs/              # nextjs-architecture, -server, -components, -state, -ui, -forms, -testing, -metadata, -performance
│       │   ├── nestjs/              # nestjs-architecture, -error-handling, -security, -performance, -database, -api-design, -testing, -microservices
│       │   └── common/              # common-clean-code, -web-interface-guidelines, -caveman, -state-patterns
│       ├── agents/
│       │   ├── brainstormer.md
│       │   ├── code-reviewer.md
│       │   ├── finding-validator.md
│       │   ├── plan-reviewer.md
│       │   ├── task-reviewer.md
│       │   ├── security-auditor.md
│       │   └── step-runner.md
│       ├── references/
│       │   ├── accessibility-checklist.md
│       │   ├── adapter-resolution.md
│       │   ├── complexity-scoring.md
│       │   ├── escalation-ladder.md
│       │   ├── mcp-catalog.md
│       │   ├── model-selection.md
│       │   ├── orientation.md
│       │   ├── run-mode.md
│       │   ├── security-checklist.md
│       │   ├── security-threat-model.md
│       │   ├── state-machine.md
│       │   ├── status-schema.md
│       │   ├── testing-patterns.md
│       │   ├── token-economy.md
│       │   └── verification-levels.md
│       └── scripts/
│           ├── board.sh
│           ├── check-adapter-versions.sh
│           ├── devflow-state.sh
│           ├── doctor.sh
│           ├── metrics.sh
│           ├── review-packet.sh
│           ├── run-evals.sh
│           ├── run-hook-tests.sh
│           ├── validate-adapters.sh
│           ├── validate-doc-links.sh
│           ├── validate-skills.sh
│           └── verify-stamp.sh
├── dist/
│   ├── devflow/                     # Claude Code build — do not edit directly
│   │   ├── .claude-plugin/          # Claude Code plugin manifest (generated)
│   │   └── ...                      # Mirror of templates/devflow/ (minus dev-only files)
│   └── devflow-antigravity/         # Antigravity CLI build — do not edit directly
│       ├── .antigravity-plugin/     # plugin.json (generated)
│       ├── hooks.json               # hooks/hooks.json translated to agy events/tools
│       ├── rules/                   # devflow-orientation.md (static routing rule)
│       └── ...                      # skills/agents with Claude-only frontmatter removed
├── scripts/
│   ├── build-plugin.sh              # Orchestrator: reads manifest.json, calls builders
│   ├── create-adapter.sh            # Scaffold a new technology adapter
│   ├── install-plugin.sh            # Unified local installer (Claude Code + Antigravity CLI)
│   └── builders/
│       ├── common.sh                # Shared helpers (ok/warn/fail/step)
│       ├── build-claude.sh          # Generates dist/devflow/ for Claude Code
│       └── build-antigravity.sh     # Generates dist/devflow-antigravity/ from dist/devflow/
├── .github/
│   └── workflows/
│       ├── adapter-freshness.yml    # CI: weekly check of adapter Verified against versions
│       ├── build-verify.yml         # CI: verify dist/ is in sync on every PR
│       └── release-please.yml       # CI: automated semver bump + GitHub Release on main push
├── release-please-config.json
├── .release-please-manifest.json
└── CHANGELOG.md
```

Feature folders (in the consumer project) use zero-padded ids (`001`, `002`, …) and `kebab-case` names confirmed with the user.

---

## Build system

The plugin uses a manifest-driven build: source lives in `templates/devflow/`, built output in `dist/devflow/` (Claude Code) and `dist/devflow-antigravity/` (Antigravity CLI), both committed. Run the build after any change to skills, adapters, or hooks:

```bash
# Rebuild dist/ after any source change
bash scripts/build-plugin.sh

# Validate all SKILL.md files
bash templates/devflow/scripts/validate-skills.sh

# Validate all adapters against ADAPTER.schema.md
bash templates/devflow/scripts/validate-adapters.sh
```

The build is **idempotent** — it recreates both `dist/` trees from scratch on every run. Requires `jq` (`brew install jq`); runs `agy plugin validate` on the Antigravity tree when `agy` is installed.

---

## Plugins (Claude Code & Antigravity CLI)

DevFlow ships one build per host, generated from the same source: [`dist/devflow/`](dist/devflow/) for Claude Code and [`dist/devflow-antigravity/`](dist/devflow-antigravity/) for Antigravity CLI (`agy`). Cursor is no longer supported (removed in 2.0.0).

### What works on each host

| Feature | Claude Code | Antigravity CLI |
| --- | --- | --- |
| Pipeline skills, adapters, references | ✅ `/devflow:<step>` | ✅ `/devflow-<step>` |
| User-only skills (`disable-model-invocation`: pr, hotfix, ship, auto, …) | ✅ run only on `/` | ✅ run only on `/` (honored by agy 1.4.9) |
| Hidden steps (`user-invocable: false`: beautify, offered by implement) | ✅ not in the `/` menu | ⚠️ field stripped — still listed as `/devflow-beautify` |
| Read-only skills (`disallowed-tools`: status, metrics, resume) | ✅ Write/Edit denied | ⚠️ field stripped — read-only by the skill's rules only |
| Review subagents (`agents/`) | ✅ read-only tools, `model: sonnet` | ✅ read-only tools (`tools` translated to agy's allowlist, verified on agy 1.4.10), host default model |
| Per-step model in `devflow.run` / `devflow.auto` | ✅ `sonnet` step-runners, `opus` only on `thorough` | ⚠️ every step-runner and reviewer on the session model — `devflow.auto` costs more; pick a mid-tier session model for unattended runs |
| Destructive-command / config-protect / scope guards | ✅ | ✅ (`run_command`, file-write tools) |
| Observe log, instincts, churn learning | ✅ | ✅ |
| Format + typecheck on Stop, debug-print check | ✅ (shown as `systemMessage`) | ✅ (results in the agy log only) |
| Token/cost metrics | ✅ tokens + cost | ✅ tokens (no price table for Gemini) |
| Session-start orientation + instincts | ✅ injected as context | ⚠️ static `dist/devflow-antigravity/rules/devflow-orientation.md`; dynamic state not injected |
| Pre-compaction state snapshot | ✅ | ❌ no PreCompact event |
| Model-switch guard + audit | ✅ | ❌ no model-switch events |
| Retry-loop detection on failed tools | ✅ (`PostToolUseFailure`) | ✅ (`error` field) |
| Bash output filtering, WebFetch cache | ✅ | ❌ no output rewrite / no tool output in payload |

### Unified Installer (Recommended)

Install or link DevFlow across all detected platforms (Antigravity, Claude Code) with a single command:

```bash
# Install to all detected platforms (auto-detects ~/.gemini, ~/.claude)
bash scripts/install-plugin.sh

# Or install to a specific platform:
bash scripts/install-plugin.sh antigravity
bash scripts/install-plugin.sh claude
```

### Install via Claude Code marketplace

```text
/plugin marketplace add Gabriele-bil/dev_flow
/plugin install devflow@devflow
```

Skills are namespaced — use them as `/devflow:task`, `/devflow:plan`, etc.

### Install locally (Claude Code)

```bash
claude --plugin-dir ./dist/devflow
```

### Install locally (Antigravity CLI / agy)

```bash
# Validate the plugin files first
agy plugin validate ./dist/devflow-antigravity

# Install the plugin locally
agy plugin install ./dist/devflow-antigravity
```

Check the hooks with `/hooks` inside `agy`. Hook payload fixtures and capture notes: [`templates/devflow/hooks/tests/fixtures/antigravity/README.md`](templates/devflow/hooks/tests/fixtures/antigravity/README.md).

More detail: [`templates/devflow/README.md`](templates/devflow/README.md).

### Recommended companion plugin: code-review-graph

Use `code-review-graph` for blast-radius aware reviews with one setup:

- `pipx install code-review-graph` (or `pip install code-review-graph`)
- `code-review-graph install` (auto-detects configured platforms, including Claude Code)
- `code-review-graph build` (initial graph indexing per repository)

### Recommended companion skill: impeccable (UI design)

Angular, Next.js and Flutter projects: install [impeccable](https://github.com/pbakaus/impeccable) and DevFlow hands UI design to it — `devflow.setup` installs it automatically at project scope when the adapter has a UI (`npx impeccable install`, or the `claude plugin` CLI when Node is missing) and offers `/impeccable init` + `/impeccable document` (`PRODUCT.md`, `DESIGN.md`); `devflow.plan` tags UI files `[ui]`; `devflow.implement` invokes impeccable for those batches. Install failed or skipped → `[ui]` files follow `DESIGN.md` tokens only; `devflow.doctor` flags it.

Manual install:

```text
/plugin marketplace add pbakaus/impeccable
/plugin install impeccable@impeccable
```

Any host (Antigravity included): `npx impeccable install` from the project root. Contract: [`templates/devflow/references/design-skill.md`](templates/devflow/references/design-skill.md).

### Required MCP baseline

| Adapter | MCP servers |
| --------- | ------------- |
| Angular | `context7`, `sequential-thinking` |
| Flutter | `context7`, `sequential-thinking`, `dart`, `supabase` |
| Next.js | `context7`, `sequential-thinking` |
| NestJS | `context7`, `sequential-thinking` |

---

## Agents

Specialized agents live in [`templates/devflow/agents/`](templates/devflow/agents/): the code reviewers are dispatched by `devflow.ship`, the brainstormer by `devflow.brainstorm`, the task reviewer by `devflow.task`, the plan reviewer by `devflow.plan` / `devflow.blueprint`, the step runner by `devflow.run` / `devflow.auto`:

| Agent | File | Role |
| ------- | ------ | ------ |
| Step Runner | [`agents/step-runner.md`](templates/devflow/agents/step-runner.md) | Runs one pipeline step — or a step group (`task → plan` in `devflow.auto`, `implement --fix → test` in the ship fix loop) — in its own context for `devflow.run` / `devflow.auto` (Claude Code: per-step model); returns a `RESULT:` line |
| Finding Validator | [`agents/finding-validator.md`](templates/devflow/agents/finding-validator.md) | Re-checks each Critical/Required ship finding against the cited `file:line`; discards only what the code disproves, so a false positive never starts a fix loop |
| Brainstormer | [`agents/brainstormer.md`](templates/devflow/agents/brainstormer.md) | Generates distinct product directions for a framed problem — value mechanism, riskiest assumption, smallest test, size — in a clean context |
| Task Reviewer | [`agents/task-reviewer.md`](templates/devflow/agents/task-reviewer.md) | Product-manager second read of a draft `task.md` (≥ 3 use cases or file/ticket input): source fidelity, product overlap, INVEST, BDD criteria, async states, scope boundaries |
| Plan Reviewer | [`agents/plan-reviewer.md`](templates/devflow/agents/plan-reviewer.md) | Engineering-lead critique of a draft `plan.md` (`standard`/`thorough`) or blueprint before it is written: codebase fit, reuse, contracts-first slicing, dependencies, risks, over-engineering |
| Code Reviewer | [`agents/code-reviewer.md`](templates/devflow/agents/code-reviewer.md) | 7-axis code review: correctness, readability, architecture, security, performance, scope fidelity, simplicity |
| Security Auditor | [`agents/security-auditor.md`](templates/devflow/agents/security-auditor.md) | Exploitable vulnerabilities, threat modeling, secure coding |

`devflow.ship` runs `code-reviewer` (plus `security-auditor` on `standard`/`thorough` profiles) in parallel, synthesizes reports into a Ship Gate Report, and routes to `devflow.pr` only if no blockers are found.

---

## References

Shared checklists and patterns in [`templates/devflow/references/`](templates/devflow/references/):

| File | Purpose |
| ------ | --------- |
| [`accessibility-checklist.md`](templates/devflow/references/accessibility-checklist.md) | WCAG 2.1 AA checklist — keyboard, screen readers, touch targets |
| [`adapter-resolution.md`](templates/devflow/references/adapter-resolution.md) | Single-app and monorepo adapter/app resolution and working-directory scoping |
| [`complexity-scoring.md`](templates/devflow/references/complexity-scoring.md) | Feature complexity score (0–20) → `quick` / `standard` / `thorough` depth profiles |
| [`escalation-ladder.md`](templates/devflow/references/escalation-ladder.md) | Bounded failure handling: retry → debug mode → re-approach → decompose → block |
| [`mcp-catalog.md`](templates/devflow/references/mcp-catalog.md) | MCP server catalog across adapters — universal baseline, stack-specific, client configs |
| [`model-selection.md`](templates/devflow/references/model-selection.md) | Haiku / Sonnet / Opus guide per pipeline step |
| [`orientation.md`](templates/devflow/references/orientation.md) | Session-start routing tree mapping project state to the active pipeline entry point |
| [`run-mode.md`](templates/devflow/references/run-mode.md) | Run-mode contract shared by `devflow.run` and `devflow.auto` |
| [`security-checklist.md`](templates/devflow/references/security-checklist.md) | OWASP Top 10, auth, input validation, secrets baseline |
| [`security-threat-model.md`](templates/devflow/references/security-threat-model.md) | AI agent threat model — prompt injection, state corruption, supply chain |
| [`state-machine.md`](templates/devflow/references/state-machine.md) | Canonical pipeline statuses, legal transitions, and active feature resolution |
| [`status-schema.md`](templates/devflow/references/status-schema.md) | `devflow.status --json` output schema and stable exit codes for CI/scripts |
| [`testing-patterns.md`](templates/devflow/references/testing-patterns.md) | AAA, Beyonce Rule, Prove-It Pattern, pass@k vs pass^k, coverage quality signals |
| [`token-economy.md`](templates/devflow/references/token-economy.md) | Index-first exploration and derive-don't-dump output discipline |
| [`verification-levels.md`](templates/devflow/references/verification-levels.md) | Goal-backward per-AC verification: existence → substantive → wired → runtime |

---

## Adapters

### Git conventions (all adapters)

- **Commit:** `[type]: [short description]` — types: `feat` · `fix` · `chore` · `docs` · `perf`
- **Branch:** `feat/[NNN]_[feature-name]` (or `fix/`, …)
- **PR title:** `[type]: [Feature Name]`

### Flutter (`templates/devflow/adapters/flutter/`)

Baseline: **Flutter · Riverpod · Supabase**. Commands: `flutter analyze`, `flutter test`.

| Skill | Purpose |
| ------- | --------- |
| `flutter-architecture` | Feature folders, layers, scaffold, cross-layer moves |
| `flutter-supabase` | Database read/write/auth, schema, RLS |
| `flutter-supabase-migrations` | Schema migrations, SQL |
| `flutter-theme` | UI screens, visual styling |
| `flutter-riverpod` | Providers, notifiers, async state |
| `flutter-models` | Entities, DTOs, JSON boundaries |
| `flutter-layout` | Layout, breakpoints, scrollables |
| `flutter-form` | Form/wizard flows |

Feature pages: `lib/features/<feature>/pages/<name>_page.dart` (one page) or `pages/<page>/` per page (several) — see `flutter-architecture`.

### Angular (`templates/devflow/adapters/angular/`)

Baseline: standalone + signals-first. Commands: `pnpm run lint`, `pnpm run test`, `pnpm run build`.

| Skill | Purpose |
| ------- | --------- |
| `angular-animations` | Native CSS `animate.enter`/`animate.leave` and animation library integration |
| `angular-architecture` | App structure, folder layout, boundaries |
| `angular-aria` | Accessible headless widgets (`@angular/aria`) |
| `angular-component` | New components, refactoring, template/class |
| `angular-forms` | Signal Forms, schema validation, submit flows |
| `angular-http` | API clients, `httpResource()`, `HttpClient`, interceptors |
| `angular-routing` | Functional routes, guards, resolvers, lazy loading, SSR/hydration |
| `angular-state` | Global & local state management with NgRx Signal Store |
| `angular-testing` | Vitest + TestBed testing patterns |
| `angular-theme` | Theme & styling with Tailwind |

### Next.js (`templates/devflow/adapters/nextjs/`)

Baseline: **Next.js 16 App Router (Cache Components) · Zustand · Tailwind CSS 4 + shadcn/ui · Server Actions + API Routes · Jest + RTL · Playwright**. Commands: `pnpm lint`, `pnpm test`, `pnpm build`.

| Skill | Purpose |
| ------- | --------- |
| `nextjs-architecture` | App structure, folder layout, route segments, parallel/intercepting routes |
| `nextjs-server` | Server Components, Server Actions, API Routes, data fetching, `'use cache'` |
| `nextjs-components` | Client Components, React hooks, interactivity, hydration errors |
| `nextjs-state` | Zustand stores, client state management |
| `nextjs-ui` | shadcn/ui, Tailwind, design tokens, dark mode, responsive |
| `nextjs-forms` | React Hook Form, Zod validation, form flows, Server Actions |
| `nextjs-testing` | Jest + RTL, unit/integration tests, coverage |
| `nextjs-metadata` | SEO, metadata, OG images, `generateMetadata`, sitemap, robots |
| `nextjs-performance` | Image optimization, font loading, script strategies, bundling |

### NestJS (`templates/devflow/adapters/nestjs/`)

Baseline: **NestJS 12 · TypeORM 1 or Prisma 7 · class-validator or Standard Schema · @nestjs/swagger · @nestjs/jwt + Passport · @nestjs/testing + Supertest**. Commands: `npm run lint`, `npm run test`, `npm run build`.

| Skill | Purpose |
| ------- | --------- |
| `nestjs-architecture` | Modules, DI, repository pattern, provider scopes, `ConfigModule` |
| `nestjs-error-handling` | HTTP exceptions, exception filters, async error handling, structured logging |
| `nestjs-security` | Input validation, guards, JWT auth, rate limiting, output sanitization |
| `nestjs-performance` | Async lifecycle hooks, lazy loading, query optimization, caching, graceful shutdown |
| `nestjs-database` | N+1 avoidance, migrations, transactions (TypeORM 1 or Prisma 7 — project choice) |
| `nestjs-api-design` | DTOs/serialization, interceptors, pipes, versioning, API-consumer accessibility (OpenAPI, RFC 7807 errors) |
| `nestjs-testing` | `TestingModule` unit tests, Supertest e2e, mocking external services |
| `nestjs-microservices` | `@MessagePattern`/`@EventPattern`, BullMQ queues, Terminus health checks |

### Common (`templates/devflow/adapters/common/`)

| Skill | Purpose |
| ------- | --------- |
| `common-clean-code` | Shared clean code patterns across all stacks |
| `common-web-interface-guidelines` | UI/UX quality rules applied during beautify on all web adapters |
| `common-caveman` | Token-lean, filler-free response style for plans and reviews |
| `common-state-patterns` | Cross-adapter state management guide — Riverpod / Signal Store / Zustand comparison, scope decision tree, unified mental model |
