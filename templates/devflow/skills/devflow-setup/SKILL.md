---
name: devflow-setup
description: Generates or updates AGENTS.md, REGISTRY.md, and docs/product.md in the consumer project root from adapter templates using token-lean managed sections and a mandatory questionnaire. Use when running devflow.setup after plugin install or when adapter/stack/product context changes.
argument-hint: [--force]
disable-model-invocation: true
---

# Skill: devflow.setup

## Purpose

Create or refresh global AI context files (`AGENTS.md`, `REGISTRY.md`) and product context (`docs/product.md`) in the consumer project root.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- No adapter supported by devflow is detected and user cannot identify the stack — resolve adapter choice first
- `devflow.setup` already ran and only a specific managed section needs updating — pass `--force` and edit directly instead of re-running the full questionnaire
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

### Step 1 - Detect and resolve adapter

Before loading templates, determine the active technology stack and update the configuration:

1. Scan the consumer project root to detect the stack:
   - If `pubspec.yaml` exists, adapter is `flutter`.
   - If `angular.json` exists, or `analog` / `@angular/core` are in `package.json`, adapter is `angular`.
   - If `next.config.js`, `next.config.mjs`, or `next.config.ts` exists, or `next` is in `package.json`, adapter is `nextjs`.
2. If the stack cannot be detected automatically, ask the user: "What stack are you using? (Available adapters: angular, flutter, nextjs)" and wait for their choice.
3. Overwrite `@devflow/config.md` with the resolved adapter:
   ```markdown
   # DevFlow Configuration

   **Adapter:** <adapter>  
   **Adapter root:** `devflow/adapters/<adapter>/`

   Pipeline skills read this file first, then load `@devflow/adapters/<adapter>/ADAPTER.md` for technology-specific commands, plan sections, checklists, and skill references.
   ```
4. Build adapter contract path:
   `@devflow/adapters/<adapter>/ADAPTER.md`

### Step 2 - Load contract and templates

1. Read adapter contract file.
2. Read `Setup dependencies` section from `@devflow/adapters/<adapter>/ADAPTER.md` and extract:
   - JavaScript package list (runtime + dev where applicable)
   - Flutter package list (`dependencies`, `dev_dependencies` if explicitly declared)
   - Optional adapter notes for setup installs
3. Resolve template directory in this order:
   - `@devflow/adapters/<adapter>/templates/` (preferred)
   - `@devflow/skills/devflow-setup/templates/` (fallback)
4. Read all templates from chosen directory:
   - `AGENTS.template.md`
   - `REGISTRY.template.md`
   - `PRODUCT.template.md`
   - `CONSTITUTION.template.md`

If preferred directory missing, report fallback in final response.
If `Setup dependencies` is missing in adapter contract, report this as a setup contract error and stop.

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
- Keep questions short and grouped by topic (product, conventions, patterns, commands, architecture).

### Step 3b - Codebase scan (optional, run after questionnaire)

After collecting questionnaire answers, scan the live repo to ground REGISTRY.md in real patterns:

1. Run `Glob` on the adapter's primary feature directory (e.g. `lib/features/*/` for Flutter, `src/app/*/` for Angular, `app/*/` or `src/app/*/` for Next.js) to enumerate existing feature/page folders
2. Sample 2-3 existing file names from each folder to infer naming conventions in use
3. For each observed pattern, extract: name, trigger condition (`when`), and example file path

Use these observations to pre-fill `pattern-1`, `pattern-2` (and optionally `pattern-3`) in the placeholder map before rendering — replacing any questionnaire `[TODO: fill]` values for patterns with real examples from the repo.

Additionally, sample 5-10 existing source files across the project root to infer `naming-conventions`:
- Extract file naming pattern (snake_case.dart, kebab-case.ts, PascalCase.tsx, etc.)
- Extract class and top-level function naming from file headers
- Pre-fill `naming-conventions` placeholder if a consistent pattern is found; otherwise leave `[TODO: fill]`

If the feature directory does not exist or is empty, skip feature scan and use questionnaire values or adapter defaults for all constitution fields.

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

For constitution fields, use these adapter defaults when the questionnaire answer is empty or `[TODO: fill]`:

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
| `feature-[N]-name` | PRODUCT | Key feature label (N = 1, 2, 3…) |
| `feature-[N]-status` | PRODUCT | `implemented`, `planned`, `in-progress`, or `deprecated` |
| `feature-[N]-notes` | PRODUCT | Scope/status notes |

Collect at least 3 features. Ask: "List your key features (name, status, notes). Add as many as needed." Add one table row per feature. `devflow.task` will maintain this table as features progress.

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

