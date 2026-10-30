# Next.js adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

Single source of skill triggers. Load skills matching current batch's files only — never all preemptively. Adapter skills: `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/skills/<name>/SKILL.md`; common skills: `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/<name>/SKILL.md`.

| File path / content pattern | Load skill |
| --- | --- |
| `app/**/layout.tsx`, `page.tsx`, `template.tsx`, `default.tsx`, `loading.tsx`, `error.tsx`, `global-error.tsx`, `not-found.tsx`, `proxy.ts`, new route folder / route group / `@slot` | `nextjs-architecture` |
| `app/api/**`, `**/actions.ts`, files with `'use server'` or `'use cache'`, imports from `next/cache` | `nextjs-server` |
| Files with `'use client'` | `nextjs-components` |
| `**/store.ts`, `**/*Store.ts`, `**/use*Store.ts`, `lib/stores/**` | `nextjs-state` |
| New store or new shared state (choosing scope) | `common-state-patterns` (with `nextjs-state`) |
| `components/ui/**`, files importing `@/components/ui`, `app/globals.css` | `nextjs-ui` |
| UI files: `**/components/**`, `app/**/page.tsx`, `app/**/layout.tsx` (a11y/UX rules) | `common-web-interface-guidelines` |
| Files with `useForm`, `zodResolver`, `z.object`, `**/_lib/schema.ts` | `nextjs-forms` |
| `**/*.test.ts`, `**/*.test.tsx`, `**/__tests__/**`, `e2e/**`, `jest.config.ts`, `playwright.config.ts` | `nextjs-testing` |
| `generateMetadata`, `metadata` export, `opengraph-image.*`, `twitter-image.*`, `robots.ts`, `sitemap.ts`, `app/icon.*` | `nextjs-metadata` |
| `<img>`, `next/image`, `next/font`, `next/script`, `<script>`, `next.config.ts` | `nextjs-performance` |
| New module in `lib/**`, refactor, or any file growing past 300 lines | `common-clean-code` |

## Implement: commands and checklist

### Format, lint, test, build

Run after substantive edits, in order:

```bash
pnpm lint
pnpm test -- --passWithNoTests --watchAll=false
pnpm build
```

`pnpm lint` runs ESLint CLI (`"lint": "eslint ."` in `package.json`) — `next lint` was removed in Next 16 and `next build` no longer lints. Script still calls removed `next lint` → stop, report, suggest `npx @next/codemod@latest next-lint-to-eslint-cli .`.

Retry failed steps up to **3** attempts each; then stop and report full output.

### Pre-handoff checklist (implement)

- [ ] `lint`, `test`, `build` pass (or failures documented)
- [ ] Skills from matrix loaded and applied for touched files
- [ ] Server/Client boundary respected (no unnecessary `use client`)
- [ ] Mutations call one invalidation API (`updateTag`, `revalidateTag(tag, 'max')`, `refresh()`, `revalidatePath`)
- [ ] Web Interface Guidelines applied to modified UI files (`common-web-interface-guidelines`)
