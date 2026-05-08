# Next.js adapter (DevFlow)

Single source of truth for Next.js behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then follow sections below.

Baseline: **Next.js 15+ App Router · Zustand · Tailwind CSS + shadcn/ui · Server Actions + API Routes · Jest + RTL**. Keep output token-lean and imperative.

## Technology skills (load by feature type)

| When | Load |
|------|------|
| App structure, folder layout, route segments, boundaries, parallel/intercepting routes | `@devflow/adapters/nextjs/skills/nextjs-architecture/SKILL.md` |
| Server Components, Server Actions, API Routes, data fetching, `'use cache'` | `@devflow/adapters/nextjs/skills/nextjs-server/SKILL.md` |
| Client Components, React hooks, interactivity, context, hydration errors | `@devflow/adapters/nextjs/skills/nextjs-components/SKILL.md` |
| Zustand stores, client state management | `@devflow/adapters/nextjs/skills/nextjs-state/SKILL.md` |
| shadcn/ui, Tailwind, design tokens, dark mode, responsive | `@devflow/adapters/nextjs/skills/nextjs-ui/SKILL.md` |
| React Hook Form, Zod validation, form flows, Server Actions | `@devflow/adapters/nextjs/skills/nextjs-forms/SKILL.md` |
| Jest + RTL, unit/integration tests, coverage | `@devflow/adapters/nextjs/skills/nextjs-testing/SKILL.md` |
| SEO, metadata, OG images, `generateMetadata`, sitemap, robots | `@devflow/adapters/nextjs/skills/nextjs-metadata/SKILL.md` |
| Image optimization, font loading, script strategies, bundling | `@devflow/adapters/nextjs/skills/nextjs-performance/SKILL.md` |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking)
- **Context7**: Next.js, React, Zustand, shadcn/ui, React Hook Form, Zod docs and version deltas.
- **Sequential Thinking**: break complex refactors and multi-step Server Action flows into small, testable steps.

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- `@devflow/adapters/nextjs/templates/AGENTS.template.md`
- `@devflow/adapters/nextjs/templates/REGISTRY.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + skill references (`@...`) only.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install.

### js-runtime-dependencies

- `next-intl`
- `zustand`
- `react-hook-form`
- `zod`
- `@hookform/resolvers`
- `class-variance-authority`
- `clsx`
- `tailwind-merge`
- `lucide-react`

### js-dev-dependencies

- `jest`
- `jest-environment-jsdom`
- `@testing-library/react`
- `@testing-library/jest-dom`
- `@types/jest`

## Caveman response rules (mandatory)

Apply to narrative text in plans, updates, reviews, PR notes:

- Drop: articles (`a/an/the`), filler (`just/really/basically/actually/simply`), pleasantries, hedging.
- Keep: technical terms exact, errors quoted exact, code blocks unchanged.
- Prefer: short synonyms (`fix`, `use`, `build`, `test`).
- Pattern: `[thing] [action] [reason]. [next step].`

Example:

- Bad: `Sure! I'd be happy to help. The issue is likely in the server action...`
- Good: `Server Action bug. Missing revalidatePath call after mutation. Add call, add test.`

## Plan: extra sections and templates

Include these in `plan.md` when applicable (after core sections from `devflow-plan`).

### Server/Client boundary table

For each component or route in scope, declare boundary explicitly:

| Component / Route | Boundary | Reason |
|---|---|---|
| `app/**/page.tsx` | Server | No interactivity; fetch data server-side |
| `**/form.tsx` | Client (`'use client'`) | Requires `useForm`, event handlers |
| `**/store.ts` | Client | Zustand runs client-side only |

Minimize `'use client'` promotion. Boundary must be justified per file.

### Route segment map

Document `app/` tree with layout ownership and route groups:

