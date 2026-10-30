---
name: devflow-ship
description: 'Pre-merge fan-out gate: dispatches 1–5 review agents (code-reviewer, security-auditor, test-engineer, +2) per complexity profile, routes devflow.pr if clean. Use when user runs devflow.ship, wants pre-merge gate, or asks "ready to ship?" — after devflow.test, before devflow.pr.'
argument-hint: "[optional notes for reviewers]"
disable-model-invocation: true
effort: medium
---

# Skill: devflow.ship

**Arguments:** `$ARGUMENTS` — empty → dispatch without reviewer notes.

## Purpose

Pre-merge fan-out gate. Dispatch specialist agents in parallel — count scaled by depth profile (`quick` = 1, `standard` = 3, `thorough` = 5) → synthesize reports → gate on findings → route to `devflow.pr`.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- `devflow.test` is not complete or tests are still failing without explicit documentation
- `devflow.beautify` has not been run
- Active adapter analyze/typecheck has unresolved errors
- `plan.md` or `task.md` are missing from `devflow/features/[NNN]_[feature-name]/`

---

## Step 0 - Input contract

Before dispatching, verify all of the following. Stop and report which check failed if any item is unmet.

- [ ] `plan.md` **Status** == `tested` — proves beautify ran (legal transitions; only the hotfix fast-track and the `quick` profile skip it)
- [ ] Tests still valid: `bash "@devflow/scripts/verify-stamp.sh" check 'test*'` — stale or failing → code changed after `devflow.test`; stop, route `devflow.test`
- [ ] `verification.md` exists at `devflow/features/[NNN]_[feature-name]/verification.md` with zero FAIL verdicts (goal-backward verification from `devflow.test` Step 6b)
- [ ] Analyze clean: `bash "@devflow/scripts/verify-stamp.sh" run analyze -- <adapter analyze cmd>` (fresh since `devflow.test` → skipped)
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] `task.md` exists at `devflow/features/[NNN]_[feature-name]/task.md`
- [ ] Depth profile resolved from `plan.md` `**Complexity:**` per `@devflow/references/complexity-scoring.md` (missing → `standard`)
- [ ] **Rigor Ratchet Checks (conditional):** if `.devflow-instincts.shared.yaml` contains entries with `check_cmd`, start them (`devflow.learn check`) in the background and dispatch Step 1 without waiting; collect the result before Step 3. Any check exceeding its `ratchet_max` (or exiting non-zero when no ratchet is set) is recorded as a **Required** finding in Step 3.

---

## Step 1 - Fan-out (parallel)

Build the review packet once, then dispatch all profile-required agents **simultaneously**. Do not wait for one before dispatching the next.

```bash
bash "@devflow/scripts/review-packet.sh" [NNN] --profile <profile> --roster "<agent names>"
```

Keep the `tree <hash>` its summary line prints: Step 4b re-reviews start from it. It writes `.devflow-review-packet.md` — changed files and diff against the base branch (uncommitted and new files included, `devflow/` excluded), acceptance criteria, scope, architecture decisions, traceability, deviations, decision flags, verification stamps, `constitution.md` and the `registry.md` entries for the changed files.

Each agent receives:

