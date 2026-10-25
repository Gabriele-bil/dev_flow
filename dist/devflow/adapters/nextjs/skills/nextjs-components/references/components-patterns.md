# Next.js Client Components — Code Patterns

## When to Use `'use client'`

**Correct — boundary at minimum level:**

```tsx
// app/dashboard/page.tsx (Server Component — NO directive)
import { StaticContent } from './_components/static-content'
import { InteractiveCounter } from './_components/interactive-counter'  // has 'use client'

export default async function Page() {
  const data = await fetchData()
  return (
    <>
      <StaticContent data={data} />
      <InteractiveCounter initialCount={data.count} />
    </>
  )
}
```

**Wrong — boundary promoted too high:**

```tsx
// ❌ Avoid
'use client'
export default function Page() { /* entire page becomes client-rendered */ }
```

## Passing Data Server → Client

```tsx
// server (page.tsx)
const user = await getUser()
return <UserCard user={user} />

// client (user-card.tsx)
'use client'
export function UserCard({ user }: { user: User }) {
  const [expanded, setExpanded] = useState(false)
  // ...
}
```

## Context Providers

```tsx
// app/providers.tsx
'use client'
import { ThemeProvider } from 'next-themes'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
      {children}
    </ThemeProvider>
  )
}

// app/layout.tsx (Server Component)
import { Providers } from './providers'
export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

## Next.js Hooks in Client Components

### Suspense boundary requirements by hook

Without `<Suspense>` where required, Next.js degrades the **entire page** to a CSR bailout:

```tsx
// ❌ — CSR bailout: entire page becomes client-rendered
export default function Page() {
  return <SearchBar /> // uses useSearchParams
}

// ✅ — only SearchBar is client-rendered; rest stays server-rendered
import { Suspense } from 'react'

export default function Page() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <SearchBar />
    </Suspense>
  )
}
```

Rule: isolate components using `useSearchParams` into leaf components and wrap them in `<Suspense>`. Apply the same pattern for `usePathname` inside dynamic routes.

## Optimistic Updates

Use `useOptimistic` for reactive UI before server confirmation.

```tsx
'use client'
import { useOptimistic } from 'react'

function LikeButton({ likes, postId }: Props) {
  const [optimisticLikes, addOptimisticLike] = useOptimistic(
    likes,
    (state, newLike) => state + newLike
  )

  async function handleLike() {
    addOptimisticLike(1)
    await likePost(postId)
  }

  return <button onClick={handleLike}>{optimisticLikes} likes</button>
}
```

## React 19 Primitives

### 1. `ref` as a standard prop (No `forwardRef`)

In React 19, `ref` is passed directly as a prop in function components:

```tsx
// components/ui/custom-input.tsx
export function CustomInput({
  ref,
  label,
  ...props
}: {
  ref?: React.Ref<HTMLInputElement>
  label: string
} & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div>
      <label>{label}</label>
      <input ref={ref} {...props} />
    </div>
  )
}
```

### 2. `use()` hook for unwrapping Promise props

In Next.js 16+, route `params` and `searchParams` passed down to Client Components can be unwrapped with `use()`:

```tsx
'use client'
import { use } from 'react'

export function UserHeader({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  return <h1>User: {id}</h1>
}
```

## useFormStatus and useActionState

In React 19, `useActionState` is imported from `'react'`:

```tsx
'use client'
import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { updateUserAction } from '../actions'

function SubmitButton() {
  const { pending } = useFormStatus()
  return <button disabled={pending}>{pending ? 'Saving...' : 'Save'}</button>
}

export function EditUserForm({ initialName }: { initialName: string }) {
  const [state, formAction, isPending] = useActionState(updateUserAction, { error: null })

  return (
    <form action={formAction}>
      <input name="name" defaultValue={initialName} disabled={isPending} />
      {state.error && <p className="text-destructive">{state.error}</p>}
      <SubmitButton />
    </form>
  )
}
```

## RSC Boundaries — Common Server→Client Errors

### 1. Async Client Component — forbidden

Only Server Components can be `async`. An async Client Component fails at runtime or behaves unpredictably:

```tsx
// ❌ — invalid async Client Component
'use client'
export default async function UserProfile() {
  const user = await getUser() // unsupported in Client Component
  return <div>{user.name}</div>
}

// ✅ — fetch in parent Server Component, pass via props
// page.tsx (server)
export default async function Page() {
  const user = await getUser()
  return <UserProfile user={user} />
}
// user-profile.tsx (client)
'use client'
export function UserProfile({ user }: { user: User }) {
  return <div>{user.name}</div>
}
```

### 2. Non-serializable props from Server → Client

Props crossing the Server→Client boundary must be JSON-serializable:

| Type | Supported? | Fix |
| --- | --- | --- |
| `string`, `number`, `boolean` | ✅ | — |
| Plain object/array | ✅ | — |
| Server Action (`'use server'`) | ✅ | — |
| `Date` | ⚠️ silent string | `.toISOString()` → `new Date(str)` in client |
| `Map`, `Set` | ❌ | `Object.fromEntries(map)` / `Array.from(set)` |
| Class instance | ❌ | Pass plain object `{ id, name }` |
| Function (not Server Action) | ❌ | Define inside Client Component |

```tsx
// ❌ — Date object: silently serialized as string, crashes on Date methods
// page.tsx (server)
return <PostCard createdAt={post.createdAt} /> // Date object

// post-card.tsx (client)
export function PostCard({ createdAt }: { createdAt: Date }) {
  return <span>{createdAt.getFullYear()}</span> // Runtime error!
}

// ✅ — serialize on server
// page.tsx
return <PostCard createdAt={post.createdAt.toISOString()} />
// post-card.tsx
export function PostCard({ createdAt }: { createdAt: string }) {
  return <span>{new Date(createdAt).getFullYear()}</span>
}
```

```tsx
// ❌ — function passed as prop (not a Server Action)
const handleClick = () => console.log('clicked')
return <ClientButton onClick={handleClick} />

// ✅ — define handler inside Client Component
'use client'
export function ClientButton() {
  const handleClick = () => console.log('clicked')
  return <button onClick={handleClick}>Click</button>
}
```

## Hydration Errors

Caused by server vs client HTML mismatch. Common causes and fixes:

| Cause | Fix |
| --- | --- |
| `Date.now()` / `Math.random()` during render | Move to `useEffect` or client-initialized state |
| `window` / `localStorage` during render | Check `typeof window !== 'undefined'` or move to `useEffect` |
| Invalid HTML nesting (`<div>` inside `<p>`, nested `<p>`) | Fix HTML structure |
| Browser extensions mutating DOM | Add `suppressHydrationWarning` on `<html>` |
| Theme (light/dark) class applied on server | Add `suppressHydrationWarning` on `<html lang="en">` in root layout |

```tsx
// Fix for dynamic dates — avoid calling Date directly in initial render
'use client'
import { useEffect, useState } from 'react'

function Timestamp() {
  const [time, setTime] = useState<string | null>(null)
  useEffect(() => {
    setTime(new Date().toLocaleTimeString())
  }, [])
  return <span>{time ?? '...'}</span>
}
```

### Unique IDs — `useId`

```tsx
// ❌ — Math.random() differs between server and client
<input id={Math.random().toString()} />

// ✅ — useId (React 18+): deterministic across server/client, SSR-safe
import { useId } from 'react'

function Field() {
  const id = useId()
  return (
    <>
      <label htmlFor={id}>Name</label>
      <input id={id} />
    </>
  )
}
```

Debug: Next.js error overlay shows the exact HTML element causing the mismatch. Look for "Expected server HTML to contain a matching...".
