# DevFlow

DevFlow is a **spec-driven development pipeline** that turns a raw idea into a reviewed, tested, and merged feature. Each step maps to a skill (and optional slash command) that defines inputs, steps, outputs, and success criteria.

The workflow is **technology-agnostic**: stack-specific rules live in **adapters** under [`devflow/adapters/`](devflow/adapters/). Today only the **Flutter** adapter ships with this repo; adding more stacks means adding a new adapter folder and switching [`devflow/config.md`](devflow/config.md).

---

## Pipeline

```
idea
  └── devflow.task
        └── devflow.plan
              └── devflow.implement
                    └── devflow.beautify
                          └── devflow.test
                                └── devflow.pr
```

Each step produces an artifact that feeds the next. Do not skip steps.

---

## Commands (entry points)

| Command | Skill | Input → Output |
|--------|--------|----------------|
| `devflow.task` | [`devflow/skills/devflow-task/SKILL.md`](devflow/skills/devflow-task/SKILL.md) | Idea → `devflow/features/[NNN]_[name]/task.md` |
| `devflow.plan` | [`devflow/skills/devflow-plan/SKILL.md`](devflow/skills/devflow-plan/SKILL.md) | `task.md` → `plan.md` |
| `devflow.implement` | [`devflow/skills/devflow-implement/SKILL.md`](devflow/skills/devflow-implement/SKILL.md) | `plan.md` → code on `feat|fix|…/[NNN]-[name]` |
| `devflow.beautify` | [`devflow/skills/devflow-beautify/SKILL.md`](devflow/skills/devflow-beautify/SKILL.md) | Implemented files → polished code |
| `devflow.test` | [`devflow/skills/devflow-test/SKILL.md`](devflow/skills/devflow-test/SKILL.md) | Feature → unit + integration tests |
| `devflow.pr` | [`devflow/skills/devflow-pr/SKILL.md`](devflow/skills/devflow-pr/SKILL.md) | Branch → PR to `main` |

Command wrappers live in [`devflow/commands/`](devflow/commands/) (e.g. [`devflow.task.md`](devflow/commands/devflow.task.md)).

---

## Project docs (in your app repo)

| File | Role | Read by |
|------|------|---------|
| `constitution.md` | Architecture, stack, layout | plan → pr |
| `registry.md` | Shared patterns | plan → pr |
| `docs/product.md` | Product / feature status | task |

---

## Directory layout

```
devflow/
├── .claude-plugin/plugin.json   # Claude Code plugin manifest
├── .cursor-plugin/plugin.json   # Cursor plugin manifest
├── config.md                    # Active adapter id
├── commands/                    # Slash-command entry points
├── skills/                      # Core pipeline skills (devflow-*)
├── adapters/
│   └── flutter/
│       ├── ADAPTER.md           # Flutter commands, plan sections, checklists
│       └── skills/              # flutter-* domain skills
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

---

## Conventions (Flutter adapter / example app)

These apply when using the Flutter adapter against a typical Flutter repo:

### Feature pages

Use a dedicated folder per page under `lib/features/<feature>/pages/` and name the entry file `page.dart` (not `*_page.dart` directly under `pages/`).

### Git

- **Commit:** `[type]: [short description]` — types: `feat` · `fix` · `chore` · `docs` · `perf`
- **Branch:** `feat/[NNN]-[feature-name]` (or `fix/`, …)
- **PR title:** `[type]: [Feature Name]`

---

## Migration from Forge

If you used the previous **Forge** layout:

| Before | After |
|--------|--------|
| `forge/` | `devflow/` |
| `forge.task` | `devflow.task` |
| `forge/skills/forge-*` | `devflow/skills/devflow-*` |
| `forge/skills/flutter-*` | `devflow/adapters/flutter/skills/flutter-*` |

Optional: keep a **symlink** `forge` → `devflow` in downstream repos until tools are updated.
