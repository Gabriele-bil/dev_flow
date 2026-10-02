# Task file template

Used by `devflow.task` Step 9 — write `devflow/features/[NNN]_[feature-name]/task.md` using this format.

```markdown
# Task - [Feature Name]

**ID:** TASK-[NNN]
**Date:** [YYYY-MM-DD]
**Status:** draft
**App:** [name] <!-- omit entire line when devflow/config.md has no ## Apps table (single-app repos) -->
**ADRs:** [docs/adr/ADR-NNN-...md or "none"] <!-- optional reference to architectural decisions from devflow.discover -->

---

## Goal & Value

- **Problem:** [1-2 sentences on the user pain point or current gap. Never copy raw input verbatim.]
- **Objective:** [Concrete outcome, business impact, or capability this feature delivers.]

---

## User Story

**As a** [user persona or role]  
**I want to** [desired action or capability]  
**So that** [benefit or value gained]  

---

## Use Cases & Scenarios

### UC-1: [Main Flow / Happy Path Title]
- **Preconditions:** [State or requirements before the interaction begins]
- **User Flow:**
  1. [User does action 1]
  2. [System responds / displays 2]
  3. [User completes action 3]
- **Outcome:** [Observable success state for the user]

### UC-2: [Alternative Flow / Edge Case Title]
- **Trigger:** [e.g. Empty state, search yields no results, cancelled action, boundary condition]
- **Expected Behavior:** [What the user experiences; guidance or fallback provided]

### UC-3: [Error Handling / Validation Title]
- **Trigger:** [e.g. Missing required fields, invalid input, permission denied, failure state]
- **Expected Behavior:** [Clear user feedback and recovery path]

---

## Acceptance Criteria

- [ ] **AC-1 (UC-1):** WHEN [trigger happy path] THE SYSTEM SHALL [verifiable outcome]
- [ ] **AC-2 (UC-2):** WHEN [trigger edge case] THE SYSTEM SHALL [verifiable outcome]
- [ ] **AC-3 (UC-3):** WHEN [trigger validation/error] THE SYSTEM SHALL [verifiable outcome]

---

## Scope Boundaries

**In scope**

- [Bullet: essential product deliverable included in this task]

**Out of scope (Not doing)**

- [Bullet: explicit non-goal with short rationale — prevents planning creep]

---

## Notes

[Assumptions made, trade-offs accepted, or decisions taken during discovery. Leave empty if none.]
```

Format rules:

- **Product-only**: strictly functional and behavioral perspective; zero implementation detail (no class names, file paths, database schemas, or API routes).
- **Goal & Value**: concise problem context and clear, outcome-oriented objective.
- **Use Cases**: at least 1 Happy Path (`UC-1`) and at least 1-2 Alternative/Error/Edge Case scenarios (`UC-2`, `UC-3`). Each flow must be actionable and user-centered.
- **Acceptance criteria**: observable, falsifiable, one per outcome, mapped directly to a Use Case (e.g. `AC-1 (UC-1)`). Use EARS phrasing (`WHEN [trigger] THE SYSTEM SHALL [response]`).
- **Scope boundaries**: In-scope defines functional commitments; Out-of-scope marks explicit trade-offs and non-goals.
- **Language**: English. All written documents must be in English regardless of conversation language.
- **Compression**: caveman-compress — drop articles/filler/hedging; keep technical and domain terms exact.
- **Unknown values**: use `[NEEDS CLARIFICATION: <reason>]` inline; never guess. No variants of this format.
- **Status**: `draft` (initial), `clarified` (post `devflow.clarify`), `done` (pipeline complete).
- **App**: present only in monorepo repos (`devflow/config.md` has a `## Apps` table); value must match an App name in that table exactly. Never present in single-app repos.
- **ADRs**: optional path(s) to ADRs from `docs/adr/` governing or constraining this feature, or "none".

See **`examples.md`** in this skill directory for full worked examples.
