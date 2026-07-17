# Angular adapter (DevFlow)

Single source of truth for Angular behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **standalone + signals-first**. Keep output token-lean and imperative.

## Technology skills (load by feature type)

| When | Load | |
|------|------| |
| App structure, folder layout, boundaries, communication flow | `@devflow/adapters/angular/skills/angular-architecture/SKILL.md` | |
| New components, refactor existing components, template/class split | `@devflow/adapters/angular/skills/angular-component/SKILL.md` | |
| Reactive forms, validation, form UX, submit flows | `@devflow/adapters/angular/skills/angular-forms/SKILL.md` | |
| API clients, HttpClient usage, interceptors, error mapping | `@devflow/adapters/angular/skills/angular-http/SKILL.md` | |
| Global and local state management patterns | `@devflow/adapters/angular/skills/angular-state/SKILL.md` | |
| Routes, guards, resolvers, navigation, rendering strategy | `@devflow/adapters/angular/skills/angular-routing/SKILL.md` | |
| Accessible custom widgets (Accordion, Listbox, Combobox, Menu, Tabs, Tree, Grid, Toolbar) | `@devflow/adapters/angular/skills/angular-aria/SKILL.md` | |
| Enter/leave animations, state transitions, route transitions | `@devflow/adapters/angular/skills/angular-animations/SKILL.md` | |
| PR review, blast radius, architecture risk checks | `@code-review-graph/skills/code-review-graph/SKILL.md` | |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
- Optional, native to Angular CLI:
  - Angular CLI MCP server — `npx @angular/cli mcp [-E tool]`
- **Context7**: Angular and RxJS API docs and version deltas.
- **Sequential Thinking**: break complex refactors into small, testable steps.
- **Angular CLI MCP**: native tools — `get_best_practices` (current Angular conventions),
  `onpush_zoneless_migration` (migration guidance), `devserver.start`/`devserver.stop`/
  `devserver.wait_for_build` (manage local dev server during implement/test loops).

## Caveman response rules (mandatory)

Apply to narrative text in plans, updates, reviews, PR notes:

- Drop: articles, filler (`just/really/basically/actually/simply`), pleasantries, hedging.
- Keep: technical terms exact, code blocks unchanged.
- Prefer: `fix`, `use`, `build`, `test`. Pattern: `[thing] [action] [reason]. [next step].`

## Step files (load only the active step)

| Step | File | Contains |
| --- | --- | --- |
| setup | `steps/setup.md` | Setup templates + dependencies |
| plan | `steps/plan.md` | Plan extra sections and templates |
| implement | `steps/implement.md` | Skill load decision matrix, commands, CLI conventions, checklist |
| beautify | `steps/beautify.md` | Beautify commands, review axes, accessibility checks |
| test | `steps/test.md` | Test layout, commands, coverage threshold, verify |
| pr | `steps/pr.md` | PR verification and body checklist |
