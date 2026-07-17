# Next.js adapter — Plan step

Loaded by `devflow-plan` together with the adapter core (`ADAPTER.md`).

## Plan: extra sections and templates

Include these in `plan.md` when applicable (after core sections from `devflow-plan`).

### Server/Client boundary table

For each component or route in scope, declare boundary explicitly:

| Component / Route | Boundary | Reason |
| --- | --- | --- |
| `app/**/page.tsx` | Server | No interactivity; fetch data server-side |
| `**/form.tsx` | Client (`'use client'`) | Requires `useForm`, event handlers |
| `**/store.ts` | Client | Zustand runs client-side only |

Minimize `'use client'` promotion. Boundary must be justified per file.

### Route segment map

Document `app/` tree with layout ownership and route groups:

```text
app/
├── layout.tsx          # root layout (font, providers)
├── (marketing)/        # route group — no shared layout segment
│   └── page.tsx
├── (app)/              # route group — authenticated shell
│   ├── layout.tsx      # sidebar, nav
│   └── dashboard/
│       └── page.tsx
└── api/
    └── webhooks/
        └── route.ts
```

List shared layouts and what they provide (auth guard, theme, global nav).

### Zustand store plan

For each store introduced or modified:

| Store | State shape | Invalidation trigger |
| --- | --- | --- |
| `useCartStore` | `items[]`, `total` | Add/remove item, checkout success |
| `useUIStore` | `sidebarOpen`, `theme` | User toggle action |

Rules:

- No server-fetched data in Zustand (use React cache / `fetch` with Next.js caching).
- Stores persist client-side only; rehydrate from URL params or server props when needed.

### Server Actions vs API Routes decision

Per endpoint, choose explicitly:

| Endpoint | Choice | Reason |
| --- | --- | --- |
| Submit contact form | Server Action | Mutation internal to app; no external consumer |
| Stripe webhook receiver | API Route | External POST from third-party service |
| Revalidate cache on CMS update | API Route | Called by external webhook |
| Update user profile | Server Action | Form-bound mutation, internal |

Rule: internal mutation bound to a form or button → Server Action. External consumer, webhook, or REST endpoint → API Route.

### Data model (omit if no new persistent entities)

When `devflow-plan` Step 4c generates `data-model.md`: use it as the single source of truth for entity definitions before writing any Zod schema, TypeScript type, or DTO file. Fields in `data-model.md` map to Zod schemas and TypeScript types — do not invent property names or types that diverge from the data model.
