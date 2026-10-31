# Angular adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/templates/AGENTS.template.md`
- `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + "when you touch X → read skill Y" list. No `@`-imports — they load into every session.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install. Each one is used by an adapter skill — add a package here only together with the skill that uses it.

Baseline project: `ng new <name> --package-manager=pnpm --style=css` (Angular v22: standalone, zoneless, Vitest). Adapter commands assume pnpm.

### js-runtime-dependencies

- `@angular/cdk` — overlays, harnesses (`angular-aria`, `angular-testing`)
- `@angular/aria` — headless accessible widgets (`angular-aria`)
- `@ngrx/signals` — Signal Store (`angular-state`)
- `@ngrx/operators` — `tapResponse` (`angular-state`)

### js-dev-dependencies

- `vitest` — unit test runner (`angular-testing`)
- `jsdom` — DOM for Vitest (`angular-testing`)
- `tailwindcss` — styling system (`angular-theme`)
- `@tailwindcss/postcss` — Tailwind v4 PostCSS plugin (`angular-theme`)
- `postcss` — required by `@tailwindcss/postcss` (`angular-theme`)
- `@playwright/test` — E2E (`steps/test.md`, `angular-testing`)

i18n library: none by default. Add one only when `constitution.md` requires i18n, and record the choice in `registry.md`.
