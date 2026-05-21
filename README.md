# DevFlow

DevFlow is a **spec-driven development pipeline** that turns a raw idea into a reviewed, tested, and merged feature. Each step maps to a skill (and optional slash command) that defines inputs, steps, outputs, and success criteria.

The workflow is **technology-agnostic**: stack-specific rules live in **adapters** under [`templates/devflow/adapters/`](templates/devflow/adapters/). Today the **Flutter**, **Angular**, and **Next.js** adapters ship with this repo; adding more stacks means adding a new adapter folder and switching [`templates/devflow/config.md`](templates/devflow/config.md).

---

## Pipeline

```
idea
  └── devflow.task
        └── devflow.plan
              └── devflow.implement
                    └── devflow.beautify
                          └── devflow.test
                                └── devflow.ship
                                      └── devflow.pr
```

Each step produces an artifact that feeds the next. Do not skip steps.

---

## Commands (entry points)

| Command | Skill | Input → Output |
|--------|--------|----------------|
| `devflow.setup` | [`templates/devflow/skills/devflow-setup/SKILL.md`](templates/devflow/skills/devflow-setup/SKILL.md) | Consumer repo context + adapter templates → root `AGENTS.md` + `REGISTRY.md` |
| `devflow.task` | [`templates/devflow/skills/devflow-task/SKILL.md`](templates/devflow/skills/devflow-task/SKILL.md) | Idea → `devflow/features/[NNN]_[name]/task.md` |
| `devflow.plan` | [`templates/devflow/skills/devflow-plan/SKILL.md`](templates/devflow/skills/devflow-plan/SKILL.md) | `task.md` → `plan.md` |
| `devflow.implement` | [`templates/devflow/skills/devflow-implement/SKILL.md`](templates/devflow/skills/devflow-implement/SKILL.md) | `plan.md` → code on `feat|fix|…/[NNN]-[name]` |
| `devflow.beautify` | [`templates/devflow/skills/devflow-beautify/SKILL.md`](templates/devflow/skills/devflow-beautify/SKILL.md) | Implemented files → polished code |
| `devflow.test` | [`templates/devflow/skills/devflow-test/SKILL.md`](templates/devflow/skills/devflow-test/SKILL.md) | Feature → unit + integration tests |
| `devflow.ship` | [`templates/devflow/commands/devflow.ship.md`](templates/devflow/commands/devflow.ship.md) | Feature → parallel review (code + security + tests) → gate before PR |
| `devflow.pr` | [`templates/devflow/skills/devflow-pr/SKILL.md`](templates/devflow/skills/devflow-pr/SKILL.md) | Branch → PR to `main` |

Command wrappers live in [`templates/devflow/commands/`](templates/devflow/commands/).

---

## Project docs (in your app repo)

| File | Role | Read by |
|------|------|---------|
| `AGENTS.md` | Global agent operating rules (token-lean, setup-managed sections) | setup + all steps (as host memory/context) |
| `REGISTRY.md` | Shared patterns and conventions summary | setup + plan → pr |
| `constitution.md` | Architecture, stack, layout | plan → pr |
| `registry.md` | Shared patterns | plan → pr |
| `docs/product.md` | Product / feature status | task |

`devflow.setup` manages root `AGENTS.md` and `REGISTRY.md` using adapter templates. By default it updates only `devflow-managed` blocks; pass `--force` to overwrite full files.

---

## Repository layout

