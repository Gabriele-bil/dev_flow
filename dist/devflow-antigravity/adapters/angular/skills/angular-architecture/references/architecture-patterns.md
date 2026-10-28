# Skill: Angular Architecture — reference detail

Loaded on demand from `../SKILL.md`.

## 2) Repository layout (`src/`)

```text
src/
  app/
  styles/
    buttons.css
    components.css
    forms.css
    theme.css
    typography.css
    utilities.css
  styles.css
```

Rules:

- `src/styles.css` is global style entrypoint.
- `src/styles.css` imports Tailwind and every file in `src/styles/`.
- CSS is split by concern. Do not collapse all styles into one file.

## 3) App layer architecture (`src/app`)

```text
src/app/
  core/
    guards/
    interceptors/
    services/
    states/
  pages/
    [page-name]/
      [sub-page-name]/          # optional, same structure as parent page
      components/
      constants/
      directives/
      models/
      pipes/
      utils/
      validators/
      page.ts
      service.ts
      state.ts
  shared/
    components/
    constants/
    directives/
    models/
    pipes/
    utils/
    validators/
  app.config.ts
  app.routes.ts
  app.ts
```

### Layer intent

- `core/`: singleton app infrastructure. Instantiate once.
- `pages/`: feature/page domains. Own UI, state, and service boundary.
- `shared/`: reusable cross-feature building blocks with no page-specific coupling.

## 5) Naming and placement rules

- One page domain = one folder in `pages/[page-name]/`.
- Main page component file is always `page.ts`.
- Main feature service file is always `service.ts`.
- Main feature state file is always `state.ts`.
- New feature-specific model/validator/util stays inside its page folder.
- Move code to `shared/` only after confirmed reuse across multiple pages.
- Keep `core/services` for app-wide infrastructure services, not page business services.

## 8) Migration guidance (when refactoring legacy code)

- Move HTTP logic out of components into `service.ts`.
- Move ad-hoc component state into `state.ts` Signal Store.
- Extract global mutable state into `core/states`.
- Split oversized page folders into `components`, `models`, `utils`, `validators`.
- Keep refactor incremental by page domain to reduce blast radius.
