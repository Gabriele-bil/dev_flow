---
name: devflow-hotfix
description: Fast-track pipeline for critical bugfixes, targeted patches, or hotfixes. Chains compact task+plan, failing regression test, minimal fix, full test suite + verification, then PR — no beautify, no ship review. Use when user runs devflow.hotfix, provides an urgent bug fix, or asks for a quick patch without full pipeline overhead.
argument-hint: "<bug-or-issue-description>"
disable-model-invocation: true
---


# Skill: devflow.hotfix

## Purpose

Fast path for critical bugs and regressions: compact `task.md` + `plan.md`, regression test red → green, minimal fix, full suite + `verification.md`, PR. Skips `beautify` and the `ship` review — the failing-then-passing regression test and the green suite are the gate; the PR review is the human one.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`
- **regression-tested** — every hotfix ships a test that failed before the fix and passes after
- **minimal scope** — root cause only, 1–3 files; anything bigger is a feature

## When NOT to Use

- New feature or refactor — use `devflow.task` or `devflow.auto`
- Multi-PR work or migrations — use `devflow.blueprint`
- Fix touches auth, payments, or security boundaries — use the full pipeline (ship's `security-auditor` gate)
- Already mid-pipeline on a feature — continue its normal steps

## Input contract

- [ ] Bug description in `$ARGUMENTS` (symptom, error, or broken behavior) — empty → ask
- [ ] `devflow/config.md` present; monorepo → target **App** known (ask — never guess)
- [ ] Working tree has no unrelated source/config changes (stash or commit first)

Any item fails → stop, report check, touch nothing.

## Workflow

Transitions: `ready → implementing → implemented → tested → shipped → pr-opened`. Every boundary: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" set plan <status>`.

### Step 1 - Diagnose + compact spec

1. Diagnose root cause (file/function) read-only, before writing anything.
2. `NNN` = `.devflow-state.json` `next_feature_number`, else highest `devflow/features/` prefix + 1 (never reuse). Dir `[NNN]_hotfix-[kebab-name]`.
3. `task.md` from `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/task-template.md`: full header (`**Status:** draft`, `**Branch:** fix/[NNN]_hotfix-[kebab-name]`, `**App:**` monorepo only); Problem = symptom, Objective = fixed behavior; `UC-1`; `AC-1 (UC-1)` fixed behavior (Gherkin); `AC-2 (UC-1)` regression test fails before fix, passes after; root cause in `## Notes`. Other sections: one line or `none`.
4. `plan.md` from `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-plan/references/plan-template.md`: header (`**Status:** ready`, `**Complexity:** N (quick)`, `**App:**` copied); Overview = root cause; Traceability row per AC; File List 1–3 `[pending]` entries, regression test first.
5. `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" branch fix/[NNN]_hotfix-[kebab-name]`.

### Step 2 - Failing test, then fix

1. Resolve adapter + app per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md`; read `steps/test.md`, `steps/implement.md`. Status `implementing`.
2. Write regression test (AC-2); run it. Must FAIL for the reported reason (Prove-It). Passes → root cause wrong → back to Step 1.1.
3. Minimal fix at root cause, File List files only. Needs >3 files or design → stop, route `devflow.task`.
4. Regression test passes; adapter format + analyze clean (monorepo: `(cd "<app-path>" && …)`). Mark entries `[done]`; Status `implemented`.

### Step 3 - Verify

1. Full adapter test suite; failures per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/escalation-ladder.md` (max 3 bounded attempts → block).
2. `verification.md` per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/verification-levels.md` — AC-1, AC-2 with evidence, zero FAIL. Status `tested`, then `shipped`.

### Step 4 - PR

Execute `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-pr/SKILL.md` exactly — base-branch detection, artifact cleanup, commit, push, PR body, `pr-opened` + task `done`, follow-up status commit and push. Never hand-roll `gh pr create`.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Regression test written green-first | Failing test before fix, every time |
| Scope creep into refactors | Root cause only; cleanups get their own task |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | Bug report from `$ARGUMENTS`, codebase, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md`, adapter `steps/test.md` + `steps/implement.md` |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/task-template.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-plan/references/plan-template.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/verification-levels.md` |
| Writes | `devflow/features/[NNN]_hotfix-[name]/task.md`, `plan.md`, `verification.md`, fix files, regression test, `.devflow-state.json` (via `devflow-state.sh`) |
| Side effects | Branch `fix/*` from up-to-date base |
| Next step | `devflow-pr` (executed in Step 4) |
