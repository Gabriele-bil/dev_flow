---
name: nestjs-security
description: Guards, JWT auth, rate limiting, input validation (DTOs/class-validator), output sanitization. Load when creating or refactoring *.guard.ts, auth strategies, DTOs, or any route accepting user input.
---

# Skill: NestJS Security

Use when writing guards, auth strategies, DTOs, rate-limit config, or reviewing input/output handling for injection/XSS risk.

Full code examples: `references/security-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (no guard/auth/DTO/input-handling change)
- Pure entity/migration work with no request-facing surface — use `nestjs-database`

## Objectives

- Every request body/query/param validated via DTO + `class-validator`, never `any`.
- Auth/authorization enforced via guards, never manual `if (!req.user)` checks in handlers.
- JWT: short-lived access tokens, minimal payload, secret from `ConfigService`, refresh tokens hashed at rest.
- Rate limiting on sensitive endpoints (auth, password reset) stricter than general API limits.
- User-generated content sanitized before storage/render; no raw HTML echoed back.

## 1) Validate All Input (HIGH)

Global `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })` in `main.ts` — non-negotiable baseline. Every DTO field carries `class-validator` decorators (`@IsString`, `@IsEmail`, `@IsInt`, `@Min`/`@Max`, `@IsUUID('4')` for path params). Never `@Body() body: any`. Query DTOs use `@Type(() => Number)` + `@IsOptional()` for defaults/coercion.

## 2) Use Guards for Auth/Authorization (HIGH)

No manual `if (!req.user.roles.includes('admin'))` in handlers. `CanActivate` guards run before pipes/interceptors — ideal for access control. Pattern: `JwtAuthGuard` (verifies token, sets `request.user`) + `RolesGuard` (reads `@Roles()` metadata via `Reflector`) registered globally via `APP_GUARD`; `@Public()` decorator to opt out per-route.

## 3) Secure JWT Authentication (CRITICAL)

`@nestjs/jwt` + `@nestjs/passport`. Secret from `ConfigService`, never hardcoded. Short-lived access tokens (`~15m`), separate long-lived refresh token hashed with bcrypt before storage. JWT payload minimal — `sub`, `email`, `roles` only; never password, SSN, or other sensitive fields (payload is base64, not encrypted). `JwtStrategy.validate()` re-checks the user still exists/is active and rejects tokens issued before a password change — a valid signature is not sufficient trust.

## 4) Rate Limiting (HIGH)

`@nestjs/throttler`, registered globally via `APP_GUARD` with tiered named limits (`short`/`medium`/`long`). Auth endpoints (`login`, `forgot-password`) get tighter per-route `@Throttle()` overrides than general read endpoints. `@SkipThrottle()` for health checks. For clustered deployments, back the throttler storage with Redis so limits are shared across instances.

## 5) Sanitize Output / Prevent XSS (HIGH)

JSON responses are inherently low XSS risk (browsers don't execute JSON), but any user-generated content that gets rendered as HTML (comments, rich text) must be sanitized before storage with `sanitize-html` (allow-list tags/attributes, never a deny-list). `@Transform()` in the DTO is the enforcement point. Set `helmet()` with a CSP in `main.ts`. UUID-validate path params (`ParseUUIDPipe`) before echoing them into error messages.

## Security Review Checklist

- [ ] Global `ValidationPipe` active with `whitelist`/`forbidNonWhitelisted`/`transform`
- [ ] Every DTO field has `class-validator` decorators — no `any` on request input
- [ ] No manual auth/role checks in handlers — guards only
- [ ] JWT secret from `ConfigService`; payload has no password/PII; access token short-lived
- [ ] Refresh tokens hashed at rest
- [ ] Rate limiting present on auth/password-reset endpoints, stricter than general limits
- [ ] User HTML content sanitized before storage (`sanitize-html`, allow-list)
- [ ] `helmet()` registered in `main.ts`

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `*.guard.ts`, `*.strategy.ts`, `*.dto.ts`, or any controller accepting `@Body()`/`@Query()`/`@Param()` |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md` |
| Related | `nestjs-api-design` (DTO response shaping), `nestjs-error-handling` (auth failure responses) |
