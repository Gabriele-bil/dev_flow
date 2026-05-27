---
name: devflow-blueprint
description: Transforms a large objective into a multi-PR blueprint with dependency graph, parallel-step detection, and adversarial review gate. Use when a feature requires 3+ PRs, spans multiple sessions, or involves parallel workstreams that cannot fit in a single devflow.plan.
argument-hint: [objective or path-to-brief]
---

# Skill: devflow.blueprint

## Quick Start

Run `/devflow.blueprint [objective or path to brief]`.

- If an argument is passed and it is a file path, read it as the objective brief
- If free text is passed, use it as the objective
- If no argument is passed, ask the user for the objective before proceeding
- Produce `plans/[slug]-blueprint.md` in the project root

## Purpose

Transform a large objective into a multi-PR blueprint. Output: dependency graph, parallel-step map, self-contained context brief per step, adversarial review gate. Complementary to `devflow.plan` (single-feature); replaces nothing.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved; blueprint approved before any `devflow.plan` begins
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep paths, IDs, commands exact
- **self-contained briefs** — every step contains enough context for a fresh agent with zero prior-session knowledge
- **explicit dependencies** — steps list their blockers; no implicit ordering
- **adversarial gate** — Opus subagent critiques the draft before it is finalised
- **parallel-first** — steps with no shared file or output dependencies are flagged as parallelizable

## When NOT to Use

- Objective fits a single PR or a single `devflow.plan` — use `devflow.task` + `devflow.plan` instead
- A blueprint already exists for this objective with status `approved` and no scope has changed
- Objective is still brainstorm-level with no concrete scope — clarify with the user first

## Input contract

Before proceeding, verify:

- [ ] Objective is concrete enough to decompose into steps (not just "improve performance")
- [ ] `constitution.md` and `docs/product.md` are readable (or at least one of them)

If objective is too vague → stop, ask one clarifying question, wait for answer.

## Workflow

### Step 1 — Read project context

Read in order:

| Source | Role |
|--------|------|
| `docs/product.md` | Domain, actors, implemented vs planned features |
| `constitution.md` | Stack, layering rules, conventions |
| `registry.md` | Shared patterns, existing modules |
| `.devflow-state.json` (if present) | Current pipeline state, feature numbering |

### Step 2 — Decompose into steps

Break the objective into concrete, independently-mergeable steps (PRs or sessions). Each step must:

- Produce a testable, merge-ready increment (no half-baked states)
- Own a clearly bounded set of files
- Have a title of the form: `[NNN] Title` (three-digit prefix, sequential)

Rules:

- Minimum granularity: one logical unit of work (not one file)
- Maximum granularity: one PR reviewable in < 2 hours
- Infrastructure/contracts steps must precede consumers (never parallelizable)
- A step that only changes tests or docs is valid and should be named as such

### Step 3 — Build dependency graph

For each step, list its **blockers** (steps that must be merged first). Use step IDs (`[NNN]`).

Derive the graph from:
- Shared files that would conflict if edited concurrently
- Logical output dependencies (e.g. step creates a type consumed by another)
- Migration / schema changes that must precede application code

Express dependencies as a table (see output template below) and as an ASCII graph.

### Step 4 — Detect parallelizable steps

A step is **parallelizable** when:

1. No step in its blocker list is unmerged, AND
2. No other concurrent step touches any of the same files, AND
3. No other concurrent step changes shared contracts (types, DB schema, API shape)

Mark such steps with `[parallel-safe]` in the step list. Add a **Parallel workstreams** summary at the top.

### Step 5 — Write context briefs

For **each step**, produce a self-contained context brief with:

| Field | Content |
|-------|---------|
| **Objective** | One sentence: what this step achieves |
| **Why now** | Why this step comes before/after its neighbors |
| **State of codebase at start** | What already exists (from prior steps + current baseline); enough for a fresh agent |
| **Files to touch** | Paths with `create` / `modify` / `delete` labels |
| **Acceptance criteria** | 2-5 observable, falsifiable conditions |
| **Blockers** | Step IDs that must be merged first (empty = none) |
| **Parallel-safe** | `yes` / `no` + brief reason |

The brief must be self-contained: a new agent handed only this section and the project codebase must be able to execute the step without reading prior steps.

### Step 6 — Adversarial review gate

Before writing the final file, spawn an Opus subagent with the **full draft blueprint** and this prompt:

