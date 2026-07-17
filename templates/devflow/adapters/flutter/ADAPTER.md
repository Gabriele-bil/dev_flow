# Flutter adapter (DevFlow)

Single source of truth for Flutter behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

## Technology skills (load by feature type)

| When | Load |
| ------ | ------ |
| New feature architecture, layer ownership, feature file-tree scaffold | `@devflow/adapters/flutter/skills/flutter-architecture/SKILL.md` |
| Database read/write/auth, schema, RLS | `@devflow/adapters/flutter/skills/flutter-supabase/SKILL.md` |
| Schema migrations / SQL artifacts | `@devflow/adapters/flutter/skills/flutter-supabase-migrations/SKILL.md` |
| New UI screens or visual styling | `@devflow/adapters/flutter/skills/flutter-theme/SKILL.md` |
| Riverpod providers, notifiers, async state | `@devflow/adapters/flutter/skills/flutter-riverpod/SKILL.md` |
| Entities, DTOs, JSON boundaries | `@devflow/adapters/flutter/skills/flutter-models/SKILL.md` |
| Layout, breakpoints, scrollables | `@devflow/adapters/flutter/skills/flutter-layout/SKILL.md` |
| Form / wizard flows | `@devflow/adapters/flutter/skills/flutter-form/SKILL.md` |
| PR review, blast radius, architecture risk checks | `@code-review-graph/skills/code-review-graph/SKILL.md` |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
  - `dart` (required on Flutter projects)
- **Dart MCP** — package APIs, Flutter/Dart signatures (use in plan, implement, beautify).
- **Context7** — third-party docs when Dart MCP is insufficient.
- **Supabase MCP** — schema, RLS, tables when the feature touches the database.

## Step files (load only the active step)

| Step | File | Contains |
| --- | --- | --- |
| setup | `steps/setup.md` | Setup templates + dependencies |
| plan | `steps/plan.md` | Plan extra sections and templates |
| implement | `steps/implement.md` | Skill load decision matrix, commands, checklist, barrel rules |
| beautify | `steps/beautify.md` | Beautify commands, review axes, accessibility checks |
| test | `steps/test.md` | Test layout, commands, coverage threshold, verify |
| pr | `steps/pr.md` | PR verification and body checklist |
