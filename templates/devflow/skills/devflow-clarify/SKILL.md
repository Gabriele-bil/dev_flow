---
name: devflow-clarify
description: Optional interactive session between devflow-task and devflow-plan. Runs the 8-dimension ambiguity scan on task.md, generates up to 5 prioritized questions, collects answers one at a time, updates task.md incrementally, removes resolved [NEEDS CLARIFICATION: ...] markers, and sets Status clarified. Use when task.md has open markers or high-risk assumptions that should be validated before planning begins.
model: haiku
effort: low
---

# Skill: devflow.clarify

## Purpose

Optional interactive session between `devflow.task` and `devflow.plan`. Validate and resolve ambiguities in `task.md` through structured Q&A, update the artifact incrementally, and set `Status: clarified` to signal readiness for planning.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- `task.md` Status is `done` — clarification has no effect on a completed task
- `task.md` has no `[NEEDS CLARIFICATION: ...]` markers and all Key assumptions are low-risk — proceed directly to `devflow.plan`
- The user wants to change the feature scope rather than resolve ambiguity — edit `task.md` directly or re-run `devflow.task`
- `devflow.plan` is already written — clarify before planning, not after; patch `plan.md` directly for post-plan changes

## Recommended triggers

Run when either condition is true:
1. `task.md` contains at least one `[NEEDS CLARIFICATION: ...]` marker
2. `task.md` Status is `draft` and Key assumptions section contains high-risk or unvalidated beliefs

## Input contract

Before running, verify:

- [ ] `task.md` exists at `devflow/features/[NNN]_[feature-name]/task.md`
- [ ] `task.md` Status is not `done`

If any item fails → stop and report which check failed.

## Workflow

### Step 1 — Load and scan

1. Read `task.md` in full.
2. Read `@devflow/skills/devflow-task/refinement-hints.md` — use all 8 dimensions as the scan framework.
3. Build the question backlog:
   - Extract every `[NEEDS CLARIFICATION: ...]` marker in `task.md` → one candidate question per marker.
   - Run the 8D scan on the full task content; generate additional candidate questions for dimensions with open ambiguities not already covered by a marker.
4. Deduplicate and prioritize the backlog by plan-invalidation risk (highest-risk dimension first).
5. Cap the queue at **≤5 questions** — keep only the highest-priority ones.

### Step 2 — Interactive Q&A loop

For each question in the prioritized queue, one at a time:

1. Present the question with:
   - The specific ambiguity or marker it resolves
   - A **recommended answer** with one-sentence rationale
   - Multiple-choice options where the answer space is bounded — use the **`AskQuestion`** tool when available (multi-choice preferred)
2. Wait for the user's answer.
3. On answer accepted:
   - Update the relevant `task.md` section (see Section update rules below).
   - If the question resolved a `[NEEDS CLARIFICATION: ...]` marker: remove the marker inline.
   - Append the Q&A pair to the `## Clarifications` section of `task.md` (see Clarifications section format).
4. Continue to the next question.

**Skip logic:** if the user answers "skip" or "not applicable", record the question as skipped in `## Clarifications` with the reason provided (or "no reason given" if none). Do not modify other sections for skipped questions.

### Section update rules

| Ambiguity source | Target section |
|------------------|----------------|
| Undefined actor or user type | `## User Story` — update actor; `## Summary` only if actor is missing there |
| Missing or vague acceptance criterion | `## Acceptance criteria` — add or sharpen the criterion |
| High-risk Key assumption | `## Key assumptions` — mark validated or replace with concrete statement |
| Scope boundary unclear | `## Scope boundaries` — move item from vague phrasing to explicit In/Out entry |
| Integration dependency unnamed | `## Key assumptions` — add named dependency; remove marker |
| Terminology divergence | `## Summary` — normalize to chosen term; update `## Subtasks` / `## Acceptance criteria` for consistency |
| Edge case unaddressed | `## Acceptance criteria` or `## Notes` — add the edge case path explicitly |

