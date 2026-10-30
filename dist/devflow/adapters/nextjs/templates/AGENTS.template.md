<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** nextjs
**Adapter:** @devflow/adapters/nextjs/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Server Component default — no `'use client'` unless hooks/browser API/event handlers required.
- State standard: Zustand for global client state. No server data in stores. URL state for filters/pagination.
- Run quality commands after edit batches: `pnpm lint`, `pnpm test -- --passWithNoTests --watchAll=false`, `pnpm build`.
- Required MCP baseline: {{mcp-baseline}}
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
Read a skill only when you touch matching files (full matrix: `@devflow/adapters/nextjs/steps/implement.md`, read on demand):

- Route segments, layouts, `proxy.ts` → `nextjs-architecture`
- `app/api/**`, `actions.ts`, `'use server'`, `'use cache'` → `nextjs-server`
- `'use client'` files → `nextjs-components`
- Zustand stores → `nextjs-state` (new store: also `common-state-patterns`)
- `components/ui/**`, `app/globals.css` → `nextjs-ui`; UI files → `common-web-interface-guidelines`
- `useForm`, `zodResolver`, `z.object` → `nextjs-forms`
- Tests, `e2e/**` → `nextjs-testing`
- Metadata, OG images, `robots.ts`, `sitemap.ts` → `nextjs-metadata`
- `next/image`, `next/font`, `next/script`, `next.config.ts` → `nextjs-performance`
- New `lib/**` module or refactor → `common-clean-code`

Skill files: `@devflow/adapters/nextjs/skills/<name>/SKILL.md`, common: `@devflow/adapters/common/skills/<name>/SKILL.md`. Pipeline steps: `/devflow:task`, `/devflow:plan`, `/devflow:implement`.
<!-- devflow-managed:end:skills -->
