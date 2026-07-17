# Angular adapter — PR step

Loaded by `devflow-pr` together with the adapter core (`ADAPTER.md`).

## PR: verification

Before push:

```bash
npm run lint
npm run test -- --watch=false
npm run build
```

### PR body checklist (copy into PR description)

- [ ] Lint passing
- [ ] Unit tests passing
- [ ] E2E passing (if present in project)
- [ ] Build passing
- [ ] `angular-architecture` constraints respected
- [ ] Relevant Angular skills applied for changed scope
- [ ] `registry.md` updated if new patterns were introduced
