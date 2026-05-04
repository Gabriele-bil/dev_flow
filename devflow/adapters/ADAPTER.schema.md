# ADAPTER.md Schema

Canonical section checklist for all DevFlow adapters. Use when creating a new adapter or auditing an existing one.

`[R]` = Required — all pipeline skills depend on it  
`[O]` = Optional — include when applicable to the stack

---

## Required sections

| Section | Key | Notes |
|---|---|---|
| Technology skills table | `## Technology skills` | `[R]` — maps feature type → skill path |
| MCP baseline | `## MCP` | `[R]` — required baseline + optional servers |
| Setup templates | `## Setup: templates` | `[R]` — template resolution paths |
| Plan extra sections | `## Plan: extra sections and templates` | `[R]` — dependency ordering + stack-specific plan blocks |
| Implement skill load matrix | `## Implement: skill load decision matrix` | `[R]` — file path → skill mapping |
| Implement commands | `## Implement: commands and checklist` | `[R]` — format/lint/analyze/build commands + rules |
| Implement pre-handoff checklist | `### Pre-handoff checklist (implement)` | `[R]` — quality gates before devflow.beautify |
| Beautify commands | `## Beautify: commands` | `[R]` — same or different from implement |
| Beautify stack-specific axes | `### Beautify: [stack]-specific review axes` | `[R]` — extra review dimensions |
| Beautify accessibility checks | `### Beautify: accessibility checks` | `[R]` — stack-specific a11y rules + severity |
| Beautify performance profiling trigger | `### Beautify: performance profiling trigger` | `[R]` — when to profile + tools |
| Test coverage threshold | `### Coverage threshold` | `[R]` — numeric threshold for gap report |
| Test placement | `### Placement` | `[R]` — unit + integration file paths |
| Test commands | `### Commands` | `[R]` — exact shell commands |
| PR verification commands | `## PR: verification` | `[R]` — pre-push commands |
| PR body checklist | `### PR body checklist` | `[R]` — copy-paste checklist items |

## Optional sections

| Section | Key | Notes |
|---|---|---|
| Caveman response rules | `## Caveman response rules` | `[O]` — stack teams may add style reminders |
| Codegen triggers | within `## Implement` | `[O]` — only for stacks with code generation |
| Responsive tests | within `## Test` | `[O]` — for UI-heavy stacks |
| Required test focus | `### Required test focus` | `[O]` — explicit test targets per concern |
| Web Interface Guidelines review | `### Beautify: web interface guidelines` | `[O]` — UI-heavy stacks; load `common-web-interface-guidelines` skill, apply rules on UI files |

---

## Completeness audit

When adding a new adapter, verify every `[R]` row is present. Missing rows are pipeline blind spots.

When updating an existing adapter, check this schema after edits to ensure no section was removed.
