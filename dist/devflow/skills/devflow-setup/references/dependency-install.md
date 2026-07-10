# Setup dependency install rules

Used by `devflow.setup` Step 7c — after successful file writes, install dependencies declared in the active adapter `Setup dependencies` section.

Rules:

1. Execute installs from the consumer project root only.
2. Detect runtime first:
   - Flutter project: `pubspec.yaml` exists → use Flutter commands.
   - JavaScript project: `package.json` exists → detect package manager in order:
     - `pnpm-lock.yaml` → `pnpm`
     - `yarn.lock` → `yarn`
     - `package-lock.json` → `npm`
     - none found → default `npm`
3. Install only packages listed in adapter `Setup dependencies`. Do not invent package names.
4. Command mapping:
   - JS runtime deps:
     - `pnpm add <packages>`
     - `yarn add <packages>`
     - `npm install <packages>`
   - JS dev deps (if adapter lists them):
     - `pnpm add -D <packages>`
     - `yarn add -D <packages>`
     - `npm install -D <packages>`
   - Flutter deps:
     - Prefer a single `flutter pub add <packages>` call per dependency bucket.
     - If adapter requires versions, keep exact constraints from adapter contract.
5. If install command fails:
   - stop setup flow
   - report exact failed command and stderr
   - do not claim setup complete
6. If dependency set is empty for active adapter:
   - skip install step
   - report `Dependency install skipped (none declared)`.
