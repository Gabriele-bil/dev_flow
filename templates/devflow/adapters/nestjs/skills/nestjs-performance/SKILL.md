---
name: nestjs-performance
description: Async lifecycle hooks, lazy module loading, query optimization, caching strategy, graceful shutdown. Load when profiling latency, touching lifecycle hooks, adding cache decorators, or handling SIGTERM/shutdown.
---

# Skill: NestJS Performance

Use when investigating latency/cold-start issues, adding caching, optimizing queries at the ORM level, or wiring lifecycle/shutdown hooks.

Full code examples: `references/performance-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (no lifecycle hook, cache decorator, or query-shape change)
- Query correctness/entity relations without a performance angle — use `nestjs-database`

## Objectives

- Async lifecycle hooks (`onModuleInit`, etc.) always `await`ed — never fire-and-forget.
- Heavy/rarely-used modules lazy-loaded, not eagerly imported at boot.
- Queries select only needed columns/relations; indexes on every frequently-filtered column.
- Caching applied strategically (hot, expensive, infrequently-changing data) with explicit invalidation — never blanket-cached.
- `SIGTERM`/`SIGINT` handled: stop new connections, drain in-flight requests, close DB/queue connections before exit.

## 1) Async Lifecycle Hooks (HIGH)

`onModuleInit`/`onApplicationBootstrap` must be `async` and the caller must `await` them — Nest waits on the returned promise before continuing boot. Fire-and-forget (`onModuleInit() { this.connect(); }` without `await`) lets the app accept traffic before dependencies (DB pool, cache) are ready. Keep constructors synchronous and fast — heavy init (file reads, network calls) belongs in `onModuleInit`, not the constructor. `onApplicationBootstrap` is the right hook for cross-module work (e.g. cache warming) since all modules are guaranteed initialized by then.

## 2) Lazy Loading (MEDIUM)

`LazyModuleLoader` for modules that are heavy or rarely used (reports, admin-only features, legacy/migration code, bulk-import) — defers their initialization cost until first actual use. Matters most for serverless cold starts and large monoliths. Don't lazy-load modules on the critical request path.

## 3) Query Optimization (HIGH — usually the largest latency source)

- `select: [...]` / TypeORM `select` object to fetch only needed columns — never `repo.find()` when only 1-2 fields are used.
- Avoid over-fetching relation trees (`relations: ['posts', 'posts.comments', 'posts.comments.author']`) when the response only needs a count or a shallow field.
- Index every column used in a frequent `WHERE`/`JOIN` (`@Index(['userId'])`), and composite indexes for common multi-column filters.
- Paginate every list endpoint (`findAndCount` + `skip`/`take`) — never return unbounded result sets.

## 4) Strategic Caching (HIGH)

`@nestjs/cache-manager` (`CACHE_MANAGER` injection) for granular, explicit caching of specific expensive/hot operations — not a blanket `@UseInterceptors(CacheInterceptor)` on every read endpoint regardless of volatility. Explicit invalidation on writes (`cache.del(key)`), ideally event-driven (`@OnEvent('product.updated')`) so invalidation logic lives in one place, not scattered across every mutating method. TTL matched to actual data volatility (categories: 30 min; per-item summaries: seconds-to-minutes).

## 5) Graceful Shutdown (MEDIUM-HIGH)

`app.enableShutdownHooks()` in `main.ts` is mandatory — without it `OnApplicationShutdown` never fires. Handle `SIGTERM`/`SIGINT`: stop accepting new connections (`server.close()`), let in-flight requests finish (track active-request count, resolve when it hits zero, with a timeout ceiling), close DB pools/queue connections in `onApplicationShutdown`, then exit. Readiness probe should return `503` once shutdown starts so Kubernetes stops routing new traffic before the process exits.

## Performance Review Checklist

- [ ] Every async lifecycle hook is `await`ed by Nest (returns a promise, not fire-and-forget)
- [ ] Constructors have no blocking I/O — heavy init in `onModuleInit`
- [ ] Rarely-used/heavy modules lazy-loaded via `LazyModuleLoader`
- [ ] List/lookup queries select only needed columns/relations
- [ ] Frequently-filtered columns indexed; composite index for common multi-column queries
- [ ] All list endpoints paginated
- [ ] Caching present only where data is hot/expensive/slow-changing, with explicit invalidation
- [ ] `app.enableShutdownHooks()` present; `SIGTERM` drains in-flight requests before exit

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement`/`devflow-beautify` when touching lifecycle hooks, cache decorators/`CACHE_MANAGER`, `main.ts` bootstrap, or per the performance profiling trigger in `ADAPTER.md` |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md` |
| Related | `nestjs-database` (query/index correctness), `nestjs-architecture` (lifecycle/DI placement) |
