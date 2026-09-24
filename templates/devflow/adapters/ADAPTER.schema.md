# Adapter Architecture & Schema

Canonical contract and section checklist for all DevFlow adapters. Use when creating a new adapter or auditing an existing one via `bash templates/devflow/scripts/validate-adapters.sh`.

`[R]` = Required — pipeline skills depend on this section / file  
`[O]` = Optional — include when applicable to the stack

---

## Directory Layout

Each adapter in `templates/devflow/adapters/<adapter>/` must follow the modular structure:

```text
adapters/<adapter>/
├── ADAPTER.md                  # Core metadata (loaded by all steps)
├── steps/                      # Per-step contract files (loaded only for active step)
│   ├── setup.md                # devflow.setup
│   ├── plan.md                 # devflow.plan
│   ├── implement.md            # devflow.implement
│   ├── beautify.md             # devflow.beautify
│   ├── test.md                 # devflow.test (and devflow.backprop)
│   └── pr.md                   # devflow.pr
├── templates/                  # Scaffolding templates applied by devflow.setup
│   ├── AGENTS.template.md      # Consumer root AGENTS.md template
│   ├── REGISTRY.template.md    # Shared patterns and conventions
│   ├── CONSTITUTION.template.md# Architecture & layout baseline
│   └── PRODUCT.template.md     # [O] Product status template (fallback in devflow-setup)
└── skills/                     # Stack-specific technology skills
    └── <stack>-<topic>/SKILL.md
```

> **Why modular?** Rather than loading a monolithic `ADAPTER.md` in every prompt, pipeline skills (`devflow-plan`, `devflow-implement`, etc.) load only the core `ADAPTER.md` plus their specific `steps/<step>.md`. This saves tokens and keeps prompt context focused.

---

## 1. Core File: `ADAPTER.md`

Loaded by all pipeline skills immediately after adapter resolution.

| Section / Element | Expected Heading / Key | Type | Consumer Skill | Notes |
| --- | --- | :---: | --- | --- |
| Technology skills table | `## Technology skills` | `[R]` | All steps | Table mapping feature type / concern → `@devflow/adapters/<adapter>/skills/<skill>/SKILL.md` |
| MCP baseline | `## MCP` | `[R]` | `devflow.setup`, `plan`, `implement` | Universal baseline + stack core tools + conditional infrastructure |
| Step files index | `## Step files` | `[R]` | All steps | Table mapping step (`setup`, `plan`, `implement`, `beautify`, `test`, `pr`) → `steps/<step>.md` |
| Caveman response rules | `## Caveman response rules` | `[O]` | All steps | Style reminders: imperative, filler-free, token-lean |

---

## 2. Step Files: `steps/*.md`

Loaded only by the corresponding pipeline skill.

### `steps/setup.md` (Consumer: `devflow.setup`)

| Section | Expected Heading / Key | Type | Notes |
| --- | --- | :---: | --- |
| Setup templates | `## Setup: templates` | `[R]` | Relative or `@devflow/...` paths to `AGENTS.template.md` and `REGISTRY.template.md` |
| Setup dependencies | `## Setup dependencies` | `[O]` | Authoritative runtime and dev dependencies auto-installed or verified |

### `steps/plan.md` (Consumer: `devflow.plan`)

| Section | Expected Heading / Key | Type | Notes |
| --- | --- | :---: | --- |
| Plan extra sections | `## Plan: extra sections and templates` | `[R]` | Stack-specific sections to include in `plan.md` |
| Dependency ordering | `### .*dependency ordering.*` or `### Dependency ordering` | `[R]` | Bottom-up layering / architectural dependency rules |
| State plan | `### State plan` | `[O]` | Structure and constraints when feature introduces state changes |
| Forms plan | `### Forms plan` | `[O]` | Form UX, validation, and submit flow constraints |
| Data model | `### Data model` | `[O]` | Single source of truth mapping entity definitions to DTOs/interfaces |
| Localization | `### Localization` | `[O]` | i18n key conventions and translation requirements |

### `steps/implement.md` (Consumer: `devflow.implement`)

