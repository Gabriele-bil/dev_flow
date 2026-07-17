# Angular adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
|---|---| |
| `*.component.ts`, `*.component.html` | `angular-component` | |
| `*.service.ts`, `*http*.ts`, `*api*.ts`, `*client*.ts` | `angular-http` | |
| `*.form*.ts`, `*-form.component.ts`, `*validator*.ts` | `angular-forms` | |
| `*.store.ts`, `*state*.ts`, `*signal*.ts`, `*.facade.ts` | `angular-state` | |
| `*.routes.ts`, `*guard*.ts`, `*resolver*.ts`, navigation/outlet code | `angular-routing` | |
| Component files importing `@angular/aria/*` directives (`ngListbox`, `ngCombobox`, `ngMenu`, `ngTabs`, `ngTree`, `ngGrid`, etc.) | `angular-aria` | |
| `*animation*.ts`, templates using `animate.enter`/`animate.leave`/`[@trigger]` | `angular-animations` | |
| `index.ts` barrel, module boundaries, new feature folder | `angular-architecture` | |

Load only the skills triggered by the current batch's file paths. Do not load all skills preemptively.

## Implement: commands and checklist

### Format, lint, test, build

Run after substantive edits, in order, using project package manager/scripts:

```bash
pnpm run lint
pnpm run test -- --watch=false
pnpm run build
```

If scripts are missing, use Angular CLI equivalents aligned with the repo setup.
Retry failed steps up to **3** attempts each; then stop and report full output.

### CLI conventions

Generation:

```bash
ng generate component features/users/user-card    # ng g c — standalone, OnPush default
ng generate service core/services/user             # ng g s
ng generate directive shared/directives/highlight  # ng g d
ng generate pipe shared/pipes/truncate             # ng g p
ng generate guard core/guards/auth --functional    # ng g g — functional only
```

Dependencies — use `ng add` for Angular-ecosystem packages (runs init schematics: config wiring, base file scaffolding), raw `npm install` only for non-schematic packages:

```bash
ng add @angular/material   # runs schematics — theme setup, module wiring
npm install date-fns       # plain dependency, no schematics
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
- [ ] Relevant Angular skills loaded and applied for touched areas
- [ ] Architecture constraints verified against `angular-architecture`
