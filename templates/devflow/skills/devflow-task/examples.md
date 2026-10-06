# Examples: devflow-task

Study structure, INVEST rigor, BDD Gherkin formatting, and token economy.

---

## Example A — Vague idea → clarification → `task.md`

**User:** “We should make notifications smarter.”

**Agent (after reading `docs/product.md`, constitution/registry as needed):** Identify problem & actor. Ask with `AskQuestion`: (1) actor (owner vs co-owner), (2) "smarter" dimension (priority/grouping/quiet hours/other), (3) success signal.

**User:** “Owners. Group by pet and don’t spam when two co-owners edit the same thing. Success is fewer taps to see what matters.”

**Agent:** Run quick stress-test from `refinement-hints.md` (INVEST check, isolate read feed from actions, async dedup). Propose three `kebab-case` names via `AskQuestion` (`notification-grouping`, `pet-notification-feed`, `smart-notification-inbox`). User picks one. Allocate next `NNN_`, run verification checklist, write `task.md`.

**Excerpt of resulting `task.md`:**

```markdown
# Task - Pet Notification Grouping

**ID:** TASK-001
**Date:** 2026-10-06
**Status:** draft

---

## Goal & Value

- **Problem:** Pet owners with multiple pets receive an unorganized stream of alerts, cluttered by duplicate notifications when co-owners perform overlapping actions.
- **Objective:** Surface notifications clustered by pet with duplicate suppression, allowing owners to triage updates with fewer taps.

---

## User Story

**As a** pet owner  
**I want to** review notifications organized by pet with duplicate co-owner updates collapsed  
**So that** I can track pet health events quickly without alert fatigue  

---

## Use Cases & Scenarios

### UC-1: Grouped Feed Review (Happy Path)
- **Preconditions:** Owner is logged in with at least one registered pet and unread alerts.
- **User Flow:**
  1. User opens Notification Center.
  2. System renders notifications grouped under pet sections with unread badges.
  3. User expands a pet group and selects an alert.
- **Outcome:** Selected alert marks as read; feed remains organized by pet.

### UC-2: Co-Owner Action De-duplication
- **Preconditions:** Multiple co-owners edit the same pet event within 5 minutes.
- **User Flow:**
  1. Second co-owner completes action.
  2. System collapses overlapping alerts into one combined item ("Updated by co-owners").
- **Outcome:** Feed displays single de-duplicated entry instead of repetitive alerts.

### UC-3: Single Pet or Zero Notification State
- **Trigger:** Owner has zero notifications or only one registered pet.
- **Expected Behavior:** Renders clean flat list for single pet, or illustrated empty state when no alerts exist.

---

## Acceptance Criteria

- [ ] **AC-1 (UC-1) — Grouped Feed Rendering:** GIVEN logged-in owner with multiple pets WHEN opening notifications THEN system displays alerts grouped by pet identifier with unread count badges
- [ ] **AC-2 (UC-1) — Async Feed Refresh:** GIVEN notification center active WHEN user pulls to refresh THEN loading indicator displays AND previous list remains interactive until new data arrives
- [ ] **AC-3 (UC-2) — Co-Owner De-duplication:** GIVEN two co-owners update same event within 5 minutes WHEN feed generates alerts THEN system collapses updates into a single "Updated by co-owners" alert
- [ ] **AC-4 (UC-3) — Empty State Display:** GIVEN owner has zero notifications WHEN opening notification center THEN system shows friendly empty state with no empty section headers

---

## Scope Boundaries

**In scope**

- Pet-level grouping in primary notification list.
- 5-minute time-window de-duplication for overlapping co-owner actions.
- Empty and single-pet responsive layout states.

**Out of scope (Not doing)**

- Push notification delivery pipeline (handled in separate push service task).
- Weekly digest emails or SMS summaries.

---

## Assumptions & Risks

### Assumptions

- Pet identifier is present on all incoming notification event payloads.
- 5-minute de-duplication window is sufficient to prevent co-owner alert noise.

### Risks

- High volume of historical alerts could delay grouping render; mitigation: paginate feed at 20 alerts per pet.

---

## Notes

None.
```

