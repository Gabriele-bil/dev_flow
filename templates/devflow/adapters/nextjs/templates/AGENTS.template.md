<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** nextjs
**Adapter:** @devflow/adapters/nextjs/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Server Component default — no `'use client'` unless hooks/browser API/event handlers required.
- Load `nextjs-architecture` when work touches routes, layouts, or folder structure.
- Load `nextjs-server` when touching Server Components, Server Actions (`actions.ts`), or API routes.
- Load `nextjs-components` when touching Client Components (`'use client'` files).
- State standard: Zustand for global client state. No server data in stores. URL state for filters/pagination.
- Run quality commands after edit batches: `pnpm lint`, `pnpm test -- --passWithNoTests --watchAll=false`, `pnpm build`.
- Required MCP baseline: `context7`, `sequential-thinking`.
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
@devflow/skills/devflow-task/SKILL.md
@devflow/skills/devflow-plan/SKILL.md
@devflow/skills/devflow-implement/SKILL.md
@devflow/adapters/nextjs/skills/nextjs-architecture/SKILL.md
@devflow/adapters/nextjs/skills/nextjs-server/SKILL.md
@devflow/adapters/nextjs/skills/nextjs-components/SKILL.md
@devflow/adapters/nextjs/skills/nextjs-state/SKILL.md
@devflow/adapters/nextjs/skills/nextjs-ui/SKILL.md
@devflow/adapters/nextjs/skills/nextjs-forms/SKILL.md
@devflow/adapters/nextjs/skills/nextjs-testing/SKILL.md
<!-- devflow-managed:end:skills -->
