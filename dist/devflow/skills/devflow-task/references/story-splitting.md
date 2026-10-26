# Story Splitting & Vertical Slicing

Operational guide for decomposing large requirements into lean, vertical increments. Based on Richard Lawrence's splitting patterns.

## Fundamental Rule: Vertical Slice, Never Horizontal

Every task or story must deliver a **vertical slice**: a demonstrable change in system behavior providing visible value that cuts through all required layers (UI, domain logic, data persistence).

- **Vertical slice (correct):** "User views list of recent orders with status filter." (Cuts UI, query, and data).
- **Horizontal slice (prohibited):** "Create database schema", "Build API controller", "Build UI shell". (Violates Independent and Valuable criteria).

## Key Splitting Patterns

1. **Workflow Steps:** Divide a multi-step user journey into distinct milestones. Deliver core flow first, then follow-up steps.
2. **Business Rule Variations:** Deliver the baseline rule first; extract advanced variations (discounts, tiered tiers, regional rules) into separate increments.
3. **Major Effort:** Isolate the foundational capability (e.g., first payment method or first sync provider); subsequent variations become lightweight additions.
4. **Simple / Complex:** Deliver the simplest viable version that solves the problem; defer complex edge handling to a subsequent increment.
5. **Data Variations:** Limit initial scope to core data types or fields; add rich media, extended formats, or optional attributes later.
6. **Data Entry Methods:** Start with basic input mechanisms before adding advanced controls (e.g., standard text input before rich drag-and-drop or date pickers).
7. **Defer Performance:** Ensure correct functionality first; extract performance optimizations into a dedicated refinement task.
8. **Operations (CRUD Separation):** Separate entity lifecycle operations into discrete use cases: Create, Read/List, Update, Delete.
9. **Spike (Last Resort):** When extreme unknowns prevent planning, schedule a time-boxed investigation spike.

## Special Optimization Rules

### 1. Separate Read/View from Action/Write

Never combine complex visualization (lists, filtering, search, sorting) with transactional mutations (creation, editing, deletion) in the same use case or bloated story.

- Isolate "Viewing & Browsing" from "Executing Action".
- Reduces cognitive load and prevents bloated implementation plans.

### 2. The Alien Test (Atomic Value)

Check: *"If this increment were deployed and the team vanished, does the user have a complete, working capability?"*

- If yes: Valid vertical slice.
- If no (e.g., a form that cannot be submitted, or a drag item that cannot be saved): Invalid horizontal fragment. Do not split past the boundary of atomic value.

### 3. Strictly Prohibit "Ghost UI"

Never render non-functional UI elements, disabled placeholder buttons, or "Coming soon" banners intended for future tasks. Today's UI must strictly reflect today's working software.
