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

- **Problem:** [1-2 sentences on user pain point or current gap. Never copy raw input verbatim.]
- **Objective:** [Concrete outcome, business impact, or capability delivered.]

---

## User Story

**As a** [specific user persona or external actor — never a technical role]  
**I want to** [desired action or intent — no implementation details, no compound and/or]  
**So that** [tangible user or business benefit — no tautology repeating the action]  

---

## Use Cases & Scenarios

### UC-1: [Main Flow Title] (Happy Path)
- **Preconditions:** [State or requirements before interaction begins]
- **User Flow:**
  1. [User does action 1]
  2. [System responds / displays 2]
  3. [User completes action 3]
- **Outcome:** [Observable success state for the user]

### UC-2: [Alternative Flow / Edge Case Title]
- **Trigger:** [e.g. Empty state, search yields no results, cancelled action, boundary condition]
- **Expected Behavior:** [What user experiences; guidance or fallback provided]

### UC-3: [Error Handling / Validation Title]
- **Trigger:** [e.g. Missing required fields, invalid input, permission denied, service failure]
- **Expected Behavior:** [Clear user feedback, input retention, recovery/retry path]

---

## Acceptance Criteria

<!-- BDD Gherkin format: Given / When / Then. Exactly one When per scenario. -->
<!-- Default: compact single-line format for token efficiency; indented multiline allowed for complex assertions. -->

- [ ] **AC-1 (UC-1) — [Scenario Title]:** GIVEN [initial state] WHEN [single trigger action] THEN [observable outcome]
- [ ] **AC-2 (UC-1) — [Async Loading & Protection]:** GIVEN [action initiated] WHEN [request in progress] THEN [loading indicator displayed] AND [submit controls disabled]
- [ ] **AC-3 (UC-2) — [Edge / Empty State]:** GIVEN [empty condition] WHEN [viewed] THEN [informative fallback displayed]
- [ ] **AC-4 (UC-3) — [Error & Recovery]:** GIVEN [invalid state or failure] WHEN [action attempted] THEN [clear error message displayed] AND [user can retry]

---

## Scope Boundaries

**In scope**

- [Bullet: essential product deliverable included in this task]

**Out of scope (Not doing)**

- [Bullet: explicit non-goal with short rationale — prevents planning creep]

---

## Assumptions & Risks

### Assumptions

- [Bullet: critical domain, business, or operational assumption]

### Risks

- [Bullet: identified technical, integration, or edge risk]

---

## Notes

[Optional discovery notes, trade-offs, or decisions. Leave empty if none.]
```

Format rules:

- **Product-only**: strictly functional and behavioral perspective; zero implementation detail (no class names, file paths, database schemas, or internal API routes).
- **Goal & Value**: concise problem context and clear, outcome-oriented objective.
- **User Story**: strictly Connextra format. Real persona (never tech role); intent-based action (no compound conjunctions); true value (no tautology).
- **Use Cases**: at least 1 Happy Path (`UC-1`) and 1-2 Alternative/Error/Edge Case scenarios (`UC-2`, `UC-3`). Isolate Read/View from Action/Write.
- **Acceptance criteria**: strict BDD Gherkin (`GIVEN ... WHEN ... THEN ...`), exactly one `When` per scenario. Mapped directly to Use Cases (e.g. `AC-1 (UC-1)`). Observable, falsifiable, binary pass/fail. Explicit async coverage (loading, disabled controls to prevent double submit, error recovery).
- **Scope boundaries**: In-scope defines functional commitments; Out-of-scope marks explicit trade-offs and non-goals.
- **Assumptions & Risks**: structured bullets feed directly into `plan.md` architecture decisions and risks/mitigations table.
- **Language**: English. All written documents must be in English regardless of conversation language.
- **Compression**: caveman-compress — drop articles/filler/hedging; keep technical and domain terms exact.
- **Unknown values**: use `[NEEDS CLARIFICATION: <reason>]` inline; never guess.
- **Status**: `draft` (initial), `clarified` (post `devflow.clarify`), `done` (pipeline complete).
- **App**: present only in monorepo repos (`devflow/config.md` has a `## Apps` table); value must match an App name in that table exactly. Never present in single-app repos.
- **ADRs**: optional path(s) to ADRs from `docs/adr/` governing or constraining this feature, or "none".

See **`examples.md`** in this skill directory for full worked examples.
