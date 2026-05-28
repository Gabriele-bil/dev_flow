# constitution.md Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `CONSTITUTION.template.md` per-adapter + one global fallback, and extend `devflow-setup/SKILL.md` so that `devflow.setup` creates a fully-populated `constitution.md` in the consumer project root.

**Architecture:** Four new template files (flutter, angular, nextjs, global fallback) use the standard `<!-- devflow-managed:start/end -->` block format. The `devflow-setup` SKILL.md is patched in eight targeted edits covering template loading, questionnaire, codebase scan, placeholder map, token budget, write rules, summary, and quality checklist. No new runtime code — all changes are markdown.

**Tech Stack:** Markdown templates with `{{placeholder}}` syntax, `<!-- devflow-managed:start/end -->` blocks, bash validation (`validate-skills.sh`), bash rebuild (`build-plugin.sh`).

---

## File Map

| Action | Path |
|---|---|
| Create | `templates/devflow/skills/devflow-setup/templates/CONSTITUTION.template.md` |
| Create | `templates/devflow/adapters/flutter/templates/CONSTITUTION.template.md` |
| Create | `templates/devflow/adapters/angular/templates/CONSTITUTION.template.md` |
| Create | `templates/devflow/adapters/nextjs/templates/CONSTITUTION.template.md` |
| Modify | `templates/devflow/skills/devflow-setup/SKILL.md` (8 targeted edits) |

---

### Task 1: Create global fallback `CONSTITUTION.template.md`

**Files:**
- Create: `templates/devflow/skills/devflow-setup/templates/CONSTITUTION.template.md`

- [ ] **Step 1: Write the file**

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

- [ ] **Step 2: Verify managed block markers are balanced**

Run:
```bash
grep -c "devflow-managed:start" templates/devflow/skills/devflow-setup/templates/CONSTITUTION.template.md
grep -c "devflow-managed:end" templates/devflow/skills/devflow-setup/templates/CONSTITUTION.template.md
```
Expected: both commands print `4`.

- [ ] **Step 3: Commit**

```bash
git add templates/devflow/skills/devflow-setup/templates/CONSTITUTION.template.md
git commit -m "feat: add global fallback CONSTITUTION.template.md"
```

---

### Task 2: Create Flutter `CONSTITUTION.template.md`

**Files:**
- Create: `templates/devflow/adapters/flutter/templates/CONSTITUTION.template.md`

- [ ] **Step 1: Write the file**

Flutter has five canonical layers (domain, data, riverpod, UI, i18n/codegen).

```markdown
<!-- devflow-managed:start:architecture -->
## Architecture
**Stack:** flutter
**Layer order:** {{layer-order}}

| Layer | Path | Responsibility |
|---|---|---|
| {{layer-1-name}} | `{{layer-1-path}}` | {{layer-1-responsibility}} |
| {{layer-2-name}} | `{{layer-2-path}}` | {{layer-2-responsibility}} |
| {{layer-3-name}} | `{{layer-3-path}}` | {{layer-3-responsibility}} |
| {{layer-4-name}} | `{{layer-4-path}}` | {{layer-4-responsibility}} |
| {{layer-5-name}} | `{{layer-5-path}}` | {{layer-5-responsibility}} |
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

- [ ] **Step 2: Verify managed block markers are balanced**

Run:
```bash
grep -c "devflow-managed:start" templates/devflow/adapters/flutter/templates/CONSTITUTION.template.md
grep -c "devflow-managed:end" templates/devflow/adapters/flutter/templates/CONSTITUTION.template.md
```
Expected: both print `4`.

- [ ] **Step 3: Commit**

```bash
git add templates/devflow/adapters/flutter/templates/CONSTITUTION.template.md
git commit -m "feat: add Flutter CONSTITUTION.template.md"
```

---

### Task 3: Create Angular `CONSTITUTION.template.md`

**Files:**
- Create: `templates/devflow/adapters/angular/templates/CONSTITUTION.template.md`

- [ ] **Step 1: Write the file**

Angular has three canonical layers (core, shared, pages).

```markdown
<!-- devflow-managed:start:architecture -->
## Architecture
**Stack:** angular
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

- [ ] **Step 2: Verify managed block markers are balanced**

