<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** angular
**Adapter:** @devflow/adapters/angular/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Load `angular-architecture` when work touches structure, boundaries, or page layout.
- Respect boundaries: `core` (singleton infra), `pages` (feature domain), `shared` (cross-feature reuse).
- State standard: Signal Store only (global + local). Do not add NgRx artifacts.
- Load specialized skills by scope: component, forms, http, state, routing, aria, animations.
- Routing: functional guards/resolvers only (`CanActivateFn`/`CanMatchFn`/`ResolveFn`); load `angular-routing` for `*.routes.ts`, guard/resolver, navigation work.
- Accessible custom widgets: use `@angular/aria` headless directives (`ng*`), never native `<select>`/`<input list>`; load `angular-aria`.
- Animations: native CSS `animate.enter`/`animate.leave` default (v20.2+); load `angular-animations` for enter/leave or route-transition work.
- Run quality commands after edit batches: `pnpm run lint`, `pnpm run test -- --watch=false`, `pnpm run build`.
- Required MCP baseline: `context7`, `sequential-thinking`.
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
@devflow/skills/devflow-task/SKILL.md
@devflow/skills/devflow-plan/SKILL.md
@devflow/skills/devflow-implement/SKILL.md
@devflow/adapters/angular/skills/angular-architecture/SKILL.md
@devflow/adapters/angular/skills/angular-component/SKILL.md
@devflow/adapters/angular/skills/angular-forms/SKILL.md
@devflow/adapters/angular/skills/angular-http/SKILL.md
@devflow/adapters/angular/skills/angular-state/SKILL.md
@devflow/adapters/angular/skills/angular-routing/SKILL.md
@devflow/adapters/angular/skills/angular-aria/SKILL.md
@devflow/adapters/angular/skills/angular-animations/SKILL.md
@code-review-graph/skills/code-review-graph/SKILL.md
<!-- devflow-managed:end:skills -->
