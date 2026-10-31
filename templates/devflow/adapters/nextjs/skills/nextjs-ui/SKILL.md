---
name: nextjs-ui
description: shadcn/ui primitives, Tailwind CSS v4 tokens (@theme inline), CVA variants, dark mode with next-themes, responsive layout. Load when touching components/ui/**, app/globals.css, or UI styling.
---

# Skill: nextjs-ui

## Purpose

UI rules: shadcn/ui primitives, Tailwind v4 CSS-first tokens, CVA variants, dark-mode parity. Token file and variant example: `references/ui-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Form field wiring and validation → `nextjs-forms`
- Accessibility/UX audit of finished UI → `@devflow/adapters/common/skills/common-web-interface-guidelines/SKILL.md`

## Baseline

| Package | Role |
| --- | --- |
| shadcn/ui (`npx shadcn@latest add <c>`) | Accessible primitives copied into `components/ui/` |
| `tailwindcss` 4 | CSS-first config in `app/globals.css` — no `tailwind.config.*` |
| `class-variance-authority` | Typed variants |
| `clsx` + `tailwind-merge` → `cn()` | Class merging (`lib/utils.ts`) |
| `next-themes` | Dark mode (`attribute="class"`) |
| `lucide-react` | Icons |

## Rules

- Tokens: shadcn variables (`--background`, `--primary`, … in OKLCH) on `:root` / `.dark`, exposed to Tailwind with `@theme inline { --color-<name>: var(--<name>); }`. New token → add to `:root`, `.dark`, and `@theme inline`.
- Theme variable referencing another variable (fonts, colors) → `@theme inline`, not plain `@theme` (plain `@theme` resolves `var()` at definition site → wrong value).
- Markup uses semantic utilities only: `bg-background`, `text-foreground`, `border-border`, `ring-ring`. No hex/rgb, no `bg-[#…]`, no inline `style`.
- Dark variant: `@custom-variant dark (&:is(.dark *));` once in `globals.css`; `dark:` only for one-off exceptions — tokens already switch.
- Variants via `cva()`; merge caller classes with `cn(variants(...), className)`.
- No mass `@apply` extraction — breaks variant overrides and `tailwind-merge`.
- Mobile-first breakpoints (`sm:` → `lg:`); primary touch targets ≥ 44px.
- Focus: `focus-visible:ring-*` on every custom interactive element; never remove Radix focus management.
- Icons: size via `className="size-4"`; decorative → `aria-hidden="true"`; icon-only button → `aria-label`.
- Edit generated `components/ui/*` only for project-wide variants; feature styling lives in feature components.

## Review checklist

- [ ] Only semantic token utilities, no hardcoded colors
- [ ] New tokens in `:root`, `.dark`, `@theme inline`
- [ ] Variants via `cva` + `cn`
- [ ] Dark mode parity checked
- [ ] Mobile-first responsive, visible focus states

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (`components/ui/**`, imports from `@/components/ui`, `app/globals.css`) |
| Reads | `references/ui-patterns.md` |
| Writes | UI components, `app/globals.css` tokens |
| Related | `nextjs-architecture`, `nextjs-components`, `common-web-interface-guidelines` |
