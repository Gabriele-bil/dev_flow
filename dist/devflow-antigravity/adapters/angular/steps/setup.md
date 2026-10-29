# Angular adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/templates/AGENTS.template.md`
- `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + skill references (`@...`) only.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install.

### js-runtime-dependencies

- `@jsverse/transloco`
- `@angular/cdk`
- `@ngrx/operators`
- `@ngrx/signals`

### js-dev-dependencies

- `vitest`
- `jsdom`
