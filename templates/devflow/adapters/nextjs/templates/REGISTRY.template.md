<!-- devflow-managed:start:patterns -->
| Pattern | When | Path |
| --- | --- | --- |
| Route Feature Slice | Any App Router feature | `app/(app)/<feature>/{page.tsx,loading.tsx,_components/,_lib/}` |
| Server Action | Form submit, data mutation | `app/(app)/<feature>/_lib/actions.ts` |
| Zustand Store | Global client UI state | `lib/stores/<feature>-store.ts` (named `use[Feature]Store`) |
| shadcn/ui Component | UI primitive | `components/ui/[component].tsx` (shadcn copy-paste) |
| Shared Feature Component | Reused across routes | `components/<feature>/[component].tsx` |
| Form Schema | Zod validation | `app/(app)/<feature>/_lib/schema.ts` (reused in action + form) |
| API Route | External/webhook endpoint | `app/api/<resource>/route.ts` |
<!-- devflow-managed:end:patterns -->

<!-- devflow-managed:start:conventions -->
**Naming:** route folders `kebab-case`; components `PascalCase.tsx`; stores `use[Feature]Store`; actions `[verb][Noun]Action`
**Routing:** App Router (`app/`); route groups `(app)` for auth, `(marketing)` for public
**Components:** Server Component default; `'use client'` only at leaf with interactivity
**State:** Zustand for global client state; `useState` for local; URL params for filters/pagination
**Forms:** React Hook Form + Zod; same schema reused in Server Action
**Branches:** `feat/[NNN]-<name>`, `fix/[NNN]-<name>`
**Commits:** `<type>: <desc>` (`feat|fix|chore|docs|perf`)
**Lint:** `pnpm lint`
**Test:** `pnpm test -- --passWithNoTests --watchAll=false`
**Build:** `pnpm build`
<!-- devflow-managed:end:conventions -->
