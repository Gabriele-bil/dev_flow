# Design: constitution.md Bootstrap via devflow.setup

**Date:** 2026-05-28  
**Status:** Approved

## Problem

`constitution.md` is referenced in 30+ places across DevFlow skills (plan, implement, beautify, blueprint, all adapters) as the authoritative source for architecture rules, naming conventions, and layer order. However, `devflow.setup` never creates it — no template exists. The file is assumed to pre-exist, creating a bootstrap gap: every pipeline skill references it, but there is no way to generate it.

## Approach

Extend `devflow.setup` (Approach A) to:
1. Create per-adapter `CONSTITUTION.template.md` files
2. Extend the questionnaire with architecture-specific questions
3. Write `constitution.md` to the consumer project root alongside AGENTS.md, REGISTRY.md, and docs/product.md
4. Apply the same managed-block merge policy used by the other three files

## Files to Create

| File | Purpose |
|---|---|
| `templates/devflow/adapters/flutter/templates/CONSTITUTION.template.md` | Flutter-specific template (Riverpod layers, Dart naming) |
| `templates/devflow/adapters/angular/templates/CONSTITUTION.template.md` | Angular-specific template (core/pages/shared, Angular naming) |
| `templates/devflow/adapters/nextjs/templates/CONSTITUTION.template.md` | Next.js-specific template (server/client boundary, App Router) |
| `templates/devflow/skills/devflow-setup/templates/CONSTITUTION.template.md` | Universal fallback template |

## Files to Modify

| File | Changes |
|---|---|
| `templates/devflow/skills/devflow-setup/SKILL.md` | Steps 2, 3, 3b, 5, 6b, 7, 8, quality checklist |

## Template Structure

All four templates share the same managed-block skeleton. Adapter-specific defaults differ.

```markdown
<!-- devflow-managed:start:architecture -->
## Architecture
**Stack:** {{adapter}}
**Layer order:** {{layer-order}}

| Layer | Path | Responsibility |
|---|---|---|
| {{layer-1-name}} | `{{layer-1-path}}` | {{layer-1-responsibility}} |
| {{layer-2-name}} | `{{layer-2-path}}` | {{layer-2-responsibility}} |
| {{layer-3-name}} | `{{layer-3-path}}` | {{layer-3-responsibility}} |
<!-- devflow-managed:end:architecture -->

<!-- devflow-managed:start:naming -->
## Naming conventions
{{naming-conventions}}
<!-- devflow-managed:end:naming -->

<!-- devflow-managed:start:imports -->
## Import conventions
{{import-conventions}}
<!-- devflow-managed:end:imports -->

<!-- devflow-managed:start:decisions -->
## Key decisions
{{key-decisions}}
<!-- devflow-managed:end:decisions -->
```

### Adapter-specific defaults

**Flutter:**
- `layer-order`: `domain → data → riverpod → UI → i18n/codegen`
- `key-decisions`: Riverpod for state, Freezed for models, slang for i18n, Supabase for backend

**Angular:**
- `layer-order`: `core → shared → pages`
- `key-decisions`: Signal Store for state, standalone components, no NgRx

**Next.js:**
- `layer-order`: `app → components → lib → actions`
- `key-decisions`: Server Components by default, Zustand for global client state, URL state for filters

## Questionnaire Additions (Step 3)

New questions grouped under topic "architecture", asked after existing questions:

| Field | Question | Fallback |
|---|---|---|
| `layer-order` | "Describe your layer order (e.g. domain → data → UI)" | adapter default |
| `layer-N-name/path/responsibility` | "List your architecture layers: name, folder path, responsibility" | `[TODO: fill]` |
| `naming-conventions` | "Describe naming rules (files, classes, functions, constants)" | inferred from codebase scan |
| `import-conventions` | "Describe import style (relative/absolute, barrel files, aliases)" | `[TODO: fill]` |
| `key-decisions` | "List key architectural decisions (state, DI, routing, DB access)" | adapter default |

## Placeholder Map Additions (Step 5)

| Placeholder | Target file | Prompt intent |
|---|---|---|
| `layer-order` | CONSTITUTION | Layer sequence label |
| `layer-N-name` | CONSTITUTION | Layer name (N = 1…N) |
| `layer-N-path` | CONSTITUTION | Folder path for layer N |
| `layer-N-responsibility` | CONSTITUTION | What layer N owns |
| `naming-conventions` | CONSTITUTION | File/class/function naming rules |
| `import-conventions` | CONSTITUTION | Import style and barrel file rules |
| `key-decisions` | CONSTITUTION | Architectural decisions list |

## Codebase Scan Extension (Step 3b)

For `naming-conventions`: sample 3-5 existing files to infer real naming patterns from the repo. If repo is empty, use adapter default. Pre-fill `naming-conventions` placeholder before render.

## Write Rules (Step 7)

| Condition | Action |
|---|---|
| File absent | Create from rendered template |
| File exists, no `--force` | Merge only managed blocks by `<section-id>` |
| File exists + `--force` | Full overwrite |
| File exists, no managed markers | Append rendered managed blocks to end, preserve user content |

## Token Budget (Step 6b)

- `constitution.md`: warn if rendered content exceeds ~400 words (~530 tokens)
- Trim order: shorten layer table rows → remove narrative sentences from decisions → abbreviate naming rules

## Summary Update (Step 8)

Add to the completion message:
```
constitution.md:  [created|updated|overwritten]
```

## Quality Checklist Additions

- `[ ] constitution.md exists in consumer root`
- `[ ] all managed blocks have valid paired markers`