Run:
```bash
grep -c "devflow-managed:start" templates/devflow/adapters/angular/templates/CONSTITUTION.template.md
grep -c "devflow-managed:end" templates/devflow/adapters/angular/templates/CONSTITUTION.template.md
```
Expected: both print `4`.

- [ ] **Step 3: Commit**

```bash
git add templates/devflow/adapters/angular/templates/CONSTITUTION.template.md
git commit -m "feat: add Angular CONSTITUTION.template.md"
```

---

### Task 4: Create Next.js `CONSTITUTION.template.md`

**Files:**
- Create: `templates/devflow/adapters/nextjs/templates/CONSTITUTION.template.md`

- [ ] **Step 1: Write the file**

Next.js has four canonical layers (app, components, lib, actions).

```markdown
<!-- devflow-managed:start:architecture -->
## Architecture
**Stack:** nextjs
**Layer order:** {{layer-order}}

| Layer | Path | Responsibility |
|---|---|---|
| {{layer-1-name}} | `{{layer-1-path}}` | {{layer-1-responsibility}} |
| {{layer-2-name}} | `{{layer-2-path}}` | {{layer-2-responsibility}} |
| {{layer-3-name}} | `{{layer-3-path}}` | {{layer-3-responsibility}} |
| {{layer-4-name}} | `{{layer-4-path}}` | {{layer-4-responsibility}} |
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

- [ ] **Step 2: Verify managed block markers are balanced**

Run:
```bash
grep -c "devflow-managed:start" templates/devflow/adapters/nextjs/templates/CONSTITUTION.template.md
grep -c "devflow-managed:end" templates/devflow/adapters/nextjs/templates/CONSTITUTION.template.md
```
Expected: both print `4`.

- [ ] **Step 3: Commit**

```bash
git add templates/devflow/adapters/nextjs/templates/CONSTITUTION.template.md
git commit -m "feat: add Next.js CONSTITUTION.template.md"
```

---

### Task 5: Update SKILL.md — Step 2 template loading + Step 3 questionnaire topic

**Files:**
- Modify: `templates/devflow/skills/devflow-setup/SKILL.md`

- [ ] **Step 1: Add `CONSTITUTION.template.md` to Step 2 template list**

Find and replace in `templates/devflow/skills/devflow-setup/SKILL.md`:

Old:
```
4. Read all templates from chosen directory:
   - `AGENTS.template.md`
   - `REGISTRY.template.md`
   - `PRODUCT.template.md`
```

New:
```
4. Read all templates from chosen directory:
   - `AGENTS.template.md`
   - `REGISTRY.template.md`
   - `PRODUCT.template.md`
   - `CONSTITUTION.template.md`
```

- [ ] **Step 2: Add `architecture` to Step 3 questionnaire topic list**

Find and replace:

Old:
```
- Keep questions short and grouped by topic (product, conventions, patterns, commands).
```

New:
```
- Keep questions short and grouped by topic (product, conventions, patterns, commands, architecture).
```

- [ ] **Step 3: Verify both strings are present**

Run:
```bash
grep "CONSTITUTION.template.md" templates/devflow/skills/devflow-setup/SKILL.md
grep "architecture" templates/devflow/skills/devflow-setup/SKILL.md | grep "topic"
```
Expected: each command returns exactly one matching line.

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/skills/devflow-setup/SKILL.md
git commit -m "feat(setup): load CONSTITUTION.template.md and add architecture questionnaire topic"
```

---

### Task 6: Update SKILL.md — Step 3b codebase scan + Step 4 adapter defaults

**Files:**
- Modify: `templates/devflow/skills/devflow-setup/SKILL.md`

- [ ] **Step 1: Extend Step 3b to scan for naming conventions**

Find and replace:

Old:
```
Use these observations to pre-fill `pattern-1`, `pattern-2` (and optionally `pattern-3`) in the placeholder map before rendering — replacing any questionnaire `[TODO: fill]` values for patterns with real examples from the repo.

If the feature directory does not exist or is empty, skip this step and use questionnaire values.
```

