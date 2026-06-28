---
name: nextjs-metadata
description: Metadata API, SEO, OG images, file-based metadata. Load when touching generateMetadata, opengraph-image, or head files.
---

# Skill: Next.js Metadata

Use when implementing SEO metadata, Open Graph images, or file-based metadata conventions.

## 1) Static Metadata

Export `metadata` object from `page.tsx` or `layout.tsx`:

```tsx
// app/page.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Home',
  description: 'Welcome to our site',
  openGraph: {
    title: 'Home',
    description: 'Welcome to our site',
    url: 'https://example.com',
    siteName: 'My App',
    images: [{ url: 'https://example.com/og.png', width: 1200, height: 630 }],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Home',
    description: 'Welcome to our site',
    images: ['https://example.com/og.png'],
  },
}
```

## 2) Dynamic Metadata — `generateMetadata`

Use for pages where title/description depend on fetched data. In Next.js 15+, `params` is async:

```tsx
// app/product/[id]/page.tsx
import type { Metadata } from 'next'

type Props = { params: Promise<{ id: string }> }

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params
  const product = await getProduct(id) // reuses cached fetch — no double request

  if (!product) {
    return { title: 'Product not found' }
  }

  return {
    title: product.name,
    description: product.description,
    openGraph: {
      title: product.name,
      images: [{ url: product.imageUrl, width: 1200, height: 630 }],
    },
  }
}

export default async function ProductPage({ params }: Props) {
  const { id } = await params
  const product = await getProduct(id) // same cached fetch — no duplicate network call
  // ...
}
```

**Rule:** fetch inside `generateMetadata` is automatically deduped with the same fetch in `page.tsx` if using the same cache key. Use `cache()` from React for non-fetch functions:

```ts
import { cache } from 'react'

const getProduct = cache(async (id: string) => {
  return db.product.findUnique({ where: { id } })
})
```

## 3) OG Image Generation — `next/og`

### File-based (simpler)

Create `opengraph-image.tsx` alongside `page.tsx`. Next.js auto-generates the route and adds the meta tag:

```tsx
// app/product/[id]/opengraph-image.tsx
import { ImageResponse } from 'next/og'

export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

type Props = { params: Promise<{ id: string }> }

export default async function Image({ params }: Props) {
  const { id } = await params
  const product = await getProduct(id)

  return new ImageResponse(
    (
      <div
        style={{
          background: 'white',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 48,
          fontWeight: 'bold',
        }}
      >
        {product.name}
      </div>
    ),
    { ...size }
  )
}
```

### Route-based (more control)

```tsx
// app/api/og/route.tsx
import { ImageResponse } from 'next/og'
import { NextRequest } from 'next/server'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const title = searchParams.get('title') ?? 'Default'

  return new ImageResponse(
    (
      <div style={{ display: 'flex', fontSize: 60 }}>
        {title}
      </div>
    ),
    { width: 1200, height: 630 }
  )
}
```

## 4) Metadata Templates — `title.template`

Set in root layout to avoid repeating site name:

```tsx
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    template: '%s | My App',
    default: 'My App',
  },
  description: 'My App description',
}

// app/dashboard/page.tsx — renders "Dashboard | My App"
export const metadata: Metadata = {
  title: 'Dashboard',
}
```

## 5) File-Based Metadata Conventions

Place these files in `app/` (or route folders) — no code needed:

| File | Output |
|---|---|
| `favicon.ico` | `<link rel="icon">` |
| `icon.png` / `icon.svg` | `<link rel="icon">` |
| `apple-icon.png` | `<link rel="apple-touch-icon">` |
| `opengraph-image.png` | `<meta property="og:image">` |
| `twitter-image.png` | `<meta name="twitter:image">` |
| `robots.txt` | `/robots.txt` |
| `sitemap.xml` | `/sitemap.xml` |

Dynamic versions use `.ts` extension:

```ts
// app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/', disallow: '/private/' },
    sitemap: 'https://example.com/sitemap.xml',
  }
}
```

```ts
// app/sitemap.ts
import type { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const products = await db.product.findMany({ select: { id: true, updatedAt: true } })

  return [
    { url: 'https://example.com', lastModified: new Date() },
    ...products.map((p) => ({
      url: `https://example.com/product/${p.id}`,
      lastModified: p.updatedAt,
    })),
  ]
}
```

## 6) Viewport — `generateViewport`

Separa viewport da metadata per migliore tree-shaking. Esporta `generateViewport` (dinamico) o `viewport` (statico):

```tsx
import type { Viewport } from 'next'

// Statico
export const viewport: Viewport = {
  themeColor: '#ffffff',
  width: 'device-width',
  initialScale: 1,
}

// Dinamico (es. basato su params)
export async function generateViewport({ params }: Props): Promise<Viewport> {
  const { id } = await params
  const product = await getProduct(id)
  return { themeColor: product.brandColor }
}
```

## 7) Sitemap multipla — `generateSitemaps`

Per siti con molte pagine (>50k URL), dividi in più sitemap:

```ts
// app/sitemap.ts
import type { MetadataRoute } from 'next'

export async function generateSitemaps() {
  // Ritorna un array di oggetti con id — Next.js genera /sitemap/0.xml, /sitemap/1.xml, ecc.
  const count = await db.product.count()
  return Array.from({ length: Math.ceil(count / 50000) }, (_, i) => ({ id: i }))
}

export default async function sitemap({ id }: { id: number }): Promise<MetadataRoute.Sitemap> {
  const products = await db.product.findMany({
    skip: id * 50000,
    take: 50000,
    select: { id: true, updatedAt: true },
  })
  return products.map((p) => ({
    url: `https://example.com/product/${p.id}`,
    lastModified: p.updatedAt,
  }))
}
```

## 8) OG Images multiple — `generateImageMetadata`

Genera più varianti di OG image per una stessa route (es. dark/light, locale):

```tsx
// app/product/[id]/opengraph-image.tsx
import { ImageResponse } from 'next/og'

export async function generateImageMetadata({ params }: Props) {
  const { id } = await params
  return [
    { id: 'light', alt: 'Product light', contentType: 'image/png', size: { width: 1200, height: 630 } },
    { id: 'dark', alt: 'Product dark', contentType: 'image/png', size: { width: 1200, height: 630 } },
  ]
}

export default async function Image({ params, id }: { params: Promise<{ id: string }>, id: string }) {
  const { id: productId } = await params
  const product = await getProduct(productId)
  const isDark = id === 'dark'

  return new ImageResponse(
    <div style={{ background: isDark ? '#000' : '#fff', color: isDark ? '#fff' : '#000' }}>
      {product.name}
    </div>
  )
}
```

## 9) Anti-Patterns

- Do NOT manually add `<meta>` tags in components — use the Metadata API.
- Do NOT fetch the same data twice in `generateMetadata` and `page.tsx` — use `cache()` for dedup.
- Do NOT put `metadata` export in Client Components — only Server Components export metadata.
- Do NOT forget `title.template` in root layout — causes repeated site name in every page title.
- Do NOT mix `viewport` inside `metadata` export — usa `generateViewport` separato.

## I/O Reference

| | |
|---|---|
| Invoked by | `devflow-implement` when touching `generateMetadata`, `generateViewport`, `generateSitemaps`, `generateImageMetadata`, `opengraph-image`, `robots.ts`, `sitemap.ts`, or metadata-related config |
| Related | `nextjs-server`, `nextjs-architecture` |
