# NestJS adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nestjs/templates/AGENTS.template.md`
- `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nestjs/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + "touching X → read skill Y" list. No `@`-imports — skills load by trigger, never in every session.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Record the ORM, validation and test-runner choices (`ADAPTER.md` → Project choices) in `constitution.md` → `## Key decisions` during the questionnaire.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install. Nest CLI scaffold already ships `@nestjs/common`, `@nestjs/core`, `@nestjs/platform-express`, `@nestjs/testing`, `supertest`, the test runner (Vitest for ESM, Jest for CommonJS) and the linter — do not re-add. No `helmet`: Nest 12 ships `app.useSecurityHeaders()`.

### js-runtime-dependencies

- `@nestjs/config`
- `@nestjs/swagger`
- `@nestjs/throttler`
- `@nestjs/jwt`
- `@nestjs/passport`
- `passport-jwt`
- `class-validator`
- `class-transformer`
- `@nestjs/cache-manager`
- `cache-manager`

### js-dev-dependencies

- `@types/passport-jwt`

### Adapter notes (ORM — install exactly one set)

ORM choice per `ADAPTER.md` → Project choices. Existing project: install nothing new. New project: ask the user, then install one set.

- TypeORM 1: runtime `@nestjs/typeorm`, `typeorm`, plus the DB driver (`pg`, `mysql2`, …).
- Prisma 7: runtime `@prisma/client@7` plus the driver adapter (`@prisma/adapter-pg` + `pg`, …); dev `prisma@7`. Pin major 7 — Prisma's own install docs use `prisma@prev`, so `@latest` is not v7. Then `npx prisma init`.
