# Angular adapter (DevFlow)

Single source of truth for Angular behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then follow sections below.

Baseline: **standalone + signals-first**. Keep output token-lean and imperative.

## Technology skills (load by feature type)

| When | Load |
|------|------|
| App structure, folder layout, boundaries, communication flow | `@devflow/adapters/angular/skills/angular-architecture/SKILL.md` |
| New components, refactor existing components, template/class split | `@devflow/adapters/angular/skills/angular-component/SKILL.md` |
| Reactive forms, validation, form UX, submit flows | `@devflow/adapters/angular/skills/angular-forms/SKILL.md` |
| API clients, HttpClient usage, interceptors, error mapping | `@devflow/adapters/angular/skills/angular-http/SKILL.md` |
| Global and local state management patterns | `@devflow/adapters/angular/skills/angular-state/SKILL.md` |
| PR review, blast radius, architecture risk checks | `@code-review-graph/skills/code-review-graph/SKILL.md` |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking)
- **Context7**: Angular and RxJS API docs and version deltas.
- **Sequential Thinking**: break complex refactors into small, testable steps.

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `@devflow/adapters/angular/templates/AGENTS.template.md`
- `@devflow/adapters/angular/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + skill references (`@...`) only.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install.

### js-runtime-dependencies

- `@jsverse/transloco`
- `@angular/cdk`
- `@ngrx/operators`
- `@ngrx/signals`

### js-dev-dependencies

- none

## Caveman response rules (mandatory)

Apply to narrative text in plans, updates, reviews, PR notes:

- Drop: articles (`a/an/the`), filler (`just/really/basically/actually/simply`), pleasantries, hedging.
- Keep: technical terms exact, errors quoted exact, code blocks unchanged.
- Prefer: short synonyms (`fix`, `use`, `build`, `test`).
- Pattern: `[thing] [action] [reason]. [next step].`

Example:

- Bad: `Sure! I'd be happy to help. The issue is likely in auth middleware...`
- Good: `Auth middleware bug. Token expiry check use < not <=. Fix guard, add test.`

## Plan: extra sections and templates

Include these in `plan.md` when applicable (after core sections from `devflow-plan`).

### Dependency ordering (layering)

Order the **File list** bottom-up by layer ownership. Source of truth for Angular boundaries and dependency flow:

- `@devflow/adapters/angular/skills/angular-architecture/SKILL.md`

### State plan (add when state changes)

Use the structure and constraints from:

- `@devflow/adapters/angular/skills/angular-state/SKILL.md`

### Forms plan (add when forms change)

Use the structure and constraints from:

- `@devflow/adapters/angular/skills/angular-forms/SKILL.md`

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
|---|---|
| `*.component.ts`, `*.component.html` | `angular-component` |
| `*.service.ts`, `*http*.ts`, `*api*.ts`, `*client*.ts` | `angular-http` |
| `*.form*.ts`, `*-form.component.ts`, `*validator*.ts` | `angular-forms` |
| `*.store.ts`, `*state*.ts`, `*signal*.ts`, `*.facade.ts` | `angular-state` |
| `index.ts` barrel, module boundaries, new feature folder | `angular-architecture` |

Load only the skills triggered by the current batch's file paths. Do not load all skills preemptively.

## Implement: commands and checklist

### Format, lint, test, build

Run after substantive edits, in order, using project package manager/scripts:

```bash
pnpm run lint
pnpm run test -- --watch=false
pnpm run build
```

If scripts are missing, use Angular CLI equivalents aligned with the repo setup.
Retry failed steps up to **3** attempts each; then stop and report full output.

### Angular implementation rules (summary)

Adapter does orchestration only. Domain rules live in skills:

- Architecture and boundaries: `@devflow/adapters/angular/skills/angular-architecture/SKILL.md`
- Components: `@devflow/adapters/angular/skills/angular-component/SKILL.md`
- Forms: `@devflow/adapters/angular/skills/angular-forms/SKILL.md`
- HTTP: `@devflow/adapters/angular/skills/angular-http/SKILL.md`
- State: `@devflow/adapters/angular/skills/angular-state/SKILL.md`

### Pre-handoff checklist (implement)

- [ ] `format`, `lint`, `test`, `build` pass (or failures documented)
- [ ] Relevant Angular skills loaded and applied for touched areas
- [ ] Architecture constraints verified against `angular-architecture`

## Beautify: commands

Same as implement pipeline: `lint`, `test`, `build`.

### Beautify: performance profiling trigger

Profile only when the plan calls out performance or a **Critical**-severity hotspot is flagged:

- Use Angular DevTools (Component profiler, Change detection cycles) before refactoring rendering performance.
- Investigate excessive change-detection cycles by checking signal/Observable scope before adding `OnPush` or `trackBy`.
- Heavy computation in templates or services called on every render cycle — move to computed signals or memoized pipes.

Default beautify relies on heuristics (avoid unnecessary recalculations in getters, narrow RxJS subscriptions, avoid `combineLatest` with broad streams). Profile only when warranted.

### Beautify: Angular-specific review axes

Apply core `devflow-beautify` axes, then evaluate touched code with relevant Angular skills:

- `angular-architecture`
- `angular-component`
- `angular-forms`
- `angular-http`
- `angular-state`

### Beautify: accessibility checks

Apply these Angular-specific accessibility checks in addition to core accessibility axis:

- Interactive custom components have `role` attribute set correctly (`button`, `dialog`, `menu`, etc.)
- Icon-only buttons and controls include `aria-label` or `aria-labelledby`
- Form fields have associated `<label>` or `aria-label`; error messages linked via `aria-describedby`
- Modal/dialog components trap focus on open (`cdkTrapFocus` or equivalent) and restore on close
- Keyboard navigation: custom dropdowns, menus, and carousels handle arrow key / Enter / Escape
- Color contrast: use design-system tokens; no hardcoded hex that may fail WCAG AA

Severity: **Critical** for screen-reader-blocking issues; **Required** for missing labels on form controls; **Nit** for enhancement.

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: colocated `*.spec.ts` or mirrored under `src/` by project convention.
- Integration: feature-level flows in project’s selected framework (Angular TestBed / Cypress / Playwright).

### Commands

Use project scripts first:

```bash
npm run test -- --watch=false
```

If e2e exists:

```bash
npm run e2e
```

### Required test focus

- Components: input/output contract, conditional rendering, accessibility-critical states.
- Forms: validator behavior, submit disable/enable transitions, error display.
- State: state/store contracts and transitions for each changed path.
- HTTP: success/error/timeout mapping through data layer.

## PR: verification

Before push:

```bash
npm run lint
npm run test -- --watch=false
npm run build
```

### PR body checklist (copy into PR description)

- [ ] Lint passing
- [ ] Unit tests passing
- [ ] E2E passing (if present in project)
- [ ] Build passing
- [ ] `angular-architecture` constraints respected
- [ ] Relevant Angular skills applied for changed scope
- [ ] `registry.md` updated if new patterns were introduced
