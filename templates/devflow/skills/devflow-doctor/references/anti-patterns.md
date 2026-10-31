# devflow-doctor — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Treating absent MCP servers as fatal errors | Mark as `DEGRADED (CLI fallback active)`; DevFlow is designed to degrade cleanly. |
| Mutating files during diagnostic check without `--fix` | Read-only inspection by default; require explicit `--fix` flag for automatic repairs. |
| Emitting vague error messages like "CLI missing" | Provide exact binary name, package manager install command, and documentation link. |