- Path to `.devflow-review-packet.md` — read first; replaces each agent's own `git diff` and full reads of `task.md`/`plan.md`/`constitution.md`
- Active adapter name and app working directory (resolved per `@devflow/references/adapter-resolution.md`)
- Optional reviewer notes from `$ARGUMENTS`
- Dispatch roster (profile + agent names) — `code-reviewer` skips its security axis when `security-auditor` is on it
- Exploration + output rules: `@devflow/references/token-economy.md` (index-first when code-index MCP available; derive, don't dump)

**Agents per depth profile:**

| Profile | Agents |
| --- | --- |
| `quick` | `code-reviewer` |
| `standard` | `code-reviewer` · `security-auditor` · `test-engineer` |
| `thorough` | `standard` set + `accessibility-auditor` · `docs-reviewer` |

Agent definitions (`thorough` profile: pass `model: opus` on the Agent calls for `code-reviewer` and `security-auditor` — Claude Code only; `@devflow/references/model-selection.md`):

1. `@devflow/agents/code-reviewer.md` — seven-axis code review (security axis delegated to `security-auditor` when both dispatched)
2. `@devflow/agents/security-auditor.md` — security audit
3. `@devflow/agents/test-engineer.md` — coverage gap analysis
4. `@devflow/agents/accessibility-auditor.md` — WCAG 2.1 AA audit (thorough only)
5. `@devflow/agents/docs-reviewer.md` — doc coverage and drift (thorough only)

---

## Step 2 - Collect reports

Wait for **all dispatched** reports. Do not proceed until all complete. Agents are read-only (`disallowedTools` + Bash rule) — a report claiming it edited files is invalid; discard and re-dispatch.

---

## Step 3 - Synthesize

Merge findings across all dispatched reports. Deduplicate overlapping findings (same file:line from multiple reviewers → one merged entry, noting which reviewers flagged it).

**Contradictions** — same file:line, opposite verdicts (one agent clears it, another flags it): keep the more severe verdict for gating, but surface the disagreement explicitly in **Reviewer Disagreements**. Never resolve a contradiction by silently dropping the dissenting verdict — the user decides, not the synthesis step.

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
| Any **Critical** issue | Stop. Present report — run mode never overrides this. User asks to fix → Step 4b fix loop (interactive, no iteration cap) |
| Any **Required** issue, no Critical | Interactive: present report, ask "Fix before PR or proceed with documented exceptions?" — fix → Step 4b; proceed → exceptions into `plan.md` `## Decision flags`, Step 5 · Run mode (`.devflow-run.json` present): Step 4b, bounded |
| Only **Nit / Optional / FYI** | Proceed automatically to Step 5 |
| No findings | Proceed automatically to Step 5 |

---

## Step 4b - Fix loop

Every code edit after `devflow.test` invalidates `verification.md` — fixes always walk the full middle pipeline again. Never patch inline and jump to Step 5.

Run mode only — iteration budget (Required-only verdicts; Critical never enters an autonomous loop):

1. `bash "@devflow/scripts/devflow-state.sh" run bump` — prints `grader iteration N/cap` and counts it; exit 3 = cap reached.
2. Cap reached → stop looping. Under `devflow.run`: present report as-is, control returns to `devflow.run`. Under `devflow.auto` (`until: "pr"`): log remaining Required findings to `plan.md` `## Decision flags` as documented exceptions (go to PR body), proceed to Step 5.

Run mode: steps 1–3 each run in a `step-runner` subagent per `@devflow/references/run-mode.md` → **Step dispatch** (implement's arguments: `--fix` + the findings); interactive: execute the skills here.

Each iteration (interactive and run mode), every status boundary written with `bash "@devflow/scripts/devflow-state.sh" set plan <status>`:

1. `@devflow/skills/devflow-implement/SKILL.md` with `--fix <findings>` — re-entry mode, scoped to this report's findings (`file:line` + description); `tested` → `implementing` → `implemented`.
2. `@devflow/skills/devflow-beautify/SKILL.md` on touched files (run mode: certain improvements only) → `beautified`.
3. `@devflow/skills/devflow-test/SKILL.md` with `--changed <files the fix touched>` — the unit suite runs through the stamp as always; Step 6b re-verifies only ACs whose Traceability files are in that list and carries the other rows over (`thorough`: no `--changed`, full re-verification) → fresh `verification.md`; `tested` only with zero FAIL. Test step fails or verification FAIL → stop loop, present report + failure (escalation per `@devflow/references/escalation-ladder.md`); never set `shipped`.
4. Re-run the fan-out from Step 1 at the **same depth profile** (same agents — never shrink on retry). `quick` / `standard`: build the packet with `--since <tree from the previous packet>`, so the agents review the fix diff with the previous report's findings as context; `thorough`: full packet, fully independent re-review.
5. Route new report through Step 4. Critical on any iteration → immediate hard stop, independent of remaining budget.

---

## Step 5 - Route to devflow.pr

If gate passes (Status `tested`, `verification.md` written after last code edit, zero FAIL): `bash "@devflow/scripts/devflow-state.sh" set plan shipped`.

**Run mode under devflow.run** (`.devflow-run.json` present with `until: "ship"` or `orchestrator: "devflow.run"`): do NOT execute `devflow-pr`. Present report, stop; PR stays human. Control returns to `devflow.run`.

**Run mode under devflow.auto** (`.devflow-run.json` present with `until: "pr"` or `orchestrator: "devflow.auto"`): gate passed (or proceeded with documented exceptions). Execute `@devflow/skills/devflow-pr/SKILL.md` directly.

Otherwise (interactive session):

```text
✅ Ship gate passed. Routing to devflow.pr.
```

Execute `@devflow/skills/devflow-pr/SKILL.md` exactly.

---

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Downgrading profile at ship to shrink fan-out | Profile fixed at plan; change requires plan.md edit + user confirmation |
| Downgrading severity in synthesis | Report as declared; escalate if disputed |
| Re-running after fixing only some Critical issues | Fix all Critical; re-run full gate from Step 1 |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

---

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `devflow/features/[NNN]_[feature-name]/plan.md`, `devflow/features/[NNN]_[feature-name]/verification.md`, `@devflow/references/adapter-resolution.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Runs | `@devflow/scripts/review-packet.sh` (Step 1, every fan-out incl. Step 4b re-runs) → `.devflow-review-packet.md` |
| Reads | `@devflow/references/complexity-scoring.md` (depth profile → fan-out), `@devflow/references/token-economy.md` (agent prompt rules) |
| Reads (conditional) | `plan.md` `## Decision flags` (→ **Open Decision Flags** report section); `.devflow-run.json` (`until` field — stops before PR if `until: "ship"`, routes to `devflow.pr` if `until: "pr"`; `ship_grader_iterations`/`ship_grader_iteration_count` for Step 4b); `references/anti-patterns.md` (when unsure / retry) |
| Writes | `plan.md` — `**Status:** shipped` on gate pass; Step 4b statuses via the chained skills; `.devflow-state.json` (merge) |
| Writes (conditional) | `.devflow-run.json` `ship_grader_iteration_count` — Step 4b, run mode only (`devflow-state.sh run bump`) |
| Dispatches | review agents per depth profile — `quick`: `code-reviewer`; `standard`: + `security-auditor`, `test-engineer`; `thorough`: + `accessibility-auditor`, `docs-reviewer` (parallel); Step 4b fix loop re-runs `devflow.implement --fix` → `devflow.beautify` → `devflow.test` before re-running the fan-out |
| Routes to | `devflow-pr` skill on gate pass |
| Replaces | Running `devflow.pr` directly when multi-perspective review is needed |
