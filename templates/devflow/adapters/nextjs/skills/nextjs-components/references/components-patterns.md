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
// ❌ Non fare così
'use client'
export default function Page() { /* intera page diventa client */ }
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

### Suspense boundary — quale hook lo richiede

Senza `<Suspense>` dove richiesto, Next.js degrada **tutta la pagina** a CSR bailout:

```tsx
// ❌ — CSR bailout: l'intera pagina diventa client-rendered
export default function Page() {
  return <SearchBar /> // contiene useSearchParams
}

// ✅ — solo SearchBar è client-rendered, il resto rimane server
import { Suspense } from 'react'

export default function Page() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <SearchBar />
    </Suspense>
  )
}
```

Regola: isola i componenti con `useSearchParams` in foglie separate e avvolgili con `<Suspense>`. Per `usePathname` in route dinamiche, stessa cosa.

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

```tsx
'use client'
import { useFormStatus } from 'react-dom'

function SubmitButton() {
  const { pending } = useFormStatus()
  return <button disabled={pending}>{pending ? 'Saving...' : 'Save'}</button>
}
```

## RSC Boundaries — Errori comuni Server→Client

### 1. Client Component async — vietato

Solo i Server Component possono essere `async`. Un Client Component async è un errore silenzioso:

```tsx
// ❌ — async client component: invalido
'use client'
export default async function UserProfile() {
  const user = await getUser() // non funziona in client component
  return <div>{user.name}</div>
}

// ✅ — fetch nel Server Component genitore, passa come prop
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

### 2. Props non-serializzabili da Server → Client

Props che attraversano il confine Server→Client devono essere JSON-serializzabili:

| Tipo | Passa? | Fix |
| --- | --- | --- |
| `string`, `number`, `boolean` | ✅ | — |
| Oggetto/array plain | ✅ | — |
| Server Action (`'use server'`) | ✅ | — |
| `Date` | ⚠️ silenzioso | `.toISOString()` → `new Date(str)` nel client |
| `Map`, `Set` | ❌ | `Object.fromEntries(map)` / `Array.from(set)` |
| Istanza di classe | ❌ | Passa oggetto plain `{ id, name }` |
| Funzione (non Server Action) | ❌ | Definisci nel client component |

```tsx
// ❌ — Date object: diventa stringa silenziosamente, poi crasha
// page.tsx (server)
return <PostCard createdAt={post.createdAt} /> // Date object

// post-card.tsx (client)
export function PostCard({ createdAt }: { createdAt: Date }) {
  return <span>{createdAt.getFullYear()}</span> // Runtime error!
}

// ✅ — serializza sul server
// page.tsx
return <PostCard createdAt={post.createdAt.toISOString()} />
// post-card.tsx
export function PostCard({ createdAt }: { createdAt: string }) {
  return <span>{new Date(createdAt).getFullYear()}</span>
}
```

```tsx
// ❌ — funzione passata come prop (non Server Action)
const handleClick = () => console.log('clicked')
return <ClientButton onClick={handleClick} />

// ✅ — definisci nel client component
'use client'
export function ClientButton() {
  const handleClick = () => console.log('clicked')
  return <button onClick={handleClick}>Click</button>
}
```

## Hydration Errors

Causati da mismatch HTML server vs client. Cause comuni e fix:

| Causa | Fix |
| --- | --- |
| `Date.now()` / `Math.random()` nel render | Sposta in `useEffect` o usa stato inizializzato client-side |
| `window` / `localStorage` nel render | `if (typeof window !== 'undefined')` oppure `useEffect` |
| HTML non valido: `<div>` dentro `<p>`, `<p>` annidati | Correggi struttura HTML |
| Estensioni browser che modificano il DOM | `suppressHydrationWarning` su `<html>` |
| Theme (light/dark) applicato lato server | `suppressHydrationWarning` su `<html lang="en">` nel root layout |

```tsx
// Fix per date dinamiche — non usare nel render direttamente
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

### IDs unici — `useId`

```tsx
// ❌ — Math.random() diverso tra server e client
<input id={Math.random().toString()} />

// ✅ — useId (React 18+): stabile server/client, sicuro per SSR
import { useId } from 'react'

function Field() {
  const id = useId()
  return (
    <>
      <label htmlFor={id}>Nome</label>
      <input id={id} />
    </>
  )
}
```

Debug: l'overlay di Next.js mostra l'elemento HTML che ha causato il mismatch. Cerca "Expected server HTML to contain a matching...".
