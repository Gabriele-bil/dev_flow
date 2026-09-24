---
name: devflow-hotfix
description: Fast-track pipeline for critical bugfixes, targeted patches, or hotfixes. Chains compact task+plan, implement, targeted test, and quick single-agent ship gate directly into PR. Use when user runs devflow.hotfix, provides an urgent bug fix, or asks for a quick patch without full 8-step overhead.
argument-hint: <bug-or-issue-description>
disable-model-invocation: true
---

# Skill: devflow.hotfix

Accelerated DevFlow pipeline execution for urgent bugfixes and targeted patches.

## Purpose

Provides a streamlined, token-efficient pipeline for critical bugs, regressions, or hotfixes where running all 8 manual pipeline steps is disproportionate to the fix scope. Generates a compact task and plan, implements the fix, verifies with targeted regression tests, runs a focused single-agent ship review (`code-reviewer`), and opens the PR.

## Core Principles

- **spec-light-not-spec-free** — even a 1-line hotfix requires a problem statement, root cause, and acceptance criteria in `task.md`
- **regression-tested** — every hotfix must include at least one test proving the bug is resolved
- **safe-acceleration** — skips `beautify` and multi-agent fan-out, but maintains linter/compiler checks, single-agent review, and PR traceability
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- New feature development or large architectural refactors — use standard `devflow.task` or `devflow.auto`
- Multi-PR features or migrations — use `devflow.blueprint`
- When you are already in the middle of a standard feature pipeline — continue with normal steps

## Workflow

### Step 1 - Generate Compact Task and Plan

1. Resolve next feature number from `devflow/features/` or `.devflow-state.json`.
2. Name feature `hotfix-[kebab-name]` (e.g. `005_hotfix-auth-token-expiry`).
3. Scaffold `task.md` with:
   - **Problem Statement**: Symptom, error message, or broken behavior.
   - **Root Cause**: Identified file/function causing the defect.
   - **Acceptance Criteria**: AC1 (fix behavior), AC2 (regression test added).
4. Scaffold `plan.md`:
   - `**Complexity:** quick`
   - `**Status:** ready`
   - File list with bottom-up dependency ordering (typically 1–3 files).
5. Create and switch to git branch `fix/[NNN]-[name]`.
6. Update `.devflow-state.json` to mark active feature and `plan_status: ready`.

### Step 2 - Implement the Fix

1. Resolve active adapter per `@devflow/references/adapter-resolution.md`.
2. Apply targeted code changes strictly necessary to resolve the root cause.
3. Save pre-step checkpoint tag: `git tag -f "devflow-checkpoint/$(git branch --show-current)/implement" HEAD`.
4. Run adapter format and lint commands (`dart format`/`flutter analyze` or `pnpm lint`).
5. Update `plan.md` File List entries to `[done]` and set `**Status:** implemented`.

### Step 3 - Regression Testing & Verification

1. Write a targeted regression test covering the defect in the appropriate test suite.
2. Run adapter test commands (`flutter test` or `pnpm test`).
3. If test fails: apply bounded retry (up to 3 attempts).
4. Generate `verification.md` confirming:
   - Regression test passes
   - Full test suite passes with zero regressions
5. Set `plan.md` `**Status:** tested`.

### Step 4 - Fast-Track Ship Gate

1. Run single-agent review (`quick` complexity profile):
   - Dispatch `@devflow/agents/code-reviewer.md` to evaluate touched files across correctness, security, and scope fidelity.
2. If review flags Critical or Required findings: resolve them immediately.
3. Once clean, set `plan.md` `**Status:** shipped`.

### Step 5 - Open Pull Request

1. Commit changes with conventional commit prefix (`fix: [description]`).
2. Push branch `fix/[NNN]-[name]` to remote.
3. Open PR toward default branch (`main`) with hotfix summary and checklist.
4. Set `plan.md` `**Status:** pr-opened` and `task.md` `**Status:** done`.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Committing code without `task.md` or `plan.md` | Hotfix writes compact specs first; never bypass specification entirely. |
| Skipping regression tests | Every bugfix must prove the defect is resolved with an automated test. |
| Expanding hotfix scope to unrelated refactors | Keep hotfix strictly scoped to the defect; file separate tasks for cleanups. |

## I/O Reference

| | |
| --- | --- |
| Reads | Bug report from `$ARGUMENTS`, existing codebase, active adapter contract |
| Writes | `devflow/features/[NNN]_hotfix-[name]/task.md`, `plan.md`, `verification.md`, application fix files, test file |
| Side effects | Creates branch `fix/*`, commits changes, pushes, opens GitHub PR |
| Next step | Pipeline complete (PR open for review) |
