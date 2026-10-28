---
name: angular-http
description: Angular v22+ HTTP with resource(), httpResource(), HttpClient. Use for API calls, signal-based data loading, interceptors. Triggers on data fetching, API integration, loading/error handling, or Observable→signal migration.
---

# Angular HTTP & Data Fetching

## Decision Guide

- **`httpResource()`**: signal-based HTTP, wraps `HttpClient` with `value/error/isLoading/status` state. Default choice for HTTP GET-driven UI.
- **`resource()`**: non-HTTP async tasks or custom fetch logic (not tied to `HttpClient`).
- **`HttpClient`** directly: Observable pipelines/operators needed. Use `@Service()` decorator for global singleton services in v22 — replaces `@Injectable({ providedIn: 'root' })`.

Full code (options, resource state, HTTP methods, request options, interceptors, error handling, loading state, DI patterns) → [references/http-patterns.md](references/http-patterns.md).

## Interceptors

Functional interceptors recommended (`HttpInterceptorFn`), registered via `provideHttpClient(withInterceptors([...]))`.

## Notes from Angular HTTP Docs

- Configure once with `provideHttpClient`.
- Prefer typed request/response models.
- Use interceptors for cross-cutting concerns (auth, logging, error mapping).
- Test HTTP with `provideHttpClientTesting` + `HttpTestingController`.

## I/O Reference

|            |                                                                   |
| ---------- | ----------------------------------------------------------------- |
| Reads      | Active HTTP/service files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular HTTP resource and service files         |
| Invoked by | `devflow.implement`, `devflow.beautify`                           |
