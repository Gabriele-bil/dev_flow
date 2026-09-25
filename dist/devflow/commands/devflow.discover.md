---
name: devflow.discover
description: Explore architectural choices for app creation or complex features, compare technical trade-offs, and generate formal ADRs.
argument-hint: [--app <name>] [--feature <slug>] [topic-or-scope]
disable-model-invocation: true
model: haiku
effort: low
---

Use `@devflow/skills/devflow-discover/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Detect discovery mode: Greenfield (app creation) vs Feature (existing app architecture).
- If monorepo (`## Apps` in `devflow/config.md`), resolve target app first (`--app <name>` or ask).
- Scan problem across the 6 architectural discovery axes (`@devflow/skills/devflow-discover/references/discovery-axes.md`).
- Run interactive context-gathering Q&A loop via `AskQuestion` (≤5 prioritized questions with recommended answers).
- Read existing context (`constitution.md`, `docs/product.md`, `registry.md`) and inspect code when in feature mode.
- Formulate 2–3 distinct architectural options grounded in confirmed context with an explicit trade-off matrix.
- Ask user for architectural decision via `AskQuestion` before finalizing.
- Deliver formal ADR under `docs/adr/ADR-NNN-[title-slug].md` and update `docs/adr/README.md`.
- Conclude with explicit handoff to `/devflow.setup` (app) or `/devflow.task` (feature).

User input:
$ARGUMENTS

If `$ARGUMENTS` is empty, ask user what architectural choice or feature they want to explore.
