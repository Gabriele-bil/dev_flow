<!-- devflow-managed:start:patterns -->
| Pattern | When | Path |
| --- | --- | --- |
| Route Feature Slice | Any App Router feature | `app/(app)/<feature>/{page.tsx,loading.tsx,actions.ts,_components/,_lib/}` |
| Server Action | Form submit, data mutation | `app/(app)/<feature>/actions.ts` (`'use server'`, returns `{ success, data \| error }`) |
| Zustand Store | Global client UI state | `lib/stores/<feature>-store.ts` (named `use[Feature]Store`) |
| shadcn/ui Component | UI primitive | `components/ui/[component].tsx` (shadcn copy-paste) |
| Shared Feature Component | Reused across routes | `components/<feature>/[component].tsx` |
| Form Schema | Zod validation | `app/(app)/<feature>/_lib/schema.ts` (reused in action + form) |
| Route Handler | External/webhook endpoint | `app/api/<resource>/route.ts` (invalid body → 400) |
| Cached query | Reused server data | `lib/<domain>/queries.ts` (`'use cache'` + `cacheLife` + `cacheTag`) |
<!-- devflow-managed:end:patterns -->

<!-- devflow-managed:start:conventions -->
**Naming:** folders and files `kebab-case` (`user-card.tsx`); components `PascalCase` function names; stores `use[Feature]Store`; actions `[verb][Noun]` (`createItem`)
**Routing:** App Router (`app/`); route groups `(app)` for auth, `(marketing)` for public
**Components:** Server Component default; `'use client'` only at leaf with interactivity
**State:** Zustand for global client state; `useState` for local; URL params for filters/pagination
**Forms:** React Hook Form + Zod 4 + shadcn `Field`; same schema reused in Server Action
**Branches:** `feat/[NNN]_<name>`, `fix/[NNN]_<name>`
**Commits:** `<type>: <desc>` (`feat|fix|chore|docs|perf`)
**Lint:** `pnpm lint` (ESLint CLI)
**Test:** `pnpm test -- --passWithNoTests --watchAll=false`
**Build:** `pnpm build`
<!-- devflow-managed:end:conventions -->
