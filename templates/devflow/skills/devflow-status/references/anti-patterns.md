# devflow-status — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Editing `.devflow-state.json` directly | Use `devflow-recovery`; never hand-edit state |
| Prose or dashboard around `--json` output | Single JSON object on stdout — consumers parse it (see `status-schema.md`) |
| Reporting status from memory | Always read `plan.md` at invocation time |
| Reporting state-file status over `plan.md` | `plan.md` authoritative; state file only feeds the Drift line |
| Using status as full routing guide | `references/orientation.md` = routing tree; status = snapshot of active feature |
