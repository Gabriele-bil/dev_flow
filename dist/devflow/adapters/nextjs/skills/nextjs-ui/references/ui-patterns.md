# Skill: nextjs-ui — project patterns

Loaded on demand from `../SKILL.md`. Full default token set comes from `npx shadcn@latest init`; check current shadcn/ui and Tailwind docs with Context7 before changing `globals.css` structure.

## Tokens — `app/globals.css` (excerpt)

```css
@import "tailwindcss";

@custom-variant dark (&:is(.dark *));

:root {
  --radius: 0.625rem;
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --border: oklch(0.922 0 0);
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --primary: oklch(0.922 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --border: oklch(1 0 0 / 10%);
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-border: var(--border);
  --radius-lg: var(--radius);
  --font-sans: var(--font-geist-sans); /* from next/font variable */
}
```

## Variant component

```tsx
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const cardVariants = cva('rounded-lg border bg-card text-card-foreground', {
  variants: {
    variant: { default: 'border-border', interactive: 'hover:border-primary/50 cursor-pointer' },
    padding: { default: 'p-6', compact: 'p-4' },
  },
  defaultVariants: { variant: 'default', padding: 'default' },
})

export function Card({ className, variant, padding, ...props }: React.ComponentProps<'div'> & VariantProps<typeof cardVariants>) {
  return <div className={cn(cardVariants({ variant, padding }), className)} {...props} />
}
```
