# Angular adapter (DevFlow)

**Verified against:** @angular/core@22.2, @angular/cli@22.2, @angular/aria@22.2, @angular/ssr@22.2, @ngrx/signals@22.0, tailwindcss@4.3, vitest@5.0, @playwright/test@1.64 (2026-10-30)

Single source of truth for Angular behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **standalone + signals-first + zoneless**, NgRx Signal Store for state (no `@ngrx/store`), native CSS animations (`@angular/animations` deprecated), Vitest, pnpm. Keep output token-lean and imperative.

## Technology skills (what each skill covers)

Index only. Triggers (file path / content → skill) live in `steps/implement.md` → skill load decision matrix — the single source.

| Skill | Covers |
| --- | --- |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-architecture/SKILL.md` | Folder layout, `core`/`pages`/`shared` boundaries, page → state → service flow, root wiring |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-component/SKILL.md` | Standalone components, signal inputs/outputs/`model()`, `linkedSignal`, host metadata, control flow |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-forms/SKILL.md` | Signal Forms: model, schema rules (`{ when }`), async validation, custom controls, submit |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-http/SKILL.md` | Where HTTP lives, `httpResource`/`resource`/`HttpClient` choice, interceptors, upload progress |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-state/SKILL.md` | NgRx Signal Store: global vs page stores, `rxMethod` + `tapResponse`, entities |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-routing/SKILL.md` | Routes, functional guards/resolvers, navigation, server routes / render modes, view transitions |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-aria/SKILL.md` | Accessible composite widgets via `@angular/aria` (Combobox, Listbox, Menu, Tabs, Tree, Grid, …) |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-animations/SKILL.md` | `animate.enter`/`animate.leave`, CSS transitions, JS animation libs, legacy animation migration |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-theme/SKILL.md` | Tailwind v4 theme, `src/styles/` layers, tokens, dark mode, component stylesheets, encapsulation |
| `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/skills/angular-testing/SKILL.md` | Zoneless Vitest + TestBed specs, timers, router/HTTP/store tests, harnesses, Playwright conventions |
| `@code-review-graph/skills/code-review-graph/SKILL.md` | PR review, blast radius, architecture risk checks (ship/pr steps) |

Common skills loaded by matrix rows: `common-state-patterns`, `common-web-interface-guidelines`, `common-clean-code` (`$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/<name>/SKILL.md`).

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
- Native to Angular CLI:
  - Angular CLI MCP server — `npx @angular/cli mcp [-E tool]`
- Testing & verification:
  - Playwright MCP server — `@playwright/mcp` (semantic accessibility snapshots + runtime E2E verification)
- Conditional (only when used in project):
  - `sentry` (`mcp.sentry.dev` / `getsentry/sentry-mcp`) — error triage and stack traces (add ONLY if project uses Sentry)
- **Context7**: Angular and RxJS API docs and version deltas.
- **Sequential Thinking**: break complex refactors into small, testable steps.
- **Angular CLI MCP**: native tools — `get_best_practices` (current Angular conventions),
  `onpush_zoneless_migration` (migration guidance), `devserver.start`/`devserver.stop`/
  `devserver.wait_for_build` (manage local dev server during implement/test loops).
- **Playwright MCP**: runtime browser verification (Level 4 in `devflow.test`) and ARIA tree accessibility audits in `devflow.beautify`.

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
