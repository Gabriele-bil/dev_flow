# devflow-init — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Dumping all interview questions in one wall of text | Overwhelms user and skips adaptive follow-ups | Ask bounded questions via `ask_question` (independent ones batched, ≤4 per call) with `(Recommended)` first |
| Using legacy stack flags (`--no-standalone`, Pages router, `.eslintrc.json`) | Violates adapter rules and modern stack baselines | Follow `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-init/references/scaffolding-matrix.md` and live `context7` docs |
| Leaving circular blockers between tasks (`002` ↔ `003`) | Deadlocks planning and implementation order | Extract shared contracts/types into foundation task `001` before consumers |
| Omitting `**Blockers:**` / `**Unlocks:**` in generated `task.md` files | Downstream `devflow.plan` cannot verify unblocked execution order | Populate explicit `**Blockers:**` and `**Unlocks:**` headers in every roadmap `task.md` |
| Writing Technical Personas ("As a backend developer") in `task.md` | Violates `devflow-task` product-only spec discipline | Use real human or external system actors and functional BDD Gherkin ACs |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Hardcode standard package versions in package.json/pubspec.yaml to save time" | Hardcoded versions rot immediately. Query `context7` / registry and use `@latest` CLIs |
| "Generate only task 001 now and let user run devflow.task later" | `devflow.init` contract requires full project decomposition (`001..NNN`) with verified DAG upfront |
| "Create and switch git branches for each task during batch generation" | Switching branches N times leaves tasks scattered or dirty. Stay on `main` and record `**Branch:**` in `task.md` |
| "Skip final `.devflow-state.json` write since `post-task-create.sh` runs automatically" | Hook only sets `next_feature_number` from last task `NNN`; final write is required to point `feature` to `001` |
| "Write `tsconfig.json` or `eslint.config.mjs` directly via Write tool" | `pre-config-protect.sh` blocks Write/Edit on linter/tsconfig files; scaffold via official CLI commands in Bash |
