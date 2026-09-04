# Quick stress-test (before finalizing a DevFlow task)

Use **after** reading `docs/product.md` and **before** locking Summary/scope/subtasks. Pick relevant dimensions; skip non-applicable.

## Dimensions

1. **User value** — Who benefits? Sharp pain or nice-to-have? Will user behavior change?
2. **Feasibility in this project** — Fits `constitution.md` / `registry.md` patterns? Any auth/data-access/locale/responsive risk?
3. **Overlap** — Duplicates/collides with **implemented** feature in `docs/product.md`? If extension, say it in Notes.
4. **Scope honesty** — Is minimum useful slice clear? If not, narrow **In scope**, expand **Out of scope**. Idea carries a vague quality claim ("faster", "more secure", "simpler", "more scalable", "better UX")? Reframe it into concrete, testable **Acceptance criteria** before locking subtasks — don't let the adjective survive into the task file:

   ```
   RAW IDEA: "Make the dashboard faster"

   REFRAMED ACCEPTANCE CRITERIA:
   - Dashboard LCP < 2.5s on 4G connection
   - Initial data load completes in < 500ms
   - No layout shift during load (CLS < 0.1)
   → Confirm these are the right targets with the user; if no hard numbers exist yet, mark [NEEDS CLARIFICATION: target threshold] rather than leaving the adjective unquantified.
   ```

   Criterion has a trigger or precondition ("when X happens", "if user is Y") → phrase it EARS-style (`WHEN [trigger] THE SYSTEM SHALL [response]` / `IF [precondition] THEN THE SYSTEM SHALL [response]`) instead of a bare declarative sentence — the trigger/precondition slot forces the actor and condition into the open, catching the "shall for whom, under what state" gap before `devflow.plan`:

   ```
   VAGUE: "Shows error on invalid input"

   EARS: "WHEN user submits form with empty required field THE SYSTEM SHALL show inline error below that field"
   ```
5. **Riskiest assumption** — Which single belief can invalidate task? Put in **Key assumptions** (+ validation hint if needed).
6. **Edge cases & error states** — Are null/empty/error paths explicit or implied? If implied, mark the boundary in Key assumptions.
7. **Integration dependencies** — Does success require external systems or services not yet named? If so, name them or mark `[NEEDS CLARIFICATION]`.
8. **Terminology** — Are there synonyms in the idea that could mean different things in plan.md? Normalize to one term in Summary.

## Tone

If idea weak/vague/too large, say it clearly. Tighten scope or route to brainstorming first. Prefer small useful task over heroic vague task.
