# Examples: devflow-task

Study structure/tone, not fictional product details.

---

## Example A — Vague idea → clarification → `task.md`

**User:** “We should make notifications smarter.”

**Agent (after reading `docs/product.md`, constitution/registry as needed):** Restate as HMW problem. Ask with `AskQuestion` or numbered list: (1) actor (owner vs co-owner), (2) "smarter" dimension (priority/grouping/quiet hours/other), (3) success signal.

**User:** “Owners. Group by pet and don’t spam when two co-owners edit the same thing. Success is fewer taps to see what matters.”

**Agent:** Run quick stress-test from `refinement-hints.md`. Propose three `kebab-case` names via `AskQuestion` (for example `notification-grouping`, `pet-notification-feed`, `smart-notification-inbox`). User picks one. Allocate next `NNN_`, run verification checklist, write `task.md`.

**Excerpt of resulting `task.md`:**

```markdown
## Summary

Owners receive many notifications. Surface them per pet in scannable form. Reduce duplicate noise from co-owner actions on same event.

## Problem framing (HMW)

How might we help pet owners see the notifications that matter for each pet without repeated alerts when co-owners perform overlapping actions?

## Scope boundaries

**In scope**

- Group or label notifications by pet for the owner’s primary notification list or hub.
- De-duplicate or collapse notifications that represent the same underlying event across co-owner activity (behavior TBD in plan).

**Out of scope (Not doing)**

- Push notification delivery mechanics or new notification types not already in the product.
- Email or SMS digests.

## Key assumptions

- [ ] Existing notification types and payloads are sufficient to infer “same event” for de-duplication — validate against current backend/event model.
- [ ] Owners are the primary audience for this hub; co-owner needs are unchanged unless product says otherwise.

## User Story

**As a** pet owner  
**I want to** see notifications organized by pet with less duplicate noise from co-owner activity  
**So that** I can understand what happened quickly with fewer taps  

## Subtasks

- [ ] Define grouping rules and duplicate-detection rules at the product level (no implementation detail here).
- [ ] Specify owner-facing UX for grouped vs single notifications, including edge cases (single pet, many pets).
- [ ] Align with responsive/navigation patterns from registry for where this surface lives.
```

---

## Example B — Clear feature → compact task

**User:** “Add a dark mode toggle in settings; persist choice locally and respect system default when unset.”

**Agent:** Skips long clarification; confirms no duplicate in `docs/product.md`; quick stress-test; `AskQuestion` for name choice (`theme-toggle`, `appearance-settings`, `dark-mode-preference`); writes task.

**Excerpt:**

```markdown
## Summary

Users choose light, dark, or system mode. Choice persists across sessions.

## Problem framing (HMW)

How might we let users control visual theme in line with platform expectations while defaulting to the OS when they have not chosen?

## Scope boundaries

**In scope**

- Settings entry for theme: light / dark / system.
- Persist user choice; apply on app start and when changed.

**Out of scope (Not doing)**

- Per-screen theme overrides or scheduling (e.g. auto dark at night only).

## Key assumptions

- [ ] Material 3 / app theme pipeline supports the three modes without a full redesign — confirm against `constitution.md` / theme docs.

## User Story

**As a** user  
**I want to** set appearance to light, dark, or system default  
**So that** the app matches my preference or device setting  

## Subtasks

- [ ] Define user-visible labels and behavior for the three modes (localized).
- [ ] Specify persistence and fallback when preference is “system.”
- [ ] Specify where the control lives in settings and accessibility expectations.
```

---

## What to notice

1. **Summary** is never a paste of the user’s words.
2. **HMW** is one sharp line, not a brainstorm doc.
3. **Out of scope** prevents plan creep; it is not a second subtask list.
4. **Subtasks** stay verifiable and free of class names, files, or APIs.
