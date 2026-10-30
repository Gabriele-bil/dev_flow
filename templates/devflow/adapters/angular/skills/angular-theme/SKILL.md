---
name: angular-theme
description: Angular theme with Tailwind + CSS layers. Use when the user asks for global styles, design tokens, dark mode, or style architecture changes.
---

# Skill: Angular Theme

## Purpose

Keep one Tailwind v4 theme source of truth (`src/styles.css` + `src/styles/*`) and semantic component classes across the Angular app.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no global stylesheet, component stylesheet or token touched).
- Enter/leave motion → `angular-animations`; ARIA-state selectors of headless widgets → `angular-aria` (uses these tokens).
- Component logic/template structure → `angular-component`.

## 1) Theme baseline (mandatory)

- Tailwind v4 is the only styling system — no second CSS framework.
- `src/styles.css` = global entry: `@import "tailwindcss";`, `@theme` tokens, imports of every `src/styles/*` layer.
- `src/styles/` split by concern (`theme.css`, `typography.css`, `components.css`, `utilities.css`, …) — no catch-all file.
- Component stylesheets start with `@reference "#styles.css";` (subpath alias in `package.json` `imports`) and use `@apply` on semantic classes.

## 2) Do / Do not

Do:

- Centralize tokens in `@theme`; name classes semantically (`.btn-primary`, `.card-elevated`).
- Reusable patterns in `src/styles/components.css`, utility abstractions in `src/styles/utilities.css`.
- Dark mode via token overrides (`@custom-variant dark` + variables), not per-component color forks.

Do not:

- Hardcode colors in component CSS — tokens only.
- Repeat the same `@apply` block in several files, or leave long utility chains in templates.
- Bypass `src/styles.css` for global setup; add `tailwind.config.js` (v4 is CSS-first).

## 3) ViewEncapsulation

- Keep default `Emulated`. Cross-boundary theming: CSS custom properties via `[style.--token]` host bindings, `:host`, `:host-context()`.
- Never use `::ng-deep` — deprecated, leaks styles globally.
- `ViewEncapsulation.None` / global CSS only for what cannot be scoped (e.g. `::view-transition-*` in `src/styles.css`, see `angular-routing`).

## Reference detail

Component styling example, Tailwind v4 entry, `@reference` alias, dark mode: [references/theme-conventions.md](references/theme-conventions.md). Check current Tailwind docs with Context7 before writing `@theme`/`@custom-variant` syntax.

## 4) Review checklist

- [ ] Tailwind is the only styling foundation; `src/styles.css` is the global entry and imports every `src/styles/*` file
- [ ] component stylesheets have `@reference "#styles.css";` and semantic classes with `@apply`
- [ ] no repetitive utility chains in templates; no hardcoded colors
- [ ] `@import "tailwindcss";` + `@theme` tokens (no `tailwind.config.js`, legacy `@tailwind` directives removed)
- [ ] `::ng-deep` never used; `ViewEncapsulation.None` only for justified global CSS

## I/O Reference

|                |                                                                    |
| -------------- | ------------------------------------------------------------------ |
| Trigger        | Theme setup, style refactor, dark mode prep, CSS layer cleanup     |
| Reads          | `src/styles.css`, `src/styles/*`, component stylesheets, templates |
| Invoked by     | `devflow.plan`, `devflow.implement`, `devflow.beautify`            |
| Related skills | `angular-architecture`, `angular-component`, `angular-routing`, `angular-aria` |
