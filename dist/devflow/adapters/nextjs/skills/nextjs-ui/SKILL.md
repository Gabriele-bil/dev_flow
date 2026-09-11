---
name: nextjs-ui
description: shadcn/ui primitives, Tailwind v4 utility composition, CVA variants, design tokens, dark mode, responsive layout. Load when touching components/ui/** or UI styling.
---

# Skill: nextjs-ui

## Purpose

Build accessible, high-performance UI using shadcn/ui primitives and Tailwind CSS v4. Enforce design tokens, CVA variants, responsive layouts, and dark mode parity.

## Core Principles

- **spec-first** — no UI code before `task.md` + `plan.md` approved
- **component-driven** — encapsulate styles and variants in reusable components with `cva()` and `cn()`, not global CSS bloat
- **token-based** — use semantic design tokens (`bg-background`, `text-primary`, `border-border`); never hardcode hex/rgb
- **accessibility-first** — adhere to Radix/shadcn keyboard navigation, ARIA attributes, and focus rings
- **token-lean** — caveman-compress: drop filler; keep precision

## Baseline

| Package | Role |
| --- | --- |
| `shadcn/ui` | Accessible headless component primitives |
| `tailwindcss` v4 | Modern styling engine with CSS-first `@theme` |
| `class-variance-authority` (CVA) | Type-safe component variant orchestration |
| `tailwind-merge` + `clsx` (`cn`) | Safe utility class concatenation |
| `next-themes` | Dark mode provider |
| `lucide-react` | Semantic SVG icons |

## Rules

**Drop:**

- Hardcoded Hex/RGB values (e.g., `#ffffff`, `rgb(15, 23, 42)`)
- Inline styles (`style={{...}}`)
- Extracting every utility class to `@apply` in `globals.css` (breaks shadcn variant composition and tailwind-merge)
- Missing dark mode states
- Missing focus rings on interactive elements

**Keep:**

- Semantic design tokens (`bg-background`, `text-foreground`, `border-border`, `ring-ring`)
- Component variants managed with `cva(...)`
- Dynamic class merging via `cn(...)`
- Mobile-first responsive modifiers (`sm:`, `md:`, `lg:`)
- Accessible touch targets (minimum 44x44px for primary interactions)

## Component Composition with CVA and `cn`

Use `cva` for components with multiple variants or sizes:

```tsx
import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const cardVariants = cva(
  'rounded-lg border bg-card text-card-foreground shadow-sm transition-colors',
  {
    variants: {
      variant: {
        default: 'border-border',
        interactive: 'border-border hover:border-primary/50 cursor-pointer',
        destructive: 'border-destructive/50 text-destructive',
      },
      padding: {
        default: 'p-6',
        compact: 'p-4',
        none: 'p-0',
      },
    },
    defaultVariants: {
      variant: 'default',
      padding: 'default',
    },
  }
)

export interface CardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof cardVariants> {}

export function Card({ className, variant, padding, ...props }: CardProps) {
  return (
    <div
      className={cn(cardVariants({ variant, padding }), className)}
      {...props}
    />
  )
}
```

## Design Tokens (Tailwind v4 `@theme`)

In Tailwind v4, tokens are defined directly in CSS using `@theme` and CSS variables:

```css
/* app/globals.css */
@import "tailwindcss";

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 240 10% 3.9%;
    --card: 0 0% 100%;
    --card-foreground: 240 10% 3.9%;
    --primary: 240 5.9% 10%;
    --primary-foreground: 0 0% 98%;
    --border: 240 5.9% 90%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 240 10% 3.9%;
    --foreground: 0 0% 98%;
    --card: 240 10% 3.9%;
    --card-foreground: 0 0% 98%;
    --primary: 0 0% 98%;
    --primary-foreground: 240 5.9% 10%;
    --border: 240 3.7% 15.9%;
  }
}
```

Always use token utility names in markup: `bg-background`, `text-primary`, `border-border`.

## Dark Mode — next-themes

- Root layout: add `suppressHydrationWarning` on `<html>`.
- Wrap app with `<ThemeProvider attribute="class" defaultTheme="system" enableSystem>`.
- Token parity: semantic tokens (`bg-background`, `text-foreground`) handle dark mode automatically; use `dark:` modifiers only for custom one-off exceptions.

## Icons — lucide-react

- Pass size classes directly via `className`: `<Search className="h-4 w-4" />` or `<Menu className="size-5" />`.
- When inside button or interactive control, set `aria-hidden="true"` or ensure container has `aria-label`.

## Anti-patterns

- **Hardcoded colors** — `bg-[#fff]`, `text-[#000]`; use `bg-background`, `text-foreground`.
- **Abusive `@apply` extraction** — moving every single Tailwind utility to a custom CSS class in `globals.css` destroys shadcn/ui variant overrides and `twMerge`.
- **Missing focus states** — always ensure interactive elements have visible `focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none`.
- **Missing `suppressHydrationWarning`** on root `<html>` when using `next-themes`.

## Review checklist

- [ ] Semantic design tokens used for colors and borders
- [ ] Variants managed with `cva(...)` and merged with `cn(...)`
- [ ] Dark mode supported seamlessly via tokens
- [ ] Responsive layouts mobile-first (`sm:`, `md:`, `lg:`)
- [ ] Accessible focus states (`focus-visible:ring-*`) on interactive elements
- [ ] `suppressHydrationWarning` on root `<html>`

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` for `components/ui/**`, files importing from `@/components/ui` or layout styling |
| Related | `nextjs-architecture`, `nextjs-components`, `common-web-interface-guidelines` |
