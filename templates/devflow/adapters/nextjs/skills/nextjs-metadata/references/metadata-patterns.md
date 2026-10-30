# Next.js Metadata — project patterns

Loaded on demand from `../SKILL.md`. Metadata fields evolve: check current docs with Context7 before adding a field not shown here.

## Root layout defaults

```tsx
// app/layout.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL('https://example.com'),
  title: { template: '%s | My App', default: 'My App' },
  description: 'My App description',
  openGraph: { siteName: 'My App', type: 'website' },
}
```

## Data-driven page

```tsx
// app/product/[id]/page.tsx
import type { Metadata } from 'next'
import { getProduct } from '@/lib/products/queries' // React.cache() or 'use cache'

type Props = { params: Promise<{ id: string }> }

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params
  const product = await getProduct(id)
  if (!product) return { title: 'Product not found' }
  return { title: product.name, description: product.summary }
}
```

## File-based OG image

```tsx
// app/product/[id]/opengraph-image.tsx
import { ImageResponse } from 'next/og'

export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)
  return new ImageResponse(<div style={{ display: 'flex', fontSize: 64 }}>{product?.name}</div>, size)
}
```

`ImageResponse` JSX supports flexbox subset only — inline `style` required here (exception to `nextjs-ui` no-inline-style rule).

## Sitemap

```ts
// app/sitemap.ts
import type { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const products = await listProductSlugs()
  return [
    { url: 'https://example.com', lastModified: new Date() },
    ...products.map((p) => ({ url: `https://example.com/product/${p.id}`, lastModified: p.updatedAt })),
  ]
}
```
