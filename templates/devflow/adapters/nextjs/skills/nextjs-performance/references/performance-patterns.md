# Next.js Performance — project patterns

Loaded on demand from `../SKILL.md`. `next/image` props change across majors: check current docs with Context7 before using a prop not shown here.

## LCP image

```tsx
import Image from 'next/image'
import hero from './hero.jpg'

<div className="relative h-96">
  <Image src={hero} alt="…" fill preload sizes="100vw" className="object-cover" placeholder="blur" />
</div>
```

## Remote image allowlist

```ts
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [new URL('https://images.example.com/uploads/**')],
  },
}
export default nextConfig
```

## Font + Tailwind

```tsx
// app/layout.tsx
import { Geist, Geist_Mono } from 'next/font/google'

const sans = Geist({ subsets: ['latin'], variable: '--font-geist-sans' })
const mono = Geist_Mono({ subsets: ['latin'], variable: '--font-geist-mono' })

// <html lang="en" className={`${sans.variable} ${mono.variable}`} suppressHydrationWarning>
```

```css
/* app/globals.css */
@theme inline {
  --font-sans: var(--font-geist-sans);
  --font-mono: var(--font-geist-mono);
}
```

## Third-party script

```tsx
import Script from 'next/script'

<Script src="https://cdn.example.com/widget.js" strategy="lazyOnload" />
```
