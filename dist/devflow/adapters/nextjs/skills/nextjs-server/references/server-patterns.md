# Next.js Server — Code Patterns

## Server Component with data fetching

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

## Cache strategies

```ts
// UNCACHED (Next.js 15+ default) — always fresh, equivalent to cache: 'no-store'
const res = await fetch('https://api.example.com/live-data')

// STATIC (opt-in) — cached indefinitely at build time
const res = await fetch('https://api.example.com/static-data', {
  cache: 'force-cache',
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

## Non-fetch cache (DB queries, ORMs) — `'use cache'`

`'use cache'` is the modern replacement for `unstable_cache` (Next.js 16+). Requires `cacheComponents: true` in `next.config.ts`.

```ts
// next.config.ts
const nextConfig = { cacheComponents: true }
export default nextConfig
```

```ts
'use cache'
import { cacheLife, cacheTag } from 'next/cache'

export async function getCachedProducts() {
  cacheLife('hours')   // profiles: default | minutes | hours | days | weeks | max
  cacheTag('products') // for targeted invalidation
  return await db.product.findMany()
}
```

Invalidate on mutation:

```ts
import { revalidateTag } from 'next/cache'

// inside a Server Action after DB write:
revalidateTag('products')
```

**Constraint:** `cookies()`, `headers()`, `searchParams` are NOT accessible inside `'use cache'`. Extract outside and pass as arguments:

```ts
// ❌ — runtime error
'use cache'
export async function getData() {
  const store = await cookies() // forbidden inside 'use cache'
}

// ✅ — extract dynamic values outside 'use cache'
async function getCachedUser(userId: string) {
  'use cache'
  cacheLife('minutes')
  return db.user.findUnique({ where: { id: userId } })
}
// call where cookies() is allowed:
const store = await cookies()
const userId = store.get('userId')?.value
const user = await getCachedUser(userId)
```

Migration from `unstable_cache`:

```ts
// BEFORE
const getCachedUser = unstable_cache(
  async (id: string) => db.user.findUnique({ where: { id } }),
  ['user'],
  { revalidate: 300, tags: ['users'] }
)

// AFTER
async function getCachedUser(id: string) {
  'use cache'
  cacheLife('minutes') // 300s ≈ 'minutes'
  cacheTag('users')
  return db.user.findUnique({ where: { id } })
}
```

## Deduplication

`fetch()` calls with identical URL + options are deduplicated automatically within the same request lifecycle. Safe to call the same endpoint in multiple Server Components — only one network request fires.

## Preload pattern — avoiding data waterfalls

Use `React.cache()` to start fetching early and avoid sequential waterfalls:

```ts
// lib/user.ts
import { cache } from 'react'

export const getUser = cache(async (id: string) => {
  return db.user.findUnique({ where: { id } })
})
```

```tsx
// page.tsx — start fetch before rendering child component
import { getUser } from '@/lib/user'

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  // Preload: kick off fetch before UserProfile requests it
  getUser(id) // fire-and-forget — React deduplicates the call

  return <UserProfile userId={id} />
}
```

For multiple parallel fetches:

```tsx
// ✅ — parallel with Promise.all
const [user, posts] = await Promise.all([getUser(id), getUserPosts(id)])
```

## Route-level cache control

```ts
// app/dashboard/page.tsx
export const dynamic = 'force-dynamic'    // always dynamic, disables all caching
export const revalidate = 60              // ISR at route level
export const fetchCache = 'force-no-store' // override all fetch defaults
```

## Server Actions

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

## API Routes

File: `app/api/[resource]/route.ts`. Named exports map to HTTP methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`.

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
// app/api/products/[id]/route.ts — params is async in Next.js 16+
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const product = await db.product.findUnique({ where: { id } })
  if (!product) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  return NextResponse.json({ data: product })
}
```

## Cookies, Headers, Redirect, notFound

All available in Server Components and Server Actions. Import from `next/headers` or `next/navigation`.

```ts
import { cookies, headers } from 'next/headers'
import { redirect, notFound } from 'next/navigation'

// Read cookie — await required in Next.js 16+
const cookieStore = await cookies()
const sessionCookie = cookieStore.get('session')?.value

// Set / delete cookie (inside Server Action only)
const cookieStore = await cookies()
cookieStore.set('session', token, { httpOnly: true, secure: true, sameSite: 'lax' })
cookieStore.delete('session')

// Read request headers — await required in Next.js 16+
const headersList = await headers()
const userAgent = headersList.get('user-agent')
const ip = headersList.get('x-forwarded-for')

// Redirect server-side (throws internally — do NOT wrap in try/catch)
redirect('/login')

// Trigger not-found.tsx boundary
notFound()
```

> **Next.js 16+ (and 15) breaking change:** `cookies()`, `headers()`, and `params` return a Promise. Always `await` before calling `.get()`, `.set()`, `.delete()`. Codemod: `npx @next/codemod@latest upgrade .`

## Error Handling

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

### `unstable_rethrow` — avoid swallowing Next.js internal errors

`redirect()`, `notFound()`, and `unauthorized()` throw internal control-flow errors. A generic `try/catch` catches and suppresses them. Call `unstable_rethrow` first inside `catch`:

```ts
import { unstable_rethrow } from 'next/navigation'