| Section | Expected Heading / Key | Type | Notes |
| --- | --- | :---: | --- |
| Skill load decision matrix | `## Implement: skill load decision matrix` | `[R]` | Table mapping file path glob/pattern → technology skill |
| Commands and checklist | `## Implement: commands and checklist` | `[R]` | Format, lint, analyze, test, and build shell commands |
| Pre-handoff checklist | `### Pre-handoff checklist (implement)` | `[R]` | Mandatory quality gates before advancing to `devflow.beautify` |
| CLI conventions | `### CLI conventions` | `[O]` | Generation commands, dependency installation conventions |
| Codegen triggers | `### Codegen` or within commands | `[O]` | Triggers for stacks with code generators (e.g. `build_runner`) |

### `steps/beautify.md` (Consumer: `devflow.beautify`)

| Section | Expected Heading / Key | Type | Notes |
| --- | --- | :---: | --- |
| Beautify commands | `## Beautify: commands` | `[R]` | Format/lint/typecheck commands executed during beautify |
| Stack-specific review axes | `### Beautify: .*review axes` | `[R]` | Stack review dimensions (theme-first, reactive scope, state purity) |
| Accessibility checks | `### Beautify: .*accessibility.*` | `[R]` | WCAG AA / ARIA rules (UI stacks) or API-consumer accessibility (backend stacks) |
| Performance profiling trigger | `### Beautify: performance profiling trigger` | `[R]` | Profiling conditions, DevTools triggers, and cost heuristics |
| Web interface guidelines | `### Beautify: web interface guidelines` | `[O]` | Required for UI-heavy web stacks (`common-web-interface-guidelines`) |

### `steps/test.md` (Consumer: `devflow.test`, `devflow.backprop`)

| Section | Expected Heading / Key | Type | Notes |
| --- | --- | :---: | --- |
| Coverage threshold | `### Coverage threshold` | `[R]` | Must contain numeric threshold line (e.g. `test-coverage-threshold: 80`) |
| Test placement | `### Placement` | `[R]` | File layout for unit and integration tests |
| Test commands | `### Commands` | `[R]` | Exact shell commands to execute test suites |
| Required test focus | `### Required test focus` | `[O]` | Explicit test targets per architectural layer |
| Runtime verify target | `### Verify (runtime)` | `[O]` | Level-4 runtime verification command (`devflow.test` Step 6b) |

### `steps/pr.md` (Consumer: `devflow.pr`)

| Section | Expected Heading / Key | Type | Notes |
| --- | --- | :---: | --- |
| PR verification commands | `## PR: verification` | `[R]` | Final pre-push checks (lint, test, build) |
| PR body checklist | `### PR body checklist` | `[R]` | Copy-paste markdown checklist items for the PR description |

---

## 3. Scaffolding Templates: `templates/`

Applied by `devflow.setup` during consumer project initialization.

| Template | Type | Purpose |
| --- | :---: | --- |
| `AGENTS.template.md` | `[R]` | Operating rules, required MCP baseline, and active technology skill pointers |
| `REGISTRY.template.md` | `[R]` | Stack-specific shared patterns, architecture rules, and folder conventions |
| `CONSTITUTION.template.md`| `[R]` | Core stack declarations, architecture layers, and non-negotiable principles |
| `PRODUCT.template.md` | `[O]` | Initial product status and feature registry template |

---

## 4. Technology Skills: `skills/`

Each adapter must provide focused technology skills referenced in its `ADAPTER.md` skills table and `steps/implement.md` decision matrix.

- Every skill must reside in `adapters/<adapter>/skills/<skill-name>/SKILL.md`.
- Skills must pass `validate-skills.sh` validation (valid YAML frontmatter with `name` and `description`, plus `## I/O Reference`).
- Every path referenced in `ADAPTER.md` must resolve to an existing file on disk (no dead links).

---

## Completeness & Validation

When adding a new adapter or modifying an existing one, run the adapter validator:

```bash
# Validate all adapters against this schema
bash templates/devflow/scripts/validate-adapters.sh

# Run strict validation (checks threshold formats, non-empty code blocks, etc.)
bash templates/devflow/scripts/validate-adapters.sh --strict
```
