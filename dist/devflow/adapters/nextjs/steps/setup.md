# Next.js adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `@devflow/adapters/nextjs/templates/AGENTS.template.md`
- `@devflow/adapters/nextjs/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + "when you touch X → read skill Y" list. No `@`-imports of skills (they would load into every session).
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install.

Baseline project: `create-next-app` defaults (App Router, TypeScript, Tailwind 4, ESLint CLI, Turbopack, Cache Components). Then `npx shadcn@latest init`. `package.json` `lint` script must be `eslint .` — `next lint` was removed in Next 16.

### js-runtime-dependencies

- `zustand`
- `react-hook-form`
- `zod`
- `@hookform/resolvers`
- `class-variance-authority`
- `clsx`
- `tailwind-merge`
- `lucide-react`
- `next-themes`

### js-dev-dependencies

- `jest`
- `jest-environment-jsdom`
- `@testing-library/react`
- `@testing-library/dom`
- `@testing-library/jest-dom`
- `@testing-library/user-event`
- `@types/jest`
- `ts-node`
- `@playwright/test`

i18n library: none by default. Add one only when `constitution.md` requires i18n, and record the choice in `registry.md`.
