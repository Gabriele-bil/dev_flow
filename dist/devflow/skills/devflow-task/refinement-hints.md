# Refinement Hints & Stress-Test

Use after reading `docs/product.md` and before locking `task.md`. Socratic pass to prevent scope creep, ambiguity, and planning defects.

## 0. Anti-Hallucination & Elicitation Gate (Ask Before Writing)

If prompt lacks critical context, do not assume — stop and clarify via `AskQuestion`:

- **Persona / Actor**: Who performs this action? Real human role or external system; never a technical role (no "Frontend", "Database").
- **Core Domain Bounds**: What format, boundary, or trigger applies? (e.g., CSV vs PDF export; immediate vs scheduled).
- **Existing Overlap**: Does this collide with an **implemented** feature in `docs/product.md`?

## 1. INVEST Discipline Pass

- **(I) Independent:** Can this ship on its own? Avoid artificial dependencies with parallel tasks.
- **(N) Negotiable:** Problem and intent only; zero implementation lock-in (no classes, DB schemas, API endpoints).
- **(V) Valuable:** Vertical slice of observable user/business value. Never horizontal layers (no DB-only or API-only tasks).
- **(E) Estimable:** Clear scope. If extreme technical uncertainty blocks estimation, suggest a time-boxed **Spike**.
- **(S) Small:** Bounded scope. Rule of thumb: 2-5 BDD scenarios. If > 5, split vertically.
- **(T) Testable:** Binary pass/fail criteria. Quantify vague quality claims ("faster" → "LCP < 2.0s").

## 2. Vertical Slicing Rules

- **Isolate Read vs Action:** Never combine complex visualization (lists, filtering, search) with transactional mutations (create, edit, delete) in the same use case. Separate Read from Write.
- **Alien Test (Value Atomicity):** If the team disappeared after shipping this slice, does the user have a complete, usable increment? If no, do not split further (avoid "Ghost UI").
- **Strictly No "Ghost UI":** Never add non-functional buttons, placeholder UI, or "Coming soon" elements for future tasks. Today's UI must strictly match today's working code.

## 3. Mandatory Async Lifecycle Coverage

For every async operation (network call, submit, state mutation):

1. **In-Flight:** Loading indicator displayed (spinner/skeleton) AND input controls/buttons disabled to prevent double-submission.
2. **Success:** Observable feedback, list/state updated, or navigation completed.
3. **Error:** Clear error message displayed AND retry/recovery path enabled without losing user inputs.
4. **Empty State:** Clean fallback state displayed when data collection is empty.

## 4. BDD Formulation Rules

- **Syntax:** `GIVEN [context] WHEN [action] THEN [observable outcome]`
- **The One `When` Rule:** Exactly one trigger action per scenario. Two `When`s = two behaviors → split.
- **Intent Over Mechanics:** Focus on user intent, not click-by-click mechanics ("confirms submission", not "clicks green button").
- **Zero Technical Leaks:** No HTTP status codes, SQL queries, or internal state in criteria.
- **Occam's Razor:** Keep scenarios lean; avoid redundant permutations that test identical failure paths.
