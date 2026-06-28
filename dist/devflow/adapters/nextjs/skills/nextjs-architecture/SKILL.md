---
name: nextjs-architecture
description: App Router folders, route segments, layout nesting, server/client boundary. Load when creating routes, layouts, or reorganizing feature folders.
---

# Skill: Next.js Architecture

Use when creating new routes, layouts, reorganizing feature folders, or reviewing architectural consistency.

## Objectives

- Keep App Router structure deterministic and reviewable.
- Enforce route group separation (auth vs no-auth layout).
- Enforce colocation: route-specific code lives inside its route folder.
- Keep server/client boundary as deep in the tree as possible.
- Enforce one-way dependency flow: page → components → actions/services → external.

## 1) Baseline (mandatory)

- Next.js 15+ App Router. No Pages Router.
- TypeScript strict mode (`"strict": true` in `tsconfig.json`).
- Default component = Server Component. No directive needed.
- `'use client'` only when absolutely required (see section 5).
- Output: caveman-style, no hedging, precise.

## 2) Route Segment Files

Each route folder can contain these reserved filenames:

| File | Purpose |
| --- | --- |
| `page.tsx` | Route leaf — makes URL publicly accessible |
| `layout.tsx` | Persistent wrapper — wraps page and children, does NOT re-mount on navigation |
| `loading.tsx` | Automatic Suspense boundary — shows while page/children stream |
| `error.tsx` | Error boundary with `reset` prop — catches runtime errors in subtree |
| `global-error.tsx` | Error boundary for root layout — must include `<html>` and `<body>` tags |
| `not-found.tsx` | Renders when `notFound()` is called within subtree |
| `template.tsx` | Like layout but re-mounts on every navigation — use when fresh state per nav is required |
| `default.tsx` | Fallback for parallel route slots — return `null` when slot is inactive |
| `route.ts` | API Route handler — no UI, named exports only (`GET`, `POST`, etc.) |
| `opengraph-image.tsx` | Auto-generated OG image for route — runs on Edge runtime |
| `twitter-image.tsx` | Auto-generated Twitter card image — runs on Edge runtime |

Rules:

- `layout.tsx` receives `children: React.ReactNode` — never fetch data that changes per-page inside root layout.
- `error.tsx` MUST be a Client Component (`'use client'`). Receives `error` and `reset` props.
- `global-error.tsx` MUST be a Client Component AND include `<html><body>` tags — replaces root layout on error.
- `loading.tsx` wraps `page.tsx` in `<Suspense>` automatically — no manual wrapping needed.
- `template.tsx` use case: tabs with per-tab animation, forms that must reset, auth-check per navigation.

## 3) Route Groups and Private Folders

**Route groups** — parentheses: `(group-name)/`

- Organize routes without adding URL segment.
- Each group can have its own `layout.tsx`.
- Use to split authenticated vs public layout.

**Private folders** — underscore: `_folder-name/`

- Excluded from routing system entirely.
- Use for components, hooks, lib co-located with a route but not routes themselves.

## 4) Recommended App Structure

```text
app/
├── (marketing)/               # public pages, no auth required
│   ├── layout.tsx             # marketing layout (nav, footer)
│   ├── page.tsx               # home page "/"
│   ├── about/
│   │   └── page.tsx
│   └── blog/
│       ├── page.tsx           # blog index
│       └── [slug]/
│           └── page.tsx       # blog post
├── (app)/                     # authenticated area
│   ├── layout.tsx             # app layout (sidebar, header) — auth check here
│   ├── dashboard/
│   │   ├── page.tsx
│   │   ├── loading.tsx        # shown while dashboard data streams
│   │   ├── error.tsx          # catches dashboard errors
│   │   └── _components/       # dashboard-only components (not routable)
│   ├── settings/
│   │   ├── page.tsx
│   │   └── _components/
│   └── [feature]/
│       ├── page.tsx
│       ├── loading.tsx
│       ├── error.tsx
│       ├── _components/
│       └── actions.ts         # Server Actions for this route
├── api/                       # API Routes
│   └── [resource]/
│       └── route.ts
├── globals.css
└── layout.tsx                 # Root layout — html, body, global providers ONLY

lib/                           # Shared utilities — no UI, no React
├── utils.ts
├── validations.ts
└── [domain]/
    └── *.ts

components/                    # Shared UI components
├── ui/                        # shadcn/ui primitives (Button, Input, etc.)
└── [feature]/                 # Feature-specific shared components

middleware.ts                  # At project root — NOT inside app/
```

## 5) Server/Client Boundary Rules

**Server Component = default.** Absence of directive = server.

Promote to Client Component ONLY when file requires:

- `useState`, `useReducer`, `useContext`
- `useEffect`, `useRef`, `useLayoutEffect`
- Event handlers attached to DOM elements (`onClick`, `onChange`, etc.)
- Browser-only APIs (`window`, `localStorage`, `navigator`, etc.)
- Third-party libraries that rely on the above

Rules:

- Put `'use client'` as deep in the tree as possible — not on parent wrappers.
- Never put `'use client'` on root `layout.tsx` — renders entire app client-side.
- Context providers MUST be in a separate `providers.tsx` with `'use client'`. Import in root layout.
- Pass server data down as props to client components — do not re-fetch in client.