New:
```
Use these observations to pre-fill `pattern-1`, `pattern-2` (and optionally `pattern-3`) in the placeholder map before rendering — replacing any questionnaire `[TODO: fill]` values for patterns with real examples from the repo.

Additionally, sample 5-10 existing source files across the project root to infer `naming-conventions`:
- Extract file naming pattern (snake_case.dart, kebab-case.ts, PascalCase.tsx, etc.)
- Extract class and top-level function naming from file headers
- Pre-fill `naming-conventions` placeholder if a consistent pattern is found; otherwise leave `[TODO: fill]`

If the feature directory does not exist or is empty, skip feature scan and use questionnaire values or adapter defaults for all constitution fields.
```

- [ ] **Step 2: Add adapter defaults for constitution fields in Step 4**

Find and replace:

Old:
```
If a value cannot be inferred, keep a literal placeholder token:
`[TODO: fill]`.
```

New:
```
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
```

- [ ] **Step 3: Verify both edits landed**

Run:
```bash
grep -n "naming-conventions.*placeholder" templates/devflow/skills/devflow-setup/SKILL.md
grep -n "layer-order.*domain" templates/devflow/skills/devflow-setup/SKILL.md
```
Expected: each returns one line.

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/skills/devflow-setup/SKILL.md
git commit -m "feat(setup): extend codebase scan for naming-conventions and add constitution adapter defaults"
```

---

### Task 7: Update SKILL.md — Step 5 placeholder map additions

**Files:**
- Modify: `templates/devflow/skills/devflow-setup/SKILL.md`

- [ ] **Step 1: Add constitution rows to the placeholder map**

Find and replace:

Old:
```
| `feature-[N]-name` | PRODUCT | Key feature label (N = 1, 2, 3…) |
| `feature-[N]-status` | PRODUCT | `implemented`, `planned`, `in-progress`, or `deprecated` |
| `feature-[N]-notes` | PRODUCT | Scope/status notes |
```

New:
```
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
```

- [ ] **Step 2: Verify constitution rows are in the file**

Run:
```bash
grep "CONSTITUTION" templates/devflow/skills/devflow-setup/SKILL.md | wc -l
```
Expected: `10` (7 new placeholder rows + 1 already-existing source row in Step 4 table + 1 in Step 7 section added later + 1 in checklist added later — at this point minimum 7 new rows + the existing one = at least 8; the exact count will be 8 after this task only).

Run a targeted check instead:
```bash
grep "layer-order" templates/devflow/skills/devflow-setup/SKILL.md
grep "naming-conventions.*CONSTITUTION" templates/devflow/skills/devflow-setup/SKILL.md
grep "import-conventions.*CONSTITUTION" templates/devflow/skills/devflow-setup/SKILL.md
```
Expected: each returns exactly one line.

- [ ] **Step 3: Commit**

```bash
git add templates/devflow/skills/devflow-setup/SKILL.md
git commit -m "feat(setup): add constitution fields to placeholder map"
```

---

### Task 8: Update SKILL.md — Step 6 budget target + Step 6b token budget + Step 7 write rules

**Files:**
- Modify: `templates/devflow/skills/devflow-setup/SKILL.md`

- [ ] **Step 1: Add constitution.md to Step 6 budget targets**

Find and replace:

Old:
```
Budget targets:

- `AGENTS.md`: under ~300 tokens
- `REGISTRY.md`: under ~600 tokens
- `docs/product.md`: under ~700 tokens
```

New:
```
Budget targets:

- `AGENTS.md`: under ~300 tokens
- `REGISTRY.md`: under ~600 tokens
- `docs/product.md`: under ~700 tokens
- `constitution.md`: under ~530 tokens
```

- [ ] **Step 2: Add constitution.md to Step 6b token budget check**

Find and replace:

Old:
```
- `docs/product.md`: warn if rendered content exceeds ~525 words
```

New:
```
- `docs/product.md`: warn if rendered content exceeds ~525 words
- `constitution.md`: warn if rendered content exceeds ~400 words
```

- [ ] **Step 3: Add constitution.md write rules to Step 7**

Find and replace:

Old:
```
When non-force mode cannot find valid managed markers in an existing file:

- append rendered managed blocks to the end of the file
- do not rewrite existing user sections

### Step 7b - Gitignore (runtime artifacts)
```

New:
```
When non-force mode cannot find valid managed markers in an existing file:

