# Next.js Server — project patterns

Loaded on demand from `../SKILL.md`. One example per decision. Caching API changes often: check current docs with Context7 before writing `'use cache'` / `cacheLife` / `cacheTag` code.

## Cached data function

```ts
// lib/products/queries.ts
import { cacheLife, cacheTag } from 'next/cache'

export async function getProducts() {
  'use cache'
  cacheLife('hours')
  cacheTag('products')
  return db.product.findMany()
}
```

Dynamic input (`cookies()`, `headers()`, `searchParams`) read outside, passed as argument — it becomes part of the cache key.

## Uncached data streams behind Suspense

```tsx
// app/(app)/dashboard/page.tsx
import { Suspense } from 'react'

export default function Page() {
  return (
    <>
      <h1>Dashboard</h1>
      <Suspense fallback={<MetricsSkeleton />}>
        <LiveMetrics /> {/* awaits cookies() + uncached fetch */}
      </Suspense>
    </>
  )
}
```

## Server Action — validate, mutate, invalidate, typed result

```ts
// app/(app)/items/actions.ts
'use server'

import { z } from 'zod'
import { updateTag } from 'next/cache'
import { itemSchema } from './_lib/schema'

export type CreateItemState =
  | { success: true; data: Item }
  | { success: false; error: string | Record<string, string[] | undefined> }
  | null

export async function createItem(_prev: CreateItemState, formData: FormData): Promise<CreateItemState> {
  const parsed = itemSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) {
    return { success: false, error: z.flattenError(parsed.error).fieldErrors }
  }

  try {
    const data = await db.item.create({ data: parsed.data })
    updateTag('items') // author sees new item immediately
    return { success: true, data }
  } catch {
    return { success: false, error: 'Failed to create item' }
  }
}
```

Client side: `useActionState(createItem, null)` — state type `CreateItemState` includes `null`, so the initial value type-checks (`nextjs-forms` reference shows full form).

## Rethrow framework errors inside catch

```ts
import { redirect, unstable_rethrow } from 'next/navigation'

try {
  await doSomething()
  redirect('/dashboard')
} catch (err) {
  unstable_rethrow(err) // redirect / notFound / request-time API errors pass through
  return { success: false, error: 'Operation failed' }
}
```

## Route Handler — one status for invalid body

```ts
// app/api/products/route.ts
import { NextResponse, type NextRequest } from 'next/server'
import { z } from 'zod'
import { productSchema } from '@/lib/products/schema'

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null)
  const parsed = productSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: z.flattenError(parsed.error) }, { status: 400 })
  }
  try {
    const product = await db.product.create({ data: parsed.data })
    return NextResponse.json({ data: product }, { status: 201 })
  } catch (err) {
    console.error('[POST /api/products]', err)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
```

Dynamic segment: second arg `{ params }: { params: Promise<{ id: string }> }`, then `await params`.

## Server Action vs Route Handler

| Route Handler | Server Action |
| --- | --- |
| Webhook, OAuth callback | Form submit, button mutation |
| Mobile / third-party consumer | Any internal data change |
| Streaming (SSE), file download | Mutation + cache invalidation |
