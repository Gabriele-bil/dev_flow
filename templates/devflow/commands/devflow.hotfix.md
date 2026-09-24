---
name: devflow.hotfix
description: Fast-track pipeline for critical bugfixes, targeted patches, or hotfixes — compact task+plan, implement, targeted test, and quick ship gate directly to PR.
argument-hint: <bug-description>
disable-model-invocation: true
---

Use `@devflow/skills/devflow-hotfix/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Scaffold compact `task.md` (problem statement, root cause, ACs) and `plan.md` (quick complexity, bottom-up order).
- Create and switch to `fix/[NNN]-[name]` branch.
- Implement the targeted fix and run adapter linter.
- Write regression test and verify all tests pass.
- Run single-agent ship review (`code-reviewer.md`) for quick gate check.
- Open PR to default branch with hotfix summary and checklist.
