<!-- devflow-managed:start:patterns -->
| Pattern | When | Path | |
|---|---|---| |
| Feature Page Triple | Any page feature | `src/app/pages/<page-name>/{page.ts,state.ts,service.ts}` | |
| Core Singleton Infra | App-wide infra and boot wiring | `src/app/core/{guards,interceptors,services,states}` | |
| Shared Reuse Modules | Reused in multiple pages | `src/app/shared/{components,constants,directives,models,pipes,utils,validators}` | |
| Global Styles Split | Global design primitives and utilities | `src/styles/*.css` + `src/styles.css` | |
| Signal Store Global+Page | Global app state and page feature state | `src/app/core/states/*` and `src/app/pages/<page-name>/state.ts` | |
<!-- devflow-managed:end:patterns -->

<!-- devflow-managed:start:conventions -->
**Naming:** feature folders `kebab-case`; main page files `page.ts`, `state.ts`, `service.ts`
**Routing:** root routes in `src/app/app.routes.ts`; standalone-first components; lazy-load via `loadComponent`/`loadChildren`; guards/resolvers in `core/guards`/`core/resolvers`, functional only (`CanActivateFn`/`CanMatchFn`/`ResolveFn`); page-domain `*.routes.ts` colocated per feature
**State:** NgRx Signal Store only (global + page); do not use `@ngrx/store` actions/reducers/effects/selectors
**HTTP:** only in `service.ts` (`HttpClient`, `httpResource()`); components read state signals
**Branches:** `feat/[NNN]_<name>`, `fix/[NNN]_<name>`
**Commits:** `<type>: <desc>` (`feat|fix|chore|docs|perf`)
**Lint:** `pnpm run lint`
**Test:** `pnpm run test -- --watch=false`
**Build:** `pnpm run build`
<!-- devflow-managed:end:conventions -->
