---
name: devflow-ship
description: Pre-merge fan-out gate. Dispatches code-reviewer, security-auditor, and test-engineer in parallel, synthesizes a Ship Gate Report, and routes to devflow.pr if no blockers. Run after devflow.test, before devflow.pr.
disable-model-invocation: true
model: sonnet
effort: high
---

# Skill: devflow.ship

## Purpose

Pre-merge fan-out gate. Dispatch three specialist agents in parallel → synthesize reports → gate on findings → route to `devflow.pr`.

---

---

## When NOT to Use

- `devflow.test` is not complete or tests are still failing without explicit documentation
- `devflow.beautify` has not been run
- Active adapter analyze/typecheck has unresolved errors
- `plan.md` or `task.md` are missing from `devflow/features/[NNN]_[feature-name]/`

---

## Step 0 - Input contract

Before dispatching, verify all of the following. Stop and report which check failed if any item is unmet.

- [ ] `devflow.test` complete — all tests passing (or failures explicitly documented)
- [ ] `devflow.beautify` complete
- [ ] Active adapter analyze/typecheck clean
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] `task.md` exists at `devflow/features/[NNN]_[feature-name]/task.md`

---

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

---

## Step 2 - Collect reports

Wait for all three reports. Do not proceed until all complete.

---

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

---

## Step 4 - Gate decision

| Finding state | Action |
| --- | --- |
| Any **Critical** issue | Stop. Present report. Wait for user to fix before re-running |
| Any **Required** issue | Present report. Ask: "Fix before PR or proceed with documented exceptions?" |
| Only **Nit / Optional / FYI** | Proceed automatically to Step 5 |
| No findings | Proceed automatically to Step 5 |

---

## Step 5 - Route to devflow.pr

If gate passes:

```text
✅ Ship gate passed. Routing to devflow.pr.
```

Execute `@devflow/skills/devflow-pr/SKILL.md` exactly.

---

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Skipping ship gate ("tests passed") | Tests prove behavior; ship gate proves merge readiness across quality, security, coverage |
| Running reviewers sequentially | Fan-out is the design; sequential loses independent perspectives |
| Auto-proceeding on Critical issue | Critical = block; fix or escalate; never auto-proceed |
| Merging reports mentally without synthesis | Written synthesis is the audit trail |
| Dispatching only `code-reviewer` | Always dispatch all 3 agents |
| Synthesizing before all agents complete | Wait for all reports before Step 3 |
| Downgrading severity in synthesis | Report as declared; escalate if disputed |
| Re-running after fixing only some Critical issues | Fix all Critical; re-run full gate from Step 1 |

---

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `devflow/features/[NNN]_[feature-name]/plan.md`, `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Reads | Files from `devflow.implement` / `devflow.beautify` summary |
| Dispatches | `code-reviewer`, `security-auditor`, `test-engineer` (parallel) |
| Routes to | `devflow-pr` skill on gate pass |
| Replaces | Running `devflow.pr` directly when multi-perspective review is needed |
