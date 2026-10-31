# Angular Routing — project decisions

Loaded on demand from `../SKILL.md`. Router/SSR options change between minors: check current docs with Context7 (`/websites/angular_dev`) before writing `provideRouter` features or server routes.

## Unsaved changes — `CanDeactivateFn`

```typescript
export const unsavedChangesGuard: CanDeactivateFn<{ canDeactivate(): boolean }> = (c) => c.canDeactivate();
// page: canDeactivate() { return !this.form().dirty() || confirm("Discard unsaved changes?"); }
```

## Resolver errors

Resolvers block navigation — keep them fast. On failure redirect, do not throw. `inject()` at the top of the resolver, never inside `catchError`:

```typescript
export const userResolver: ResolveFn<User | RedirectCommand> = (route) => {
  const users = inject(UserService);
  const router = inject(Router);
  return users.getById(route.paramMap.get("id")!).pipe(
    catchError(() => of(new RedirectCommand(router.parseUrl("/not-found")))),
  );
};
```

## Outlets and router events

- Named outlets only for persistent side panels; pass context with `routerOutletData` + `ROUTER_OUTLET_DATA`.
- Global navigation loading flag: Signal Store in `core/states` reading `Router.events` (`NavigationStart` → true; `NavigationEnd`/`Cancel`/`Error` → false).
- `withDebugTracing()` local debugging only — never commit.

## Render modes (SSR / SSG)

`prerender: true` on a route is not supported — render mode lives in server routes:

```typescript
// app.routes.server.ts
export const serverRoutes: ServerRoute[] = [
  { path: "", renderMode: RenderMode.Client },
  { path: "about", renderMode: RenderMode.Prerender },
  { path: "**", renderMode: RenderMode.Server },
];
// app.config.server.ts: provideServerRendering(withRoutes(serverRoutes))
```

- Parameterized prerendered routes need `getPrerenderParams` — check docs.
- Below-fold heavy components on SSR pages: `@defer (hydrate on viewport)`.
- SSR apps: no `withXhr()`, no direct `window`/`document` outside `afterNextRender`.

## Route transitions

`provideRouter(routes, withViewTransitions())`. `::view-transition-old/new` CSS goes in global `src/styles.css` — component encapsulation cannot target these pseudo-elements. Skip via `onViewTransitionCreated: ({ transition }) => transition.skipTransition()` when `prefers-reduced-motion`.
