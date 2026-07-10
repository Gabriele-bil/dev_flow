---
name: nextjs-components
description: 'use client' components — React hooks, interactivity, context providers. Load when touching files with 'use client' directive.
---

# Next.js Client Components

Build interactive UI with `'use client'`. Keep boundary minimal. Server fetches, Client renders.

Full code examples: `references/components-patterns.md`.

## Baseline

Next.js 14+, React 18+, TypeScript strict.

## When to Use `'use client'`

Add directive ONLY if component uses:

- `useState`, `useEffect`, `useRef`, `useCallback`, `useMemo`
- Event handlers: `onClick`, `onChange`, `onSubmit`, etc.
- Browser-only APIs: `window`, `document`, `localStorage`
- Next.js client hooks: `useRouter`, `usePathname`, `useSearchParams`, `useParams`

**Rule:** place `'use client'` at the lowest leaf in the tree — not in parent. One `'use client'` file makes its entire import subtree client-side. Full correct/wrong examples → `references/components-patterns.md`.

## Passing Data Server → Client

- Server Component fetches → passes as props to Client Component
- Never re-fetch in Client Component
- Props must be serializable: no functions, no class instances, no raw `Date` (use ISO string)

Full code → `references/components-patterns.md`.

## Context Providers

Wrap in dedicated Client Component (`providers.tsx`). Import in root `layout.tsx` as single entry point. Full code → `references/components-patterns.md`.

## Next.js Hooks in Client Components

All from `next/navigation` — NOT `next/router` (legacy Pages Router):

- `useRouter()` — programmatic navigation
- `usePathname()` — current pathname
- `useSearchParams()` — query string (**requires Suspense boundary**)
- `useParams()` — dynamic route params

### Suspense boundary — quale hook lo richiede

| Hook | Suspense richiesto |
| --- | --- |
| `useSearchParams()` | Sempre |
| `usePathname()` | Solo in route dinamiche (`[slug]`, `[id]`) |
| `useParams()` | No |
| `useRouter()` | No |

Senza `<Suspense>` dove richiesto, Next.js degrada tutta la pagina a CSR bailout. Isola i componenti con `useSearchParams` in foglie separate e avvolgili con `<Suspense>`. Full code → `references/components-patterns.md`.

## Optimistic Updates

Use `useOptimistic` for reactive UI before server confirmation. Full code → `references/components-patterns.md`.

## useFormStatus and useActionState

- `useFormStatus` — access parent form state (`pending`, `data`, `method`, `action`)
- `useActionState` — manage Server Action state/error with progressive enhancement

Full code → `references/components-patterns.md`.

## RSC Boundaries — Errori comuni Server→Client

1. **Client Component async — vietato.** Solo i Server Component possono essere `async`. Fetch nel Server Component genitore, passa il risultato come prop.
2. **Props non-serializzabili.** Devono essere JSON-serializzabili: `Date` va convertito con `.toISOString()`, `Map`/`Set` convertiti in oggetti/array plain, istanze di classe passate come oggetto plain, funzioni non-Server-Action definite nel client component.

Full code + tabella tipi → `references/components-patterns.md`.

## Hydration Errors

Causati da mismatch HTML server vs client. Cause comuni: `Date.now()`/`Math.random()` nel render, accesso a `window`/`localStorage` nel render, HTML non valido, estensioni browser, theme applicato lato server. Fix: sposta logica in `useEffect`, usa `suppressHydrationWarning` dove appropriato, usa `useId()` invece di `Math.random()` per ID stabili.

Debug: l'overlay di Next.js mostra l'elemento HTML che ha causato il mismatch. Cerca "Expected server HTML to contain a matching...". Full code → `references/components-patterns.md`.

## Anti-patterns

- No `'use client'` on root `layout.tsx`
- No data fetching in Client Components — receive from Server Component via props
- No `'use client'` wrapping entire `page.tsx` — isolate interactive part only
- No importing Server Components inside Client Components — invert: Server wraps Client
- No `useEffect` for initial data fetch — use Server Components
- No `async` Client Components — solo i Server Component possono essere async
- No `Date`, `Map`, `Set`, class instances come props Server→Client — serializza prima
- No `Math.random()` per IDs — usa `useId()`

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
