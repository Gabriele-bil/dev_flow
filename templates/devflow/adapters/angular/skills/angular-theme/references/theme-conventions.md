# Skill: Angular Theme — reference detail

Loaded on demand from `../SKILL.md`.

## Tailwind v4 entry

PostCSS: `.postcssrc.json` → `{ "plugins": { "@tailwindcss/postcss": {} } }`. No `tailwind.config.js`.

```css
/* src/styles.css */
@import "tailwindcss";
@import "./styles/theme.css";
@import "./styles/components.css";
@import "./styles/utilities.css";

@custom-variant dark (&:where(.dark, .dark *));

@theme {
  --color-primary-600: oklch(0.55 0.2 263);
  --font-display: "Inter", sans-serif;
}
```

Migrating v3: move `theme.extend` into `@theme` variables, replace `@tailwind base/components/utilities` with the single `@import`, delete `tailwind.config.js`.

## Component stylesheets

Component CSS is compiled separately — it sees tokens and `@apply` only through `@reference`. Alias once in `package.json`:

```json
{ "imports": { "#styles.css": "./src/styles.css" } }
```

```css
/* user-card.css */
@reference "#styles.css";

.btn-primary {
  @apply inline-flex items-center rounded-md px-4 py-2 font-medium;
  @apply bg-primary-600 text-white hover:bg-primary-700;
}
```

```html
<button class="btn-primary">Save</button>
```

Simple token reads need no `@apply`: `color: var(--color-primary-600);`.
