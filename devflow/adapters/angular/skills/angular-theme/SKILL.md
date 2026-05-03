---
name: angular-theme
description: Build and refactor Angular app theme with Tailwind and shared CSS layers. Use when defining global styles, component theme classes, design tokens, dark mode, or style architecture cleanup.
---

# Skill: Angular Theme

Use when creating or refactoring app theme rules. Keep style system predictable. Keep style system reusable.

## Objectives

- Keep one theme source of truth.
- Keep Tailwind as single styling system.
- Keep component styles consistent across pages.
- Keep templates clean. Utility noise down.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## 1) Theme baseline (mandatory)

- Use Tailwind. No mixed styling framework.
- Use `src/styles.css` as global style entrypoint.
- Use `src/styles/` for theme layers split by concern.
- Import theme layers from `src/styles.css`.

## 2) Required style contract

Repository contract:

```text
src/
  styles/
    components.css
    utilities.css
    ...other theme layer files
  styles.css
```

Rules:

- `src/styles.css` defines global style setup.
- `src/styles.css` imports Tailwind and `src/styles/*` layers.
- `src/styles/` files stay focused by concern. No giant catch-all file.

## 3) Component styling rules

- Do not write long Tailwind utility chains in templates.
- Create semantic component class in CSS.
- Apply utilities with `@apply` inside CSS class.
- Add `@reference "#styles.css";` in each component stylesheet.

Example:

```css
@reference "#styles.css";

.btn-primary {
  @apply inline-flex items-center rounded-md px-4 py-2 font-medium;
  @apply bg-primary-600 text-white hover:bg-primary-700;
}
```

```html
<button class="btn-primary">Save</button>
```

## 4) Do / Do not

Do:

- Keep theme tokens centralized.
- Keep naming semantic (`.btn-primary`, `.card-elevated`).
- Keep reusable patterns in `src/styles/components.css`.
- Keep utility abstractions in `src/styles/utilities.css`.

Do not:

- Do not duplicate same `@apply` block in many files.
- Do not hardcode random colors in component CSS.
- Do not style components only with inline template utilities.
- Do not bypass `src/styles.css` for global theme setup.

## 5) Review checklist

Before merge, confirm:

- [ ] Tailwind is the only styling foundation
- [ ] `src/styles.css` is global entrypoint
- [ ] `src/styles.css` imports every required file in `src/styles/`
- [ ] component styles use semantic classes with `@apply`
- [ ] each component stylesheet includes `@reference "#styles.css";`
- [ ] no repetitive utility chains remain in templates

## I/O Reference

|                |                                                                    |
| -------------- | ------------------------------------------------------------------ |
| Trigger        | Theme setup, style refactor, dark mode prep, CSS layer cleanup     |
| Reads          | `src/styles.css`, `src/styles/*`, component stylesheets, templates |
| Invoked by     | `devflow.plan`, `devflow.implement`, `devflow.beautify`            |
| Related skills | `angular-architecture`, `angular-component`                        |
