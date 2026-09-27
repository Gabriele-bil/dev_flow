# Interactive Interview & Structured Clarification Reference

Guidelines for conducting structured user interviews and clarification loops in DevFlow (`devflow.clarify`, `devflow.task`, `devflow.discover`, and `devflow.plan`).

## Purpose

Unstructured open-ended questioning creates cognitive friction, ambiguous answers, and stalled pipelines. Structured elicitation presents concrete, bounded options with a recommended default, enabling fast decisions while preserving user control.

## Multi-Platform Tool Invocation

DevFlow runs in multiple agentic hosts. Use the appropriate interactive questioning tool:

| Environment | Primary Tool | Tool Call Pattern |
| ----------- | ------------ | ----------------- |
| **Antigravity** | `ask_question` | `ask_question(questions=[{question: "...", options: ["(Recommended) ...", "..."], is_multi_select: false}])` |
| **Claude Code** | `AskQuestion` | `AskQuestion(questions=[{question: "...", options: ["(Recommended) ...", "..."]}])` |
| **CLI / Fallback** | Chat Prompt | Formatted markdown block with numbered choices, explicit recommendation, and write-in prompt |

### Core Questioning Rules

1. **One question at a time:** Do not batch multiple questions into a single tool invocation unless the decisions are strictly coupled. Each answer shapes the next question.
2. **2 to 4 options:** Keep choices distinct and mutually exclusive. Avoid overwhelming menus.
3. **Recommended option first:** Always prefix the primary choice with `(Recommended)` and append a concise technical rationale (e.g. `"(Recommended) Use SQLite with WAL mode — eliminates external service dependency for local-first architecture"`).
4. **Direct user response phrasing:** Phrase options from the user's perspective (e.g. `"Use optimistic UI with rollback on error"` instead of `"The agent should use optimistic UI..."`).
5. **No redundant 'Other' option:** Do not add a manual "Other" or "None of the above" option. Host tools provide automatic write-in fallbacks.
6. **Single vs multi-select:** Default to `is_multi_select: false`. Enable multi-select only when choices represent independent, non-exclusive features or settings.
7. **Maximum 5 questions per session:** Keep elicitation token-lean and high-leverage. Focus on architectural forks, scope boundaries, and critical acceptance criteria.

## Automated / Run Mode (`.devflow-run.json`)

When running in unattended or automated mode (`.devflow-run.json` present):

- Do NOT pause or block on interactive questions (unless missing monorepo `**App:**`).
- Auto-select the `(Recommended)` option as the defensible default.
- Precedence order for defaults: repository precedent > `constitution.md` / `docs/product.md` > conservative / fail-closed design.
- Record each assumed decision with its rationale in `task.md` (`## Notes` or `## Clarifications`) or `plan.md` (`## Decision flags`).

## Deep Architectural Grilling (`/grill-me`)

When planning or discovering complex features where trade-offs span multiple services or data models:

- Suggest the **/grill-me** slash command to the user if they wish to stress-test their requirements against failure modes, edge cases, and scale constraints before locking `task.md` or `plan.md`.
