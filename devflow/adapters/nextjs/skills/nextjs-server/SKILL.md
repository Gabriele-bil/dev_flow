---
name: nextjs-server
description: Server Components, Server Actions, API Routes, and data fetching with Next.js cache extensions. Load when touching files with 'use server' directive, app/api/** routes, or **/actions.ts files.
---

# Skill: Next.js Server

Use when implementing Server Components with data fetching, Server Actions for mutations, or API Route handlers.

## Objectives

- Enforce server-first data fetching — fetch as close to data source as possible.
- Enforce typed, non-throwing Server Actions with Zod validation.
- Enforce correct cache strategy per data freshness requirement.
- Keep secrets and sensitive logic server-side only.
- Enforce API Routes only for external-facing endpoints; use Server Actions for internal mutations.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## 1) Server Components (default)

No directive needed — absence of `'use client'` = Server Component.

Capabilities:
- `async/await` directly in component body — no `useEffect` needed for data fetching
- Access to filesystem, database, environment secrets — never exposed to client bundle
- Import server-only libraries (Node.js APIs, ORMs, SDKs with secrets)
- Cannot use React hooks (`useState`, `useEffect`, `useRef`, etc.)
- Cannot attach event handlers directly — pass interactive parts to Client Components

```tsx
// app/dashboard/page.tsx — Server Component, no directive
import { Dashboard } from './_components/dashboard'

async function DashboardPage() {
  const data = await fetch('https://api.example.com/metrics', {
    next: { revalidate: 60 },
  })
  const metrics = await data.json()

  return <Dashboard metrics={metrics} />
}

export default DashboardPage
```

Pattern: Server Component fetches data → passes as props to Client Component. Client Component handles interactivity only.

## 2) Data Fetching and Cache Extensions

Next.js extends the native `fetch()` API with cache control options.

### Cache strategies

```ts
// STATIC — cached at build time, never refetched (default when no option given)
const res = await fetch('https://api.example.com/static-data')

// DYNAMIC — always fresh, never cached
const res = await fetch('https://api.example.com/live-data', {
  cache: 'no-store',
})

// ISR — revalidate every N seconds (Incremental Static Regeneration)
const res = await fetch('https://api.example.com/products', {
  next: { revalidate: 3600 },
})

// TAG-BASED — cache indefinitely, invalidate on demand via revalidateTag()
const res = await fetch('https://api.example.com/products', {
  next: { tags: ['products'] },
})
```

### Non-fetch cache (DB queries, ORMs)

Use `unstable_cache` for functions that don't use `fetch()`:

```ts
import { unstable_cache } from 'next/cache'
import { db } from '@/lib/db'

const getCachedUser = unstable_cache(
  async (id: string) => db.user.findUnique({ where: { id } }),
  ['user'],
  { revalidate: 300, tags: ['users'] }
)
```

### Deduplication

`fetch()` calls with identical URL + options are deduplicated automatically within the same request lifecycle. Safe to call the same endpoint in multiple Server Components — only one network request fires.

### Route-level cache control

```ts
// app/dashboard/page.tsx
export const dynamic = 'force-dynamic'    // always dynamic, disables all caching
export const revalidate = 60              // ISR at route level
export const fetchCache = 'force-no-store' // override all fetch defaults
```

## 3) Server Actions

Server Actions are async functions that run on the server, called from client or server.

Add `'use server'` at top of file (preferred) or top of inline async function.

**File-level (preferred):**

```ts
// app/dashboard/actions.ts
'use server'

import { z } from 'zod'
import { revalidatePath, revalidateTag } from 'next/cache'
import { redirect } from 'next/navigation'

const CreateItemSchema = z.object({
  name: z.string().min(1, 'Name required').max(100),
  description: z.string().optional(),
})

export async function createItem(formData: FormData) {
  const parsed = CreateItemSchema.safeParse({
    name: formData.get('name'),
    description: formData.get('description'),
  })

  if (!parsed.success) {
    return { success: false as const, error: parsed.error.flatten().fieldErrors }
  }

  let result
  try {
    result = await db.item.create({ data: parsed.data })
  } catch {
    return { success: false as const, error: 'Failed to create item' }
  }

  revalidatePath('/dashboard')
  return { success: true as const, data: result }
}
```

**Inline (acceptable for single use):**

```tsx
// Inside a Server Component
async function handleSubmit(formData: FormData) {
  'use server'
  // ... action logic
}

return <form action={handleSubmit}>...</form>
```

### Server Action rules

- Validate ALWAYS with Zod before any DB/IO operation.
- Return typed discriminated union: `{ success: true, data }` | `{ success: false, error }`.
- Never `throw` toward client — client cannot catch server exceptions.
- Call `revalidatePath()` or `revalidateTag()` after mutations that affect cached data.
- Use `redirect()` inside Server Actions for post-mutation navigation (throws internally — put after try/catch).

### Using with forms (progressive enhancement)

