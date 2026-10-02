# Plan - AI E2E Testing & Ephemeral PR UI Screenshots

**ID:** PLAN-001
**Task:** [task.md](file:///Users/gabrielebilello/Developer/dev_flow/devflow/features/001_e2e-testing-pr-screenshots/task.md)
**ADRs:** none
**Date:** 2026-10-02
**Status:** pr-opened
**Complexity:** 10 (standard)

---

## Overview

Adds standardized AI-driven E2E/integration testing workflows and automated ephemeral UI screenshot attachments for pull requests. Integrates Web (Playwright/browser tools) and Mobile/Flutter (Maestro/integration_test) verification conventions into test skills and adapter step definitions. Implements UI change detection, headless bypass, `/tmp/`-scoped image capture with shell `trap` cleanup, and native `gh pr create --attach` upload in `devflow.pr`. Execution split across two vertical slices: Slice 1 (E2E testing conventions) and Slice 2 (ephemeral PR screenshot capture & cleanup).

---

## Architecture decisions

- **ADR alignment:** None / standard DevFlow plugin patterns.
- **Vertical slicing:** 2 end-to-end user-visible increments — Slice 1 defines test execution and goal-backward runtime verification across platforms; Slice 2 delivers automated UI screenshot capture, PR attachment, and guaranteed temp file cleanup.
- **Ephemeral PR upload via `gh` CLI:** Use native GitHub CLI `gh pr create --attach "$IMG#UI Preview"` (or inline markdown rewrite). Avoids external cloud storage dependencies and keeps local git working tree clean.
- **Guaranteed cleanup mechanism:** Store temporary screenshot files strictly in `/tmp/devflow-ui-preview-${FEATURE}.png` outside git working tree. Wrap capture and upload in bash subshell with `trap 'rm -f "$TEMP_IMG"' EXIT INT TERM` ensuring deletion on success, failure, or interruption.
- **Headless and non-UI bypass:** Detect UI changes by inspecting git diff and `plan.md` `[ui]` markers. Skip screenshot capture gracefully without errors when no UI files are modified or when running in headless environment without display/emulator/browser runner.

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Orphan temp files if capture interrupted | Med | Shell `trap 'rm -f "$TEMP_IMG"' EXIT INT TERM` guarantees cleanup; temp path in `/tmp/` outside repo |
| Older GitHub CLI version lacking `--attach` flag | Low | Check `gh` version or fallback to embedding local path with graceful error bypass |
| Flaky or slow emulator/browser startup | Med | Keep E2E verification scoped strictly to acceptance criteria flows; provide headless flags and clear error diagnostics |
| False-positive UI detection on non-UI changes | Low | Inspect changed file extensions and directory paths (`lib/ui/`, `src/app/`, `.tsx`, `.vue`) in addition to `[ui]` tags |

---

## Traceability

| Use Case / Subtask | Acceptance criteria | File(s) |
|---------------------|---------------------|---------|
| UC-1: AI-Driven E2E and Integration Test Execution | AC-1: Verify user flows against ACs on browser or emulator and report runtime errors | `templates/devflow/skills/devflow-test/SKILL.md`<br>`templates/devflow/references/verification-levels.md`<br>`templates/devflow/adapters/flutter/steps/test.md` |
| UC-2: Ephemeral UI Screenshot Capture & PR Attachment | AC-2: Capture visual preview of modified screen and embed into PR body via GitHub CLI | `templates/devflow/skills/devflow-pr/SKILL.md`<br>`templates/devflow/adapters/flutter/steps/pr.md`<br>`templates/devflow/adapters/nextjs/steps/pr.md`<br>`templates/devflow/adapters/angular/steps/pr.md`<br>`templates/devflow/evals/cases/devflow-pr.json` |
| UC-3: Non-UI Feature or Headless Environment Bypass | AC-4: Skip screenshot capture without failure when non-UI or graphical runtime unavailable | `templates/devflow/skills/devflow-pr/SKILL.md` |
| UC-4: Guaranteed Cleanup on Error or Interruption | AC-3: Immediately delete temporary screenshot files from local filesystem prior to git staging | `templates/devflow/skills/devflow-pr/SKILL.md` |

---

## File List

Ordered by implementation sequence.

**Batch:** M

**Slice 1 — AI-Driven E2E & Integration Testing Runtime Conventions** (deps: none)

### 001. `templates/devflow/references/verification-levels.md` - modify [done]
Extend Level 4b definition to include Mobile/Flutter E2E (Maestro, `integration_test` on emulator) alongside Web Playwright/browser tools.

### 002. `templates/devflow/skills/devflow-test/SKILL.md` - modify [done]
Update Step 3 and Step 6b with explicit workflows for platform detection (Web vs Mobile/Flutter), automated E2E execution, and runtime error reporting against acceptance criteria.

### 003. `templates/devflow/adapters/flutter/steps/test.md` - modify [done]
Document Maestro test conventions alongside Flutter `integration_test` for mobile UI flow verification and headless/emulator execution.

**Batch:** M

**Slice 2 — Ephemeral UI Screenshot Capture & Guaranteed Cleanup** (deps: 1)

### 004. `templates/devflow/skills/devflow-pr/SKILL.md` - modify [done]
Add UI change detection, headless environment bypass, ephemeral screenshot capture into `/tmp/`, bash `trap` cleanup on EXIT/INT/TERM, and `gh pr create --attach` integration.

### 005. [P] `templates/devflow/adapters/flutter/steps/pr.md` - modify [done]
Add UI screenshot attachment verification to Flutter PR step checklist and pre-push requirements.

### 006. [P] `templates/devflow/adapters/nextjs/steps/pr.md` - modify [done]
Add UI screenshot attachment verification to Next.js PR step checklist and pre-push requirements.

### 007. [P] `templates/devflow/adapters/angular/steps/pr.md` - modify [done]
Add UI screenshot attachment verification to Angular PR step checklist and pre-push requirements.

### 008. [P] `templates/devflow/evals/cases/devflow-pr.json` - modify [done]
Add eval trigger cases validating ephemeral PR screenshot and UI attachment intent routing.

---

## Implementation checkpoints

- **After Slice 1 (E2E & Integration Testing Conventions):**
  - Run skill validation: `bash templates/devflow/scripts/validate-skills.sh --strict`
  - Verify `templates/devflow/references/verification-levels.md` and `devflow-test/SKILL.md` consistency.
- **After Slice 2 (Ephemeral UI Screenshot & PR Attachment):**
  - Run skill validation: `bash templates/devflow/scripts/validate-skills.sh --strict`
  - Run evals: `bash templates/devflow/scripts/run-evals.sh`
  - Rebuild plugin: `bash scripts/build-plugin.sh`
  - Verify clean git status: no orphan temporary files in repo tree.

---

## Edge Cases & Error Handling

- **Headless CI / No display available:** `devflow-pr` detects lack of display (`$DISPLAY` unset, headless flag, or no emulator/browser session) and skips screenshot capture without failing the PR process.
- **Feature without UI changes:** `devflow-pr` checks git diff for modified UI components or `plan.md` `[ui]` markers; if absent, bypasses screenshot capture and proceeds with standard text-only PR.
- **Process cancellation (SIGINT/SIGTERM):** Trap handler `trap 'rm -f "$TEMP_IMG"' EXIT INT TERM` ensures `/tmp/devflow-ui-preview-${FEATURE}.png` is unlinked even if user interrupts `gh pr create`.
- **`gh` CLI lacks `--attach` support:** Fall back to regular PR creation with warning, ensuring PR creation does not hard-block.

---

## Pre-implement checklist

- [x] Constitution Gate passed (Step 0b) — no Critical violations
- [x] Every `task.md` use case / subtask appears in **Traceability** with its acceptance criterion
- [x] Every **File List** entry maps to ≥1 **Traceability** row — no orphan/gold-plated files
- [x] **File list** order respects **Dependency ordering** (and any stated exceptions)
- [x] All **adapter-specific sections** from `ADAPTER.md` are present or correctly omitted per adapter rules (e.g. i18n keys for UI)
- [x] **Implementation checkpoints** are actionable (commands per `ADAPTER.md` — analyze / tests / smoke)
- [x] **Open questions** are empty or resolved if **Status** is `ready`
- [x] Existing shared components checked; no duplication of a component already in `shared/`
- [x] New reusable components identified in this plan are listed under their `shared/` path in the **File List**
- [ ] `devflow.analyze` run (or explicitly waived) — no Critical findings
- [x] If feature touches persistent entities → `data-model.md` exists and is non-empty (N/A)
- [x] `**Complexity:**` recorded per `references/complexity-scoring.md` — profile floor applied (auth/migrations/input → minimum `standard`)
