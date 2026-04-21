<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** flutter
**Adapter:** @devflow/adapters/flutter/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Respect order: migrations -> domain -> data -> Riverpod -> UI -> i18n/codegen.
- Use `slang` keys for user-visible copy; no hardcoded UI strings.
- Cover compact/medium/expanded layouts with project breakpoints.
- Run `dart format .` then `flutter analyze` after edit batches.
- Required MCP baseline: `context7`, `sequential-thinking`, `dart` (Flutter required).
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
@devflow/skills/devflow-task/SKILL.md
@devflow/skills/devflow-plan/SKILL.md
@devflow/skills/devflow-implement/SKILL.md
@devflow/adapters/flutter/skills/flutter-layout/SKILL.md
@devflow/adapters/flutter/skills/flutter-riverpod/SKILL.md
@devflow/adapters/flutter/skills/flutter-theme/SKILL.md
@devflow/adapters/flutter/skills/flutter-supabase/SKILL.md
@code-review-graph/skills/code-review-graph/SKILL.md
<!-- devflow-managed:end:skills -->
