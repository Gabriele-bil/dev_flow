# Blueprint file template

Used by `devflow.blueprint` Step 7 — write `devflow/plans/[slug]-blueprint.md` using this format.

`[slug]` = kebab-case summary of the objective (e.g. `auth-refactor`, `billing-v2`).

```markdown
# Blueprint — [Objective Title]

**ID:** BLUEPRINT-[slug]
**Date:** [YYYY-MM-DD]
**Status:** approved
**Steps:** [N] total · [P] parallel-safe

---

## Objective

[2-3 sentences. What this blueprint achieves, who benefits, and what the end state looks like.]

---

## Parallel workstreams

[Only if P > 0. List which steps can be worked in parallel and under what condition (e.g. "after [001] is merged").]

- After `[001]` merges: `[003]` and `[004]` can run in parallel
- After `[005]` merges: `[006]`, `[007]`, `[008]` can run in parallel

---

## Dependency graph

```

[001] Foundation
  └── [002] Data layer
        ├── [003] API layer (parallel-safe with [004])
        └── [004] Worker jobs (parallel-safe with [003])
              └── [005] UI

```text

| Step | Blockers |
|------|----------|
| [001] Title | — |
| [002] Title | [001] |
| [003] Title | [002] |
| [004] Title | [002] |
| [005] Title | [003], [004] |

---

## Steps

### [001] Title · [parallel-safe: no]

**Objective:** [one sentence]

**Why now:** [why this is step 1]

**State of codebase at start:**
[What already exists. Enough for a fresh agent: key files, patterns, shared contracts in place.]

**Files to touch:**
- `path/to/file.ts` — create
- `path/to/other.ts` — modify

**Acceptance criteria:**
- [ ] [Observable, falsifiable condition]
- [ ] [Observable, falsifiable condition]

**Blockers:** none

**Parallel-safe:** no — establishes shared contracts consumed by all later steps

---

### [002] Title · [parallel-safe: no]

**Objective:** [one sentence]

**Why now:** [why after [001]]

**State of codebase at start:**
[What [001] introduced + baseline. Fresh agent needs this to know what's available.]

**Files to touch:**
- `path/to/file.ts` — create

**Acceptance criteria:**
- [ ] [Condition]

**Blockers:** [001]

**Parallel-safe:** no — [reason]

---

[... repeat for each step ...]

---

## Review notes

[Populated by adversarial review gate. Document issues found and fixes applied. Omit if no issues found.]

| Round | Severity | Step | Issue | Fix applied |
|-------|----------|------|-------|-------------|
| 1 | minor | [002] | Brief missing existing auth pattern | Added auth pattern description to brief |

---

## Execution guide

1. Start with step `[001]` — no blockers
2. After `[001]` merges: run `devflow.plan` for `[002]`
3. [Continue per dependency graph]
4. Parallelizable steps: spin up separate agents or sessions per step

Each step → own `devflow.plan` → own `devflow.implement` run.
```
