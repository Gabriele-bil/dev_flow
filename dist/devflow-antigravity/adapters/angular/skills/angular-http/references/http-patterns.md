# Angular HTTP — project decisions

Loaded on demand from `../SKILL.md`. Generic `HttpClient` / `resource()` usage: check current docs with Context7 (`/websites/angular_dev`) before writing — options change between minors.

## Where HTTP lives

One rule: HTTP is declared in `service.ts` (page or `core/services`), never in a component or `page.ts`.

- `HttpClient` methods and `httpResource()` fields both go in the service. State (`state.ts`) calls the service; components read signals from state.
- Page-scoped read (one GET driven by page signals): `httpResource()` field in the page `service.ts`, provided in the page `providers`; state re-exposes `value/isLoading/error`.
- Signal-form async validation (`validateHttp`): schema function lives in `validators/`, imported by the form — not inline in the component.

```typescript
@Service()
export class UserService {
  private readonly http = inject(HttpClient);
  private readonly selectedId = signal<string | null>(null);

  // undefined request = no call
  readonly user = httpResource<User>(() => {
    const id = this.selectedId();
    return id ? `/api/users/${id}` : undefined;
  });

  select(id: string) { this.selectedId.set(id); }
  update(id: string, changes: Partial<User>) { return this.http.patch<User>(`/api/users/${id}`, changes); }
}
```

## Which API

| Need | Use | Why |
| --- | --- | --- |
| GET driven by signals | `httpResource()` | value/error/isLoading/status signals, cancels stale requests |
| Non-HTTP async (SDK, IndexedDB) | `resource()` | same state shape without `HttpClient` |
| POST/PUT/PATCH/DELETE | `HttpClient` | docs: avoid `httpResource` for mutations |
| Debounce, retry, combine streams | `HttpClient` + RxJS (in store `rxMethod`) | operators |

- Root singleton services: `@Service()` instead of `@Injectable({ providedIn: 'root' })`.
- Config values: `InjectionToken` with `factory` — no hard-coded base URLs in services.

## Interceptors

Functional `HttpInterceptorFn` only, registered with `provideHttpClient(withInterceptors([...]))`. Class interceptors via `HTTP_INTERCEPTORS` multi-provider: do not use (legacy DI path).

- Call `inject()` at the top of the interceptor body. `inject()` inside `catchError`/`subscribe` callbacks runs outside the injection context → NG0203.

```typescript
export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router); // injection context: here, not inside catchError
  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) router.navigate(['/login']);
      return throwError(() => error);
    }),
  );
};
```

## Streams that must survive errors

`catchError` goes inside the inner `switchMap` stream. Outside it, first error completes the outer stream (search stops working).

```typescript
switchMap((q) => this.http.get<Result[]>(`/api/search?q=${q}`).pipe(catchError(() => of([]))))
```

## Upload progress

Default backend is fetch: it throws on `reportUploadProgress`. Upload progress needs `provideHttpClient(withXhr())` + `reportUploadProgress: true` + `observe: 'events'`. Never `withXhr()` in SSR apps — server XHR deprecated, removal planned in v23.

## Testing

`provideHttpClientTesting()` (test env provides `HttpClient`; add `provideHttpClient(withInterceptors([...]))` only when testing interceptors), `HttpTestingController.expectOne` + `flush`, `verify()` in `afterEach`. `httpResource`: `TestBed.tick()` to issue the request, `await fixture.whenStable()` after `flush`.
