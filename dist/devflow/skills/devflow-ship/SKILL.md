---
name: devflow-ship
description: Pre-merge fan-out gate: dispatches 1–5 review agents (code-reviewer, security-auditor, test-engineer, +2) per complexity profile, routes devflow.pr if clean. Use when user runs devflow.ship, wants pre-merge gate, or asks "ready to ship?" — after devflow.test, before devflow.pr.
disable-model-invocation: true
model: sonnet
effort: high
---

# Skill: devflow.ship

## Purpose

Pre-merge fan-out gate. Dispatch specialist agents in parallel — count scaled by depth profile (`quick` = 1, `standard` = 3, `thorough` = 5) → synthesize reports → gate on findings → route to `devflow.pr`.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

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
- [ ] `verification.md` exists at `devflow/features/[NNN]_[feature-name]/verification.md` with zero FAIL verdicts (goal-backward verification from `devflow.test` Step 6b)
- [ ] `devflow.beautify` complete
- [ ] Active adapter analyze/typecheck clean
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] `task.md` exists at `devflow/features/[NNN]_[feature-name]/task.md`
- [ ] Depth profile resolved from `plan.md` `**Complexity:**` per `@devflow/references/complexity-scoring.md` (missing → `standard`)

---

## Step 1 - Fan-out (parallel)

Dispatch all profile-required agents **simultaneously**. Do not wait for one before dispatching the next.

Each agent receives:

- Path to `task.md` and `plan.md`
- List of files created/modified by `devflow.implement` and `devflow.beautify`
- Active adapter name (from `@devflow/config.md`)
- Optional reviewer notes from `$ARGUMENTS`
- Exploration + output rules: `@devflow/references/token-economy.md` (index-first when code-index MCP available; derive, don't dump)

**Agents per depth profile:**

| Profile | Agents |
| --- | --- |
| `quick` | `code-reviewer` |
| `standard` | `code-reviewer` · `security-auditor` · `test-engineer` |
| `thorough` | `standard` set + `accessibility-auditor` · `docs-reviewer` |

Agent definitions:

1. `@devflow/agents/code-reviewer.md` — seven-axis code review (correctness, readability, architecture, security, performance, scope fidelity, simplicity)
2. `@devflow/agents/security-auditor.md` — security audit
3. `@devflow/agents/test-engineer.md` — coverage gap analysis
4. `@devflow/agents/accessibility-auditor.md` — WCAG 2.1 AA audit (thorough only)
5. `@devflow/agents/docs-reviewer.md` — doc coverage and drift (thorough only)

---

## Step 2 - Collect reports

Wait for **all dispatched** reports. Do not proceed until all complete.

---

## Step 3 - Synthesize

Merge findings across all dispatched reports. Deduplicate overlapping findings (same file:line from multiple reviewers → one merged entry, noting which reviewers flagged it).

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

### Open Decision Flags
(from plan.md ## Decision flags — autonomous decisions made under devflow.run; user reviews each before PR. Omit section when plan.md has no flags)
- F[N] — [decision]; alternatives: [...]; files: [...]

### Done Well
- [positive observations from all agents]

---
Profile: [quick | standard | thorough] · Reviewed by: [agents actually dispatched]
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

If gate passes: set `plan.md` `**Status:** shipped`; refresh `.devflow-state.json` per `@devflow/references/state-machine.md` → **State update snippet**.

**Run mode** (`.devflow-run.json` present — reached via `devflow.run --until ship`): do NOT execute `devflow-pr`. Present report, stop; PR stays human. Control returns to `devflow.run`.

Otherwise:

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
| Dispatching fewer agents than profile requires | Fan-out per depth profile table: `quick` = 1, `standard` = 3, `thorough` = 5 |
| Downgrading profile at ship to shrink fan-out | Profile fixed at plan; change requires plan.md edit + user confirmation |
| Synthesizing before all agents complete | Wait for all dispatched reports before Step 3 |
| Downgrading severity in synthesis | Report as declared; escalate if disputed |
| Omitting decision flags from the report | Every `## Decision flags` entry surfaces in **Open Decision Flags** — autonomous decisions get human review before PR |
| Auto-routing to `devflow.pr` with run mode active | Run never crosses the PR boundary; present report and stop |
| Re-running after fixing only some Critical issues | Fix all Critical; re-run full gate from Step 1 |

---

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `devflow/features/[NNN]_[feature-name]/plan.md`, `devflow/features/[NNN]_[feature-name]/verification.md`, `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Reads | Files from `devflow.implement` / `devflow.beautify` summary |
| Reads | `@devflow/references/complexity-scoring.md` (depth profile → fan-out), `@devflow/references/token-economy.md` (agent prompt rules) |
| Reads (conditional) | `plan.md` `## Decision flags` (→ **Open Decision Flags** report section); `.devflow-run.json` (existence — never route to `devflow.pr` when present) |
| Writes | `plan.md` — `**Status:** shipped` on gate pass |
| Dispatches | review agents per depth profile — `quick`: `code-reviewer`; `standard`: + `security-auditor`, `test-engineer`; `thorough`: + `accessibility-auditor`, `docs-reviewer` (parallel) |
| Routes to | `devflow-pr` skill on gate pass |
| Replaces | Running `devflow.pr` directly when multi-perspective review is needed |