```
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
|---|---|---|
| `useCartStore` | `items[]`, `total` | Add/remove item, checkout success |
| `useUIStore` | `sidebarOpen`, `theme` | User toggle action |

Rules:
- No server-fetched data in Zustand (use React cache / `fetch` with Next.js caching).
- Stores persist client-side only; rehydrate from URL params or server props when needed.

### Server Actions vs API Routes decision

Per endpoint, choose explicitly:

| Endpoint | Choice | Reason |
|---|---|---|
| Submit contact form | Server Action | Mutation internal to app; no external consumer |
| Stripe webhook receiver | API Route | External POST from third-party service |
| Revalidate cache on CMS update | API Route | Called by external webhook |
| Update user profile | Server Action | Form-bound mutation, internal |

Rule: internal mutation bound to a form or button → Server Action. External consumer, webhook, or REST endpoint → API Route.

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
|---|---|
| `app/**/layout.tsx`, `app/**/page.tsx`, `app/**/template.tsx` | `nextjs-architecture` |
| `app/**/loading.tsx`, `app/**/error.tsx`, `app/**/not-found.tsx` | `nextjs-architecture` |
| `app/api/**`, `**/actions.ts`, `**/action.ts` | `nextjs-server` |
| File with `'use server'` directive | `nextjs-server` |
| File with `'use client'` directive | `nextjs-components` |
| `**/store.ts`, `**/*Store.ts`, `**/use*Store.ts` | `nextjs-state` |
| `**/components/ui/**`, files importing from `@/components/ui` | `nextjs-ui` |
| Files with `useForm`, `zodResolver`, `z.object` | `nextjs-forms` |
| `**/*.test.tsx`, `**/*.test.ts`, `**/__tests__/**` | `nextjs-testing` |
| Files with `generateMetadata`, `opengraph-image`, `robots.ts`, `sitemap.ts` | `nextjs-metadata` |
| `<img>` tags, font imports, `<script>` tags, `next.config.ts` images/font config | `nextjs-performance` |

Load only skills triggered by current batch's file paths. Do not load all skills preemptively.

## Implement: commands and checklist

### Format, lint, test, build

Run after substantive edits, in order:

```bash
pnpm lint
pnpm test -- --passWithNoTests --watchAll=false
pnpm build
```

Retry failed steps up to **3** attempts each; then stop and report full output.

### Next.js implementation rules (summary)

Adapter does orchestration only. Domain rules live in skills:

- Architecture and boundaries: `@devflow/adapters/nextjs/skills/nextjs-architecture/SKILL.md`
- Server Components, Actions, API Routes, `'use cache'`: `@devflow/adapters/nextjs/skills/nextjs-server/SKILL.md`
- Client Components, hooks, hydration errors: `@devflow/adapters/nextjs/skills/nextjs-components/SKILL.md`
- State (Zustand): `@devflow/adapters/nextjs/skills/nextjs-state/SKILL.md`
- UI (shadcn/ui, Tailwind): `@devflow/adapters/nextjs/skills/nextjs-ui/SKILL.md`
- Forms (RHF + Zod): `@devflow/adapters/nextjs/skills/nextjs-forms/SKILL.md`
- Testing (Jest + RTL): `@devflow/adapters/nextjs/skills/nextjs-testing/SKILL.md`
- SEO, metadata, OG images: `@devflow/adapters/nextjs/skills/nextjs-metadata/SKILL.md`
- Image, font, script, bundling: `@devflow/adapters/nextjs/skills/nextjs-performance/SKILL.md`

### Pre-handoff checklist (implement)

- [ ] `lint`, `test`, `build` pass (or failures documented)
- [ ] Relevant Next.js skills loaded and applied for touched areas
- [ ] Server/Client boundary respected (no unnecessary `use client`)
- [ ] Web Interface Guidelines applied to modified UI files (`@devflow/adapters/common/skills/common-web-interface-guidelines/SKILL.md`)

## Beautify: commands

Same as implement pipeline: `lint`, `test`, `build`.

```bash
pnpm lint
pnpm test -- --passWithNoTests --watchAll=false
pnpm build
```

### Beautify: performance profiling trigger

Profile only when plan flags performance or **Critical**-severity hotspot:

- Use React DevTools Profiler for slow components before refactoring rendering.
- Run `next build --debug` + Bundle Analyzer to inspect bundle weight.
- Check Server Component vs Client Component ratio — unnecessary `use client` increases JS bundle.
- Apply `dynamic()` import for heavy components below the fold.
- Use `<Image>` with `priority` only for LCP element.

Default beautify uses heuristics. Profile only when warranted.

### Beautify: Next.js-specific review axes

Apply core `devflow-beautify` axes, then evaluate touched code with relevant Next.js skills:

- `nextjs-architecture` — boundaries, colocation, route structure
- `nextjs-server` — fetch strategy, caching, action granularity
- `nextjs-components` — `use client` scope minimized
- `nextjs-state` — store size, no server data in Zustand
- `nextjs-ui` — token usage, dark mode parity, responsiveness
- `nextjs-forms` — validation schema, error display, progressive enhancement
- `nextjs-testing` — coverage, test quality

### Beautify: web interface guidelines

Trigger: edit to `**/components/**`, `**/app/**/page.tsx`, `**/app/**/layout.tsx`, files importing `@/components/ui`.

1. Load `@devflow/adapters/common/skills/common-web-interface-guidelines/SKILL.md`
2. Read modified UI files
3. Apply all rules
4. Output `file:line — rule`. No preamble.

### Beautify: accessibility checks

Apply these Next.js-specific accessibility checks in addition to core accessibility axis:

- Interactive elements have correct `role` attribute (`button`, `dialog`, `menu`, etc.)
- Icon-only buttons include `aria-label`
- Form fields have `<label>` or `aria-label`; errors linked via `aria-describedby`
- shadcn/ui uses Radix primitives — verify `aria-*` overrides do not break built-in accessibility
- Keyboard navigation: dialog, menu, popover handle Esc / Tab / Arrow keys
- Focus trap on modal — Radix Dialog manages automatically; do not remove
- Color contrast: use Tailwind tokens; no hardcoded hex values that violate WCAG AA

Severity: **Critical** for screen-reader-blocking issues; **Required** for missing form labels; **Nit** for enhancement.

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: colocated `*.test.tsx` / `*.test.ts` in same directory as source file.
- Integration: `__tests__/` at feature level or project root.

### Commands

```bash
pnpm test -- --passWithNoTests --watchAll=false --coverage
```

### Required test focus

- Components: conditional rendering, prop contract, accessibility-critical states.
- Forms: validator behavior, submit disable/enable transitions, error display.
- State (Zustand): state transitions, selector output.
- Server Actions / API Routes: success/error mapping.

## PR: verification

Before push:

```bash
pnpm lint
pnpm test -- --passWithNoTests --watchAll=false
pnpm build
```

### PR body checklist (copy into PR description)

- [ ] Lint passing
- [ ] Tests passing (coverage ≥ 80% on modified areas)
- [ ] Build passing
- [ ] `nextjs-architecture` constraints respected
- [ ] Server/Client boundary documented for new components
- [ ] `use client` scope minimal (no unnecessary promotion)
- [ ] Web Interface Guidelines checked on modified UI files (no violations at Critical/Required severity)
- [ ] `registry.md` updated if new patterns introduced
