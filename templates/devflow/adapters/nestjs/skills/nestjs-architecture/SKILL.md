---
name: nestjs-architecture
description: Module structure, dependency injection, injection tokens, provider scopes, circular deps, service boundaries, config. Load when creating or refactoring *.module.ts, *.service.ts, or any file wiring constructor DI.
---

# Skill: NestJS Architecture

## Purpose

Project rules for feature modules, DI wiring, provider scope and configuration in NestJS 12. Examples: `references/architecture-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-architecture`
- Pure DTO/schema or entity shape work with no module or DI change — use `nestjs-api-design` / `nestjs-database`
- Generic SOLID / naming questions — use `common-clean-code`

## Rules

1. **Feature modules.** One module per domain owning its controller, service, repository, DTOs. Never top-level `controllers/`, `services/`, `entities/` folders.
2. **One provider, one home.** Provide a service in exactly one module, `export` it, import that module elsewhere — providing it twice creates two instances with diverging state. `@Global()` only for config, logging, DB connection.
3. **Shared dynamic modules by reference.** Since Nest 11 dynamic modules are deduplicated by object reference, not by config hash: assign `X.forRoot(...)`/`register(...)` to an exported constant and import the constant everywhere.
4. **No circular module imports** (direct or transitive). Extract a shared module or decouple with `@nestjs/event-emitter` (`emit` / `@OnEvent`). `forwardRef()` only as a documented last resort.
5. **One service, one domain.** Name with "And" or >1 unrelated repository → split. Cross-domain orchestration lives in the controller or a dedicated use-case service.
6. **Query logic in `<feature>.repository.ts`**, not in services (ORM detail: `nestjs-database`).
7. **Events for fan-out.** One action notifying 3+ unrelated consumers → emit a domain event; each consumer module listens. Emitter never changes when consumers are added.
8. **Constructor injection only.** Property injection only for `@Optional()` dependencies. No `ModuleRef.get()` in business logic — allowed only for factory lookup by runtime key.
9. **Interfaces via token.** TS interfaces vanish at runtime: inject with `Symbol('X')` + `@Inject(X)`, or use an abstract class as token. Tokens live in `<feature>.tokens.ts`.
10. **Scope.** Default singleton. Never store per-request state on a singleton. Need request context → `nestjs-cls` (`ClsService`) before `Scope.REQUEST`, which re-instantiates the whole injection chain per request and skips lifecycle hooks.
11. **Config.** No `process.env` outside config files. `ConfigModule.forRoot({ isGlobal: true, validationSchema })` with a Standard Schema (Zod/Valibot/ArkType; Joi ≥18) so bad env fails at boot. Namespaces via `registerAs('db', …)`, injected as `ConfigType<typeof dbConfig>`.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-beautify` per `steps/implement.md` → skill load decision matrix |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md`, `references/architecture-patterns.md` |
| Related | `nestjs-database` (repository), `nestjs-microservices` (cross-process events), `common-clean-code` (SOLID) |
