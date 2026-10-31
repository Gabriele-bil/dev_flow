---
name: angular-http
description: Angular v22+ HTTP with resource(), httpResource(), HttpClient. Use for API calls, signal-based data loading, interceptors. Triggers on data fetching, API integration, loading/error handling, or Observable→signal migration.
---

# Angular HTTP & Data Fetching

## Purpose

Decide where HTTP lives and which API to use (`httpResource`, `resource`, `HttpClient`) in Angular v22 services and interceptors.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no service, interceptor or API client touched).
- Store wiring around a service call (`rxMethod`, `tapResponse`) → `angular-state`.
- Form async validation rules → `angular-forms` (only the `validators/` placement rule lives here).

## Rules

- **No HTTP in components or `page.ts`** — `HttpClient` and `httpResource()` both live in `service.ts`. Flow: page → state → service → HTTP (`angular-architecture`).
- **`httpResource()`**: signal-driven GETs. Return `undefined` from the request fn to skip the call.
- **`HttpClient`**: mutations (POST/PUT/PATCH/DELETE) and RxJS pipelines. Never `httpResource` for mutations.
- **`resource()`**: non-HTTP async work.
- **`@Service()`** for root singletons, instead of `@Injectable({ providedIn: 'root' })`.
- **Interceptors**: functional `HttpInterceptorFn` + `provideHttpClient(withInterceptors([...]))`; `inject()` at top of the interceptor, never inside `catchError`.
- **Upload progress**: `withXhr()` + `reportUploadProgress: true` (fetch backend throws). Not in SSR apps.
- **Errors**: `catchError` inside inner `switchMap` stream; map errors to typed domain errors in the service.

Detail + examples (placement, API table, interceptor, upload, testing): [references/http-patterns.md](references/http-patterns.md). Check current docs with Context7 before writing `httpResource`/`resource` options.

## I/O Reference

|            |                                                                   |
| ---------- | ----------------------------------------------------------------- |
| Reads      | Active HTTP/service/interceptor files, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular HTTP services and interceptors          |
| Invoked by | `devflow.implement`, `devflow.beautify`                           |
