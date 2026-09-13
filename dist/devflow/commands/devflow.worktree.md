---
name: devflow.worktree
description: Create, list, or remove isolated git worktrees for parallel DevFlow feature development, with dev-server port-offset assignment.
argument-hint: [create|remove|list] [feature-name]
disable-model-invocation: true
model: haiku
effort: low
---

Use `@devflow/skills/devflow-worktree/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Parse `$ARGUMENTS` as `[create|remove|list] [feature-name]`; default subcommand `create`.
- `create`: run overlap detection against `.devflow-worktrees.json` before creating anything; assign a port offset from the adapter's base dev port.
- `remove`: confirm with the user before `git worktree remove --force` — it discards uncommitted work in that worktree.

$ARGUMENTS
