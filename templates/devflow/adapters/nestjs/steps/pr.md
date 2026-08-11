# NestJS adapter — PR step

Loaded by `devflow-pr` together with the adapter core (`ADAPTER.md`).

## PR: verification

Before push:

```bash
npm run lint
npm test -- --passWithNoTests
npm run test:e2e
npm run build
```

### PR body checklist (copy into PR description)

- [ ] Lint passing
- [ ] Unit tests passing (coverage ≥ 80% on modified areas)
- [ ] E2E tests passing
- [ ] Build passing
- [ ] `nestjs-architecture` constraints respected (feature modules, constructor injection, no circular deps)
- [ ] All new/changed endpoints documented with `@nestjs/swagger` decorators
- [ ] All new DTOs validated with `class-validator`; guards applied to protected routes
- [ ] `registry.md` updated if new patterns introduced
