# Next.js adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
| --- | --- |
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

### Pre-handoff checklist (implement)

- [ ] `lint`, `test`, `build` pass (or failures documented)
- [ ] Relevant Next.js skills loaded and applied for touched areas
- [ ] Server/Client boundary respected (no unnecessary `use client`)
- [ ] Web Interface Guidelines applied to modified UI files (`@devflow/adapters/common/skills/common-web-interface-guidelines/SKILL.md`)
