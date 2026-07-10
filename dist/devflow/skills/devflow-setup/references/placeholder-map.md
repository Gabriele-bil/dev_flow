# Setup placeholder map and adapter defaults

Used by `devflow.setup` Step 4 (adapter defaults for constitution fields) and Step 5 (required placeholder fields).

## Constitution field adapter defaults

Use when the questionnaire answer is empty or `[TODO: fill]`.

**Flutter:**

- `layer-order`: `domain → data → riverpod → UI → i18n/codegen`
- `import-conventions`: `Use package:{{project-name}} imports. Barrel files: index.dart per layer. No relative cross-layer imports.`
- `key-decisions`:
  - State: Riverpod (flutter_riverpod + riverpod_annotation)
  - Models: Freezed + json_serializable
  - i18n: slang
  - Backend: Supabase
  - Routing: [TODO: fill]

**Angular:**

- `layer-order`: `core → shared → pages`
- `import-conventions`: `Path aliases: @core/, @shared/, @pages/. Barrel files: public-api.ts. No deep cross-module imports.`
- `key-decisions`:
  - State: Signal Store (no NgRx)
  - Components: standalone (no NgModules)
  - HTTP: HttpClient with typed responses
  - Routing: Angular Router with lazy loading

**Next.js:**

- `layer-order`: `app → components → lib → actions`
- `import-conventions`: `Path alias: @/ → project root. Barrel files: index.ts per directory. No server imports in Client Components.`
- `key-decisions`:
  - Components: Server Components by default; 'use client' only for hooks/browser API
  - State: Zustand for global client state; URL state for filters/pagination
  - Data: Server Actions (actions.ts) for mutations
  - Routing: App Router (app/ directory)

## Required placeholder fields

You must collect and resolve these fields before render:

| Placeholder | Target file | Prompt intent |
| --- | --- | --- |
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
| `feature-[N]-name` | PRODUCT | Key feature label (N = 1, 2, 3…) |
| `feature-[N]-status` | PRODUCT | `implemented`, `planned`, `in-progress`, or `deprecated` |
| `feature-[N]-notes` | PRODUCT | Scope/status notes |
| `layer-order` | CONSTITUTION | Layer sequence label (e.g. `domain → data → UI`) |
| `layer-N-name` | CONSTITUTION | Layer name (N = 1…N) |
| `layer-N-path` | CONSTITUTION | Folder path for layer N |
| `layer-N-responsibility` | CONSTITUTION | What layer N owns |
| `naming-conventions` | CONSTITUTION | File/class/function naming rules |
| `import-conventions` | CONSTITUTION | Import style and barrel file rules |
| `key-decisions` | CONSTITUTION | Architectural decisions list (state, DI, routing, DB) |

Collect at least 3 features. Ask: "List your key features (name, status, notes). Add as many as needed." Add one table row per feature. `devflow.task` will maintain this table as features progress.
