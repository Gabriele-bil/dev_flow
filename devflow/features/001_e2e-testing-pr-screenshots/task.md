# Task - AI E2E Testing & Ephemeral PR UI Screenshots

**ID:** TASK-001
**Date:** 2026-10-01
**Status:** draft
**ADRs:** none

---

## Goal & Value

- **Problem:** Developers and AI agents lack a standardized workflow to execute realistic end-to-end and integration tests across web and mobile apps. Additionally, pull request reviewers cannot quickly inspect visual changes without manually saved screenshots that risk cluttering the repository.
- **Objective:** Provide native support for AI-driven end-to-end and integration testing, and introduce automated capture of ephemeral UI screenshots attached to pull requests for UI changes, ensuring immediate deletion of temporary files from the local filesystem.

---

## User Story

**As a** developer using DevFlow to build web and mobile applications  
**I want to** run AI-guided E2E/integration checks and have UI screenshots automatically attached to pull requests without lingering files  
**So that** I can validate critical user flows before merge and provide reviewers with immediate visual evidence while keeping the git working tree clean  

---

## Use Cases & Scenarios

### UC-1: AI-Driven E2E and Integration Test Execution
- **Preconditions:** The feature implementation is complete and the local application/server environment is running or startable.
- **User Flow:**
  1. The system detects the application platform (Web or Mobile/Flutter).
  2. The system executes integration tests or drives interaction (browser or emulator) against the feature's acceptance criteria.
  3. The system verifies clean state transitions, absence of crashes or unhandled runtime errors, and reports results.
- **Outcome:** Structured test report with PASS/FAIL verdicts for each criterion.

### UC-2: Ephemeral UI Screenshot Capture & Pull Request Attachment
- **Preconditions:** The feature includes visual (UI) changes and the test/verification phase passed.
- **User Flow:**
  1. During pull request preparation, the system identifies that the feature touches UI components.
  2. The system captures a visual screenshot of the updated screen (via browser or emulator).
  3. The screenshot is uploaded/embedded into the pull request body (e.g., via GitHub CLI asset upload or preview link).
  4. The local image file is deleted immediately before git staging.
- **Outcome:** The created GitHub Pull Request displays the visual screenshot, while local `git status` remains completely clean.

### UC-3: Non-UI Feature or Headless Environment Bypass
- **Trigger:** The feature touches backend logic, data contracts, or algorithms, or runs in a headless environment without a display.
- **Expected Behavior:** The system detects no UI components were modified or no display is available, gracefully skips screenshot capture, and generates a standard text-only pull request without errors.

### UC-4: Guaranteed Cleanup on Error or Interruption
- **Trigger:** Screenshot capture, upload, or pull request creation fails or is interrupted by the user.
- **Expected Behavior:** The system triggers a cleanup hook/trap that deletes any temporary screenshot files from the working directory, preventing orphan assets from remaining untracked.

---

## Acceptance Criteria

- [ ] **AC-1 (UC-1):** WHEN the test verification step runs for a feature with configured E2E/integration targets, THE SYSTEM SHALL verify user flows against acceptance criteria on browser or emulator and report runtime errors.
- [ ] **AC-2 (UC-2):** WHEN a pull request is generated for a feature that includes user interface changes, THE SYSTEM SHALL capture a visual preview of the modified screen and embed it into the pull request body.
- [ ] **AC-3 (UC-2, UC-4):** WHEN the visual screenshot has been attached to the pull request (or upon error/cancellation), THE SYSTEM SHALL immediately delete the temporary image file from the local filesystem prior to git commit/push.
- [ ] **AC-4 (UC-3):** WHEN a feature does not modify visual components or a graphical runtime is unavailable, THE SYSTEM SHALL create the pull request without attempting screenshot capture and without failing.

---

## Scope Boundaries

**In scope**

- Configuration and conventions for E2E/integration test runtimes on Web (Playwright/MCP) and Mobile/Flutter (Maestro or `integration_test`).
- Ephemeral UI capture mechanism integrated into the pull request creation step (`devflow.pr`).
- Embedding screenshot links/assets into the PR body via GitHub CLI (`gh`).
- Guaranteed deletion (`trap` cleanup or post-upload removal) before staging files into git.

**Out of scope (Not doing)**

- Building or hosting a proprietary cloud screenshot service (rely on native GitHub PR/issue attachment mechanisms).
- Pixel-by-pixel automated visual regression diffing with color tolerances.
- Forcing visual capture on headless backend or pure library features.

---

## Notes

- For ephemeral PR attachments, the GitHub CLI (`gh`) supports image uploads in issue/PR descriptions, followed by local `rm -f`.
- Temporary files must be stored in `/tmp/` or a path ignored by `.gitignore` to prevent accidental commits.
