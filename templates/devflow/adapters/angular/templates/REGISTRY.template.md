<!-- devflow-managed:start:patterns -->
| Pattern | When | Path |
|---|---|---|
| Feature Page Triple | Any page feature | `src/app/pages/<page-name>/{page.ts,state.ts,service.ts}` |
| Core Singleton Infra | App-wide infra and boot wiring | `src/app/core/{guards,interceptors,services,states}` |
| Shared Reuse Modules | Reused in multiple pages | `src/app/shared/{components,constants,directives,models,pipes,utils,validators}` |
| Global Styles Split | Global design primitives and utilities | `src/styles/*.css` + `src/styles.css` |
| Signal Store Global+Local | Global app state and local feature state | `src/app/core/states/*` and `src/app/pages/<page-name>/state.ts` |
<!-- devflow-managed:end:patterns -->

<!-- devflow-managed:start:conventions -->
**Naming:** feature folders `kebab-case`; main page files `page.ts`, `state.ts`, `service.ts`
**Routing:** root routes in `src/app/app.routes.ts`; standalone-first components; lazy-load via `loadComponent`/`loadChildren`; guards/resolvers in `core/guards`/`core/resolvers`, functional only (`CanActivateFn`/`CanMatchFn`/`ResolveFn`); page-domain `*.routes.ts` colocated per feature
**State:** Signal Store only (global + local); no NgRx actions/reducers/effects/selectors
**Branches:** `feat/[NNN]-<name>`, `fix/[NNN]-<name>`
**Commits:** `<type>: <desc>` (`feat|fix|chore|docs|perf`)
**Lint:** `pnpm run lint`
**Test:** `pnpm run test -- --watch=false`
**Build:** `pnpm run build`
<!-- devflow-managed:end:conventions -->