async function maybeRedirect() {
  try {
    await doSomething()
    redirect('/dashboard')
  } catch (err) {
    unstable_rethrow(err) // rethrows Next.js internal errors (redirect, notFound, etc.)
    return { success: false, error: 'Operation failed' }
  }
}
```

### Server Components

```tsx
// Let errors propagate to error.tsx boundary for unexpected failures
async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await db.product.findUnique({ where: { id } })

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

## `after()` — post-response work

Run secondary side effects (analytics, logging, cleanup) after the response finishes streaming without blocking response time:

```ts
import { after } from 'next/server'

// Inside a Server Action
export async function createOrder(formData: FormData) {
  const order = await db.order.create({ data: parseOrder(formData) })

  after(async () => {
    await logAnalytics({ event: 'order_created', orderId: order.id })
    await sendConfirmationEmail(order)
  })

  return { success: true, orderId: order.id }
}

// Inside a Route Handler
export async function POST(request: Request) {
  const data = await processRequest(request)

  after(async () => {
    await logToDataWarehouse(data)
  })

  return Response.json({ success: true })
}
```

`after()` runs to completion even if the client disconnects.

## Debug — MCP Endpoint

Next.js exposes `/_next/mcp` in development for AI-assisted debugging:

- **Next.js 16+**: enabled by default, use `next-devtools-mcp`
- **Next.js < 16**: set `experimental.mcpServer: true` in `next.config.ts`

```bash
# Check active dev server port (do not assume 3000)
curl -X POST http://localhost:<PORT>/_next/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_errors","arguments":{}}}'
```

Available MCP tools:

| Tool | Output |
| --- | --- |
| `get_errors` | Current build + runtime errors with source maps |
| `get_routes` | All routes discovered by filesystem scan |
| `get_project_metadata` | Project path and dev server URL |
| `get_logs` | Path to `<distDir>/logs/next-development.log` |
| `get_server_action_by_id` | Locates a Server Action by `actionId` |

Rebuild specific routes only (Next.js 16+):

```bash
next build --debug-build-paths "/dashboard,/product/[id]"
```

## API Routes vs Server Actions — decision rule

| Use API Route when | Use Server Action when |
| --- | --- |
| External consumer (mobile app, third-party) | Mutation from within Next.js app |
| Webhook receiver | Form submission |
| OAuth callback | Button click mutation |
| File upload endpoint | Any user-triggered data change |
| Streaming response (SSE, chunked) | Revalidation after save |

Full code: GET/POST handlers with Zod validation, dynamic route segments (`params` must be awaited: `const { resource } = await params`) → `references/server-patterns.md`.

## 5) Async Request APIs (Cookies, Headers, Params)

> **Next.js 16+ (and 15) breaking change:** `cookies()`, `headers()`, `params`, and `searchParams` return Promises. You MUST `await` them in Server Components, Route Handlers, and Server Actions.
>
> - Server Component: `export default async function Page({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ [key: string]: string }> }) { const { id } = await params; ... }`
> - Cookies: `const cookieStore = await cookies(); const token = cookieStore.get('token');`
> - Headers: `const headersList = await headers();`
>
> Codemod: `npx @next/codemod@latest upgrade .`

`redirect()` and `notFound()` throw internally — place them AFTER try/catch blocks, never inside them.

Full code → `references/server-patterns.md`.

## 6) Error Handling

Server Actions return typed error objects, never throw toward client. Server Components let unexpected errors propagate to `error.tsx`; use `notFound()` for expected not-found cases. API Routes catch and return `NextResponse.json({ error }, { status: 500 })`.

`redirect()`/`notFound()`/`unauthorized()` throw internally — a generic try/catch swallows them. Use `unstable_rethrow(err)` from `next/navigation` to re-throw Next.js internal errors before handling real errors.

Full code → `references/server-patterns.md`.

## 7) `after()` — post-response code

Run secondary work (analytics, logging, cleanup) after the response finishes streaming, without blocking response time. Guaranteed to complete even if client disconnects. Full code → `references/server-patterns.md`.

## 8) Runtime Selection

Default runtime = **Node.js**. Do not change unless necessary (`export const runtime = 'edge'`).

| Use Node.js (default) when | Use Edge when |
| --- | --- |
| DB access (Prisma, Drizzle, pg) | Proxy / Routing (globally distributed) |
| File system access | Request geolocation / A-B testing |
| Node.js-only packages | Ultra-low latency, no Node.js APIs needed |
| Auth, cron, heavy computation | Simple request rewriting |

Edge runtime limitations: no Node.js APIs, no native addons, no filesystem, smaller bundle budget.

## Debug — MCP Endpoint

Next.js exposes `/_next/mcp` in development for AI-assisted debugging (Next.js 16+ enabled by default; < 16 needs `experimental.mcpServer: true`). Tools: `get_errors`, `get_routes`, `get_project_metadata`, `get_logs`, `get_server_action_by_id`. Full curl example and tool table → `references/server-patterns.md`.
