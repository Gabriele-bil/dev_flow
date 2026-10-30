---
name: angular-routing
description: Angular v22+ routing — routes, guards, resolvers, navigation, SSR/hydration. Use for route config, lazy loading, protection, prefetch, or rendering decisions. Triggers on route file creation, guard/resolver work, or navigation flows.
---

# Angular Routing

## Purpose

Configure routes, functional guards/resolvers, navigation and per-route render mode (CSR / SSG / SSR) for Angular v22.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no `*.routes.ts`, guard, resolver or navigation code touched).
- Element enter/leave animations → `angular-animations` (route transitions stay here).
- Data loading inside a page → `angular-http` / `angular-state` (resolvers only when navigation must wait).

## Route Definition

Root routes: `src/app/app.routes.ts`. Page-domain routes: colocated `*.routes.ts`, imported via `loadChildren`.

```typescript
import { Routes } from "@angular/router";

export const routes: Routes = [
  { path: "", redirectTo: "dashboard", pathMatch: "full" },
  { path: "dashboard", loadComponent: () => import("./pages/dashboard/page").then((m) => m.DashboardPage) },
  { path: "admin", canMatch: [adminGuard], loadChildren: () => import("./pages/admin/admin.routes").then((m) => m.adminRoutes) },
  { path: "**", loadComponent: () => import("./pages/not-found/page").then((m) => m.NotFoundPage) },
];
```

Specific paths before generic, `**` last. `loadComponent`/`loadChildren` for every non-landing route.

## Functional Guards and Resolvers

Functional only (`CanActivateFn`, `CanMatchFn`, `CanDeactivateFn`, `ResolveFn`). Do not use class-based guards/resolvers. Place in `core/guards`, `core/resolvers`.

```typescript
export const authGuard: CanActivateFn = (route, state) => {
  const auth = inject(AuthStore);
  const router = inject(Router);
  return auth.isAuthenticated() || router.createUrlTree(["/login"], { queryParams: { redirect: state.url } });
};
```

- `CanMatchFn` for feature flags/roles — runs before the lazy chunk loads.
- Return `boolean | UrlTree | RedirectCommand` (sync, Promise or Observable).
- Resolved data → component `input()` via `withComponentInputBinding()`; do not read `ActivatedRoute.data` by hand.

## Navigation

`RouterLink` + `routerLinkActive` for declarative links; `Router.navigate()` only after an action (submit, guard result). Relative: `{ relativeTo: inject(ActivatedRoute) }`.

## Rendering Strategy

| Route kind | Render mode |
| --- | --- |
| Authenticated app / dashboard | `RenderMode.Client` |
| Marketing / content, stable data | `RenderMode.Prerender` |
| SEO-critical + dynamic data | `RenderMode.Server` + `provideClientHydration(withEventReplay())` |

Set per route in `app.routes.server.ts` (`ServerRoute[]`), wired with `provideServerRendering(withRoutes(serverRoutes))`. Detail: [references/routing-patterns.md](references/routing-patterns.md).

## Reference detail

CanDeactivate, resolver errors, outlets, router events, render modes, view transitions: [references/routing-patterns.md](references/routing-patterns.md).

## I/O Reference

|            |                                                                  |
| ---------- | ---------------------------------------------------------------- |
| Reads      | Active route/guard/resolver files, `app.routes.server.ts`, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored route config, guard, resolver, server route, navigation files |
| Invoked by | `devflow.implement`, `devflow.beautify`                          |
