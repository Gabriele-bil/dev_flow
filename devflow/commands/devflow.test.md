---
name: devflow.test
description: Write and execute DevFlow feature tests using the devflow-test skill workflow.
argument-hint: [optional-plan-path]
disable-model-invocation: true
model: sonnet
effort: medium
---

Use `@devflow/skills/devflow-test/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Test only the current feature’s touched files; mirror `lib/` under `test/` and use `integration_test/features/[feature-name]/` per the skill.
- For **bugfixes**, prefer a **failing test that reproduces the bug first** (Prove-It), then fix, then run the relevant suite and broader tests as the skill directs.
- Run unit tests and integration tests (Android emulator, then Chrome) with the skill’s commands; cap retries per failing test as in the skill.
- Report with **raw command output**, not a vague “all passed” summary.
- If failures persist after the retry budget, use **systematic debugging** before speculative changes.

Optional input (plan path):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the plan at `devflow/features/*/plan.md` with the **highest existing `NNN_` numeric prefix** and proceed.
