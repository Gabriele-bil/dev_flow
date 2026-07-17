# Next.js adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `@devflow/adapters/nextjs/templates/AGENTS.template.md`
- `@devflow/adapters/nextjs/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + skill references (`@...`) only.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install.

### js-runtime-dependencies

- `next-intl`
- `zustand`
- `react-hook-form`
- `zod`
- `@hookform/resolvers`
- `class-variance-authority`
- `clsx`
- `tailwind-merge`
- `lucide-react`

### js-dev-dependencies

- `jest`
- `jest-environment-jsdom`
- `@testing-library/react`
- `@testing-library/jest-dom`
- `@types/jest`
