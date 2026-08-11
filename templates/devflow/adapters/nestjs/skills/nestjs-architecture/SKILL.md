---
name: nestjs-architecture
description: Module structure, dependency injection, injection tokens, provider scopes, circular deps, service boundaries. Load when creating or refactoring *.module.ts, *.service.ts, or any file wiring constructor DI.
---

# Skill: NestJS Architecture

Use when creating modules/services, wiring DI, defining injection tokens, or reviewing architectural consistency.

Full code examples: `references/architecture-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (not a module/service/DI file)
- Pure DTO/entity shape work with no module or DI change — use `nestjs-api-design` / `nestjs-database`

## Objectives

- Feature-module organization — one module per domain, never technical-layer grouping.
- Constructor injection only — dependencies explicit, testable, typed.
- No circular module dependencies — the #1 cause of NestJS runtime crashes.
- Single Responsibility per service — no "god services" spanning unrelated domains.
- Interfaces injected via token — TypeScript interfaces are erased at runtime, cannot be injection tokens directly.

## 1) Feature Modules (CRITICAL)

Organize by domain, not technical layer. Each feature module owns its controllers, services, entities, DTOs:

```text
src/
├── users/
│   ├── dto/
│   ├── entities/
│   ├── users.controller.ts
│   ├── users.service.ts
│   ├── users.repository.ts
│   └── users.module.ts
├── orders/
└── app.module.ts
```

Never: `src/controllers/`, `src/services/`, `src/entities/` at the top level — this is the technical-layer anti-pattern. Full comparison → references.

## 2) Module Sharing (CRITICAL)

Modules are singletons. Providing the same service in two modules creates **two separate instances** with diverging state — memory waste, sync bugs. Always: provide in one dedicated module, `export`, import that module elsewhere. Reserve `@Global()` for true cross-cutting concerns (config, logging, DB connection) — overuse hides dependencies and hurts testability.

## 3) Avoid Circular Dependencies (CRITICAL)

Module A imports Module B which imports Module A (directly or transitively) → runtime crash risk. Fix by extracting shared logic into a third module, or decoupling via `@nestjs/event-emitter` (`EventEmitter2.emit()` / `@OnEvent()`) instead of direct service-to-service imports.

## 4) Single Responsibility for Services (CRITICAL)

One service = one domain concept. Service name containing "And" (`UserAndOrderService`), or a service touching >1 unrelated repository, is a smell — split it. Orchestration across domains belongs in the controller or a dedicated orchestrator, not inside one service.

## 5) Repository Pattern (HIGH)

Encapsulate query logic — `createQueryBuilder` chains, complex `where`/`having` — in a dedicated `<feature>.repository.ts`, not inline in the service. Keeps services testable with a mocked repository and keeps DB-specific logic swappable.

## 6) Event-Driven Decoupling (MEDIUM-HIGH)

A service that must notify 3+ unrelated consumers on one action (inventory, email, analytics, loyalty…) is tightly coupled by construction. Emit a domain event (`OrderCreatedEvent`) via `EventEmitter2`; let each consumer's own module `@OnEvent()` listener react. Adding a new consumer requires zero changes to the emitting service.

## 7) Dependency Injection Rules (CRITICAL)

- **Constructor injection only.** Property injection (`@Inject()` on a class field) hides dependencies and bypasses TypeScript's instantiation-time guarantees — reserve for genuinely `@Optional()` dependencies only.
- **No service locator.** Never resolve dependencies at runtime via `ModuleRef.get()` in business logic — this hides the dependency graph and breaks testability. `ModuleRef` is valid only for dynamic factory-pattern lookups (e.g. selecting a handler by a runtime string key).
- **Injection tokens for interfaces.** TypeScript interfaces don't exist at runtime — inject via `Symbol('TOKEN')` or an abstract class, never a bare interface type as the constructor parameter type.
- **Interface Segregation.** Don't force a consumer to depend on a fat interface (8 methods) when it uses 1. Split by capability (`EmailSender`, `SmsSender`) so tests mock only what's used.
- **Liskov Substitution.** Every implementation of an interface/token (including test mocks) must honor the full contract — same return shape, same thrown-exception types. A mock that returns `null` where the interface promises an object breaks every caller silently.

## 8) Provider Scopes (CRITICAL)

Three scopes: `DEFAULT` (singleton — default, use for almost everything), `REQUEST` (new instance per HTTP request — bubbles up the whole injection chain, real performance cost), `TRANSIENT` (new instance per injection point). Never store per-request mutable state (e.g. current user id) on a singleton — it leaks across concurrent requests. Prefer `REQUEST`-scoped `@Inject(REQUEST)` or an async-context library (`nestjs-cls`) over ad hoc singleton state.

## 9) Configuration (`@nestjs/config`)

Never read `process.env` directly in business code. Use `ConfigModule.forRoot()` with a validated schema (Joi/Zod/class-validator) so misconfiguration fails at startup, not at first request. Namespace config (`registerAs('database', ...)`) for typed, scoped injection via `ConfigService`.

## Architecture Review Checklist

- [ ] Feature-module organization — no technical-layer top-level folders
- [ ] No service provided in more than one module (singleton instance preserved)
- [ ] No circular module imports (check both direct and transitive)
- [ ] Every service has one clear domain responsibility
- [ ] Constructor injection everywhere; no `ModuleRef.get()` outside factory patterns
- [ ] Interfaces injected via token/abstract class, never bare interface type
- [ ] `REQUEST`/`TRANSIENT` scope used deliberately, not by default
- [ ] `process.env` accessed only through `ConfigService`

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `*.module.ts`, `*.service.ts`, or files with constructor DI / `@Inject()` / injection tokens |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md` |
| Related | `nestjs-database` (repository pattern), `nestjs-api-design` (controllers), `nestjs-microservices` (event patterns) |
