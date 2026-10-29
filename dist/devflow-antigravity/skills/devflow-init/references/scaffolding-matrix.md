# Evergreen Technology Scaffolding Matrix (`devflow.init`)

Used by `devflow.init` Step 2 — authoritative rules for scaffolding live, always-up-to-date project workspaces across **Nx**, **Angular**, **Next.js**, **Flutter**, and **NestJS**.

---

## 1. The "Always Up-to-Date" Guarantee (Mandatory)

1. **Zero hardcoded package versions:** Never write static `package.json` or `pubspec.yaml` templates with pinned historical versions. AI training weights go stale; live registries and official `@latest` CLIs are the source of truth.
2. **Pre-scaffold live lookup:** Before executing CLI generators or writing configuration files, verify current latest stable versions and configuration formats:
   - **MCP first:** Query `context7` MCP (and active stack MCP: `angular-cli`, `next-devtools`, `dart`) for current framework setup conventions.
   - **Registry lookup via Bash:**
     - Node/TS stacks: `npm view <pkg> version` (e.g. `npm view nx version`, `npm view @angular/cli version`, `npm view next version`, `npm view @nestjs/cli version`).
     - Flutter/Dart: `flutter --version` and `flutter pub outdated` after project creation.
3. **Hook compatibility (`pre-config-protect.sh`):**
   - DevFlow's `pre-config-protect.sh` hook blocks `Write`, `Edit`, and `MultiEdit` tool calls on `analysis_options.yaml`, `eslint.config.*`, `.eslintrc*`, `tsconfig*.json`, `.editorconfig`, `biome.json`, and `.prettierrc*`.
   - **Rule:** Always generate linter, formatter, and TypeScript configuration files via official CLI scaffolding commands in `Bash` (or shell redirection inside the bootstrap script when configuring a brand-new workspace), never via `Write`/`Edit` tool calls on protected filenames.

---

## 2. Workspace & Git Initialization (All Modes)

Run from the resolved project root (`<project-slug>/` or `.`):

```bash
mkdir -p devflow/features devflow/plans docs/adr
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || git init -b main
```

Ensure `.gitignore` includes stack-standard ignores plus DevFlow runtime state ignores:

```gitignore
# devflow runtime state
.devflow-state.json
.devflow-run.json
.devflow-fanout-state.json
.devflow-worktrees.json
.devflow-learnings.jsonl*
.devflow-instincts.yaml
!.devflow-instincts.shared.yaml
.devflow-observe.jsonl*
.devflow-filter-stats.jsonl
.devflow-test-summary.json
.devflow-metrics.jsonl
.devflow-fetch-cache/
.devflow-init-answers.tmp
*.tmp
```

---

## 3. Stack CLI Scaffolding Matrix (`@latest` Non-Interactive)

### A. Nx Monorepo Workspace (`nx`)

Use when user selects **Nx Monorepo** in Phase B (`QB.1`).

1. **Check latest Nx version:** `npm view create-nx-workspace version`
2. **Scaffold workspace root:**
   ```bash
   npx --yes create-nx-workspace@latest <project-slug> \
     --preset=apps \
     --pm=pnpm \
     --nxCloud=skip \
     --interactive=false
   ```
3. **Add Nx plugins & generate apps per declared `## Apps` entry:**
   - **Next.js app in Nx (`apps/<app-name>`):**
     ```bash
     pnpm add -D -w @nx/next@latest
     npx nx g @nx/next:application "apps/<app-name>" \
       --appDir=true --style=tailwind --unitTestRunner=jest --e2eTestRunner=playwright --no-interactive
     ```
   - **Angular app in Nx (`apps/<app-name>`):**
     ```bash
     pnpm add -D -w @nx/angular@latest
     npx nx g @nx/angular:application "apps/<app-name>" \
       --standalone=true --routing=true --style=css --unitTestRunner=vitest --e2eTestRunner=playwright --no-interactive
     ```
   - **NestJS app in Nx (`apps/<app-name>`):**
     ```bash
     pnpm add -D -w @nx/nest@latest
     npx nx g @nx/nest:application "apps/<app-name>" \
       --unitTestRunner=jest --no-interactive
     ```
   - **Flutter app inside Nx monorepo (`apps/<app-name>`):**
     ```bash
     mkdir -p apps
     flutter create --org com.example --project-name "<snake_case_app_name>" "apps/<app-name>"
     ```
4. **Verify workspace config:** Confirm `nx.json`, `tsconfig.base.json`, `eslint.config.mjs` (flat config), and per-app `project.json` exist at their expected paths.

---

### B. Angular (`angular` — Single-App or Multi-App Folder)

1. **Check latest CLI:** `npm view @angular/cli version`
2. **Scaffold via `@latest` CLI:**
   ```bash
   npx --yes @angular/cli@latest new <app-name> \
     --directory="<target-dir>" \
     --standalone \
     --routing \
     --style=css \
     --package-manager=pnpm \
     --skip-git \
     --defaults \
     --interactive=false
   ```
