<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** angular
**Adapter:** @devflow/adapters/angular/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Respect boundaries: `core` (singleton infra), `pages` (feature domain), `shared` (cross-feature reuse). Flow: page → state → service → HTTP.
- No HTTP in components: `HttpClient` and `httpResource()` live in `service.ts`.
- State: NgRx Signal Store only (global + page). Do not use `@ngrx/store` (actions/reducers/effects/selectors).
- Routing: functional guards/resolvers only (`CanActivateFn`/`CanMatchFn`/`ResolveFn`).
- Accessible custom widgets: `@angular/aria` headless directives (`ng*`), never native `<select>`/`<input list>` for those patterns.
- Animations: native CSS `animate.enter`/`animate.leave`; `@angular/animations` is deprecated — do not use it.
- Run quality commands after edit batches: `pnpm run lint`, `pnpm run test -- --watch=false`, `pnpm run build`.
- Required MCP baseline: {{mcp-baseline}}
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
Read a skill only when the work touches its files (full matrix: `@devflow/adapters/angular/steps/implement.md`):

- Barrels, `app.config*.ts`, new page/core folders, boundary moves → `angular-architecture`
- `@Component`/`@Directive`/`@Pipe` files, templates → `angular-component`
- `service.ts`, interceptors, `HttpClient`/`httpResource` → `angular-http`
- Signal Forms, `validators/**` → `angular-forms`
- `state.ts`, `*.store.ts`, `core/states/**` → `angular-state`
- `*.routes.ts`, `app.routes.server.ts`, guards, resolvers → `angular-routing`
- `@angular/aria` imports, custom select/menu/tabs/tree → `angular-aria`
- `animate.enter`/`animate.leave`, transitions, legacy animation migration → `angular-animations`
- `src/styles.css`, `src/styles/**`, component stylesheets, tokens → `angular-theme`
- `*.spec.ts`, harnesses → `angular-testing`
- Pipeline steps: `/devflow:task`, `/devflow:plan`, `/devflow:implement` — invoked on demand, not imported
<!-- devflow-managed:end:skills -->
