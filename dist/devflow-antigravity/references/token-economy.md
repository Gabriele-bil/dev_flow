# Token Economy — Exploration and Output Discipline

Shared reference for pipeline skills. Two rule families: read less (index-first), emit less (derive-don't-dump). Ported from tokless gap analysis (`docs/tokless-gap-analysis.md` in plugin repo).

## Index-first exploration

Applies to any structural question about existing code: how does X work, who calls Y, where is Z, blast radius, subsystem structure.

```text
Project has code-index MCP (tokensave / codegraph / serena / LSP-based)?
├─ YES → one semantic query FIRST. Source + relationships in one call.
│        Trust result — no re-grep, no re-search, no re-read of returned
│        source. Full AST/semantic parse; safe to edit from.
│        grep/Read only for what index does not cover (configs, docs,
│        .env) — after index narrows scope.
└─ NO  → grep/Read as usual. Do not call absent index tools.
```

Rules:

- **Index first, never as fallback.** Semantic query before any grep/Read chain — not after grep churn fails.
- **Trust results.** Re-grep/re-read of source the index returned = pure waste.
- **One call replaces the chain.** One semantic query replaces grep→read→grep→read.
- **Detection at orientation.** Session start: note which index MCP is available; record for the session. Absent → normal tools, zero behavior change.

## Derive, don't dump

Applies to steps running builds, tests, diffs, or any verbose command.

- Batch related commands into one invocation; filter at source (`| tail -20`, `| grep -E 'FAIL|error'`) — never dump full output for analysis.
- State the derived answer ("3 tests fail, all in auth_test.py, same root cause"); quote only decisive lines.
- Decision needs >200 lines of source → extract relevant section; never paste wholesale.
- Re-run of same check → report delta only.
- **Evidence rules win.** Where a skill mandates raw output (e.g. `devflow.test` notify report), paste required evidence exact. Derive-don't-dump governs intermediate runs and analysis, not mandated evidence.
