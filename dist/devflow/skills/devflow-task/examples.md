# Examples: devflow-task

Study structure/tone, not fictional product details.

---

## Example A — Vague idea → clarification → `task.md`

**User:** “We should make notifications smarter.”

**Agent (after reading `docs/product.md`, constitution/registry as needed):** Identify problem & actor. Ask with `AskQuestion`: (1) actor (owner vs co-owner), (2) "smarter" dimension (priority/grouping/quiet hours/other), (3) success signal.

**User:** “Owners. Group by pet and don’t spam when two co-owners edit the same thing. Success is fewer taps to see what matters.”

**Agent:** Run quick stress-test from `refinement-hints.md`. Propose three `kebab-case` names via `AskQuestion` (`notification-grouping`, `pet-notification-feed`, `smart-notification-inbox`). User picks one. Allocate next `NNN_`, run verification checklist, write `task.md`.

**Excerpt of resulting `task.md`:**

```markdown
## Goal & Value

- **Problem:** Pet owners with multiple pets receive an unorganized stream of alerts, cluttered by duplicate notifications when co-owners perform overlapping actions.
- **Objective:** Surface notifications clustered by pet with duplicate suppression, allowing owners to triage updates with fewer taps.

## User Story

**As a** pet owner  
**I want to** see notifications organized by pet with duplicate co-owner updates suppressed  
**So that** I can review relevant pet events quickly without alert fatigue  

## Use Cases & Scenarios

### UC-1: Grouped Feed Review (Happy Path)
- **Preconditions:** Owner is logged in and has at least one pet with unread notifications.
- **User Flow:**
  1. User navigates to Notification Center.
  2. System displays notifications grouped under collapsible pet sections with count badges.
  3. User expands a pet section and taps a notification to inspect details.
- **Outcome:** Notifications for that pet are marked as read; list stays organized by pet.

### UC-2: Co-Owner Action De-duplication
- **Trigger:** Two co-owners update the same pet log event within a 5-minute window.
- **Expected Behavior:** System collapses the duplicate alerts into a single unified entry indicating "Updated by Co-owners", avoiding multiple separate alert pings.

### UC-3: Single Pet or Zero Notification State
- **Trigger:** Owner has only one registered pet or no notifications exist.
- **Expected Behavior:** System renders a clean flat list without redundant category headers, or an informative empty state illustration when empty.

## Acceptance Criteria

- [ ] **AC-1 (UC-1):** WHEN owner opens notifications THE SYSTEM SHALL display alerts grouped by pet identifier with unread counts.
- [ ] **AC-2 (UC-2):** WHEN multiple co-owners log changes to the same event within 5 minutes THE SYSTEM SHALL collapse them into one notification item.
- [ ] **AC-3 (UC-3):** WHEN an owner has no notifications THE SYSTEM SHALL show a friendly empty state with no empty section headers.

## Scope Boundaries

**In scope**

- Pet-level grouping in the primary notification list.
- Time-window de-duplication for overlapping co-owner actions.
- Empty and single-pet layout states.

**Out of scope (Not doing)**

- Push notification delivery mechanics or new push channels (handled in separate push service task).
- Email or SMS weekly digests.
```

---

## Example B — Clear feature → compact task

**User:** “Add a dark mode toggle in settings; persist choice locally and respect system default when unset.”

**Agent:** Skips long clarification; confirms no duplicate in `docs/product.md`; quick stress-test; `AskQuestion` for name choice (`theme-toggle`, `appearance-settings`, `dark-mode-preference`); writes task.

**Excerpt:**

```markdown
## Goal & Value

- **Problem:** App currently locks to light mode, causing visual discomfort in low-light environments and ignoring device theme settings.
- **Objective:** Enable user selection of light, dark, or system-matching theme with seamless persistence.

## User Story

**As a** user  
**I want to** select my preferred theme (light, dark, or system default)  
**So that** the app matches my device settings or visual preference  

## Use Cases & Scenarios

### UC-1: Select Explicit Theme (Happy Path)
- **Preconditions:** User is on the Settings screen.
- **User Flow:**
  1. User opens Settings → Appearance.
  2. User selects "Dark" (or "Light").
  3. System updates the app theme immediately without reload.
- **Outcome:** Visual appearance updates instantly and choice persists across future app launches.

### UC-2: Follow System Preference
- **Trigger:** User chooses "System" preference, then device OS switches between day and night mode.
- **Expected Behavior:** App automatically switches between light and dark palettes in real time without manual user intervention.

### UC-3: First Launch / Unset State
- **Trigger:** New installation with no previously stored preference.
- **Expected Behavior:** App defaults to "System" option and matches the current OS theme seamlessly.

## Acceptance Criteria

- [ ] **AC-1 (UC-1):** WHEN user selects Dark or Light mode THE SYSTEM SHALL switch the UI theme immediately and persist the selection.
- [ ] **AC-2 (UC-2):** WHEN preference is set to System and device theme changes THE SYSTEM SHALL update app colors dynamically.
- [ ] **AC-3 (UC-3):** WHEN app launches for the first time THE SYSTEM SHALL default to the System theme.

## Scope Boundaries

**In scope**

- Settings radio/toggle control with Light, Dark, System options.
- Dynamic theme application and local persistence across restarts.

**Out of scope (Not doing)**

- Custom accent color palettes or high-contrast custom themes.
- Per-screen theme overrides or scheduled time-based triggers.
```

---

## What to notice

1. **Goal & Value** states the problem and measurable objective; never repeats raw input.
2. **User Story** captures the persona and benefit cleanly.
3. **Use Cases** cover Happy Path (`UC-1`) plus edge/alternative scenarios (`UC-2`, `UC-3`) with concrete steps.
4. **Acceptance Criteria** link directly to Use Cases and use testable EARS phrasing.
5. **Product-only discipline**: zero references to classes, databases, APIs, or file paths — pure product specification ready for `devflow.plan`.
