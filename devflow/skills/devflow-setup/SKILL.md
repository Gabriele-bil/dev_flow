---
name: devflow-setup
description: Generates or updates AGENTS.md and REGISTRY.md in the consumer project root from adapter templates using token-lean managed sections. Use when running devflow.setup after plugin install or when adapter/stack changes.
argument-hint: [--force]
disable-model-invocation: true
---

# Skill: devflow.setup

## Purpose

Create or refresh global AI context files (`AGENTS.md`, `REGISTRY.md`) in the consumer project root.
Output must be concise, stable, and safe to re-run.

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
3. Read both templates from chosen directory:
   - `AGENTS.template.md`
   - `REGISTRY.template.md`

If preferred directory missing, report fallback in final response.

### Step 3 - Scan consumer project context

Collect values for template placeholders from these sources:

| Source | Extract | Required |
|---|---|:---:|
| `constitution.md` | architecture/layering, naming, default commands | no |
| `docs/product.md` | project/app name (if present) | no |
| Adapter-defined project manifests (for example language/package manifests) | package/project name | no |
| `@devflow/config.md` | adapter id | yes |
| `@devflow/adapters/<adapter>/ADAPTER.md` | stack commands, key rules | yes |

If a value cannot be inferred, keep a literal placeholder token:
`[TODO: fill]`.

### Step 4 - Render token-lean content

Render both files by replacing `{{...}}` placeholders.

Token-efficiency rules:

- imperative short lines, no filler
- preserve commands/paths/symbols as-is
- avoid long explanations
- keep section count fixed to template structure

Budget targets:

- `AGENTS.md`: under ~300 tokens
- `REGISTRY.md`: under ~600 tokens

### Step 5 - Write files

Target location: consumer project root.

#### AGENTS.md

- file missing: create from rendered template
- file exists, no `--force`: replace only managed sections by matching `<section-id>`
- file exists + `--force`: overwrite full file

#### REGISTRY.md

- same rules as `AGENTS.md`

When non-force mode cannot find valid managed markers in an existing file:

- append rendered managed blocks to the end of the file
- do not rewrite existing user sections

### Step 6 - Notify user

Respond with:

```text
✅ Setup complete

AGENTS.md: [created|updated|overwritten]
REGISTRY.md: [created|updated|overwritten]

Template source: [adapter|fallback]
Manual placeholders: [N]
- [file]: [placeholder]

Next: run devflow.task
```

## Output quality checklist

Before final response:

- [ ] both files exist in consumer root
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
