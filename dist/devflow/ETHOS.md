# DevFlow Ethos

Four principles that govern every pipeline step. Non-negotiable.

---

## spec-first

No code before `task.md` + `plan.md` are written and approved.

**Why:** Code without spec is untracked work. Spec creates traceability, catches scope drift early, and produces a written record of intent that survives context loss.

**Violation pattern:** "Let me just try something first." Stop. Write the task.

---

## traceability

Every subtask maps to an acceptance criterion. Every acceptance criterion maps to one or more files. No orphan code, no orphan tests.

**Why:** Traceability makes review mechanical: check each criterion, find the files, verify the behavior. Without it, review is guesswork and regressions are invisible.

**Violation pattern:** Writing files not listed in `plan.md`. Deviation allowed only if documented in plan.

---

## vertical slices

For plans with >5 files: implement end-to-end user-visible increments, never layers.

**Why:** Layers (models first, then services, then UI) produce unrunnable, untestable intermediate states. Vertical slices produce working software at each checkpoint, enabling early feedback and clean handoffs.

**Violation pattern:** "I'll do all models first, then wiring." Stop. Slice vertically.

---

## token-lean

Caveman-compress all written output: drop articles (a/the/an), hedging (should/might/consider), filler (basically/simply/just), linking phrases (in order to/make sure to). Keep: technical terms exact, file paths exact, commands exact, all verbs, negations, conditions.

**Why:** Every token is context budget. Bloat forces earlier compaction, loses progress, increases error. Lean prose is faster to read, harder to misread.

**Violation pattern:** "You should consider reading the file before proceeding." → "Read file before proceeding."

---

*These principles are short enough to memorise. They are long enough to matter.*
