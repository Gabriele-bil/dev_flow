# DevFlow

DevFlow is a **spec-driven development pipeline** that turns a raw idea into a reviewed, tested, and merged feature. Each step maps to a skill (and optional slash command) that defines inputs, steps, outputs, and success criteria.

The workflow is **technology-agnostic**: stack-specific rules live in **adapters** under [`devflow/adapters/`](devflow/adapters/). Today the **Flutter** and **Angular** adapters ship with this repo; adding more stacks means adding a new adapter folder and switching [`devflow/config.md`](devflow/config.md).

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
| `devflow.setup` | [`devflow/skills/devflow-setup/SKILL.md`](devflow/skills/devflow-setup/SKILL.md) | Consumer repo context + adapter templates → root `AGENTS.md` + `REGISTRY.md` |
| `devflow.task` | [`devflow/skills/devflow-task/SKILL.md`](devflow/skills/devflow-task/SKILL.md) | Idea → `devflow/features/[NNN]_[name]/task.md` |
| `devflow.plan` | [`devflow/skills/devflow-plan/SKILL.md`](devflow/skills/devflow-plan/SKILL.md) | `task.md` → `plan.md` |
| `devflow.implement` | [`devflow/skills/devflow-implement/SKILL.md`](devflow/skills/devflow-implement/SKILL.md) | `plan.md` → code on `feat|fix|…/[NNN]-[name]` |
| `devflow.beautify` | [`devflow/skills/devflow-beautify/SKILL.md`](devflow/skills/devflow-beautify/SKILL.md) | Implemented files → polished code |
| `devflow.test` | [`devflow/skills/devflow-test/SKILL.md`](devflow/skills/devflow-test/SKILL.md) | Feature → unit + integration tests |
| `devflow.ship` | [`devflow/commands/devflow.ship.md`](devflow/commands/devflow.ship.md) | Feature → parallel review (code + security + tests) → gate before PR |
| `devflow.pr` | [`devflow/skills/devflow-pr/SKILL.md`](devflow/skills/devflow-pr/SKILL.md) | Branch → PR to `main` |

Command wrappers live in [`devflow/commands/`](devflow/commands/).

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

## Directory layout

```
devflow/
├── .claude-plugin/plugin.json   # Claude Code plugin manifest
├── .cursor-plugin/plugin.json   # Cursor plugin manifest
├── config.md                    # Active adapter id
├── AGENTS.md                    # Global agent rules
├── CONTRIBUTING.md
├── hooks/
│   ├── hooks.json               # SessionStart hook config
│   └── session-start.sh         # Auto-initializes project context on session start
├── commands/                    # Slash-command entry points
├── skills/                      # Core pipeline skills (devflow-*)
│   ├── devflow-beautify/
│   ├── devflow-discovery/
│   ├── devflow-implement/
│   ├── devflow-plan/
│   ├── devflow-pr/
│   ├── devflow-setup/
│   ├── devflow-task/
│   └── devflow-test/
├── adapters/
│   ├── ADAPTER.schema.md
│   ├── angular/
│   │   ├── ADAPTER.md
│   │   ├── templates/
│   │   └── skills/              # angular-architecture, -component, -forms, -http, -state, -testing, -theme
│   ├── flutter/
│   │   ├── ADAPTER.md
│   │   ├── templates/
│   │   └── skills/              # flutter-supabase, -supabase-migrations, -theme, -riverpod, -models, -layout, -form
│   └── common/
│       └── skills/              # common-clean-code
├── agents/
│   ├── code-reviewer.md         # Architecture-focused code review
│   ├── security-auditor.md      # Security review
│   └── test-engineer.md         # Test validation
├── references/
│   ├── accessibility-checklist.md
│   ├── security-checklist.md
│   └── testing-patterns.md
└── features/                    # Generated task.md / plan.md per feature
    └── [NNN]_[feature-name]/
```

Feature folders use zero-padded ids (`001`, `002`, …) and `kebab-case` names confirmed with the user.

---

## Plugins (Claude Code & Cursor)

The [`devflow/`](devflow/) folder is a **dual-marketplace plugin**: same tree loads in Claude Code and Cursor.

- **Claude Code:** `claude --plugin-dir ./devflow` — see [Create plugins](https://code.claude.com/docs/en/plugins). Skills are namespaced (e.g. `/devflow:task`).
- **Cursor:** symlink `~/.cursor/plugins/local/devflow` → this `devflow` directory, reload window — see [Plugins](https://cursor.com/docs/plugins).

More detail: [`devflow/README.md`](devflow/README.md).

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

---

## Agents

Specialized agents live in [`devflow/agents/`](devflow/agents/) and are dispatched automatically by `devflow.ship`:

| Agent | File | Role |
|-------|------|------|
| Code Reviewer | [`agents/code-reviewer.md`](devflow/agents/code-reviewer.md) | Architecture-focused code review |
| Security Auditor | [`agents/security-auditor.md`](devflow/agents/security-auditor.md) | Security vulnerabilities and hardening |
| Test Engineer | [`agents/test-engineer.md`](devflow/agents/test-engineer.md) | Test coverage and quality validation |

`devflow.ship` runs all three in parallel, synthesizes their reports, and routes to `devflow.pr` only if no blockers are found.

---

## References

Shared checklists and patterns in [`devflow/references/`](devflow/references/):

| File | Purpose |
|------|---------|
| [`accessibility-checklist.md`](devflow/references/accessibility-checklist.md) | A11y guidelines |
| [`security-checklist.md`](devflow/references/security-checklist.md) | Security review points |
| [`testing-patterns.md`](devflow/references/testing-patterns.md) | Testing best practices |

---

## Adapters

### Flutter (`devflow/adapters/flutter/`)

Domain skills:

| Skill | Purpose |
|-------|---------|
| `flutter-supabase` | Database read/write/auth, schema, RLS |
| `flutter-supabase-migrations` | Schema migrations, SQL |
| `flutter-theme` | UI screens, visual styling |
| `flutter-riverpod` | Providers, notifiers, async state |
| `flutter-models` | Entities, DTOs, JSON boundaries |
| `flutter-layout` | Layout, breakpoints, scrollables |
| `flutter-form` | Form/wizard flows |

Git conventions:
- **Commit:** `[type]: [short description]` — types: `feat` · `fix` · `chore` · `docs` · `perf`
- **Branch:** `feat/[NNN]-[feature-name]` (or `fix/`, …)
- **PR title:** `[type]: [Feature Name]`

Feature pages: use `lib/features/<feature>/pages/` with entry file named `page.dart`.

### Angular (`devflow/adapters/angular/`)

Domain skills:

| Skill | Purpose |
|-------|---------|
| `angular-architecture` | App structure, folder layout, boundaries |
| `angular-component` | New components, refactoring, template/class |
| `angular-forms` | Reactive forms, validation, submit flows |
| `angular-http` | API clients, HttpClient, interceptors |
| `angular-state` | Global & local state management |
| `angular-testing` | Testing patterns |
| `angular-theme` | Theme & styling with Tailwind |

Baseline: standalone + signals-first. Commands: `pnpm run lint`, `pnpm run test`, `pnpm run build`.

### Common (`devflow/adapters/common/`)

| Skill | Purpose |
|-------|---------|
| `common-clean-code` | Shared clean code patterns across all stacks |
