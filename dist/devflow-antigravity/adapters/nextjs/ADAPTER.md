# Next.js adapter (DevFlow)

Single source of truth for Next.js behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **Next.js 16+ App Router · Zustand 5 · Tailwind CSS v4 + shadcn/ui · Server Actions + API Routes · Turbopack · Jest + RTL**. Keep output token-lean and imperative.

## Technology skills (load by feature type)

| When | Load |
| ------ | ------ |
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
  - `sequential-thinking` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
- Native to Next.js:
  - Next.js DevTools MCP — `next-devtools-mcp` (connects to Next.js 16+ dev server `/_next/mcp`)
- Testing & verification:
  - Playwright MCP server — `@playwright/mcp` (semantic accessibility snapshots + runtime E2E verification)
- Conditional (only when used in project):
  - `postgres` (`@microsoft/postgres-mcp` or `mcp-postgres-server`, read-only) — schema introspection (add ONLY if project connects directly to Postgres; omit otherwise)
  - `supabase` (Supabase MCP) — schema, RLS, tables (add ONLY if project uses Supabase as backend/DB; omit otherwise)
  - `sentry` (`mcp.sentry.dev` / `getsentry/sentry-mcp`) — error triage and stack traces (add ONLY if project uses Sentry)
- **Context7**: Next.js, React, Zustand, shadcn/ui, React Hook Form, Zod docs and version deltas.
- **Sequential Thinking**: break complex refactors and multi-step Server Action flows into small, testable steps.
- **Next.js DevTools MCP**: live diagnostics — `get_errors`, `get_routes`, `get_project_metadata`, `get_logs`, `get_server_action_by_id`.
- **Playwright MCP**: runtime browser verification (Level 4 in `devflow.test`) and ARIA tree accessibility audits in `devflow.beautify`.

## Caveman response rules (mandatory)

Apply to narrative text in plans, updates, reviews, PR notes:

- Drop: articles, filler (`just/really/basically/actually/simply`), pleasantries, hedging.
- Keep: technical terms exact, code blocks unchanged.
- Prefer: `fix`, `use`, `build`, `test`. Pattern: `[thing] [action] [reason]. [next step].`

## Step files (load only the active step)

| Step | File | Contains |
| --- | --- | --- |
| setup | `steps/setup.md` | Setup templates + dependencies |
| plan | `steps/plan.md` | Plan extra sections and templates |
| implement | `steps/implement.md` | Skill load decision matrix, commands, checklist |
| beautify | `steps/beautify.md` | Beautify commands, review axes, web interface guidelines, accessibility checks |
| test | `steps/test.md` | Test layout, commands, coverage threshold, verify |
| pr | `steps/pr.md` | PR verification and body checklist |
