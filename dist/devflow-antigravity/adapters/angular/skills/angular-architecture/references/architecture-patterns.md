# Skill: Angular Architecture — reference detail

Loaded on demand from `../SKILL.md`.

## Repository layout (`src/`)

```text
src/
  app/
  styles/        # theme layers split by concern — see angular-theme
  styles.css     # global entry: Tailwind + src/styles/* imports
```

## App layer architecture (`src/app`)

```text
src/app/
  core/
    guards/  interceptors/  resolvers/  services/  states/
  pages/
    [page-name]/
      [sub-page-name]/          # optional, same structure as parent page
      components/ constants/ directives/ models/ pipes/ utils/ validators/
      page.ts  service.ts  state.ts  [page-name].routes.ts (when it has children)
  shared/
    components/ constants/ directives/ models/ pipes/ utils/ validators/
  app.config.ts  app.routes.ts  app.ts
```

- `core/`: singleton app infrastructure, instantiated once.
- `pages/`: feature/page domains — own UI, state and service boundary.
- `shared/`: reusable cross-feature building blocks, no page coupling.

## Naming and placement rules

- One page domain = one folder in `pages/[page-name]/`; main files always `page.ts`, `service.ts`, `state.ts`.
- Feature-specific model/validator/util stays in its page folder.
- `core/services` for app-wide infrastructure only, not page business services.

## Migration guidance (legacy code)

- HTTP out of components into `service.ts` (including `httpResource()` fields).
- Ad-hoc component state into `state.ts` Signal Store; global mutable state into `core/states`.
- `@ngrx/store` slices: migrate to Signal Store when the slice is touched — do not use `@ngrx/store` for new state.
- Split oversized page folders into `components`, `models`, `utils`, `validators`.
- Refactor one page domain at a time to limit blast radius.
