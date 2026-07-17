# Next.js adapter — Beautify step

Loaded by `devflow-beautify` together with the adapter core (`ADAPTER.md`).

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
