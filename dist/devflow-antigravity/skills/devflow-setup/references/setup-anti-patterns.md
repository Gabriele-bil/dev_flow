# Setup Anti-Patterns Reference

Full catalog of setup anti-patterns, symptoms, and required fixes.

## Anti-Patterns Catalog

| Anti-Pattern | Fix |
| --- | --- |
| Writing files inside `devflow/features/` during setup | Write only to consumer project root; `devflow/` is read-only during setup. |
| Skipping the questionnaire and guessing adapter | Always run the full questionnaire; no defaults. |
| Regenerating setup files without `--force` on existing project | Check for managed markers; preserve non-managed content. |
| Installing setup dependencies globally | Use project package manager (`pnpm add`, `flutter pub add`). |
| Leaving `[TODO: fill]` placeholders before routing to `devflow.task` | Fill all placeholders first. |
| Generating marker-less content | Wrap all managed content with `<!-- devflow-managed:start / :end -->`. |
| Appending managed blocks onto marker-less DevFlow-looking content | Surface conflict, ask replace-or-append; duplicate sections corrupt consumer context files. |
| Expanding templates with long narrative prose | Output must be token-lean, imperative, filler-free. |
| Using adapter template that doesn't exist without fallback | Fall back to global templates if adapter template missing. |
| Auto-scanning the repo tree for apps, or forcing an `apps/<name>/` convention | Apps are declared explicitly by the user — ask, never infer from folder layout. |
| Forking AGENTS/REGISTRY/CONSTITUTION/PRODUCT template files into "monorepo variants" | Business logic belongs in this skill, not templates — same template files render both modes; only the writing rules (Step 6) differ. |
| Duplicating per-app commands into REGISTRY.md instead of pointing at `@devflow/config.md` | Second source of truth drifts; pointer line only. |