3. **Modern baseline:** Standalone components (`standalone: true` default in Angular v19+), Signals + NgRx Signal Store, zoneless/modern change detection, ESLint flat config (`eslint.config.mjs`), Vitest unit testing.
4. **Architectural layer folders & barrels (`src/app/`):**
   ```bash
   mkdir -p "<target-dir>/src/app/core" "<target-dir>/src/app/shared" "<target-dir>/src/app/pages"
   touch "<target-dir>/src/app/core/public-api.ts" \
         "<target-dir>/src/app/shared/public-api.ts" \
         "<target-dir>/src/app/pages/public-api.ts"
   ```

---

### C. Next.js (`nextjs` — Single-App or Multi-App Folder)

1. **Check latest CLI:** `npm view create-next-app version`
2. **Scaffold via `@latest` CLI:**
   ```bash
   npx --yes create-next-app@latest "<target-dir>" \
     --ts \
     --tailwind \
     --eslint \
     --app \
     --src-dir \
     --import-alias "@/*" \
     --use-pnpm \
     --disable-git \
     --yes
   ```
3. **Modern baseline:** Next.js App Router (`src/app/`), `next.config.ts` (or `.mjs`), React Server Components default, Tailwind CSS, ESLint flat config (`eslint.config.mjs`).
4. **Architectural layer folders & barrels (`src/`):**
   ```bash
   mkdir -p "<target-dir>/src/components/ui" \
            "<target-dir>/src/components/shared" \
            "<target-dir>/src/lib" \
            "<target-dir>/src/actions" \
            "<target-dir>/src/stores"
   touch "<target-dir>/src/components/shared/index.ts" \
         "<target-dir>/src/lib/index.ts" \
         "<target-dir>/src/actions/index.ts" \
         "<target-dir>/src/stores/index.ts"
   ```

---

### D. Flutter (`flutter` — Single-App or Multi-App Folder)

1. **Verify SDK & upgrade check:** `flutter --version`
2. **Scaffold via Flutter CLI:**
   ```bash
   flutter create \
     --org com.example \
     --project-name "<snake_case_name>" \
     "<target-dir>"
   ```
3. **Modern baseline:** Latest `flutter_lints` / `custom_lint` in `analysis_options.yaml`, Riverpod (`flutter_riverpod` + `riverpod_annotation`), Freezed (`freezed_annotation` + `json_annotation`).
4. **Architectural layer folders & barrels (`lib/`):**
   ```bash
   mkdir -p "<target-dir>/lib/core" \
            "<target-dir>/lib/shared" \
            "<target-dir>/lib/features" \
            "<target-dir>/lib/domain" \
            "<target-dir>/lib/data" \
            "<target-dir>/lib/ui"
   touch "<target-dir>/lib/core/index.dart" \
         "<target-dir>/lib/shared/index.dart" \
         "<target-dir>/lib/domain/index.dart" \
         "<target-dir>/lib/data/index.dart" \
         "<target-dir>/lib/ui/index.dart"
   ```

---

### E. NestJS (`nestjs` — Single-App or Multi-App Folder)

1. **Check latest CLI:** `npm view @nestjs/cli version`
2. **Scaffold via `@latest` CLI:**
   ```bash
   npx --yes @nestjs/cli@latest new "<target-dir>" \
     --package-manager=pnpm \
     --skip-git \
     --strict
   ```
3. **Modern baseline:** `nest-cli.json`, strict TypeScript (`tsconfig.json`), modular DI layout, Swagger OpenAPI, `ValidationPipe` ready.
4. **Architectural layer folders & barrels (`src/`):**
   ```bash
   mkdir -p "<target-dir>/src/common" \
            "<target-dir>/src/config" \
            "<target-dir>/src/modules" \
            "<target-dir>/src/database"
   touch "<target-dir>/src/common/index.ts" \
         "<target-dir>/src/config/index.ts" \
         "<target-dir>/src/database/index.ts"
   ```

---

## 4. Adapter Setup Dependency Installation & Latest Upgrade

After CLI scaffolding completes, read `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/steps/setup.md` → `## Setup dependencies` for each active app and install latest compatible packages:

1. **Node / TypeScript adapters (`angular`, `nextjs`, `nestjs`):**
   - Run from the app directory (or workspace root with `-w` / `--filter` in Nx/pnpm workspaces):
     ```bash
     pnpm add <js-runtime-dependencies-with-@latest>
     pnpm add -D <js-dev-dependencies-with-@latest>
     ```
2. **Flutter adapter (`flutter`):**
   - Run from the Flutter app directory:
     ```bash
     flutter pub add <flutter-dependencies>
     flutter pub add --dev <flutter-dev-dependencies>
     flutter pub upgrade --major-versions
     ```
3. **Post-scaffold verification gate:**
   - Run static analysis / build smoke check (`flutter analyze` for Flutter; `pnpm run build` or `pnpm run lint` for JS/TS/Nx) to verify zero broken imports or incompatible peer dependencies before moving to Step 3.