- append rendered managed blocks to the end of the file
- do not rewrite existing user sections

#### constitution.md

- file missing: create from rendered template
- file exists, no `--force`: replace only managed sections by matching `<section-id>`
- file exists + `--force`: overwrite full file

When non-force mode cannot find valid managed markers in an existing file:

- append rendered managed blocks to the end of the file
- do not rewrite existing user sections

### Step 7b - Gitignore (runtime artifacts)
```

- [ ] **Step 4: Verify all three edits are present**

Run:
```bash
grep "constitution.md.*530 tokens" templates/devflow/skills/devflow-setup/SKILL.md
grep "constitution.md.*400 words" templates/devflow/skills/devflow-setup/SKILL.md
grep -A3 "#### constitution.md" templates/devflow/skills/devflow-setup/SKILL.md | head -5
```
Expected: each returns at least one line.

- [ ] **Step 5: Commit**

```bash
git add templates/devflow/skills/devflow-setup/SKILL.md
git commit -m "feat(setup): add constitution.md token budget and write rules"
```

---

### Task 9: Update SKILL.md — Step 8 summary + quality checklist

**Files:**
- Modify: `templates/devflow/skills/devflow-setup/SKILL.md`

- [ ] **Step 1: Add `constitution.md` line to Step 8 summary template**

Find and replace:

Old:
```
AGENTS.md: [created|updated|overwritten]
REGISTRY.md: [created|updated|overwritten]
docs/product.md: [created|updated|overwritten]
```

New:
```
AGENTS.md: [created|updated|overwritten]
REGISTRY.md: [created|updated|overwritten]
docs/product.md: [created|updated|overwritten]
constitution.md: [created|updated|overwritten]
```

- [ ] **Step 2: Update quality checklist — file count and new checks**

Find and replace:

Old:
```
- [ ] all three files exist in consumer root
- [ ] managed markers are valid and paired
- [ ] non-managed user content preserved (unless `--force`)
- [ ] adapter setup dependencies installed (or explicit skip reason reported)
- [ ] no verbose filler added
- [ ] unresolved values listed as `[TODO: fill]`
```

New:
```
- [ ] all four files exist in consumer root (AGENTS.md, REGISTRY.md, docs/product.md, constitution.md)
- [ ] managed markers are valid and paired
- [ ] non-managed user content preserved (unless `--force`)
- [ ] adapter setup dependencies installed (or explicit skip reason reported)
- [ ] no verbose filler added
- [ ] unresolved values listed as `[TODO: fill]`
- [ ] constitution.md layer table has at least one row per adapter layer
- [ ] all constitution `{{placeholder}}` tokens are resolved or marked `[TODO: fill]`
```

- [ ] **Step 3: Verify both edits are present**

Run:
```bash
grep "constitution.md: \[created" templates/devflow/skills/devflow-setup/SKILL.md
grep "all four files" templates/devflow/skills/devflow-setup/SKILL.md
grep "layer table" templates/devflow/skills/devflow-setup/SKILL.md
```
Expected: each returns exactly one line.

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/skills/devflow-setup/SKILL.md
git commit -m "feat(setup): add constitution.md to setup summary and quality checklist"
```

---

### Task 10: Validate with `validate-skills.sh` and rebuild `dist/`

**Files:**
- No changes — validation and build only.

- [ ] **Step 1: Run skill validator**

Run:
```bash
bash templates/devflow/scripts/validate-skills.sh
```
Expected output ends with: `Results: 41 ok, 0 error(s), 0 warning(s)`

If errors appear, read the error message, locate the failing SKILL.md section, and fix it before proceeding.

- [ ] **Step 2: Rebuild dist/**

Run:
```bash
bash scripts/build-plugin.sh
```
Expected: exits 0 with no errors. The `dist/devflow/` directory is updated.

- [ ] **Step 3: Verify new template files are in dist/**

Run:
```bash
find dist/devflow -name "CONSTITUTION.template.md"
```
Expected: four paths printed (flutter, angular, nextjs, global fallback).

- [ ] **Step 4: Commit dist/ rebuild**

```bash
git add dist/
git commit -m "chore: rebuild dist after constitution.md template additions"
```
