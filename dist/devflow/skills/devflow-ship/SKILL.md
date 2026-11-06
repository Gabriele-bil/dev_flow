---
name: ship
description: 'Pre-merge gate: dispatches code-reviewer (+ security-auditor from standard profile up) in parallel, synthesizes one Ship Gate Report, routes devflow.pr if clean. Use when user runs devflow.ship, wants pre-merge gate, or asks "ready to ship?" — after devflow.test, before devflow.pr.'
argument-hint: "[optional notes for reviewers]"
disable-model-invocation: true
effort: medium
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

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
- [ ] Tests still valid: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify-stamp.sh" check 'test*'` — stale or failing → code changed after `devflow.test`; stop, route `devflow.test`
- [ ] `verification.md` present with zero FAIL verdicts
- [ ] Analyze clean: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify-stamp.sh" run analyze -- <adapter analyze cmd>` (fresh since `devflow.test` → skipped)
- [ ] Depth profile from `plan.md` `**Complexity:**` per `${CLAUDE_PLUGIN_ROOT}/references/complexity-scoring.md` (missing → `standard`)
- [ ] **Rigor ratchet (conditional):** `.devflow-instincts.shared.yaml` has `check_cmd` entries → start `devflow.learn check` in background, collect in Step 2; check over `ratchet_max` (or non-zero exit without ratchet) = **Required** finding

## Workflow

### Step 1 - Fan-out (parallel)

| Profile | Roster |
| --- | --- |
| `quick` | `code-reviewer` (all seven axes, security included) |
| `standard` | `code-reviewer` · `security-auditor` |
| `thorough` | `code-reviewer` · `security-auditor` — both with `model: opus` (Claude Code only; `${CLAUDE_PLUGIN_ROOT}/references/model-selection.md`) |

Build the packet once, then dispatch the roster **simultaneously**:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/review-packet.sh" [NNN] --profile <profile> --roster "<agent names>"
```

Keep the `tree <hash>` from its summary line — Step 4b re-reviews start from it. Each agent receives: path to `.devflow-review-packet.md` (read first — replaces own `git diff` and full reads of `task.md`/`plan.md`/`constitution.md`), adapter + app working directory (`${CLAUDE_PLUGIN_ROOT}/references/adapter-resolution.md`), reviewer notes from `$ARGUMENTS`, the roster (`code-reviewer` skips its security axis when `security-auditor` is on it), and `${CLAUDE_PLUGIN_ROOT}/references/token-economy.md` output rules.

Agents: `${CLAUDE_PLUGIN_ROOT}/agents/code-reviewer.md`, `${CLAUDE_PLUGIN_ROOT}/agents/security-auditor.md`. Read-only — a report claiming edits is invalid; discard, re-dispatch.

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

### Discarded by validator
(omit when none — Step 3b)
- [agent] `[file:line]` — [finding] — discarded: [evidence]

---
Profile: [quick | standard | thorough] · Reviewed by: [agents dispatched]
```

### Step 3b - Validate blocking findings

Any **Critical** or **Required** in the report → dispatch `${CLAUDE_PLUGIN_ROOT}/agents/finding-validator.md` once (Claude Code: Agent, `subagent_type: "devflow:finding-validator"`; Antigravity: `invoke_subagent`, subagent `finding-validator`) with the packet path and the numbered Critical + Required list. `DISCARDED` entries move to **Discarded by validator** with their evidence and stop gating; `CONFIRMED` stay. Re-compute the verdict. Nit/FYI never validated. Step 4b re-reviews validate their new blocking findings the same way.

### Step 4 - Gate decision

| Findings | Action |
| --- | --- |
| Any **Critical** | Stop, present report — run mode never overrides. User asks fix → Step 4b (no cap) |
| **Required**, no Critical | Interactive: ask "Fix before PR or proceed with documented exceptions?" — fix → Step 4b; proceed → exceptions into `plan.md` `## Decision flags`, Step 5 · Run mode: Step 4b, bounded |
| Only Nit/FYI, or none | Step 5 |

### Step 4b - Fix loop

Code edit after `devflow.test` invalidates `verification.md` — never patch inline and jump to Step 5.

Run mode only (Required-only verdicts; Critical never loops autonomously): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" run bump` — exit 3 = cap reached → under `devflow.run`: present report, return control; under `devflow.auto`: remaining Required → `## Decision flags` as documented exceptions, Step 5.

Each iteration (run mode: steps 1–2 in **one** `step-runner` subagent — group `implement --fix` → `test --changed`, per `${CLAUDE_PLUGIN_ROOT}/references/run-mode.md` → **Step dispatch**; interactive: execute here):

1. `${CLAUDE_PLUGIN_ROOT}/skills/devflow-implement/SKILL.md` `--fix <findings>` (confirmed findings only, `file:line` + description) — `tested` → `implementing` → `implemented`.
2. `${CLAUDE_PLUGIN_ROOT}/skills/devflow-test/SKILL.md` `--changed <files the fix touched>` (`thorough`: no `--changed`) — `implemented` → `tested` only with zero FAIL. Fails → stop loop, present report + failure (`${CLAUDE_PLUGIN_ROOT}/references/escalation-ladder.md`); never set `shipped`.
3. Re-review the delta — packet built with `--since <previous tree>`, roster = `code-reviewer` + every agent whose confirmed findings this iteration fixed (`thorough`: full packet, same roster as Step 1) → Steps 2–4 (Step 3b on new blocking findings). Critical on any iteration → hard stop regardless of budget.

### Step 5 - Route to devflow.pr

Gate passed (Status `tested`, fresh `verification.md`, zero FAIL): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" set plan shipped`.

- `.devflow-run.json` with `until: "ship"` / `orchestrator: "devflow.run"` → present report, stop; PR stays human.
- `.devflow-run.json` with `until: "pr"` / `orchestrator: "devflow.auto"` → execute `${CLAUDE_PLUGIN_ROOT}/skills/devflow-pr/SKILL.md`.
- Interactive → `✅ Ship gate passed. Routing to devflow.pr.` → execute `${CLAUDE_PLUGIN_ROOT}/skills/devflow-pr/SKILL.md` exactly.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Downgrading profile or severity to pass the gate | Profile fixed at plan; severity reported as declared |
| Fixing findings, then setting `shipped` on old `verification.md` | Every fix walks implement `--fix` → test |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `task.md`, `plan.md` (`**Complexity:**`, `## Decision flags`), `verification.md` in `devflow/features/[NNN]_[feature-name]/`; `${CLAUDE_PLUGIN_ROOT}/references/complexity-scoring.md`, `${CLAUDE_PLUGIN_ROOT}/references/adapter-resolution.md`, `${CLAUDE_PLUGIN_ROOT}/references/token-economy.md` |
| Reads (conditional) | `.devflow-run.json` (`until`/`orchestrator`, grader budget); `references/anti-patterns.md` |
| Runs | `${CLAUDE_PLUGIN_ROOT}/scripts/review-packet.sh` → `.devflow-review-packet.md` (every fan-out, incl. Step 4b) |
| Dispatches | `code-reviewer` (+ `security-auditor` on `standard`/`thorough`), parallel; `finding-validator` on Critical/Required (Step 3b); Step 4b chains `devflow.implement --fix` → `devflow.test` (run mode: one step-runner) |
| Writes | `plan.md` `**Status:** shipped` + `.devflow-state.json` via `devflow-state.sh`; `## Decision flags` (documented exceptions); `.devflow-run.json` grader count (run mode) |
| Routes to | `devflow-pr` on gate pass |
