---
name: angular-routing
description: Define and manage Angular routes, guards, resolvers, navigation, and rendering strategy for v22+. Use for route config, lazy loading, route protection, data prefetch, programmatic/declarative navigation, and SSR/hydration decisions. Triggers on route file creation, guard/resolver implementation, navigation flows, or rendering-strategy choices.
---

# Angular Routing

Configure routes, protect/prefetch with guards and resolvers, navigate, pick rendering strategy. Functional style only — no class-based guards/resolvers.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Route Definition

Root routes: `src/app/app.routes.ts`. Page-domain routes: colocate per feature, import into root.

```typescript
import { Routes } from "@angular/core";

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

## Resolvers

Use `ResolveFn` + `withComponentInputBinding()`. Bind resolved data as component input — do NOT read via `ActivatedRoute.data` manually.

```typescript
// user.resolver.ts
import { inject } from "@angular/core";
import { ResolveFn } from "@angular/router";

export const userResolver: ResolveFn<User> = (route) => {
  const usersService = inject(UsersService);
  return usersService.getById(route.paramMap.get("id")!);
};
```

```typescript
// app.routes.ts
{ path: "users/:id", resolve: { user: userResolver }, loadComponent: () => import("./pages/user-detail/page").then((m) => m.UserDetailPage) }
```

```typescript
// app.config.ts
provideRouter(routes, withComponentInputBinding())
```

```typescript
// user-detail page.ts — resolved data arrives as input
export class UserDetailPage {
  user = input.required<User>();
}
```

Resolvers block navigation until resolved — keep them fast, surface loading via `Router.events`.

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

## Outlets

```html
<router-outlet />
<!-- Named outlet -->
<router-outlet name="sidebar" />
```

```typescript
{ path: "settings", loadComponent: () => ..., outlet: "sidebar" }
```

Nested outlets live in child route's component template. Pass contextual data via `routerOutletData` input + `ROUTER_OUTLET_DATA` injection token.

## Router Lifecycle

Event order: `NavigationStart` → `RoutesRecognized` → `GuardsCheckStart/End` → `ResolveStart/End` → `NavigationEnd`/`NavigationCancel`/`NavigationError`.

```typescript
private router = inject(Router);

constructor() {
  this.router.events
    .pipe(filter((e): e is NavigationEnd => e instanceof NavigationEnd))
    .subscribe((e) => this.analytics.trackPageView(e.urlAfterRedirects));
}
```

Use `withDebugTracing()` in `provideRouter()` only for local debugging — remove before commit.

## Rendering Strategy

Decision matrix:

| Strategy | When | Setup |
|---|---|---|
| CSR (default) | Internal tools, dashboards, authenticated apps | none |
| SSG / prerender | Marketing/content pages, stable data | `ng add @angular/ssr`, `prerender: true` per route |
| SSR + hydration | SEO-critical, fast first paint, dynamic data | `provideClientHydration(withEventReplay())` |

Use incremental hydration (`@defer (hydrate on viewport)`) for below-fold heavy components on SSR pages.

## Route Transition Animations

```typescript
// app.config.ts
provideRouter(routes, withViewTransitions({
  onViewTransitionCreated: ({ transition }) => {
    if (shouldSkip()) transition.skipTransition();
  },
}))
```

```css
/* src/styles.css — global only, NOT component-scoped */
::view-transition-old(root) { animation: fade-out 0.2s ease-out; }
::view-transition-new(root) { animation: fade-in 0.2s ease-in; }
```

View Transition CSS MUST live in `src/styles.css` — component encapsulation blocks pseudo-element selectors. Use `view-transition-name` for element-specific transitions.

For advanced patterns, see [references/routing-patterns.md](references/routing-patterns.md).

## I/O Reference

|            |                                                                  |
| ---------- | ---------------------------------------------------------------- |
| Reads      | Active route/guard/resolver files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored route config, guard, resolver, navigation files |
| Invoked by | `devflow.implement`, `devflow.beautify`                          |
