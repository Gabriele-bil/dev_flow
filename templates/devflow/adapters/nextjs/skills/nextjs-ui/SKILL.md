---
name: nextjs-ui
description: shadcn/ui, Tailwind @apply, design tokens, dark mode, responsive layout. Load when touching components/ui/** or @/components/ui imports.
---

# Skill: nextjs-ui

## Purpose

Build UI with shadcn/ui + Tailwind v4. No utility vomit in HTML. Extract styles to CSS with `@apply`. Keep tokens, dark mode, responsive.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — subtask → criterion → file
- **vertical slices** — end-to-end increments
- **token-lean** — caveman-compress: drop fluff; keep precision
- **semantic-html** — no utility lists in HTML. Use descriptive classes + `@apply`.

## Baseline

| Package | Role |
| --- | --- |
| `shadcn/ui` | Component primitives |
| `tailwindcss` v4 | Styling engine |
| `@apply` | CSS extraction directive |
| `next-themes` | Dark mode |
| `lucide-react` | Icons |

## Rules

**Drop:**

- Utility class lists in `className`
- Inline styles (`style={{...}}`)
- Hex/RGB values
- Articles (a, an, the), filler, hedging

**Keep:**

- Descriptive, semantic class names
- Design tokens (`--primary`, `--border`)
- `@apply` directive in CSS
- Dark mode parity
- Responsive breakpoints

**Patterns:**

- HTML: `<tag className="descriptive-name">`
- CSS: `.descriptive-name { @apply utility-1 utility-2 ...; }`
- Mobile-first: base styles first → media queries or responsive `@apply`

## Examples

| Aspect | Bad (Utility Vomit) | Good (Clean HTML + @apply) |
| --- | --- | --- |
| **Component** | `<div className="p-4 bg-white rounded-lg shadow-md border border-gray-200 dark:bg-zinc-950">` | `<div className="card">` |
| **CSS** | N/A | `.card { @apply p-4 bg-background border border-border rounded-lg shadow-sm; }` |
| **Responsive** | `<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4">` | `<div className="layout-grid">` |
| **Responsive CSS** | N/A | `.layout-grid { @apply grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4; }` |

## shadcn/ui — Refactor Model

shadcn/ui adds utilities to `components/ui/` by default. **Refactor immediately:**

1. Run `npx shadcn@latest add [component]`
2. Open `components/ui/[component].tsx`
3. Identify utility strings
4. Move to `globals.css` inside descriptive class
5. Replace `className` in TSX with new class

## Design Tokens

Tokens in `globals.css`. Use via `@apply` or `var()`.

```css
.btn-primary {
  @apply bg-primary text-primary-foreground border-input;
}
```

## Dark Mode — next-themes

- Root layout: add `suppressHydrationWarning` on `<html>`
- Style parity: every state (hover, focus) needs dark variant via `dark:` or media query

```css
.card {
  @apply bg-white dark:bg-zinc-950;
}
```

## Icons — lucide-react

- Size: use `@apply` on container or icon class
- Correct: `<Search className="icon-sm" />`
- CSS: `.icon-sm { @apply h-4 w-4; }`

## Anti-patterns

- **Utility vomit** — long `className` strings in TSX
- **Hardcoded hex/rgb** — use tokens only
- **Style-logic mix** — complex ternary styling in TSX; move to CSS classes
- **Anonymous classes** — `.div1`, `.box`; use semantic names (`.sidebar-item`)

## Review checklist

- [ ] HTML clean? No utility lists in `className`
- [ ] `@apply` used in CSS for all Tailwind styles
- [ ] Descriptive classes (semantic) used
- [ ] Dark mode parity on all states
- [ ] Responsive? No `md:` in TSX
- [ ] `suppressHydrationWarning` on `<html>` in root layout

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` for `components/ui/**`, files importing from `@/components/ui` |
| Related | `nextjs-architecture`, `nextjs-components` |