**Do not rewrite the `## Summary` body** to incorporate the full answer verbatim — preserve the original wording. Minimal targeted edits (term normalization, actor name) are allowed. The answer itself belongs in `## Clarifications`.

### Step 3 — Finalize

After the Q&A loop completes:

1. Scan `task.md` for remaining `[NEEDS CLARIFICATION: ...]` markers.
   - Resolved markers: should already be removed.
   - Skipped markers: leave in place — they represent accepted risk.
2. Update `task.md` header: set `**Status:** clarified`.
3. Output a **Clarification Summary** in the response:

```
## Clarification Summary
**Feature:** [NNN]_[feature-name]
**Session:** [YYYY-MM-DD]
**Questions asked:** N
**Resolved:** N
**Skipped:** N
**Remaining [NEEDS CLARIFICATION] markers:** N

[N remaining marker(s) → accepted risk; document in plan.md Open questions if material]
— or —
[All markers resolved → Status: clarified → proceed to devflow.plan]
```

## Clarifications section format

`devflow.clarify` appends a `## Clarifications` section at the end of `task.md` (after `## Notes`) on first run. Subsequent runs add a new `### Session` block — prior sessions are never overwritten.

```markdown
## Clarifications

### Session [YYYY-MM-DD]

**Q:** [question text — the ambiguity being resolved]
**A:** [accepted answer]
**Updated:** [section(s) modified, e.g. "## Acceptance criteria", "## Key assumptions"]

**Q:** [question text]
**A:** skipped — [reason]
**Updated:** none
```

This section is an audit trail only. Do not reformat, compress, or omit it after writing.

## Common Rationalizations

| Thought | Reality |
|---------|---------|
| "Markers are minor — skip to devflow.plan" | `devflow.plan` stops on unresolved markers. Resolve or explicitly waive them first |
| "I'll answer all questions at once, then update" | One-at-a-time ensures each answer shapes the next question correctly; batch answers break incremental consistency |
| "Rewrite Summary to incorporate the answer" | Summary preserves original wording for traceability. Answers belong in the target section and in `## Clarifications` |
| "devflow.clarify is mandatory on every task" | Optional. If no markers and assumptions are low-risk, go directly to `devflow.plan` |
| "Skip clarify — plan can absorb the ambiguity" | Ambiguity absorbed into `plan.md` becomes silent assumptions; they surface as bugs in `devflow.test` |

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Updating `task.md` after the full Q&A without intermediate saves | Later answers may conflict with earlier ones | Update `task.md` after each accepted answer, before presenting the next question |
| Rewriting `## Summary` to incorporate clarification answers | Destroys original wording; breaks traceability | Update the target section; record answer in `## Clarifications` |
| Running clarify after `devflow.plan` is already written | Plan was built on unresolved assumptions; mid-plan clarification causes plan drift | Run clarify only between task and plan; patch `plan.md` directly for post-plan adjustments |
| Skipping all questions without recording them | Plan inherits the unresolved risk silently | Record every skip in `## Clarifications` with its reason |
| Generating more than 5 questions | Too many questions means no prioritization | Cap at 5; surface only the highest-risk ambiguities |

## I/O Reference

| | |
|---|---|
| Reads | `devflow/features/[NNN]_[feature-name]/task.md` |
| Reads | `@devflow/skills/devflow-task/refinement-hints.md` (8D scan framework) |
| Writes | `devflow/features/[NNN]_[feature-name]/task.md` — inline marker removal, targeted section updates, `## Clarifications` section appended, `Status` → `clarified` |
| Precedes | `devflow.plan` |
| Follows | `devflow.task` |
| Related skills | `devflow-task` (writes `[NEEDS CLARIFICATION: ...]` markers; defines valid Status values); `devflow-plan` (stops on unresolved markers; accepts `clarified` status) |
