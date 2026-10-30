---
name: devflow-hotfix
description: Fast-track pipeline for critical bugfixes, targeted patches, or hotfixes. Chains compact task+plan, implement, targeted test, and quick single-agent ship gate directly into PR. Use when user runs devflow.hotfix, provides an urgent bug fix, or asks for a quick patch without full 8-step overhead.
argument-hint: "<bug-or-issue-description>"
disable-model-invocation: true
---


# Skill: devflow.hotfix

Accelerated DevFlow pipeline execution for urgent bugfixes and targeted patches.

## Purpose

Provides a streamlined, token-efficient pipeline for critical bugs, regressions, or hotfixes where running all 8 manual pipeline steps is disproportionate to the fix scope. Generates a compact task and plan, implements the fix, verifies with targeted regression tests, runs a focused single-agent ship review (`code-reviewer`), and opens the PR.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`
- **regression-tested** — every hotfix includes at least one test proving the defect is resolved
- **safe-acceleration** — skips `beautify` and multi-agent fan-out, while keeping linter/compiler checks, single-agent review, and PR traceability

## When NOT to Use

- New feature development or large architectural refactors — use standard `devflow.task` or `devflow.auto`
- Multi-PR features or migrations — use `devflow.blueprint`
- When you are already in the middle of a standard feature pipeline — continue with normal steps

## Input contract

- [ ] Bug description in `$ARGUMENTS` (symptom, error, or broken behavior) — empty → ask
- [ ] `devflow/config.md` present; monorepo → target **App** known (ask — never guess)
- [ ] Working tree has no unrelated source/config changes (stash or commit first)

Any item fails → stop, report check, touch nothing.

## Workflow

Fast-track transitions: `ready → implementing → implemented → tested → shipped → pr-opened` (beautify skipped). Every boundary: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" set plan <status>` (legal for the fast-track).

### Step 1 - Compact task + plan from real templates

1. `NNN` = `.devflow-state.json` `next_feature_number`, else highest `devflow/features/` prefix + 1 (never reuse). Dir `[NNN]_hotfix-[kebab-name]`; branch `fix/[NNN]_hotfix-[kebab-name]`.
2. Diagnose root cause (file/function) before writing anything — read-only.
3. `task.md` from `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/task-template.md`: full header (`**ID:**`, `**Date:**`, `**Status:** draft`, `**Branch:**`, `**App:**` monorepo only); Goal & Value (Problem = symptom, Objective = fixed behavior); `UC-1` fixed path; `AC-1 (UC-1)` fixed behavior (Gherkin); `AC-2 (UC-1)` regression test fails before fix, passes after; root cause in `## Notes`. Other template sections: one line or `none`.
4. `plan.md` from `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-plan/references/plan-template.md`: header (`**Task:**`, `**App:**` copied, `**Status:** ready`, `**Complexity:** N (quick)`); Overview = root cause; **Traceability** row per AC → file(s); **File List** 1–3 entries `[pending]`, regression test file first; Implementation checkpoints = adapter test + analyze commands.
5. Branch from the up-to-date base branch: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" branch fix/[NNN]_hotfix-[name]`.

### Step 2 - Checkpoint, then failing test first

1. Resolve adapter + app per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md`; read `steps/test.md`, `steps/implement.md`.
2. **Before any code edit:** `git tag -f "devflow-checkpoint/$(git branch --show-current)/implement" HEAD`; Status `implementing`.
3. Write regression test (AC-2) per adapter test conventions; run it. Must FAIL for the reported reason (Prove-It). Passes → root cause wrong → back to Step 1.2; never fix against a green test.

### Step 3 - Fix

1. Minimal change at root cause; only File List files. Scope grows beyond 3 files or needs design → stop, route `devflow.task`.
2. Regression test passes; adapter format + analyze clean (monorepo: `(cd "<app-path>" && …)`).
3. Mark entries `[done]`; Status `implemented`.

### Step 4 - Verify

1. Full adapter test suite; failures per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/escalation-ladder.md` (max 3 bounded attempts → block).
2. Write `verification.md` per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/verification-levels.md` — AC-1, AC-2 with evidence; zero FAIL.
3. Status `tested`.

### Step 5 - Quick ship gate

Dispatch `$HOME/.gemini/antigravity-cli/plugins/devflow/agents/code-reviewer.md` (= `devflow.ship` `quick` profile) on touched files. Critical/Required → fix → back to Step 3 (tests + `verification.md` regenerated). Clean → Status `shipped`.

### Step 6 - PR

Execute `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-pr/SKILL.md` exactly — base-branch detection, artifact cleanup, commit, push, PR body, `pr-opened` + task `done`. Never hand-roll `gh pr create`.

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Tag after fix — same commit anyway" | Tag before first edit is the rollback point; after-fix tag restores the fix |
| "Write test after fix, it passes, done" | Test never seen failing proves nothing — Prove-It |
| "Hotfix spec can skip Traceability/Branch" | `devflow.backprop`, `devflow.analyze`, `devflow.rollback`, `devflow.pr` read them |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Committing code without `task.md` or `plan.md` | Compact specs from real templates first |
| Skipping regression test or writing it green-first | Failing test before fix, every time |
| Expanding hotfix scope to unrelated refactors | Strictly scoped; separate tasks for cleanups |
| Hardcoded `main` / own `gh pr create` | Hand off to `devflow-pr` (base detection, cleanup) |

## I/O Reference

| | |
| --- | --- |
| Reads | Bug report from `$ARGUMENTS`, codebase, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md`, adapter `steps/test.md` + `steps/implement.md` |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-task/references/task-template.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-plan/references/plan-template.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/verification-levels.md` |
| Writes | `devflow/features/[NNN]_hotfix-[name]/task.md`, `plan.md`, `verification.md`, fix files, regression test, `.devflow-state.json` (merge) |
| Side effects | Branch `fix/*` from `origin/<default>`, tag `devflow-checkpoint/<branch>/implement` |
| Next step | `devflow-pr` (executed in Step 6) |
