---
name: angular-routing
description: Angular v22+ routing — routes, guards, resolvers, navigation, SSR/hydration. Use for route config, lazy loading, protection, prefetch, or rendering decisions. Triggers on route file creation, guard/resolver work, or navigation flows.
---

# Angular Routing

Configure routes, protect/prefetch with guards and resolvers, navigate, pick rendering strategy. Functional style only — no class-based guards/resolvers.

## Route Definition

Root routes: `src/app/app.routes.ts`. Page-domain routes: colocate per feature, import into root.

```typescript
import { Routes } from "@angular/router";

export const routes: Routes = [
  { path: "", redirectTo: "dashboard", pathMatch: "full" },
  { path: "dashboard", loadComponent: () => import("./pages/dashboard/page").then((m) => m.DashboardPage) },
  { path: "users/:id", loadComponent: () => import("./pages/user-detail/page").then((m) => m.UserDetailPage) },
  { path: "admin", loadChildren: () => import("./pages/admin/admin.routes").then((m) => m.adminRoutes) },
  { path: "**", loadComponent: () => import("./pages/not-found/page").then((m) => m.NotFoundPage) },
];
```

Order: specific paths before generic, wildcard `**` last. `loadComponent`/`loadChildren` default for non-landing routes — minimize initial bundle.

## Functional Guards

Use functional guards (`CanActivateFn`, `CanMatchFn`, `CanDeactivateFn`). Do NOT use class-based guards.

```typescript
import { inject } from "@angular/core";
import { CanActivateFn, Router } from "@angular/router";

export const authGuard: CanActivateFn = (route, state) => {
  const auth = inject(AuthStore);
  const router = inject(Router);

  if (auth.isAuthenticated()) return true;
  return router.createUrlTree(["/login"], { queryParams: { redirect: state.url } });
};
```

```typescript
// Feature-flag gating with CanMatch — runs before lazy chunk loads
export const betaFeatureGuard: CanMatchFn = () => {
  const flags = inject(FeatureFlagsStore);
  return flags.betaEnabled() || new RedirectCommand(inject(Router).parseUrl("/"));
};
```

Place guards in `core/guards`. Return `boolean | UrlTree | RedirectCommand` (sync or async).

## Reference detail

Detail for Resolvers, Outlets, Router Lifecycle, Rendering Strategy, Route Transition Animations: [references/routing-patterns.md](references/routing-patterns.md) — load when touching those areas.

## Navigation

```html
<!-- Declarative -->
<a [routerLink]="['/users', user.id()]" routerLinkActive="active">{{ user.name() }}</a>
<nav>
  <a routerLink="/dashboard" routerLinkActive="active" [routerLinkActiveOptions]="{ exact: true }">Dashboard</a>
</nav>
```

```typescript
// Programmatic
private router = inject(Router);

goToUser(id: string) {
  this.router.navigate(["/users", id], { queryParams: { tab: "profile" } });
}
```

Prefer `RouterLink` for declarative nav, `Router.navigate()` for conditional/post-action nav.

## I/O Reference

|            |                                                                  |
| ---------- | ---------------------------------------------------------------- |
| Reads      | Active route/guard/resolver files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored route config, guard, resolver, navigation files |
| Invoked by | `devflow.implement`, `devflow.beautify`                          |
