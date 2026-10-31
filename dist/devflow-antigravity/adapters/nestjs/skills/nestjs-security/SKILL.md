---
name: nestjs-security
description: Security headers, CSRF, guards, JWT auth, rate limiting, input validation (DTO classes or Standard Schema), output sanitization. Load when creating or refactoring main.ts, *.guard.ts, auth strategies, or any route accepting user input.
---

# Skill: NestJS Security

## Purpose

Project rules for the security baseline of a NestJS 12 app: bootstrap hardening, authentication, authorization, input validation, abuse limits. Examples: `references/security-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-security`
- Response shaping / hiding fields — use `nestjs-api-design`
- Entity or migration work with no request-facing surface — use `nestjs-database`

## Rules

1. **Bootstrap hardening in `main.ts`**, right after `NestFactory.create()`, before `init`/`listen`:
   - `app.useSecurityHeaders()` — built-in headers (HSTS, CSP, …), removes `X-Powered-By`. Do not add the `helmet` package instead; tune options on this call.
   - `app.enableCsrfProtection()` when any route authenticates by cookie/session. Built-in check is Fetch-Metadata/Origin based (not a token): `GET`/`HEAD`/`OPTIONS` must never change state; list cross-origin front-ends in `trustedOrigins`. Bearer-token-only APIs may skip it — record that in `constitution.md`.
2. **Validate every input** per `ADAPTER.md` → Project choices. Never `@Body() body: any`, never raw `req.body`.
   - DTO classes: global `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`; every field decorated; path ids through `ParseUUIDPipe`/`ParseIntPipe`.
   - Standard Schema: global `StandardSchemaValidationPipe`; `@Body({ schema })`, `@Query({ schema })`, `@Param('id', { schema })`. Both pipes may be bound together — each only touches its own parameters.
3. **Guards own access control.** No `if (!req.user…)` in handlers. Global `JwtAuthGuard` + `RolesGuard` via `APP_GUARD`; `@Public()` / `@Roles()` metadata read with `Reflector.getAllAndOverride`.
4. **JWT.** Secret from `ConfigService`; access token ~15 min; payload `sub` + roles only (base64, not encrypted — no PII, no password hash). Refresh tokens random, hashed at rest, rotated on use. `validate()` re-checks user exists/active and rejects tokens issued before last password change.
5. **Rate limits.** `@nestjs/throttler` global via `APP_GUARD` with named tiers (ttl in ms); tighter `@Throttle({ name: { limit, ttl } })` on login / reset / OTP; `@SkipThrottle()` on health. Multi-instance → shared Redis storage.
6. **Sanitize stored HTML.** User rich text rendered as HTML → `sanitize-html` with an allow-list before storage. Never build HTML responses by string interpolation of user data.
7. **Secrets** only through `ConfigService`; never in code, logs, or error bodies.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-beautify` per `steps/implement.md` → skill load decision matrix |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nestjs/ADAPTER.md`, `references/security-patterns.md` |
| Related | `nestjs-api-design` (response DTOs, pipes), `nestjs-error-handling` (auth failure shape), `nestjs-performance` (`main.ts` shutdown) |
