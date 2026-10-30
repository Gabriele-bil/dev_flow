# devflow-beautify — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Expanding scope beyond `devflow.implement` summary | Limit strictly to the implement summary |
| Adding features during beautify ("while I'm here") | Log as new subtask; implement in next cycle |
| Format/analyze only on new files | Run on the full changed set |
| Treating Nit as mandatory | Fix Critical/Required; user decides Nit/Optional |
| Applying opinable improvements while run mode active | Certain improvements only; opinable candidates → `## Decision flags`, not applied |
| Flagging hardcoded style as Nit when DESIGN.md defines a token | Token equivalent exists → Required finding |
| Profiling without confirmed bottleneck | Apply heuristics only; profile when benchmark confirms |