```tsx
// providers.tsx — wrap all context providers here
'use client'
import { ThemeProvider } from 'next-themes'
import { SessionProvider } from 'next-auth/react'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SessionProvider>
      <ThemeProvider attribute="class" defaultTheme="system">
        {children}
      </ThemeProvider>
    </SessionProvider>
  )
}

// app/layout.tsx — stays Server Component
import { Providers } from './_components/providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

## 6) Dependency Flow

```text
page.tsx
  └── _components/*.tsx
        └── actions.ts / lib/[domain]/service.ts
              └── External APIs / DB / FS
```

- Pages orchestrate: import components, call actions, pass data down.
- Components render: receive data via props, emit events via callbacks.
- Actions mutate: validate, persist, revalidate cache.
- Services fetch: HTTP, DB queries, external integrations.
- No component calls external API directly.
- No page contains raw fetch logic — delegate to service or action.

## 7) Middleware / Proxy

File at **project root** (sibling to `app/`, `lib/`, `components/`). Never inside `app/`.

Next.js 16+ renamed `middleware.ts` → `proxy.ts` (codemod: `npx @next/codemod@latest upgrade`):

| Version | File | Export | Matcher config |
| --- | --- | --- | --- |
| 14–15 | `middleware.ts` | `middleware()` | `config` |
| 16+ | `proxy.ts` | `proxy()` | `proxyConfig` |

```ts
// middleware.ts (Next.js 14-15)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('session')?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/app/:path*', '/dashboard/:path*'],
}
```

```ts
// proxy.ts (Next.js 16+)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  const token = request.cookies.get('session')?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const proxyConfig = {
  matcher: ['/app/:path*', '/dashboard/:path*'],
}
```

## 8) Naming Conventions

| Target | Convention | Example |
| --- | --- | --- |
| Folders / files | kebab-case | `user-profile/`, `user-card.tsx` |
| React components | PascalCase (function name) | `export function UserCard()` |
| Utility functions | camelCase | `formatDate()`, `parseSlug()` |
| Server Actions files | `actions.ts` | `app/dashboard/actions.ts` |
| API route handlers | `route.ts` | `app/api/users/route.ts` |
| Private folders | `_` prefix | `_components/`, `_lib/`, `_hooks/` |
| Route groups | `()` wrapping | `(marketing)/`, `(app)/` |
| Dynamic segments | `[]` wrapping | `[slug]/`, `[id]/` |
| Catch-all segments | `[...]` wrapping | `[...slug]/` |

## 9) Parallel Routes e Intercepting Routes

### Parallel Routes — slot `@name`

Rendono più pagine nello stesso layout simultaneamente (es. modale su sfondo):

```text
app/
  @modal/                    # slot parallelo
    (.)product/[id]/         # intercepting route — cattura /product/[id]
      page.tsx               # contenuto modale
  product/
    [id]/
      page.tsx               # pagina completa (navigazione diretta / refresh)
  layout.tsx                 # riceve { children, modal }
  default.tsx                # ritorna null — slot fallback quando @modal inattivo
```

```tsx
// app/layout.tsx
export default function RootLayout({
  children,
  modal,
}: {
  children: React.ReactNode
  modal: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        {children}
        {modal}
      </body>
    </html>
  )
}
```

```tsx
// app/default.tsx — obbligatorio per evitare 404 al refresh
export default function Default() {
  return null
}
```

```tsx
// app/@modal/(.)product/[id]/page.tsx — modale
'use client'
import { useRouter } from 'next/navigation'

export default async function ProductModal({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)

  return (
    <dialog open>
      <button onClick={() => useRouter().back()}>Chiudi</button>
      <ProductDetail product={product} />
    </dialog>
  )
}
```

**Regole:**

- `default.tsx` obbligatorio in ogni slot parallelo — evita 404 al refresh diretto.
- Chiudi il modale con `router.back()`, non `router.push('/')`.
- Notazione intercepting: `(.)` = stesso livello, `(..)` = un livello su, `(...)` = root.

## 10) Architecture Review Checklist

Before merge, confirm:

- [ ] Route groups used to separate authenticated/public layout (`(app)/` vs `(marketing)/`)
- [ ] Colocation respected — route-specific components in `_components/` inside route folder
- [ ] Private folders (`_`) used for non-route code inside route directories
- [ ] Root `layout.tsx` contains only `html`, `body`, and global providers — no business logic
- [ ] `loading.tsx` present for routes with async data fetching
- [ ] `error.tsx` present for routes with operations that can fail at runtime
- [ ] `'use client'` only where required, placed as deep in tree as possible
- [ ] Dependency flow respected: page → components → actions/services → external

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `app/**/page.tsx`, `app/**/layout.tsx`, `app/**/template.tsx`, `app/**/loading.tsx`, `app/**/error.tsx`, `app/**/not-found.tsx` |
| Reads | `@devflow/adapters/nextjs/ADAPTER.md` |
| Related | `nextjs-server`, `nextjs-components` |