```
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
│       ├── commands/                # Slash-command entry points
│       ├── skills/                  # Core pipeline skills (devflow-*)
│       │   ├── devflow-beautify/
│       │   ├── devflow-discovery/
│       │   ├── devflow-implement/
│       │   ├── devflow-plan/
│       │   ├── devflow-pr/
│       │   ├── devflow-setup/
│       │   ├── devflow-task/
│       │   └── devflow-test/
│       ├── adapters/
│       │   ├── ADAPTER.schema.md
│       │   ├── angular/             # angular-architecture, -component, -forms, -http, -state, -testing, -theme
│       │   ├── flutter/             # flutter-supabase, -migrations, -theme, -riverpod, -models, -layout, -form
│       │   ├── nextjs/              # nextjs-architecture, -server, -components, -state, -ui, -forms, -testing, -metadata, -performance
│       │   └── common/              # common-clean-code, -web-interface-guidelines, -caveman
│       ├── agents/
│       │   ├── code-reviewer.md
│       │   ├── security-auditor.md
│       │   └── test-engineer.md
│       ├── references/
│       │   ├── accessibility-checklist.md
│       │   ├── security-checklist.md
│       │   └── testing-patterns.md
│       └── scripts/
│           └── validate-skills.sh
├── dist/
│   └── devflow/                     # Build output — do not edit directly
│       ├── .claude-plugin/          # Claude Code plugin manifest (generated)
│       ├── .cursor-plugin/          # Cursor plugin manifest (generated)
│       └── ...                      # Mirror of templates/devflow/ (minus dev-only files)
├── scripts/
│   ├── build-plugin.sh              # Orchestrator: reads manifest.json, calls builders
│   └── builders/
│       ├── common.sh                # Shared helpers (ok/warn/fail/step)
│       ├── build-claude.sh          # Generates dist/ for Claude Code
│       └── build-cursor.sh          # Adds Cursor layer on dist/
├── .github/
│   └── workflows/
│       ├── build-verify.yml         # CI: verify dist/ is in sync on every PR
│       └── release-please.yml       # CI: automated semver bump + GitHub Release on main push
├── release-please-config.json
├── .release-please-manifest.json
└── CHANGELOG.md
```

Feature folders (in the consumer project) use zero-padded ids (`001`, `002`, …) and `kebab-case` names confirmed with the user.

---

## Build system

The plugin uses a manifest-driven build: source lives in `templates/devflow/`, built output in `dist/devflow/` (committed). Run the build after any change to skills, adapters, or hooks:

```bash
# Rebuild dist/ after any source change
bash scripts/build-plugin.sh

# Validate all SKILL.md files
bash templates/devflow/scripts/validate-skills.sh
```

The build is **idempotent** — it recreates `dist/devflow/` from scratch on every run. Requires `jq` (`brew install jq`).

---

## Plugins (Claude Code & Cursor)

The [`dist/devflow/`](dist/devflow/) folder is a **dual-marketplace plugin**: same tree loads in Claude Code and Cursor.

### Install via Claude Code marketplace (recommended)

```
/plugin marketplace add Gabriele-bil/dev_flow
/plugin install devflow@devflow
```

Skills are namespaced — use them as `/devflow:task`, `/devflow:plan`, etc.

### Install locally (Claude Code)

```bash
claude --plugin-dir ./dist/devflow
```

### Install locally (Cursor)

Symlink `~/.cursor/plugins/local/devflow` → this repo's `dist/devflow` directory, then reload the window — see [Plugins](https://cursor.com/docs/plugins).

More detail: [`templates/devflow/README.md`](templates/devflow/README.md).

### Recommended companion plugin: code-review-graph

Use `code-review-graph` for blast-radius aware reviews in both Cursor and Claude with one setup:

- `pipx install code-review-graph` (or `pip install code-review-graph`)
- `code-review-graph install` (auto-detects configured platforms including Cursor and Claude Code)
- `code-review-graph build` (initial graph indexing per repository)

### Required MCP baseline

| Adapter | MCP servers |
|---------|-------------|
| Angular | `context7`, `sequential-thinking` |
| Flutter | `context7`, `sequential-thinking`, `dart`, `supabase` |
| Next.js | `context7`, `sequential-thinking` |

---

## Agents

Specialized agents live in [`templates/devflow/agents/`](templates/devflow/agents/) and are dispatched automatically by `devflow.ship`:

