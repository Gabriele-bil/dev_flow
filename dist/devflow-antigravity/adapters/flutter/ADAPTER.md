# Flutter adapter (DevFlow)

**Verified against:** sdk:flutter@3.47, sdk:dart@3.13, pub:flutter_riverpod@3.4, pub:hooks_riverpod@3.4, pub:riverpod_generator@4.0, pub:freezed@4.0 (2026-10-30)

Single source of truth for Flutter behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **Riverpod 3 codegen + hooks · freezed 4 · slang · skeletonizer · Material 3 theme · Supabase (optional)**. APIs that change between minors (Riverpod, freezed, Supabase, Flutter widgets): check current docs with Context7 / Dart MCP before writing them.

## Technology skills (load by feature type)

Feature-level index (`devflow-plan`). Per-file triggers: `steps/implement.md` → skill load decision matrix — single source; keep both in sync.

| When (feature) | Load |
| ------ | ------ |
| New feature: layers, dependency direction, feature file tree | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-architecture/SKILL.md` |
| Entities, `mock()`, DTOs, mappers, failures, repository contracts | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-models/SKILL.md` |
| Providers, notifiers, async state, `.skeleton(mock:)` loading UI, provider tests | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-riverpod/SKILL.md` |
| Supabase datasources, repositories, auth, storage, realtime (Supabase apps only) | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-supabase/SKILL.md` |
| Schema migrations, RLS, SQL (Supabase apps only) | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-supabase-migrations/SKILL.md` |
| Theme tokens, colors, typography, component themes | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-theme/SKILL.md` |
| Constraints, breakpoints, scrollables, spacing | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-layout/SKILL.md` |
| `flutter_form_builder` forms, validation, wizards | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/flutter/skills/flutter-form/SKILL.md` |
| PR review, blast radius, architecture risk checks | `@code-review-graph/skills/code-review-graph/SKILL.md` |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
  - `dart` (required on Flutter projects)
- Conditional (only when used in project):
  - `supabase` (Supabase MCP) — schema, RLS, tables (add ONLY if project uses Supabase as backend/DB; omit otherwise)
  - `sentry` (`mcp.sentry.dev` / `getsentry/sentry-mcp`) — error triage and stack traces (add ONLY if project uses Sentry)
- **Dart MCP** — package APIs, Flutter/Dart signatures (use in plan, implement, beautify).
- **Context7** — third-party docs when Dart MCP is insufficient.
- **Supabase MCP** — schema, RLS, tables when the feature touches the database (active only on Supabase-backed apps).

## Step files (load only the active step)

| Step | File | Contains |
| --- | --- | --- |
| setup | `steps/setup.md` | Setup templates + dependencies |
| plan | `steps/plan.md` | Plan extra sections and templates |
| implement | `steps/implement.md` | Skill load decision matrix, commands, checklist, barrel rules |
| beautify | `steps/beautify.md` | Beautify commands, review axes, accessibility checks |
| test | `steps/test.md` | Test layout, commands, coverage threshold, verify |
| pr | `steps/pr.md` | PR verification and body checklist |
