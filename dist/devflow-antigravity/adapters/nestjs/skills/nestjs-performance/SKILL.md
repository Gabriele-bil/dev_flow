---
name: nestjs-performance
description: Async lifecycle hooks, lazy module loading, caching strategy, graceful shutdown in NestJS 12. Load when touching main.ts bootstrap, lifecycle hooks, cache-manager code, or LazyModuleLoader.
---

# Skill: NestJS Performance

## Purpose

Project rules for boot, cache and shutdown behavior. Query shape and indexes belong to `nestjs-database`. Examples: `references/performance-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-performance`
- Query correctness, N+1, indexes — use `nestjs-database`
- Profiling decision during review — `steps/beautify.md` → performance profiling trigger

## Rules

1. **Lifecycle hooks return promises.** `async onModuleInit()` that `await`s its work — Nest awaits it before boot continues; a non-awaited call lets traffic in before the pool/cache is ready. Constructors stay sync and I/O-free. Cross-module work (cache warm-up) in `onApplicationBootstrap`. Request-scoped providers get no lifecycle hooks.
2. **Lazy-load rare heavy modules** (reports, admin, bulk import) with `LazyModuleLoader`; never on the hot request path. Matters most for serverless cold start.
3. **Cache deliberately.** `@nestjs/cache-manager` (Keyv stores) with `CACHE_MANAGER` for hot, expensive, slow-changing reads. TTL in **milliseconds**, matched to data volatility. Invalidate explicitly on write, ideally in one `@OnEvent` listener per aggregate. No blanket `CacheInterceptor` on volatile endpoints; never cache per-user data under a shared key.
4. **Shutdown is built in — do not hand-roll it.** `app.enableShutdownHooks()` in `main.ts`; Nest 12 HTTP adapters wait for in-flight responses on `app.close()`. Release resources in `onModuleDestroy`/`onApplicationShutdown`. No custom `SIGTERM` handlers, request counters, or `server.close()` wrappers.
5. **Zero-downtime on Kubernetes.** `TerminusModule.forRoot({ gracefulShutdownTimeoutMs })` slightly above the readiness probe period: on `SIGTERM` health reports `shutting_down` (`503`) while in-flight requests finish. `forceCloseConnections: true` only when keep-alive clients block exit.
6. **Measure before optimizing.** Latency work starts from a profile or load test (`steps/beautify.md`), not intuition.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-beautify` per `steps/implement.md` → skill load decision matrix |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nestjs/ADAPTER.md`, `references/performance-patterns.md` |
| Related | `nestjs-database` (queries, indexes), `nestjs-microservices` (health checks), `nestjs-security` (`main.ts` order) |