| Agent | File | Role |
|-------|------|------|
| Code Reviewer | [`agents/code-reviewer.md`](templates/devflow/agents/code-reviewer.md) | Architecture-focused code review |
| Security Auditor | [`agents/security-auditor.md`](templates/devflow/agents/security-auditor.md) | Security vulnerabilities and hardening |
| Test Engineer | [`agents/test-engineer.md`](templates/devflow/agents/test-engineer.md) | Test coverage and quality validation |

`devflow.ship` runs all three in parallel, synthesizes their reports, and routes to `devflow.pr` only if no blockers are found.

---

## References

Shared checklists and patterns in [`templates/devflow/references/`](templates/devflow/references/):

| File | Purpose |
|------|---------|
| [`accessibility-checklist.md`](templates/devflow/references/accessibility-checklist.md) | A11y guidelines |
| [`security-checklist.md`](templates/devflow/references/security-checklist.md) | Security review points |
| [`testing-patterns.md`](templates/devflow/references/testing-patterns.md) | Testing best practices |

---

## Adapters

### Git conventions (all adapters)

- **Commit:** `[type]: [short description]` — types: `feat` · `fix` · `chore` · `docs` · `perf`
- **Branch:** `feat/[NNN]-[feature-name]` (or `fix/`, …)
- **PR title:** `[type]: [Feature Name]`

### Flutter (`templates/devflow/adapters/flutter/`)

Baseline: **Flutter · Riverpod · Supabase**. Commands: `flutter analyze`, `flutter test`.

| Skill | Purpose |
|-------|---------|
| `flutter-supabase` | Database read/write/auth, schema, RLS |
| `flutter-supabase-migrations` | Schema migrations, SQL |
| `flutter-theme` | UI screens, visual styling |
| `flutter-riverpod` | Providers, notifiers, async state |
| `flutter-models` | Entities, DTOs, JSON boundaries |
| `flutter-layout` | Layout, breakpoints, scrollables |
| `flutter-form` | Form/wizard flows |

Feature pages: use `lib/features/<feature>/pages/` with entry file named `page.dart`.

### Angular (`templates/devflow/adapters/angular/`)

Baseline: standalone + signals-first. Commands: `pnpm run lint`, `pnpm run test`, `pnpm run build`.

| Skill | Purpose |
|-------|---------|
| `angular-architecture` | App structure, folder layout, boundaries |
| `angular-component` | New components, refactoring, template/class |
| `angular-forms` | Reactive forms, validation, submit flows |
| `angular-http` | API clients, HttpClient, interceptors |
| `angular-state` | Global & local state management |
| `angular-testing` | Testing patterns |
| `angular-theme` | Theme & styling with Tailwind |

### Next.js (`templates/devflow/adapters/nextjs/`)

Baseline: **Next.js 15+ App Router · Zustand · Tailwind CSS + shadcn/ui · Server Actions + API Routes · Jest + RTL**. Commands: `pnpm lint`, `pnpm test`, `pnpm build`.

| Skill | Purpose |
|-------|---------|
| `nextjs-architecture` | App structure, folder layout, route segments, parallel/intercepting routes |
| `nextjs-server` | Server Components, Server Actions, API Routes, data fetching, `'use cache'` |
| `nextjs-components` | Client Components, React hooks, interactivity, hydration errors |
| `nextjs-state` | Zustand stores, client state management |
| `nextjs-ui` | shadcn/ui, Tailwind, design tokens, dark mode, responsive |
| `nextjs-forms` | React Hook Form, Zod validation, form flows, Server Actions |
| `nextjs-testing` | Jest + RTL, unit/integration tests, coverage |
| `nextjs-metadata` | SEO, metadata, OG images, `generateMetadata`, sitemap, robots |
| `nextjs-performance` | Image optimization, font loading, script strategies, bundling |

### Common (`templates/devflow/adapters/common/`)

| Skill | Purpose |
|-------|---------|
| `common-clean-code` | Shared clean code patterns across all stacks |
| `common-web-interface-guidelines` | UI/UX quality rules applied during beautify on all web adapters |
| `common-caveman` | Token-lean, filler-free response style for plans and reviews |
