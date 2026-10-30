# devflow-implement — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Committing mid-implement ("save point") | Mark `[done]` in `plan.md`; commits in `devflow.pr` only |
| Implementing files out of dependency order | Follow **File List** order; deps before dependents |
| Creating shared components without checking registry | Read `registry.md` before writing any shared file |
| Loading full codebase "for context" | Load only `plan.md` files + one exemplar pattern per task |
| Skipping codegen, localization, or loading/error states | Adapter rules apply from first line; hardcoded copy/colors fail beautify |
| Deviating from plan without logging it | Report deviations in Step 7b summary |
| Running analyze only at the end, or after every file | Once per vertical slice checkpoint + once after the last file (Step 6) |
| Guessing unspecified behavior | Find repo precedent; if none → ask |
| Pausing on ambiguity while run mode active | Defensible default + `## Decision flags` entry; interactive pause only without `.devflow-run.json` |
| Pushing through host compaction warning | Write `handoff.md` first — orientation for next session costs 10 lines now |
| Writing code no AC requires (gold-plating, speculative options) | Every line traces to plan/AC; log the idea via `devflow.learn` instead |
| Writing helper that stdlib/platform/installed dependency covers | Lazy ladder rungs 2–5: reuse > stdlib > platform > installed dep > new code |
| Dumping full build/test output into response | Derive answer, quote decisive lines — `token-economy.md` |
| grep→read chain when code-index MCP available | One semantic query first; trust result, no re-grep |
| Skipping registry update for shared folder element | Anything in shared/ must be in `registry.md` by the end of Step 7 |
| Fixing beautify/test issues during implement | Log in `## Deviations` (Step 7b); fix in `devflow.beautify` |