```
You are a senior architect reviewing a multi-PR blueprint.
Your job: find problems BEFORE implementation begins.

Critique the blueprint on these axes and respond with a structured list of issues (severity: critical / major / minor):

1. Missing dependencies — steps that implicitly require another step's output but don't list it as a blocker
2. Wrong parallelization — steps marked parallel-safe that actually share files or contracts
3. Incomplete context briefs — briefs where a fresh agent would need to ask follow-up questions
4. Scope inflation — steps that are larger than one reviewable PR
5. Sequencing risk — steps ordered so that a late-stage failure invalidates prior work
6. Naming clarity — step titles that don't clearly describe the increment

For each issue: cite the step ID, describe the problem, suggest the fix.
Respond with "LGTM" only if you find no issues of severity critical or major.
```

Collect the subagent's response. Then:

- **LGTM** → proceed to Step 7
- **Critical / major issues found** → fix them (update steps, dependencies, briefs) and re-run adversarial review
- **Minor issues only** → apply fixes inline, no re-run required; document fixes in the blueprint's `## Review notes` section

Maximum two adversarial review rounds. If critical issues persist after two rounds, stop and surface to the user.

### Step 7 — Write blueprint file

Create `plans/[slug]-blueprint.md` in the project root using the template below.

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
```

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

### Step 8 — Notify user

After writing the file:

```text
✅ Blueprint created: plans/[slug]-blueprint.md

[Objective in 1 line]
[N] steps · [P] parallel-safe · [B] blockers resolved in adversarial review

Next: run devflow.plan for step [001] → [step title]
```

## Adversarial review: what to do with output

| Subagent verdict | Action |
|-----------------|--------|
| LGTM | Write file immediately |
| Minor issues | Fix inline; add to Review notes; write file |
| Major issues | Fix steps/briefs/deps; re-run adversarial review (max 1 more round) |
| Critical issues (after 2 rounds) | Surface to user; do not write file |

## Common Rationalizations

| Thought | Reality |
|---------|---------|
| "Steps are obvious — skip dependency graph" | Implicit deps → merge conflicts. Always make them explicit |
| "Context briefs are redundant — agents can read prior steps" | Prior steps may be in a different session or agent. Briefs must be self-contained |
| "Adversarial review is slow — skip it for small blueprints" | Small blueprints with wrong parallelization waste agent time. Run the gate |
| "I'll mark steps parallel-safe unless I'm sure they conflict" | Incorrect parallel-safe marking → concurrent edits to same file. Default to `no`; prove `yes` |
| "Blueprint can evolve during implement" | Changes mid-implement invalidate context briefs of downstream steps. Approve before coding |
| "One big step is fine — fewer PRs = less overhead" | Large steps → long reviews, big-bang merges, hard rollbacks. Keep steps PR-sized |

## Red flags

| Symptom | Why it fails |
|---------|-------------|
| Step has no acceptance criteria | `devflow.implement` cannot prove completion |
| Context brief says "see step [NNN] for details" | Brief is not self-contained; fresh agent cannot proceed |
| Two parallel-safe steps touch the same file | Guaranteed merge conflict |
| Dependency graph is a straight line with no parallelism | Likely over-sequenced; review for independent workstreams |
| Blueprint status is `approved` but steps were edited after adversarial review | Bypass of review gate; re-run adversarial review or mark status `draft` |
| Step title is a layer ("add tests", "update DB") not an increment | Layer-shaped steps → big-bang delivery; reframe as outcome increments |

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Marking all steps `parallel-safe: yes` by default | Concurrent edits to shared files → merge conflicts | Default to `no`; explicitly prove `yes` only when steps have no shared file |
| Skipping adversarial review for "simple" blueprints | Wrong parallelization detected only during implement (too late) | Always run adversarial review; it is fast and catches ordering errors |
| Writing context briefs that say "see step X" | Brief not self-contained; fresh agent in new session cannot proceed | Each brief must be fully self-contained (files, contracts, constraints) |
| Using blueprint for single-PR features | Blueprint overhead without benefit; adds ceremony, delays | Use `devflow.task` → `devflow.plan` directly for single-PR scope |
| Editing steps after adversarial review without marking `draft` | Review gate bypassed; invalid parallelization may ship | Mark `status: draft` → re-run adversarial review → re-approve |
| Dependency graph without transitive edges | Implement proceeds in wrong order | Include all transitive dependencies; missing edge = missing ordering constraint |

## I/O Reference

| | |
|---|---|
| Reads | `docs/product.md`, `constitution.md`, `registry.md`, `.devflow-state.json` |
| Spawns | Opus subagent (adversarial review, Step 6) |
| Writes | `plans/[slug]-blueprint.md` |
| Next step | `devflow.plan` per step, in dependency order |
| Related skills | `devflow-plan` (per-step planning), `devflow-task` (single-feature scoping) |
