---
name: devflow.clarify
description: Optional interactive session between devflow.task and devflow.plan. Resolves [NEEDS CLARIFICATION ...] markers and high-risk assumptions in task.md via structured Q&A, then sets Status clarified.
argument-hint: "[optional-task-path]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-clarify/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature per `@devflow/references/state-machine.md` → **Active feature resolution**.
