# Skill: Angular Theme — reference detail

Loaded on demand from `../SKILL.md`.

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

## 5) Tailwind v4 conventions

- Entry point uses `@import "tailwindcss";` — NOT legacy `@tailwind base; @tailwind components; @tailwind utilities;`.
- No `tailwind.config.js`. Config is CSS-first via `@theme` blocks + PostCSS (`.postcssrc.json` + `@tailwindcss/postcss`).
- Theme as CSS variables — define design tokens in `@theme`, consume as `var(--color-primary-600)` or Tailwind utilities that reference them.

```css
/* src/styles.css */
@import "tailwindcss";

@theme {
  --color-primary-600: oklch(0.55 0.2 263);
  --font-display: "Inter", sans-serif;
}
```

```json
// .postcssrc.json
{ "plugins": { "@tailwindcss/postcss": {} } }
```

Migrating an existing v3 project: drop `tailwind.config.js`, move `theme.extend` values into `@theme` as CSS custom properties, replace `@tailwind` directives with the single `@import`.