---

## Example B — Interactive Mutation Feature (Read vs Write Separation + Async Lifecycle)

**User:** “Add bookmarking to article view with offline persistence.”

**Agent:** Confirms actor (Reader) and scope. Distinguishes Reading state from Toggling mutation. Verifies async states (in-flight spinner, disabled button to prevent double-tap, error roll-back). Writes `task.md`.

**Excerpt:**

```markdown
# Task - Article Bookmark Offline

**ID:** TASK-002
**Date:** 2026-10-06
**Status:** draft

---

## Goal & Value

- **Problem:** Readers lose articles of interest when switching devices or losing connectivity.
- **Objective:** Enable instant article bookmarking with immediate local persistence and offline access.

---

## User Story

**As a** reader  
**I want to** bookmark articles with instant offline access  
**So that** I can read saved articles later even without internet connectivity  

---

## Use Cases & Scenarios

### UC-1: Bookmark State Display (Read / View)
- **Preconditions:** Reader navigates to an article view.
- **User Flow:**
  1. System checks stored bookmark status.
  2. System renders active or inactive bookmark icon accordingly.
- **Outcome:** Reader sees accurate current bookmark status immediately.

### UC-2: Toggle Bookmark (Action / Mutation)
- **Preconditions:** Article view open.
- **User Flow:**
  1. Reader taps bookmark icon.
  2. System immediately toggles visual state and initiates local save.
  3. System disables toggle button briefly to prevent rapid double-clicks.
- **Outcome:** Article is added to saved list and persisted for offline retrieval.

### UC-3: Storage Error & Recovery
- **Trigger:** Local storage failure or quota exceeded during save.
- **Expected Behavior:** System reverts icon state, re-enables button, and displays non-intrusive warning notification with retry option.

---

## Acceptance Criteria

- [ ] **AC-1 (UC-1) — Initial Icon State:** GIVEN saved article WHEN reader opens article view THEN bookmark icon renders in filled active state
- [ ] **AC-2 (UC-2) — Optimistic Toggle & Double-Submit Protection:** GIVEN unbookmarked article WHEN reader taps bookmark THEN icon toggles immediately AND tap input is disabled until save completes
- [ ] **AC-3 (UC-2) — Offline Persistence:** GIVEN article bookmarked WHEN device is offline THEN article content remains accessible in saved list
- [ ] **AC-4 (UC-3) — Save Failure Reversion:** GIVEN storage error occurs during bookmark save WHEN save fails THEN icon reverts to original state AND toast notification offers retry

---

## Scope Boundaries

**In scope**

- Bookmark icon toggle on article screen.
- Local offline persistence and retrieval.
- Optimistic UI with failure reversion.

**Out of scope (Not doing)**

- Cloud synchronization across multiple devices (deferred to multi-device sync task).
- Custom bookmark folders or tags.

---

## Assumptions & Risks

### Assumptions

- Article content size fits within local device storage limits.

### Risks

- Rapid toggle spam could corrupt local state; mitigated by temporary button disable during mutation.

---

## Notes

None.
```

---

## What to notice

1. **Goal & Value**: concise problem context and clear, outcome-oriented objective.
2. **User Story**: strictly Connextra format; human persona; no compound "and"/"or" verbs; true value without tautology.
3. **Vertical Slicing**: isolates Read/View flows (`UC-1`) from Action/Mutation flows (`UC-2`), avoiding cognitive overload.
4. **Acceptance Criteria**: strict BDD Gherkin (`GIVEN ... WHEN ... THEN ...`) with exactly one `When` per scenario; covers async loading, double-submit protection, and error recovery.
5. **Assumptions & Risks**: structured bullets feed directly into `plan.md` risks table and architecture decisions.
6. **Product-only discipline**: zero leaks of class names, database tables, or framework internals.
