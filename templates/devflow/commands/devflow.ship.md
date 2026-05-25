---
name: devflow.ship
description: Pre-merge gate before devflow.pr. Dispatches code-reviewer, security-auditor, and test-engineer in parallel, synthesizes reports, and routes to devflow.pr if no blockers. Use when devflow.test is complete and the feature is ready for final review before PR.
argument-hint: [optional notes for reviewers]
disable-model-invocation: true
model: sonnet
effort: high
---

Use `@devflow/skills/devflow-ship/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Verify all Step 0 input contract checks before dispatching agents.
- Dispatch `code-reviewer`, `security-auditor`, and `test-engineer` simultaneously — not sequentially.
- Write the full Ship Gate Report before making the gate decision.
- On gate pass, execute `devflow-pr` skill directly without asking for confirmation.

Optional notes for reviewers:
`$ARGUMENTS`
