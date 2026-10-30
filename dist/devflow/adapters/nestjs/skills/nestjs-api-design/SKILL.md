---
name: nestjs-api-design
description: Response serialization, interceptors, pipes, API versioning, Express v5 routes, OpenAPI docs. Load when creating or refactoring *.controller.ts, *.dto.ts, *.schema.ts, *.interceptor.ts, *.pipe.ts, or @nestjs/swagger decorators.
---

# Skill: NestJS API Design

## Purpose

Project rules for the HTTP contract: what goes on the wire, how it is transformed, versioned and documented. Examples: `references/api-design-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-api-design`
- Whether input is validated at all, auth, rate limits — use `nestjs-security`
- Error body shape and filters — use `nestjs-error-handling`

## Rules

1. **Never return raw persistence objects.** The response type is a DTO or response schema, so new columns never leak.
   - DTO classes: global `ClassSerializerInterceptor`; `@Exclude()` sensitive fields, or `@SerializeOptions({ type: UserResponseDto })` with `@Expose()`; `groups` for role-dependent fields.
   - Standard Schema: `StandardSchemaSerializerInterceptor` + `@SerializeOptions({ schema: userResponseSchema })` (item schema — applied per element for arrays).
   - Prisma returns plain objects: `@Exclude()` on a class does nothing unless the handler returns an instance — use one of the two forms above.
2. **Cross-cutting = interceptor.** Timing logs, envelopes, timeouts, deprecation headers: one `NestInterceptor`, bound via `APP_INTERCEPTOR` or `@UseInterceptors`. Never copy-paste per handler.
3. **Pipes over manual parsing.** `ParseUUIDPipe`, `ParseIntPipe`, `ParseEnumPipe`, `DefaultValuePipe`, or a param schema (`@Param('id', { schema })`). No `parseInt` / regex checks in handlers.
4. **Version breaking changes.** `app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' })` — one strategy per app; `@Version('2')` for the new shape, `VERSION_NEUTRAL` for unaffected routes. Retire old versions with `Deprecation` / `Sunset` headers, never silently. No hand-written `v1/` prefixes.
5. **Express v5 paths.** Named wildcards (`*splat`; `{*splat}` also matches the bare prefix) — Nest still accepts bare `*` in controllers, but it is deprecated in middleware and exclude paths. Optional segments in braces (`users{/:id}`); the `?` suffix and inline regex are not supported in Express v5.
6. **Status codes.** `201` create, `204` empty delete, `409` conflict, one validation code app-wide (`400` default), never `200` on an error path.
7. **OpenAPI complete.** Every public route: `@ApiOperation`, `@ApiResponse` per status. Request/response fields come from the Swagger CLI plugin (DTO classes) or from `schema` options (Standard Schema; add a `standardSchemaConverter` when the library has no native JSON Schema). No `unknown` fields in the generated doc.
8. **Machine-readable errors** for multi-locale or automated consumers: stable `code` (`USER_NOT_FOUND`) next to the message.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-beautify` per `steps/implement.md` → skill load decision matrix |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md`, `references/api-design-patterns.md` |
| Related | `nestjs-security` (input validation), `nestjs-error-handling` (error shape), `nestjs-database` (what the ORM returns) |
