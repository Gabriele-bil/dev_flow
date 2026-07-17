# Next.js adapter — PR step

Loaded by `devflow-pr` together with the adapter core (`ADAPTER.md`).

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
