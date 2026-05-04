---
name: nextjs-components
description: Client Components with 'use client' directive, React hooks, interactivity patterns, and context providers. Load when touching files containing 'use client' directive.
---

# Next.js Client Components

Build interactive UI with `'use client'`. Keep boundary minimal. Server fetches, Client renders.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Baseline

Next.js 14+, React 18+, TypeScript strict.

## When to Use `'use client'`

Add directive ONLY if component uses:
- `useState`, `useEffect`, `useRef`, `useCallback`, `useMemo`
- Event handlers: `onClick`, `onChange`, `onSubmit`, etc.
- Browser-only APIs: `window`, `document`, `localStorage`
- Next.js client hooks: `useRouter`, `usePathname`, `useSearchParams`, `useParams`

**Rule:** place `'use client'` at the lowest leaf in the tree — not in parent. One `'use client'` file makes its entire import subtree client-side.

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
// ❌ Non fare così
'use client'
export default function Page() { /* intera page diventa client */ }
```

## Passing Data Server → Client

- Server Component fetches → passes as props to Client Component
- Never re-fetch in Client Component
- Props must be serializable: no functions, no class instances, no raw `Date` (use ISO string)

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

Wrap in dedicated Client Component (`providers.tsx`). Import in root `layout.tsx` as single entry point.

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

All from `next/navigation` — NOT `next/router` (legacy Pages Router):

- `useRouter()` — programmatic navigation
- `usePathname()` — current pathname
- `useSearchParams()` — query string (wrap in `<Suspense>` when required)
- `useParams()` — dynamic route params

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

## useFormStatus and useActionState

- `useFormStatus` — access parent form state (`pending`, `data`, `method`, `action`)
- `useActionState` — manage Server Action state/error with progressive enhancement

```tsx
'use client'
import { useFormStatus } from 'react-dom'

function SubmitButton() {
  const { pending } = useFormStatus()
  return <button disabled={pending}>{pending ? 'Saving...' : 'Save'}</button>
}
```

## Anti-patterns

- No `'use client'` on root `layout.tsx`
- No data fetching in Client Components — receive from Server Component via props
- No `'use client'` wrapping entire `page.tsx` — isolate interactive part only
- No importing Server Components inside Client Components — invert: Server wraps Client
- No `useEffect` for initial data fetch — use Server Components

## Review Checklist

- [ ] `'use client'` only where necessary
- [ ] Boundary at lowest possible level in tree
- [ ] Server data passed as props, not re-fetched
- [ ] Context providers centralized in `providers.tsx`
- [ ] No `useEffect` for initial data fetch

## I/O Reference

|            |                                                                        |
| ---------- | ---------------------------------------------------------------------- |
| Invoked by | `devflow-implement` for files containing `'use client'` directive      |
| Related    | `nextjs-architecture`, `nextjs-server`, `nextjs-state`, `nextjs-forms` |
