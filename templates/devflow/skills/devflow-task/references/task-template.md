# Task file template

Used by `devflow.task` Step 8 — write `devflow/features/[NNN]_[feature-name]/task.md` using this format.

```markdown
# Task - [Feature Name]

**ID:** TASK-[NNN]
**Date:** [YYYY-MM-DD]
**Status:** draft

---

## Summary

[2-4 sentences. Rewrite and clarify the original idea. Remove ambiguity.
Add implicit context from product.md. Never copy the raw input verbatim.]

---

## Problem framing (HMW)

[Single sentence: "How might we ..." — actionable, user-centered, not a solution disguised as a question.]

---

## Scope boundaries

**In scope**

- [Bullet: what this task commits to at product/outcome level]

**Out of scope (Not doing)**

- [Bullet: explicit non-goals with short reason — not a second subtask checklist]

---

## Key assumptions

- [ ] [Assumption — optional brief hint how to validate if non-obvious]
- [ ] [Use "None — well-understood feature" only when truly trivial]

---

## User Story

**As a** [user type]
**I want to** [desired action or capability]
**So that** [benefit or goal]

---

## Subtasks

- [ ] [Subtask 1 - clear, atomic, verifiable]
- [ ] [Subtask 2]
- [ ] [Subtask N]

---

## Acceptance criteria

- [ ] [Observable, falsifiable condition — e.g. "user sees inline error on empty required field save"]
- [ ] [Each criterion maps to at least one subtask; no solution detail]

---

## Notes

[Assumptions made, edge cases identified, decisions taken during analysis.
Leave empty if none.]
```

Format rules:

- **HMW**: one line, actionable, user-centered, not solution-disguised.
- **Scope**: Out-of-scope explicit — trade-offs, not TODOs.
- **Assumptions**: omit only for truly trivial tasks.
- **Subtasks**: atomic, verifiable; no class names, methods, or file paths.
- **Acceptance criteria**: observable, falsifiable, one per outcome, no solution detail.
- **Language**: English.
- **Compression**: caveman-compress — drop articles/filler/hedging; fragments OK; keep technical terms/paths/commands exact.
- **Unknown values**: use `[NEEDS CLARIFICATION: <reason>]` inline; never guess. No variants of this format.
- **Status**: `draft` (initial), `clarified` (post `devflow.clarify`), `done` (pipeline complete).

See **`examples.md`** in this skill directory for full worked examples.
