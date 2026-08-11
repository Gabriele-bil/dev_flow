---
name: nestjs-api-design
description: Response DTOs/serialization, interceptors, pipes, API versioning, OpenAPI docs. Load when creating or refactoring *.controller.ts, *.interceptor.ts, response DTOs, or `@nestjs/swagger` decorators.
---

# Skill: NestJS API Design

Use when shaping controller responses, writing interceptors/pipes, versioning breaking changes, or documenting endpoints with `@nestjs/swagger`.

Full code examples: `references/api-design-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (no controller/interceptor/pipe/DTO-response change)
- Request validation only, no response shaping — use `nestjs-security` (input DTOs)

## Objectives

- Controllers never return entities directly — response DTOs (`class-transformer` `@Exclude`/`@Expose`) control the exact wire shape.
- Cross-cutting concerns (logging, response transform, timeout, cache) live in interceptors, never duplicated per-handler.
- Input transformation (`ParseUUIDPipe`, `ParseIntPipe`, custom pipes) — no manual `parseInt`/regex checks in handlers.
- Breaking response-shape changes go through NestJS versioning (`@Version()`), never silently.
- Every public endpoint documented with `@nestjs/swagger` decorators — OpenAPI spec stays complete.

## 1) DTOs and Serialization for Responses (MEDIUM)

Never `return this.usersService.findById(id)` where the return type is the raw entity — it leaks whatever columns exist (`passwordHash`, `internalNotes`). Mark sensitive entity columns `@Exclude()` and enable `app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)))` globally, or use explicit `UserResponseDto` classes with `@Expose()` + `plainToInstance(..., { excludeExtraneousValues: true })` for shapes that differ from the entity. `@Expose({ groups: [...] })` + `@SerializeOptions({ groups: [...] })` for role-conditional field visibility (public vs admin vs owner).

## 2) Interceptors for Cross-Cutting Concerns (MEDIUM-HIGH)

Logging, response-envelope transformation, timeouts, caching, error-type mapping — implement once as a `NestInterceptor`, apply via `APP_INTERCEPTOR` (global) or `@UseInterceptors()` (scoped). Never duplicate `const start = Date.now(); ...; logger.log(...)` inside every handler. `intercept()` wraps `next.handle()` with RxJS operators (`tap`, `map`, `timeout`, `catchError`).

## 3) Pipes for Input Transformation (MEDIUM)

Built-ins first: `ParseUUIDPipe`, `ParseIntPipe`, `ParseEnumPipe`, `DefaultValuePipe`. Custom `PipeTransform` for domain-specific parsing (`ParseDatePipe`, comma-separated-list parsing) — keeps handlers free of manual `parseInt`/`isUUID`/type-coercion checks. Global `ValidationPipe({ transform: true, transformOptions: { enableImplicitConversion: true } })` complements per-param pipes for whole-DTO query/body transformation.

## 4) API Versioning (MEDIUM)

Enable via `app.enableVersioning({ type: VersioningType.URI | HEADER | MEDIA_TYPE, defaultVersion: '1' })` — pick one strategy, apply consistently, never mix ad hoc `v1/users`-style manual route prefixes with the built-in system. `@Version('2')` on a controller/handler for breaking changes; `@Version(VERSION_NEUTRAL)` for endpoints unaffected by the bump; `@Version(['1','2'])` when one handler serves multiple versions. Deprecate old versions explicitly — `Deprecation`/`Sunset`/`Link` response headers via an interceptor — rather than silently dropping them.

## 5) API-Consumer Accessibility (OpenAPI + Structured Errors)

`common-web-interface-guidelines` does not apply — NestJS is backend-only, no DOM/ARIA surface. The equivalent quality bar for an API's "accessibility" to its consumers:

- Every endpoint has complete `@ApiOperation`/`@ApiResponse`/`@ApiParam`/`@ApiBody` (`@nestjs/swagger`) — undocumented endpoints are invisible to API clients and codegen tools.
- Error responses follow a consistent, structured shape (see `nestjs-error-handling`) — ideally RFC 7807 `application/problem+json` (`type`, `title`, `status`, `detail`, `instance`) or the project's equivalent single consistent envelope.
- Validation error messages are field-specific and human-readable (`class-validator` custom `message:` strings), not just `Bad Request`.
- Correct HTTP status codes always (`201` on create, `204` on empty-body delete, `409` on conflict, `422`/`400` on validation — never `200` for an error case).
- i18n-ready error messages when the consumer base is multi-locale — message keys/codes in the response body (`code: 'USER_NOT_FOUND'`), not just an English string, so clients can localize.

## API Design Review Checklist

- [ ] No entity returned directly from a controller with unexcluded sensitive fields
- [ ] Response shape controlled by DTO/`class-transformer`, not manual spreading
- [ ] Repeated cross-cutting logic (logging/timing/caching) extracted to an interceptor
- [ ] No manual `parseInt`/regex validation in a handler — pipes used instead
- [ ] Breaking response changes versioned via `@Version()`, not a silent shape change
- [ ] Every public endpoint has `@nestjs/swagger` decorators
- [ ] Error responses structured and consistent; correct HTTP status per case

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `*.controller.ts`, `*.interceptor.ts`, `*.pipe.ts`, or response-shaping DTOs |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md` |
| Related | `nestjs-error-handling` (error response shape), `nestjs-security` (request-side DTO validation) |
