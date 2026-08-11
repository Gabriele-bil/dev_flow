---
name: nestjs-error-handling
description: HTTP exceptions, exception filters, async error handling, structured logging. Load when creating or refactoring *.filter.ts, catch blocks, event handlers, scheduled tasks, or any file that throws/logs errors.
---

# Skill: NestJS Error Handling

Use when writing service error paths, exception filters, async event/cron handlers, or structured logging.

Full code examples: `references/error-handling-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (no error throwing/catching/logging)
- Pure validation-shape work with no error path — use `nestjs-security` (class-validator DTOs)

## Objectives

- Services throw `HttpException` subclasses directly — controllers stay thin.
- Every response error shape centralized in exception filters, never formatted ad hoc in a controller.
- Async errors (event handlers, `@Cron`, fire-and-forget promises) always explicitly handled — unhandled rejections crash the process.
- Structured JSON logging via NestJS `Logger` (or Pino) with context — never `console.log`.

## 1) Throw HTTP Exceptions from Services (HIGH)

Services throw `NotFoundException`, `ConflictException`, etc. directly instead of returning `{ error }` objects for the controller to translate. Keeps controllers thin: `return this.usersService.findById(id)` — no manual `if (result.error)` branching. For layer-agnostic services, throw a domain exception and map it to HTTP status in a dedicated `@Catch(DomainException)` filter.

## 2) Use Exception Filters (HIGH)

Never `try/catch` + manually `res.status().json()` inside a controller. Register:

- Domain-specific filters (`@Catch(DomainException)`) for expected error families.
- One global `@Catch()` filter (`AllExceptionsFilter`) as the fallback — logs the exception, derives status from `HttpException.getStatus()` (500 otherwise), returns a consistent `{ statusCode, message, timestamp, path }` shape.

Register via `APP_FILTER` provider (module-scoped, DI-aware) or `app.useGlobalFilters()` in `main.ts`.

## 3) Handle Async Errors Explicitly (HIGH)

NestJS only auto-catches errors from awaited route-handler promises. These do NOT get automatic handling and crash the process on rejection:

- Fire-and-forget calls (`this.emailService.sendWelcome(...)` without `await` or `.catch()`)
- `@OnEvent()` handlers that call an async function without `await`/`try-catch`
- `@Cron()` tasks without `try-catch`

Fix: `.catch(err => logger.error(...))` on fire-and-forget promises; `try/catch` inside every `@OnEvent`/`@Cron` handler body (never rethrow — that crashes the process, dead-letter-queue or log instead); register `process.on('unhandledRejection', ...)` and `process.on('uncaughtException', ...)` in `main.ts` as a last-resort safety net.

## 4) Structured Logging (MEDIUM-HIGH)

`new Logger(ClassName.name)` per class, never `console.log`. Log with context objects (`this.logger.error('msg', error.stack, { userId })`), never string concatenation. Never log secrets (passwords, tokens) — redact in Pino config (`redact: ['req.headers.authorization']`) if using `nestjs-pino`. Attach request-scoped context (request ID, user ID) via `nestjs-cls` middleware so every log line in a request is traceable together.

## Error Handling Checklist

- [ ] No `{ error: string }` return shape from a service — throw instead
- [ ] No manual `try/catch` + `res.json()` in a controller — use exception filters
- [ ] One global `AllExceptionsFilter` registered (`APP_FILTER` or `useGlobalFilters`)
- [ ] Every `@OnEvent`/`@Cron` handler wraps its body in `try/catch`, never rethrows
- [ ] Fire-and-forget promises have `.catch()`
- [ ] No `console.log`/`console.error` — `Logger` only, no secrets in log payloads

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `*.filter.ts`, or content has `catch`/`@OnEvent`/`@Cron`/`Logger`/`throw` |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md` |
| Related | `nestjs-api-design` (RFC7807-style error response shape), `nestjs-security` (input validation errors) |
