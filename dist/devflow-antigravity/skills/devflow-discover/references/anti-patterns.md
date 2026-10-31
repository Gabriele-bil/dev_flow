# devflow-discover — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Asking open-ended essay questions | Paralyzes user and produces vague answers | Use bounded multi-choice questions with a recommended option |
| Skipping multi-axis analysis | Misses critical non-functional constraints (scale, security, blast radius) | Systematically review the 6 discovery axes before formulating options |
| Monolithic option dumping | Overwhelms user with unformatted text | Use structured comparison table followed by focused `ask_question` |
| Skipping existing code inspection | Re-invents existing modules or violates constitution conventions | Read `constitution.md` and inspect codebase before proposing options |
| Leaving ADR in draft without user decision | Unresolved decisions stall downstream pipeline | Run interactive Q&A loop to reach explicit Accepted status |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Skip discovery questions — infer context from prompt" | Inferred assumptions hide critical constraints. 2–3 targeted questions prevent costly architectural rework |
| "Skip discovery — pick familiar stack immediately" | Familiarity traps produce architectural debt. Compare alternatives against project constraints before locking in |
| "Only present one option to go faster" | One option is an ultimatum, not discovery. Minimum 2 distinct options required to expose trade-offs |
| "Write code prototype during discovery" | Discovery decides architecture and boundaries. Code before spec violates spec-first principle |
| "ADR is unnecessary bureaucracy for small decisions" | Undocumented decisions lead to architectural drift and repeated debates. ADR takes 2 minutes and preserves intent |
