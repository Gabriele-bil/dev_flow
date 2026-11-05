---
name: devflow-ship
description: 'Pre-merge gate: dispatches code-reviewer (+ security-auditor from standard profile up) in parallel, synthesizes one Ship Gate Report, routes devflow.pr if clean. Use when user runs devflow.ship, wants pre-merge gate, or asks "ready to ship?" — after devflow.test, before devflow.pr.'
argument-hint: "[optional notes for reviewers]"
disable-model-invocation: true
effort: medium
---

# Skill: devflow.ship

**Arguments:** `$ARGUMENTS` — empty → dispatch without reviewer notes.

## Purpose

Pre-merge gate. Dispatch 1–2 review agents in parallel per depth profile → one synthesized report → gate on findings → route to `devflow.pr`. Test coverage is already proven by `devflow.test` (`verification.md`) — ship reviews code, not coverage.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- `plan.md` Status ≠ `tested` — run `devflow.test` first
- Hotfix — `devflow.hotfix` has no ship gate; it goes straight from verified tests to PR

## Input contract

Stop and report the failed check if any item is unmet.

- [ ] `task.md`, `plan.md` exist in `devflow/features/[NNN]_[feature-name]/`; `plan.md` **Status** == `tested`
- [ ] Tests still valid: `bash "@devflow/scripts/verify-stamp.sh" check 'test*'` — stale or failing → code changed after `devflow.test`; stop, route `devflow.test`
- [ ] `verification.md` present with zero FAIL verdicts
- [ ] Analyze clean: `bash "@devflow/scripts/verify-stamp.sh" run analyze -- <adapter analyze cmd>` (fresh since `devflow.test` → skipped)
- [ ] Depth profile from `plan.md` `**Complexity:**` per `@devflow/references/complexity-scoring.md` (missing → `standard`)
- [ ] **Rigor ratchet (conditional):** `.devflow-instincts.shared.yaml` has `check_cmd` entries → start `devflow.learn check` in background, collect in Step 2; check over `ratchet_max` (or non-zero exit without ratchet) = **Required** finding

## Workflow

### Step 1 - Fan-out (parallel)

| Profile | Roster |
| --- | --- |
| `quick` | `code-reviewer` (all seven axes, security included) |
| `standard` | `code-reviewer` · `security-auditor` |
| `thorough` | `code-reviewer` · `security-auditor` — both with `model: opus` (Claude Code only; `@devflow/references/model-selection.md`) |

Build the packet once, then dispatch the roster **simultaneously**:

```bash
bash "@devflow/scripts/review-packet.sh" [NNN] --profile <profile> --roster "<agent names>"
```

Keep the `tree <hash>` from its summary line — Step 4b re-reviews start from it. Each agent receives: path to `.devflow-review-packet.md` (read first — replaces own `git diff` and full reads of `task.md`/`plan.md`/`constitution.md`), adapter + app working directory (`@devflow/references/adapter-resolution.md`), reviewer notes from `$ARGUMENTS`, the roster (`code-reviewer` skips its security axis when `security-auditor` is on it), and `@devflow/references/token-economy.md` output rules.

Agents: `@devflow/agents/code-reviewer.md`, `@devflow/agents/security-auditor.md`. Read-only — a report claiming edits is invalid; discard, re-dispatch.

### Step 2 - Collect

Wait for every dispatched report and the ratchet result.

### Step 3 - Synthesize

Merge, dedupe (same `file:line` → one entry, list reviewers). Contradiction (one clears, other flags) → keep more severe verdict for gating, list it under **Reviewer Disagreements** — never drop the dissent.

```markdown
## Ship Gate Report: [feature-name]

### Verdict: APPROVE | REQUEST CHANGES

### Critical Blockers
- [agent] `[file:line]` — [description + fix]

### Required
- [agent] `[file:line]` — [description + fix]

### Nit / Optional / FYI
- [agent] `[file:line]` — [description]

### Reviewer Disagreements
(omit when none)

### Open Decision Flags
(from plan.md ## Decision flags — omit when none)
- F[N] — [decision]; alternatives: [...]; files: [...]

---
Profile: [quick | standard | thorough] · Reviewed by: [agents dispatched]
```

### Step 4 - Gate decision

| Findings | Action |
| --- | --- |
| Any **Critical** | Stop, present report — run mode never overrides. User asks fix → Step 4b (no cap) |
| **Required**, no Critical | Interactive: ask "Fix before PR or proceed with documented exceptions?" — fix → Step 4b; proceed → exceptions into `plan.md` `## Decision flags`, Step 5 · Run mode: Step 4b, bounded |
| Only Nit/FYI, or none | Step 5 |

### Step 4b - Fix loop

Code edit after `devflow.test` invalidates `verification.md` — never patch inline and jump to Step 5.

Run mode only (Required-only verdicts; Critical never loops autonomously): `bash "@devflow/scripts/devflow-state.sh" run bump` — exit 3 = cap reached → under `devflow.run`: present report, return control; under `devflow.auto`: remaining Required → `## Decision flags` as documented exceptions, Step 5.

Each iteration (run mode: each skill in a `step-runner` subagent per `@devflow/references/run-mode.md` → **Step dispatch**; interactive: execute here):

1. `@devflow/skills/devflow-implement/SKILL.md` `--fix <findings>` (`file:line` + description) — `tested` → `implementing` → `implemented`.
2. `@devflow/skills/devflow-test/SKILL.md` `--changed <files the fix touched>` (`thorough`: no `--changed`) — `implemented` → `tested` only with zero FAIL. Fails → stop loop, present report + failure (`@devflow/references/escalation-ladder.md`); never set `shipped`.
3. Re-run Step 1 with the **same roster**, packet built with `--since <previous tree>` (`thorough`: full packet) → Steps 2–4. Critical on any iteration → hard stop regardless of budget.

### Step 5 - Route to devflow.pr

Gate passed (Status `tested`, fresh `verification.md`, zero FAIL): `bash "@devflow/scripts/devflow-state.sh" set plan shipped`.

- `.devflow-run.json` with `until: "ship"` / `orchestrator: "devflow.run"` → present report, stop; PR stays human.
- `.devflow-run.json` with `until: "pr"` / `orchestrator: "devflow.auto"` → execute `@devflow/skills/devflow-pr/SKILL.md`.
- Interactive → `✅ Ship gate passed. Routing to devflow.pr.` → execute `@devflow/skills/devflow-pr/SKILL.md` exactly.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Downgrading profile or severity to pass the gate | Profile fixed at plan; severity reported as declared |
| Fixing findings, then setting `shipped` on old `verification.md` | Every fix walks implement `--fix` → test |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `task.md`, `plan.md` (`**Complexity:**`, `## Decision flags`), `verification.md` in `devflow/features/[NNN]_[feature-name]/`; `@devflow/references/complexity-scoring.md`, `@devflow/references/adapter-resolution.md`, `@devflow/references/token-economy.md` |
| Reads (conditional) | `.devflow-run.json` (`until`/`orchestrator`, grader budget); `references/anti-patterns.md` |
| Runs | `@devflow/scripts/review-packet.sh` → `.devflow-review-packet.md` (every fan-out, incl. Step 4b) |
| Dispatches | `code-reviewer` (+ `security-auditor` on `standard`/`thorough`), parallel; Step 4b chains `devflow.implement --fix` → `devflow.test` |
| Writes | `plan.md` `**Status:** shipped` + `.devflow-state.json` via `devflow-state.sh`; `## Decision flags` (documented exceptions); `.devflow-run.json` grader count (run mode) |
| Routes to | `devflow-pr` on gate pass |