```tsx
// Client Component — works without JS, enhanced with JS
'use client'
import { useActionState } from 'react'
import { createItem } from '../actions'

export function CreateItemForm() {
  const [state, action, isPending] = useActionState(createItem, null)

  return (
    <form action={action}>
      <input name="name" required />
      {state?.success === false && <p>{String(state.error)}</p>}
      <button type="submit" disabled={isPending}>
        {isPending ? 'Creating...' : 'Create'}
      </button>
    </form>
  )
}
```

## 4) API Routes

File: `app/api/[resource]/route.ts`

Named exports map to HTTP methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`.

```ts
// app/api/products/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const page = Number(searchParams.get('page') ?? '1')

  try {
    const products = await db.product.findMany({
      skip: (page - 1) * 20,
      take: 20,
    })
    return NextResponse.json({ data: products })
  } catch {
    return NextResponse.json({ error: 'Failed to fetch products' }, { status: 500 })
  }
}

const CreateProductSchema = z.object({
  name: z.string().min(1),
  price: z.number().positive(),
})

export async function POST(request: NextRequest) {
  const body = await request.json()
  const parsed = CreateProductSchema.safeParse(body)

  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 422 })
  }

  try {
    const product = await db.product.create({ data: parsed.data })
    return NextResponse.json({ data: product }, { status: 201 })
  } catch {
    return NextResponse.json({ error: 'Failed to create product' }, { status: 500 })
  }
}
```

### Dynamic route segments

```ts
// app/api/products/[id]/route.ts
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const product = await db.product.findUnique({ where: { id: params.id } })
  if (!product) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  return NextResponse.json({ data: product })
}
```

### API Routes vs Server Actions — decision rule

| Use API Route when | Use Server Action when |
|---|---|
| External consumer (mobile app, third-party) | Mutation from within Next.js app |
| Webhook receiver | Form submission |
| OAuth callback | Button click mutation |
| File upload endpoint | Any user-triggered data change |
| Streaming response (SSE, chunked) | Revalidation after save |

## 5) Cookies, Headers, Redirect, notFound

All available in Server Components and Server Actions. Import from `next/headers` or `next/navigation`.

```ts
import { cookies, headers } from 'next/headers'
import { redirect, notFound } from 'next/navigation'

// Read cookie
const sessionCookie = cookies().get('session')?.value

// Set cookie (inside Server Action only)
cookies().set('session', token, { httpOnly: true, secure: true, sameSite: 'lax' })

// Delete cookie (inside Server Action only)
cookies().delete('session')

// Read request header
const userAgent = headers().get('user-agent')
const ip = headers().get('x-forwarded-for')

// Redirect server-side (throws internally — do NOT wrap in try/catch)
redirect('/login')

// Trigger not-found.tsx boundary
notFound()
```

`redirect()` and `notFound()` throw internally — place them AFTER try/catch blocks, never inside them.

## 6) Error Handling

### Server Actions

```ts
export async function updateUser(id: string, formData: FormData) {
  const parsed = UpdateUserSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) {
    return { success: false as const, error: parsed.error.flatten().fieldErrors }
  }

  try {
    const user = await db.user.update({ where: { id }, data: parsed.data })
    revalidatePath('/settings')
    return { success: true as const, data: user }
  } catch {
    return { success: false as const, error: 'Update failed. Try again.' }
  }
}
```

### Server Components

```tsx
// Let errors propagate to error.tsx boundary for unexpected failures
async function ProductPage({ params }: { params: { id: string } }) {
  const product = await db.product.findUnique({ where: { id: params.id } })

  // Expected not-found — use notFound()
  if (!product) notFound()

  // Pass data to component; unexpected DB errors propagate to error.tsx
  return <ProductDetail product={product} />
}
```

### API Routes

```ts
export async function GET(request: NextRequest) {
  try {
    const data = await riskyOperation()
    return NextResponse.json({ data })
  } catch (err) {
    console.error('[GET /api/resource]', err)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
```

## 7) Anti-Patterns

Do NOT:

- Put `process.env` secrets in Client Components or client-importable files — they leak to browser bundle.
- Use `fetch()` in Client Components when data can be fetched server-side and passed as props.
- `throw` from Server Actions toward client — client cannot catch server-side exceptions.
- Skip `revalidatePath()` / `revalidateTag()` after mutations — causes stale UI.
- Wrap `redirect()` or `notFound()` in try/catch — they throw intentionally.
- Use `cache: 'no-store'` on every fetch by default — defeats the performance model.
- Call Server Actions in `useEffect` — use `startTransition` or form `action` instead.
- Put business logic in API Routes when Server Actions would suffice — Server Actions are simpler and type-safe end-to-end.

## I/O Reference

| | |
|---|---|
| Invoked by | `devflow-implement` when `app/api/**`, `**/actions.ts`, `**/action.ts`, or files containing `'use server'` |
| Reads | `@devflow/adapters/nextjs/ADAPTER.md` |
| Related | `nextjs-architecture`, `nextjs-components`, `nextjs-forms` |
