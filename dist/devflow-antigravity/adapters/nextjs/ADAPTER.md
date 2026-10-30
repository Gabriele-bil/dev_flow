# Next.js adapter (DevFlow)

**Verified against:** next@16.4, react@19.3, zod@4.6, tailwindcss@4.3, zustand@5.0 (2026-10-30)

Single source of truth for Next.js behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **Next.js 16.4 App Router + Cache Components · React 19 · Zustand 5 · Tailwind CSS 4 + shadcn/ui · Zod 4 · Server Actions + Route Handlers · Turbopack · ESLint CLI · Jest + RTL · Playwright**. Keep output token-lean and imperative.

Banned APIs (validator-enforced): `deprecated-apis.txt`. For fast-moving APIs (caching, `next/image`, shadcn, Zod) check current docs with Context7 before writing code.

## Technology skills (what each covers)

Index only. Triggers (file path / content → skill) live in one place: `steps/implement.md` → skill load decision matrix.

| Skill | Covers |
| ------ | ------ |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-architecture/SKILL.md` | App structure, route groups, segment files, parallel/intercepting routes, `proxy.ts`, boundary placement |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-server/SKILL.md` | Server Components, `'use cache'` / `cacheLife` / `cacheTag`, invalidation, Server Actions, Route Handlers |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-components/SKILL.md` | Client Components, React 19 hooks, serializable props, hydration errors |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-state/SKILL.md` | Zustand stores, selectors, `persist`, store tests |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-ui/SKILL.md` | shadcn/ui, Tailwind 4 tokens (`@theme inline`), CVA, dark mode, responsive |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-forms/SKILL.md` | React Hook Form + Zod 4 + shadcn `Field`, Server Action submit |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-testing/SKILL.md` | Jest + RTL units, Playwright E2E, coverage config |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-metadata/SKILL.md` | Metadata API, OG images, `robots.ts`, `sitemap.ts`, viewport |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/nextjs-performance/SKILL.md` | `next/image` (`preload`, `sizes`), `next/font`, `next/script`, bundle analysis |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/common-state-patterns/SKILL.md` | State scope decision (local / lifted / store) |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/common-web-interface-guidelines/SKILL.md` | UI accessibility and UX audit rules |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/common-clean-code/SKILL.md` | Naming language, file size, duplication, dependency direction |

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
