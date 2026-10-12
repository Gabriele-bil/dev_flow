# Task notify-user template

Used by `devflow.task` Step 11 — respond with this format after `task.md` is written.

```text
✅ Task created: devflow/features/[NNN]_[feature-name]/task.md
Branch: [feat/fix/chore/doc/ecc...]/[number-of-task-is-present]_[feature-name]

[User story in 1 line]

docs/product.md: [updated | not found — create with devflow.setup]

[[NEEDS CLARIFICATION] markers present? → devflow.clarify (recommended before devflow.plan)]
Continue to planning? → devflow.plan
```
