# NestJS adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `@devflow/adapters/nestjs/templates/AGENTS.template.md`
- `@devflow/adapters/nestjs/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + skill references (`@...`) only.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install. Nest CLI scaffold already ships `@nestjs/common`, `@nestjs/core`, `@nestjs/platform-express`, `@nestjs/testing`, `jest`, `supertest`, `eslint`, `prettier` — do not re-add.

### js-runtime-dependencies

- `@nestjs/config`
- `@nestjs/swagger`
- `@nestjs/throttler`
- `@nestjs/jwt`
- `@nestjs/passport`
- `passport-jwt`
- `class-validator`
- `class-transformer`
- `@nestjs/typeorm`
- `typeorm`
- `@nestjs/cache-manager`
- `cache-manager`

### js-dev-dependencies

- `@types/passport-jwt`
