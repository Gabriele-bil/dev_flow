---
name: devflow-setup
description: Generates or updates AGENTS.md, REGISTRY.md, and docs/product.md in the consumer project root from adapter templates using token-lean managed sections and a mandatory questionnaire. Use when running devflow.setup after plugin install or when adapter/stack/product context changes.
argument-hint: [--force]
disable-model-invocation: true
---

# Skill: devflow.setup

## Purpose

Create or refresh global AI context files (`AGENTS.md`, `REGISTRY.md`) and product context (`docs/product.md`) in the consumer project root.
Output must be concise, stable, and safe to re-run.
`AGENTS.md` must keep any template-provided `code-review-graph` skill reference intact.

Command is **standalone** (pre-pipeline), not feature step like `task/plan/implement`.

## Input

- Optional `$ARGUMENTS` with `--force`

`--force` behavior:

- present: overwrite full file contents
- absent: update only `devflow-managed` sections

## Managed block format (required)

All generated sections must use this delimiter format:

```markdown
<!-- devflow-managed:start:<section-id> -->
...managed content...
<!-- devflow-managed:end:<section-id> -->
```

Never edit user content outside managed blocks unless `--force` is set.

## Workflow

### Step 1 - Resolve adapter

1. Read `@devflow/config.md`.
2. Extract `Adapter` and `Adapter root`.
3. Build adapter contract path:
   `@devflow/adapters/<adapter>/ADAPTER.md`

### Step 2 - Load contract and templates

1. Read adapter contract file.
2. Resolve template directory in this order:
   - `@devflow/adapters/<adapter>/templates/` (preferred)
   - `@devflow/skills/devflow-setup/templates/` (fallback)
3. Read all templates from chosen directory:
   - `AGENTS.template.md`
   - `REGISTRY.template.md`
   - `PRODUCT.template.md`

If preferred directory missing, report fallback in final response.

### Step 3 - Mandatory full questionnaire (always)

Before rendering any file, run a complete questionnaire to collect all values required by all templates.
Do not skip this step even if values can be inferred.

Collection order:

1. Prefer `AskQuestion` for structured choices.
2. Use concise chat questions for free text fields.
3. Confirm ambiguous answers once, then proceed.

Rules:

- Always ask for every field listed in **Placeholder map**.
- If user refuses or does not know, store `[TODO: fill]`.
- Keep questions short and grouped by topic (product, conventions, patterns, commands).

### Step 4 - Build placeholder map from answers + context

Build final values for template placeholders from:

| Source | Extract | Required |
|---|---|:---:|
| `constitution.md` | architecture/layering, naming, default commands | no |
| existing `docs/product.md` | product/app hints for continuity | no |
| Adapter-defined project manifests (for example language/package manifests) | package/project name | no |
| `@devflow/config.md` | adapter id | yes |
| `@devflow/adapters/<adapter>/ADAPTER.md` | stack commands, key rules | yes |
| **Mandatory questionnaire answers** | all unresolved placeholders | yes |

If a value cannot be inferred, keep a literal placeholder token:
`[TODO: fill]`.

### Step 5 - Placeholder map (required)

You must collect and resolve these fields before render:

| Placeholder | Target file | Prompt intent |
|---|---|---|
| `project-name` | AGENTS, PRODUCT | Product/app name shown to humans |
| `adapter` | AGENTS | Active stack adapter id |
| `format-cmd` | AGENTS, REGISTRY | Formatting command |
| `analyze-cmd` | AGENTS, REGISTRY | Static analysis command |
| `test-cmd` | REGISTRY | Test command |
| `naming-rule` | REGISTRY | Naming conventions summary |
| `pattern-1-name` | REGISTRY | Pattern title |
| `pattern-1-when` | REGISTRY | When to apply pattern 1 |
| `pattern-1-path` | REGISTRY | Path for pattern 1 |
| `pattern-2-name` | REGISTRY | Pattern title |
| `pattern-2-when` | REGISTRY | When to apply pattern 2 |
| `pattern-2-path` | REGISTRY | Path for pattern 2 |
| `product-domain` | PRODUCT | Problem space/domain |
| `target-users` | PRODUCT | Primary actors/users |
| `primary-outcome` | PRODUCT | Main user value |
| `feature-1-name` | PRODUCT | Key feature label |
| `feature-1-status` | PRODUCT | `implemented` or `planned` |
| `feature-1-notes` | PRODUCT | Scope/status notes |
| `feature-2-name` | PRODUCT | Key feature label |
| `feature-2-status` | PRODUCT | `implemented` or `planned` |
| `feature-2-notes` | PRODUCT | Scope/status notes |
| `feature-3-name` | PRODUCT | Key feature label |
| `feature-3-status` | PRODUCT | `implemented` or `planned` |
| `feature-3-notes` | PRODUCT | Scope/status notes |

### Step 6 - Render token-lean content

Render all files by replacing `{{...}}` placeholders.

Token-efficiency rules:

- imperative short lines, no filler
- preserve commands/paths/symbols as-is
- avoid long explanations
- keep section count fixed to template structure

Budget targets:

- `AGENTS.md`: under ~300 tokens
- `REGISTRY.md`: under ~600 tokens
- `docs/product.md`: under ~700 tokens

### Step 7 - Write files

Target location: consumer project root.

#### AGENTS.md

- file missing: create from rendered template
- file exists, no `--force`: replace only managed sections by matching `<section-id>`
- file exists + `--force`: overwrite full file

#### REGISTRY.md

- same rules as `AGENTS.md`

#### docs/product.md

- file missing: create from rendered template (always)
- file exists, no `--force`: replace only managed sections by matching `<section-id>`
- file exists + `--force`: overwrite full file

When non-force mode cannot find valid managed markers in an existing file:

- append rendered managed blocks to the end of the file
- do not rewrite existing user sections

### Step 8 - Notify user

Respond with:

```text
✅ Setup complete

AGENTS.md: [created|updated|overwritten]
REGISTRY.md: [created|updated|overwritten]
docs/product.md: [created|updated|overwritten]

Template source: [adapter|fallback]
Manual placeholders: [N]
- [file]: [placeholder]

Questionnaire fields asked: [N]
Auto-inferred fields: [N]
User-provided fields: [N]

Next: run devflow.task
```

## Output quality checklist

Before final response:

- [ ] all three files exist in consumer root
- [ ] managed markers are valid and paired
- [ ] non-managed user content preserved (unless `--force`)
- [ ] no verbose filler added
- [ ] unresolved values listed as `[TODO: fill]`

## Red flags

- Writing files inside `devflow/` instead of consumer root
- Overwriting user content without `--force`
- Generating marker-less content
- Expanding templates with long narrative prose
- Using adapter templates when they do not exist without fallback
- Skipping any required questionnaire field
