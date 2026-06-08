# Angular Routing — Advanced Patterns

## Lazy Loading with Injection Context

`loadComponent`/`loadChildren` factories run in injection context — `inject()` works directly for gating decisions.

```typescript
{
  path: "beta",
  canMatch: [() => inject(FeatureFlagsStore).betaEnabled()],
  loadComponent: () => import("./pages/beta/page").then((m) => m.BetaPage),
}
```

## CanDeactivate — Unsaved Changes Guard

```typescript
export interface CanComponentDeactivate {
  canDeactivate(): boolean | Observable<boolean>;
}

export const unsavedChangesGuard: CanDeactivateFn<CanComponentDeactivate> = (component) =>
  component.canDeactivate();
```

```typescript
export class EditPage implements CanComponentDeactivate {
  form = form(this.model, ...);

  canDeactivate() {
    return !this.form().dirty() || confirm("Discard unsaved changes?");
  }
}
```

## Resolver Error Handling

```typescript
export const userResolver: ResolveFn<User> = (route) => {
  const usersService = inject(UsersService);
  const router = inject(Router);

  return usersService.getById(route.paramMap.get("id")!).pipe(
    catchError(() => of(new RedirectCommand(router.parseUrl("/not-found")))),
  );
};
```

## Matrix Params and Query Params

```typescript
// Matrix params: /products;category=books;sort=price
this.router.navigate(["/products", { category: "books", sort: "price" }]);

// Query params merge (preserve existing)
this.router.navigate([], { queryParams: { page: 2 }, queryParamsHandling: "merge" });
```

## Programmatic Navigation with Relative Paths

```typescript
private route = inject(ActivatedRoute);
private router = inject(Router);

goToSibling() {
  this.router.navigate(["../sibling"], { relativeTo: this.route });
}
```

## RouteReuseStrategy — Cache Detached Routes

```typescript
export class CachedRouteReuseStrategy implements RouteReuseStrategy {
  private handles = new Map<string, DetachedRouteHandle>();

  shouldDetach(route: ActivatedRouteSnapshot) {
    return route.data["reuse"] === true;
  }

  store(route: ActivatedRouteSnapshot, handle: DetachedRouteHandle | null) {
    if (handle) this.handles.set(route.routeConfig!.path!, handle);
    else this.destroyDetachedRouteHandle(route.routeConfig!.path!);
  }

  shouldAttach(route: ActivatedRouteSnapshot) {
    return this.handles.has(route.routeConfig?.path ?? "");
  }

  retrieve(route: ActivatedRouteSnapshot): DetachedRouteHandle | null {
    return this.handles.get(route.routeConfig?.path ?? "") ?? null;
  }

  shouldReuseRoute(future: ActivatedRouteSnapshot, curr: ActivatedRouteSnapshot) {
    return future.routeConfig === curr.routeConfig;
  }

  private destroyDetachedRouteHandle(path: string) {
    this.handles.get(path)?.componentRef?.destroy();
    this.handles.delete(path);
  }
}
```

Use official `destroyDetachedRouteHandle` API to clean up cached components — prevents memory leaks from stale detached handles.

## Loading Indicator from Router Events

```typescript
export const NavigationLoadingStore = signalStore(
  { providedIn: "root" },
  withState({ loading: false }),
  withMethods((store, router = inject(Router)) => ({
    _track: rxMethod<void>(
      pipe(
        switchMap(() =>
          router.events.pipe(
            tap((e) => {
              if (e instanceof NavigationStart) patchState(store, { loading: true });
              if (e instanceof NavigationEnd || e instanceof NavigationCancel || e instanceof NavigationError) {
                patchState(store, { loading: false });
              }
            }),
          ),
        ),
      ),
    ),
  })),
  withHooks({ onInit: (store) => store._track() }),
);
```

## Incremental Hydration (SSR)

```html
@defer (hydrate on viewport) {
  <app-comments [postId]="postId()" />
} @placeholder {
  <div class="comments-skeleton"></div>
}
```

Defers hydration of below-fold components until viewport intersection — reduces SSR initial payload + speeds up TTI.

## Platform Navigation API (experimental)

```typescript
provideRouter(routes, withExperimentalPlatformNavigation())
```

Integrates router with browser Navigation API — finer control over back/forward and navigation interception. Developer-preview, opt-in only.
