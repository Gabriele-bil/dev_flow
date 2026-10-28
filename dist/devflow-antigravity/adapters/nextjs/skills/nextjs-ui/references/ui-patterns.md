# Skill: nextjs-ui — reference detail

Loaded on demand from `../SKILL.md`.

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
