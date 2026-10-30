# Angular adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

Single source of skill triggers for this adapter. Match each file in the batch by path or content; load every skill its rows name. Adapter skills: `@devflow/adapters/angular/skills/<name>/SKILL.md`. Common skills: `@devflow/adapters/common/skills/<name>/SKILL.md`.

| File path / content pattern | Load skill |
| --- | --- |
| `index.ts` barrel, `app.config*.ts`, `app.ts`, new `pages/<page>/` or `core/` folder, boundary moves | `angular-architecture` |
| Files with `@Component`/`@Directive`/`@Pipe` (`page.ts`, `*.component.ts`, `components/**/*.ts`), `*.html` templates | `angular-component` + `common-web-interface-guidelines` |
| `service.ts`, `*.service.ts`, `core/interceptors/**`, `*api*.ts`, `*client*.ts`, files with `HttpClient`/`httpResource`/`resource(` | `angular-http` |
| `*.form.ts`, `*-form.ts`, `validators/**`, files with `form(`/`[formField]` from `@angular/forms/signals` | `angular-forms` |
| `state.ts`, `*.store.ts`, `core/states/**`, `*.facade.ts`, files with `signalStore(` | `angular-state` + `common-state-patterns` |
| `*.routes.ts`, `app.routes.server.ts`, `core/guards/**`, `core/resolvers/**`, navigation/outlet code | `angular-routing` |
| Files importing `@angular/aria/*` (`ngListbox`, `ngCombobox`, `ngMenu`, `ngTabs`, `ngTree`, `ngGrid`, …) or building a custom select/menu/tabs/tree | `angular-aria` |
| Templates/styles with `animate.enter`/`animate.leave`, keyframes/transitions, legacy `@angular/animations` code to migrate (deprecated) | `angular-animations` |
| `src/styles.css`, `src/styles/**`, component stylesheets (`*.css`), `.postcssrc.json`, design tokens, dark mode | `angular-theme` |
| `*.spec.ts`, test helpers, component harnesses | `angular-testing` |
| Any `*.ts` with new classes/functions or refactor of existing logic | `common-clean-code` |

Load only the skills triggered by the current batch's files. Do not load all skills preemptively.

## Implement: commands and checklist

### Format, lint, test, build

Run after substantive edits, in order, using project package manager/scripts:

```bash
pnpm run lint
pnpm run test -- --watch=false
pnpm run build
```

If scripts are missing, use Angular CLI equivalents aligned with the repo setup.
Retry failed steps up to **3** attempts each; then stop and report the failing command + decisive error lines.

### CLI conventions

Generation:

```bash
ng generate component pages/users/components/user-card  # ng g c — standalone, OnPush default
ng generate service core/services/user                    # ng g s
ng generate directive shared/directives/highlight         # ng g d
ng generate pipe shared/pipes/truncate                    # ng g p
ng generate guard core/guards/auth --functional           # ng g g — functional only
```

Dependencies — `pnpm ng add` for Angular-ecosystem packages with init schematics (config wiring, scaffolding), `pnpm add` for plain packages:

```bash
pnpm ng add @angular/ssr   # runs schematics — server entry, server routes, config
pnpm add date-fns          # plain dependency, no schematics
```

Local API proxying — `proxy.conf.json` + `angular.json` `serve.options.proxyConfig`:

```json
// proxy.conf.json
{ "/api": { "target": "http://localhost:3000", "secure": false, "changeOrigin": true } }
```

```json
// angular.json — architect.serve.options
{ "proxyConfig": "proxy.conf.json" }
```

### Pre-handoff checklist (implement)

- [ ] `format`, `lint`, `test`, `build` pass (or failures documented)
- [ ] Skills named by matched matrix rows loaded and applied
- [ ] Architecture constraints verified against `angular-architecture`
