---
name: devflow.clarify
description: Optional interactive session between devflow.task and devflow.plan. Resolves [NEEDS CLARIFICATION ...] markers and high-risk assumptions in task.md via structured Q&A, then sets Status clarified.
argument-hint: [optional-task-path]
disable-model-invocation: true
model: haiku
effort: low
---

Use `@devflow/skills/devflow-clarify/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Read `task.md` and run the 8D scan from `refinement-hints.md` before generating questions.
- Generate at most 5 prioritized questions — ask one at a time via the `AskQuestion` tool (multi-choice where possible).
- After each accepted answer: update the relevant `task.md` section, remove the resolved `[NEEDS CLARIFICATION: ...]` marker if present, and record the Q&A pair in `## Clarifications`.
- Do not rewrite `## Summary` to incorporate answers — preserve original wording; minimal term-normalization edits only.
- After the loop: set `**Status:** clarified` and output a Clarification Summary with resolved / skipped / remaining marker counts.

Optional input (task path):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the task at `devflow/features/*/task.md` with the **highest existing `NNN_` numeric prefix** and proceed.
