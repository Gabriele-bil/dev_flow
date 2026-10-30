---
name: nestjs-error-handling
description: HTTP exceptions, exception filters, async error handling in event/cron handlers, structured logging. Load when creating or refactoring *.filter.ts, catch blocks, event handlers, scheduled tasks, or any file that throws/logs errors.
---

# Skill: NestJS Error Handling

## Purpose

Project rules for throwing, mapping and logging errors so every response has one shape and no rejection crashes the process. Examples: `references/error-handling-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-error-handling`
- Validation rules for request input — use `nestjs-security` / `nestjs-api-design`
- RPC/event-transport errors between services — use `nestjs-microservices`

## Rules

1. **Services throw, never return `{ error }`.** Throw `HttpException` subclasses (`NotFoundException`, `ConflictException`, …); controllers stay `return this.service.x()`. Layer-agnostic services throw a domain error mapped to HTTP in a `@Catch(DomainError)` filter.
2. **One error shape, set by filters.** Never `try/catch` + `res.status().json()` in a controller. One global `@Catch()` filter (registered via `APP_FILTER` so it gets DI) logs and returns `{ statusCode, message, code?, timestamp, path }` — or RFC 7807 if `constitution.md` says so. Domain filters only for expected error families.
3. **No internals in responses.** Unknown errors → `500` with a generic message; stack, SQL, paths only in logs.
4. **Async outside the request is on you.** Nest catches only awaited handler promises. Fire-and-forget → `.catch(log)`. Every `@OnEvent` / `@Cron` / queue callback body → `try/catch`, log, dead-letter or retry; never rethrow.
5. **Logger, not console.** `private readonly logger = new Logger(Cls.name)` per class — `Logger` is instantiated, never injected as a provider. Log context objects, not concatenated strings. Never log secrets; with `nestjs-pino` set `redact` for `authorization` and password fields.
6. **Correlate.** Request id from `nestjs-cls` (`generateId: true`) on every log line and in the error body.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-beautify` per `steps/implement.md` → skill load decision matrix |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md`, `references/error-handling-patterns.md` |
| Related | `nestjs-api-design` (consumer-facing error contract), `nestjs-architecture` (`nestjs-cls`) |