### Step 6b - Token budget check (after render, before write)

After rendering each file, estimate token count using word count as proxy (300 words ≈ 400 tokens):

- `AGENTS.md`: warn if rendered content exceeds ~225 words
- `REGISTRY.md`: warn if rendered content exceeds ~450 words
- `docs/product.md`: warn if rendered content exceeds ~525 words

If over budget, trim in this order:
1. Remove worked examples or multi-sentence explanations from bullets — replace with imperative fragment
2. Remove any sentence starting with "This section..." or "Note that..."
3. Shorten skill reference paths only if duplicated elsewhere in the file

Log the final word count per file in the Step 8 summary.

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

### Step 7b - Gitignore (runtime artifacts)

Ensure `.devflow-state.json` is listed in the consumer project's `.gitignore`.

- `.gitignore` exists and already contains `.devflow-state.json` → skip
- `.gitignore` exists and does not contain it → append:
  ```
  # devflow runtime state
  .devflow-state.json
  ```
- `.gitignore` does not exist → skip (the `pre-compact` hook appends it automatically on first run)

### Step 7c - Install adapter setup dependencies (required)

After successful file writes, install dependencies declared in the active adapter `Setup dependencies` section.

Rules:

1. Execute installs from the consumer project root only.
2. Detect runtime first:
   - Flutter project: `pubspec.yaml` exists → use Flutter commands.
   - JavaScript project: `package.json` exists → detect package manager in order:
     - `pnpm-lock.yaml` → `pnpm`
     - `yarn.lock` → `yarn`
     - `package-lock.json` → `npm`
     - none found → default `npm`
3. Install only packages listed in adapter `Setup dependencies`. Do not invent package names.
4. Command mapping:
   - JS runtime deps:
     - `pnpm add <packages>`
     - `yarn add <packages>`
     - `npm install <packages>`
   - JS dev deps (if adapter lists them):
     - `pnpm add -D <packages>`
     - `yarn add -D <packages>`
     - `npm install -D <packages>`
   - Flutter deps:
     - Prefer a single `flutter pub add <packages>` call per dependency bucket.
     - If adapter requires versions, keep exact constraints from adapter contract.
5. If install command fails:
   - stop setup flow
   - report exact failed command and stderr
   - do not claim setup complete
6. If dependency set is empty for active adapter:
   - skip install step
   - report `Dependency install skipped (none declared)`.

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

Dependency install:
- adapter: [adapter]
- manager: [pnpm|yarn|npm|flutter]
- installed runtime deps: [N]
- installed dev deps: [N]
- commands:
  - [command 1]
  - [command 2]

Next: run devflow.task
```

## Output quality checklist

Before final response:

- [ ] all three files exist in consumer root
- [ ] managed markers are valid and paired
- [ ] non-managed user content preserved (unless `--force`)
- [ ] adapter setup dependencies installed (or explicit skip reason reported)
- [ ] no verbose filler added
- [ ] unresolved values listed as `[TODO: fill]`

## Red flags

- Writing files inside `devflow/` instead of consumer root
- Overwriting user content without `--force`
- Generating marker-less content
- Expanding templates with long narrative prose
- Using adapter templates when they do not exist without fallback
- Skipping any required questionnaire field
- Skipping adapter `Setup dependencies` install without explicit `none declared` evidence

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Writing files inside `devflow/features/` during setup | Consumer project artefacts pollute plugin directory | Write only to consumer project root; `devflow/` is read-only during setup |
| Skipping the questionnaire and guessing adapter | Wrong adapter → wrong templates → broken pipeline from step 1 | Always run the full questionnaire; no defaults |
| Regenerating setup files without `--force` on existing project | User content overwritten silently | Check for managed markers; preserve non-managed content |
| Installing setup dependencies globally instead of per-project | Global installs break other projects; not reproducible | Use project package manager (`pnpm add`, `flutter pub add`) |
| Leaving `[TODO: fill]` placeholders in `AGENTS.md` and proceeding to `devflow.task` | First task fails input contract; agent has no project context | Fill all placeholders before routing to `devflow.task` |

## I/O Reference

| | |
|---|---|
| Reads | `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` (including `Setup dependencies`), adapter + fallback templates |
| Writes | `AGENTS.md`, `REGISTRY.md`, `docs/product.md` (consumer project root); `@devflow/config.md`; `.gitignore` (appends `.devflow-state.json` if missing) |
| Side effects | Installs adapter setup dependencies using project package manager or Flutter pub |
| Next step | `devflow.task` |
