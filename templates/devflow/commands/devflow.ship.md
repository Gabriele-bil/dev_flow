---
name: devflow.ship
description: Pre-merge gate before devflow.pr. Dispatches code-reviewer, security-auditor, and test-engineer in parallel, synthesizes reports, and routes to devflow.pr if no blockers. Use when devflow.test is complete and the feature is ready for final review before PR.
argument-hint: [optional notes for reviewers]
disable-model-invocation: true
model: sonnet
effort: high
---

# devflow.ship

Pre-merge fan-out gate. Run after `devflow.test`, before `devflow.pr`.

## Purpose

Dispatch three specialist agents in parallel → synthesize reports → gate on findings → route to `devflow.pr`.

## Input contract

Before running, verify:

- [ ] `devflow.test` complete — all tests passing (or failures explicitly documented)
- [ ] `devflow.beautify` complete
- [ ] Active adapter analyze/typecheck clean
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] `task.md` exists at `devflow/features/[NNN]_[feature-name]/task.md`

If any item fails → stop, report which check failed, do not dispatch agents.

## Step 1 - Fan-out (parallel)

Dispatch all three agents **simultaneously**. Do not wait for one before dispatching the next.

Each agent receives:
- Path to `task.md` and `plan.md`
- List of files created/modified by `devflow.implement` and `devflow.beautify`
- Active adapter name (from `@devflow/config.md`)
- Optional reviewer notes from `$ARGUMENTS`

**Agents to dispatch:**

1. `@devflow/agents/code-reviewer.md` — five-axis code review
2. `@devflow/agents/security-auditor.md` — security audit
3. `@devflow/agents/test-engineer.md` — coverage gap analysis

## Step 2 - Collect reports

Wait for all three reports. Do not proceed until all complete.

## Step 3 - Synthesize

Merge findings across all three reports. Deduplicate overlapping findings (same file:line from multiple reviewers → one merged entry, noting which reviewers flagged it).

Produce a unified report:

```markdown
## Ship Gate Report: [feature-name]

### Verdict: APPROVE | REQUEST CHANGES

### Critical Blockers
(findings marked Critical by any agent — must resolve before devflow.pr)
- [agent] `[file:line]` — [description + fix]

### Required
(findings with no prefix / Required severity — fix before merge)
- [agent] `[file:line]` — [description + fix]

### Nit / Optional / FYI
- [agent] `[file:line]` — [description]

### Coverage Gaps
- [from test-engineer: uncovered acceptance criteria or public surfaces]

### Done Well
- [positive observations from all agents]

---
Reviewed by: code-reviewer · security-auditor · test-engineer
```

## Step 4 - Gate decision

| Finding state | Action |
|---|---|
| Any **Critical** issue | Stop. Present report. Wait for user to fix before re-running |
| Any **Required** issue | Present report. Ask: "Fix before PR or proceed with documented exceptions?" |
| Only **Nit / Optional / FYI** | Proceed automatically to Step 5 |
| No findings | Proceed automatically to Step 5 |

## Step 5 - Route to devflow.pr

If gate passes:

```text
✅ Ship gate passed. Routing to devflow.pr.
```

Execute `@devflow/skills/devflow-pr/SKILL.md` exactly.

## Common Rationalizations

| Thought | Reality |
|---------|---------|
| "Skip ship gate — tests already passed" | Tests prove behavior; ship gate proves merge readiness across code quality, security, and coverage |
| "Run reviewers sequentially to save context" | Fan-out is the design. Sequential loses the benefit of independent perspectives |
| "One Critical issue is minor — proceed anyway" | Critical means block. Fix it or explicitly escalate to user; never auto-proceed |
| "Merge reports mentally without writing synthesis" | Written synthesis is the audit trail; skip it and findings get lost before devflow.pr |

## I/O Reference

| | |
|---|---|
| Reads | `task.md`, `plan.md`, `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Reads | files from `devflow.implement` / `devflow.beautify` summary |
| Dispatches | `code-reviewer`, `security-auditor`, `test-engineer` (parallel) |
| Routes to | `devflow-pr` skill on gate pass |
| Replaces | Running `devflow.pr` directly when multi-perspective review is needed |
