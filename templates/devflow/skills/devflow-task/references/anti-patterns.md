# devflow-task — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Asking user for branch or feature name | Never ask: automatically infer type and kebab-case name, and set branch per `[type]/[number-of-task-is-present]_[name]` |
| Technical details in task (classes, DB schemas, endpoints) | Product-only; technical decisions belong in `devflow.plan` |
| Technical persona ("As a Frontend Developer", "As a Database") | Use real human role or external system actor |
| Compound user story ("I want X and Y") | Split into separate use cases or tasks |
| Tautological value ("so that I can do action") | Articulate real business/user benefit |
| Mixing Read view and Action mutation in one flow | Isolate Read/View from Action/Write into distinct use cases |
| Missing async states (in-flight, error, empty) | Explicitly specify loading spinner, input disabling, retry, and fallback |
| Ghost UI (dead buttons or "coming soon" placeholders) | Strict Alien test: only include working, releasable functionality |
| Multiple `When` statements in a single AC scenario | Exactly one `When` per scenario; split multiple triggers |
| Vague adjectives or empty boosters ("fast", "intuitive", "robust", "seamless") | Replace with observable mechanism or user-verified threshold; if target is unknown, ask in Step 4 instead of inventing numbers |
| Specific-looking vagueness (inventing SLAs, metrics, or rules not in source) | Preserve source truth: ask user or record explicit default in `## Assumptions & Risks` |
| Copying raw user wording into Goal or Problem | Rewrite into structured problem/outcome while preserving user's domain terms |
| Assuming NNN prefix without reading state | Read `.devflow-state.json`; never reuse prefix |
