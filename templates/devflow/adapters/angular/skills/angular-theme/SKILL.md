---
name: angular-theme
description: Angular theme with Tailwind + CSS layers. Use when the user asks for global styles, design tokens, dark mode, or style architecture changes.
---

# Skill: Angular Theme

Use when creating or refactoring app theme rules. Keep style system predictable. Keep style system reusable.

## Objectives

- Keep one theme source of truth.
- Keep Tailwind as single styling system.
- Keep component styles consistent across pages.
- Keep templates clean. Utility noise down.

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

## Reference detail

Detail for Component styling rules, Tailwind v4 conventions: [references/theme-conventions.md](references/theme-conventions.md) — load when touching those areas.

## 3) Do / Do not

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

## 4) ViewEncapsulation guidance

- Default `ViewEncapsulation.Emulated` — component styles scoped automatically. Leave unset; don't override per-component without reason.
- Cross-boundary styling: use `:host`, `:host-context()`, `::ng-deep`-free patterns. Never use `::ng-deep` — deprecated, leaks styles globally, breaks encapsulation guarantees.
- `ViewEncapsulation.None` required ONLY for genuinely global CSS that can't be scoped — e.g. route-transition animation CSS (`::view-transition-old/new`, see `angular-routing`), which MUST live in global `src/styles.css` regardless of encapsulation mode (pseudo-elements can't be targeted from encapsulated component styles).
- Prefer CSS custom properties (passed via `[style.--token]` host bindings) over `None`/`::ng-deep` for theme values that must cross component boundaries.

## 5) Review checklist

Before merge, confirm:

- [ ] Tailwind is the only styling foundation
- [ ] `src/styles.css` is global entrypoint
- [ ] `src/styles.css` imports every required file in `src/styles/`
- [ ] component styles use semantic classes with `@apply`
- [ ] each component stylesheet includes `@reference "#styles.css";`
- [ ] no repetitive utility chains remain in templates
- [ ] Tailwind entry uses `@import "tailwindcss";` + `@theme` tokens (no `tailwind.config.js`, no legacy `@tailwind` directives)
- [ ] no `::ng-deep` usage; `ViewEncapsulation.None` only for justified global CSS (e.g. route-transition styles in `src/styles.css`)

## I/O Reference

|                |                                                                    |
| -------------- | ------------------------------------------------------------------ |
| Trigger        | Theme setup, style refactor, dark mode prep, CSS layer cleanup     |
| Reads          | `src/styles.css`, `src/styles/*`, component stylesheets, templates |
| Invoked by     | `devflow.plan`, `devflow.implement`, `devflow.beautify`            |
| Related skills | `angular-architecture`, `angular-component`, `angular-routing`, `angular-aria` |
