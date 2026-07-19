---
name: devflow-setup
description: Generates AGENTS.md, REGISTRY.md, docs/product.md via adapter templates + questionnaire. Use when running devflow.setup post-install, or adapter/stack/product context changes.
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
Output must be concise, stable, safe to re-run; `AGENTS.md` keeps any template-provided `code-review-graph` skill reference intact.

Command is **standalone** (pre-pipeline), not feature step like `task/plan/implement`.

## Input

- Optional `$ARGUMENTS` with `--force` — present: overwrite full file contents; absent: update only `devflow-managed` sections

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

   Pipeline skills read this file first, then load `@devflow/adapters/<adapter>/ADAPTER.md` (core: technology skills, MCP) plus `@devflow/adapters/<adapter>/steps/<step>.md` for the active step's commands, plan sections, and checklists.
   ```

4. Build adapter contract paths:
   `@devflow/adapters/<adapter>/ADAPTER.md` (core) and `@devflow/adapters/<adapter>/steps/setup.md` (setup templates + dependencies). Legacy adapters without `steps/`: all sections live in `ADAPTER.md`.

### Step 2 - Load contract and templates

1. Read adapter contract files (core + setup step file).
2. Read `Setup dependencies` section from `@devflow/adapters/<adapter>/steps/setup.md` (legacy: `ADAPTER.md`) and extract:
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
| --- | --- | :---: |
| `constitution.md` | architecture/layering, naming, default commands | no |
| existing `docs/product.md` | product/app hints for continuity | no |
| Adapter-defined project manifests (for example language/package manifests) | package/project name | no |
| `@devflow/config.md` | adapter id | yes |
| `@devflow/adapters/<adapter>/ADAPTER.md` + `steps/setup.md` | stack commands, key rules | yes |
| **Mandatory questionnaire answers** | all unresolved placeholders | yes |

If a value cannot be inferred, keep a literal placeholder token:
`[TODO: fill]`.

For constitution fields and the full required placeholder table, see `references/placeholder-map.md`.

### Step 5 - Placeholder map (required)

Collect and resolve every field in `references/placeholder-map.md` before render. Collect at least 3 features. Ask: "List your key features (name, status, notes). Add as many as needed." Add one table row per feature. `devflow.task` will maintain this table as features progress.

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
- `constitution.md`: under ~530 tokens

### Step 6b - Token budget check (after render, before write)

After rendering each file, estimate token count using word count as proxy (300 words ≈ 400 tokens):

- `AGENTS.md`: warn if rendered content exceeds ~225 words
- `REGISTRY.md`: warn if rendered content exceeds ~450 words
- `docs/product.md`: warn if rendered content exceeds ~525 words
- `constitution.md`: warn if rendered content exceeds ~400 words

If over budget, trim in this order:

1. Remove worked examples or multi-sentence explanations from bullets — replace with imperative fragment
2. Remove any sentence starting with "This section..." or "Note that..."
3. Shorten skill reference paths only if duplicated elsewhere in the file

Log the final word count per file in the Step 8 summary.

### Step 7 - Write files

Target location: consumer project root. Same rules for all four files (`AGENTS.md`, `REGISTRY.md`, `docs/product.md`, `constitution.md`):

- file missing: create from rendered template (`docs/product.md` and `constitution.md`: always create if missing)
- file exists, no `--force`: replace only managed sections by matching `<section-id>`
- file exists + `--force`: overwrite full file

When non-force mode cannot find valid managed markers in an existing file (`docs/product.md`, `constitution.md`):

- Marker-less DevFlow-looking content present (headings matching template sections — pre-marker leftovers)? → stop, list conflicts, ask user: replace with managed blocks or append fresh. Never guess; never leave two copies of same section (plugin `CONTRIBUTING.md` → **Managed-Section Discipline**)
- Otherwise append rendered managed blocks to the end of the file; do not rewrite existing user sections

### Step 7b - Gitignore (runtime artifacts)

Ensure `.devflow-state.json` is listed in the consumer project's `.gitignore`.

- `.gitignore` exists and already contains `.devflow-state.json` → skip
- `.gitignore` exists and does not contain it → append:

  ```gitignore
  # devflow runtime state
  .devflow-state.json
  ```

- `.gitignore` does not exist → skip (the `pre-compact` hook appends it automatically on first run)

### Step 7c - Install adapter setup dependencies (required)

After successful file writes, install dependencies declared in the active adapter `Setup dependencies` section. Full rules: `references/dependency-install.md`.

### Step 8 - Notify user

Respond using the template in `references/notify-template.md`.

## Output quality checklist

Before final response:

- [ ] all four files exist in consumer root (AGENTS.md, REGISTRY.md, docs/product.md, constitution.md)
- [ ] managed markers are valid and paired
- [ ] non-managed user content preserved (unless `--force`)
- [ ] adapter setup dependencies installed (or explicit skip reason reported)
- [ ] no verbose filler added
- [ ] unresolved values listed as `[TODO: fill]`
- [ ] constitution.md layer table has at least one row per adapter layer
- [ ] all constitution `{{placeholder}}` tokens are resolved or marked `[TODO: fill]`

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Writing files inside `devflow/features/` during setup | Write only to consumer project root; `devflow/` is read-only during setup. |
| Skipping the questionnaire and guessing adapter | Always run the full questionnaire; no defaults. |
| Regenerating setup files without `--force` on existing project | Check for managed markers; preserve non-managed content. |
| Installing setup dependencies globally | Use project package manager (`pnpm add`, `flutter pub add`). |
| Leaving `[TODO: fill]` placeholders before routing to `devflow.task` | Fill all placeholders first. |
| Generating marker-less content | Wrap all managed content with `<!-- devflow-managed:start / :end -->`. |
| Appending managed blocks onto marker-less DevFlow-looking content | Surface conflict, ask replace-or-append; duplicate sections corrupt consumer context files. |
| Expanding templates with long narrative prose | Output must be token-lean, imperative, filler-free. |
| Using adapter template that doesn't exist without fallback | Fall back to global templates if adapter template missing. |

## I/O Reference

| | |
| --- | --- |
| Reads | `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` (core) + `steps/setup.md` (including `Setup dependencies`), adapter + fallback templates |
| Writes | `AGENTS.md`, `REGISTRY.md`, `docs/product.md` (consumer project root); `@devflow/config.md`; `.gitignore` (appends `.devflow-state.json` if missing) |
| Side effects | Installs adapter setup dependencies using project package manager or Flutter pub |
| Next step | `devflow.task` |
