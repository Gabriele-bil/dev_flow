<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** {{adapter}}
**Adapter:** @devflow/adapters/{{adapter}}/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Follow layer order: migrations -> domain -> data -> providers -> UI.
- No hardcoded user strings; use i18n system.
- Run `{{format-cmd}}` then `{{analyze-cmd}}` after edit batches.
- Required MCP baseline: `context7`, `sequential-thinking`; add `dart` when adapter is `flutter`.
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
@devflow/skills/devflow-task/SKILL.md
@devflow/skills/devflow-plan/SKILL.md
@devflow/skills/devflow-implement/SKILL.md
@devflow/skills/devflow-test/SKILL.md
@devflow/skills/devflow-pr/SKILL.md
@code-review-graph/skills/code-review-graph/SKILL.md
<!-- devflow-managed:end:skills -->
