# devflow-learn — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Promoting low-confidence or unverified local instincts | Pollutes team shared context with premature rules | Require confidence ≥ 0.85 and multi-session validation |
| Git-ignoring `.devflow-instincts.shared.yaml` | Team loses architectural gotchas discovered in earlier sessions | Keep shared file tracked in git; only local file is ignored |
| Never pruning stale local instincts | Stale instincts mislead future sessions | Run `prune` periodically after major refactors |
| Logging external docs or tutorials as instincts | Bloats prompt context with non-codebase knowledge | Only log codebase-specific behaviors observed during sessions |
