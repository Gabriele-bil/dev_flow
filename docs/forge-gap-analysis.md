# Forge → DevFlow Gap Analysis & Improvement Proposals

Comparison of the [Forge plugin](https://github.com/LucasDuys/forge) (analyzed at `~/Developer/forge`, v0.3.0) with DevFlow, followed by a prioritized catalogue of improvements. Each proposal states what Forge does (with file references), why it matters, and how to transpose it into DevFlow's architecture without breaking its design constraints.

---

## 1. Executive summary

Both plugins turn an idea into implemented, reviewed, committed code through a spec-first pipeline. They differ radically in *who drives*:

| Dimension | Forge | DevFlow |
| --- | --- | --- |
| Driver | **Self-prompting loop.** A Stop hook intercepts every Claude exit, reads `.forge/state.md`, and injects the next prompt (`hooks/stop-hook.sh` → `routeDecision()`). Human reads diffs in the morning. | **User-gated pipeline.** The user invokes each step (`devflow.task` → `plan` → `implement` → `beautify` → `test` → `ship` → `pr`). |
| Runtime | Node.js engine (`forge-tools.cjs`, ~200-line state machine), JS hooks | Markdown skills + bash/jq hooks — no runtime dependency |
| Pipeline | brainstorm → plan → execute → review + verify → backprop | setup → task → (clarify) → plan → (analyze) → implement → beautify → test → ship → pr |
| Spec format | R-numbered requirements with testable ACs | task.md with HMW framing, subtasks, ACs; traceability table in plan.md |
| Execution unit | Task DAG, streaming topological dispatch, per-task git worktrees, squash-merge | File-ordered plan, vertical slices, single feature branch, commits only at `devflow.pr` |
| Verification | Goal-backward, 4 levels: existence → substantive → wired → runtime | Agent fan-out review at ship (5 specialists) + adapter test/analyze targets |
| Failure handling | 7-level circuit breakers (debug → cross-model rescue → re-decompose → block) | Scattered "retry 3×" rules per step |
| Model economics | Complexity score 0–20 → haiku/sonnet/opus routing, per-depth token profiles, budget-pressure downgrade | Static guide (`references/model-selection.md`) |
| Recovery | On-disk state machine, per-task checkpoints, lock heartbeat, forensic rebuild from git | `.devflow-state.json` (PreCompact snapshot), `[done]` markers in plan.md, `devflow.recovery` skill |
| Multi-stack support | None (generic) | **Adapters** (Flutter/Angular/Next.js) with tech skills, per-stack commands, setup templates |
| Multiplayer | Claim leases, forward-motion flags, Ably/git-polling transports | None |
| Self-testing | 745 unit tests over engine + hooks | `validate-skills.sh --strict`, Tier-2 trigger evals, `bash -n` |

**Where DevFlow is already ahead:** stack adapters with per-technology skills, the clarify/analyze consistency steps, five-specialist ship gate, learnings log with distillation hooks, skill lint + trigger evals, multi-host support (Claude Code / Cursor / Antigravity).

**Where Forge is ahead (and transposable):** durable state machine with resume, goal-backward verification, spec backpropagation, bounded escalation ladders, complexity-based depth/model routing, tool-output filtering, machine-readable status, self-tests for hook logic, and documentation that sells the tool.

**Design constraint for every proposal below:** DevFlow must stay markdown + bash/jq (no mandatory Node runtime) and keep explicit user gates as the default. Items that shift that philosophy are flagged and scoped as opt-in.

---

## 2. Transposable from Forge

### P0 — high value, low friction

#### 2.1 Formal pipeline state machine + `devflow.resume`

**Forge:** `references/state-machine.md` defines every phase (`idle`, `executing`, `reviewing_branch`, `verifying`, plus failure phases `budget_exhausted`, `conflict_resolution`, `recovering`, `lock_conflict`) and an authoritative transition table. Current phase lives in `.forge/state.md` frontmatter; the stop hook routes from it. `/forge resume` rebuilds state from lock + checkpoints + git when `state.md` is missing or stale.

**DevFlow today:** `.devflow-state.json` is written only by `hooks/pre-compact.sh` (and touched by `post-task-create.sh`), and the pipeline phase is *inferred* from plan.md `**Status:**` values via a hardcoded `case` mapping. There is no document defining valid statuses and transitions; `devflow.recovery` and `session-start.sh` each re-derive state their own way.

**Proposal:**

1. Add `references/state-machine.md` to the plugin: enumerate the canonical statuses (`draft`, `clarified`, `ready`, `implementing`, `implemented`, `beautified`, `tested`, `shipped`, `pr-opened`) and legal transitions, including failure states (`blocked`, `recovering`). Make it the single source of truth cited by discovery, status, recovery, and the hooks.
2. Have each core skill update `.devflow-state.json` at entry/exit (step boundary), not only at PreCompact — a 5-line jq snippet in each skill's final step, or a shared `hooks/update-state.sh` helper.
3. Add a `devflow.resume` skill: read `.devflow-state.json` → cross-check against plan.md `[done]`/`[pending]` markers and `**Status:**` → confirm resume position → re-enter the correct skill. Today this logic exists only as a paragraph inside `devflow-implement` Step 1 ("Long sessions / session resume") and inside recovery; promote it to a first-class entry point.

**Effort:** M. **Depends on:** nothing; unlocks 2.9, 2.12, and simplifies recovery.

#### 2.2 Goal-backward verification (four levels)

**Forge:** `docs/verification.md`. The verifier works *backwards from the spec*, not forwards from the tasks, checking each R-number at four levels:

| Level | Checks |
| --- | --- |
| Existence | Expected files, functions, routes, migrations exist |
| Substantive | Real code, not stubs — detects TODO, hardcoded returns, empty catch, skipped tests, placeholder components |
| Wired | Imported where used, route registered, middleware applied — dead code = not satisfied |
| Runtime | E2E via Playwright, webhook handlers, deploy preview, CI status — whatever the stack offers |

**DevFlow today:** `devflow.test` proves tests pass; `devflow.ship` fans out five reviewer agents. Both are *forward-looking* ("is the code good?"). Nothing systematically asks "is every acceptance criterion in task.md actually satisfied, wired, and reachable?" A stubbed function with a passing unit test and clean review sails through.

**Proposal:** add a **Verification step** — either a Step inside `devflow.test` after the test run, or a standalone `devflow.verify` between test and ship. For each AC in task.md: locate implementing file(s) via plan.md's Traceability table (already mandatory — DevFlow's traceability makes this nearly free), then run the four checks. Levels 1–3 are pure static inspection (grep/read); level 4 maps to adapter targets (see 2.15). Output a per-AC verdict table; ship's input contract adds "verification report exists, no FAILED ACs".

**Effort:** M. **Depends on:** nothing. Highest quality-per-token item in this list.

#### 2.3 Spec backpropagation — `devflow.backprop`

**Forge:** `references/backprop-patterns.md` + the backprop phase: when a runtime failure exposes a spec gap, trace behavior → spec → nearest R-number → classify the gap (**missing criterion** / **incomplete criterion** / **missing requirement**) → tighten the AC → add a regression test → resume the loop. It also catalogs common gap families (input validation, concurrency, error handling, integration) and a systemic rule: after 3+ backprops of the same category, add a standard brainstorming question for it.

**DevFlow today:** `devflow.learn` logs project quirks and `stop-learn-distill.sh` detects file churn, but a bug found after implement produces no change to `task.md` — the spec silently stays wrong, and the next feature repeats the gap.

**Proposal:** new `devflow.backprop` skill: input a bug description or failing test → trace to the AC via the Traceability table → classify the gap using Forge's taxonomy → propose an updated criterion in task.md + a named regression test → log the gap category via `devflow.learn`. Systemic rule transposed directly: 3+ same-category entries in `.devflow-learnings.jsonl` → propose a new standard question for `devflow.clarify`'s 8D scan. Forge's reference file can be adapted almost verbatim into `references/backprop-patterns.md`.

**Effort:** S–M. **Synergy:** closes the loop between the learnings system and the spec — the piece DevFlow's learning machinery is currently missing.

#### 2.4 Unified circuit-breaker escalation ladder

**Forge:** seven bounded levels (`docs/verification.md`): 3 consecutive test failures → DEBUG mode; 2 failed debug attempts → cross-model rescue (fresh perspective, different model); 3 total → re-decompose the task into sub-tasks; 3 review iterations → accept with warnings; 2 identical progress snapshots → block for human; 100 iterations → force exit; budget 100% → graceful handoff file.

**DevFlow today:** independent "retry up to 3 attempts, then stop and report" clauses in implement (codegen, format/analyze) and test. No escalation *between* mechanisms — after 3 failed attempts the pipeline just stops; no "try a different angle before giving up", no stuck-detection.

**Proposal:** add `references/escalation-ladder.md` and cite it from implement/test/beautify instead of the scattered clauses:

1. 3 failed attempts at a command → stop patching, enter explicit debug mode (read error fully, form hypothesis, minimal probe).
2. 2 failed hypotheses → re-approach: reread task.md/plan.md, question the plan step itself, propose plan deviation (logged in `## Implementation deviations`).
3. Still stuck → split the slice into smaller sub-steps in plan.md.
4. No progress across two consecutive rounds (same error text) → block and hand to user with a structured stuck-report.

Cross-model rescue is noted as a variant for hosts that support model switching per agent.

**Effort:** S. Pure prompt-engineering; no hooks needed.

#### 2.5 Anti-over-engineering guardrails (Karpathy guardrails)

**Forge:** `skills/karpathy-guardrails/SKILL.md`, inlined into executor, reviewer, and planner: executor checks for ambiguity before coding and builds *only what the AC requires*, tracing every changed line to a requirement; reviewer flags over-engineering, scope creep, silent assumptions, and goal misalignment as IMPORTANT findings; planner rejects gold-plated tasks and enforces one concern per task.

**DevFlow today:** partially present — reuse-first, "guessing unspecified behavior" anti-pattern, deviations log. But no reviewer axis for scope creep, and no "every changed line traces to an AC" check. The five-axis code-reviewer covers correctness/readability/architecture/security/performance — over-engineering falls between the cracks.

**Proposal:**

- `agents/code-reviewer.md`: add a sixth axis or fold into architecture: *scope fidelity* — flag code not required by any AC, speculative generality, unused parameters/options, gold-plating.
- `devflow-implement` Step 4 checklist: "every file/function you write must trace to a plan.md entry; if you feel the urge to add 'while I'm here' improvements, log them via `devflow.learn` instead of writing them."
- `devflow-plan`: reject plan entries that don't map to a subtask (already implied by the Traceability contract — make it an explicit validation bullet).

**Effort:** S. The cheapest high-value item in this document.

#### 2.6 Documentation as a product surface

**Forge:** the README opens with the pain ("You are the project manager. You are the state machine. You are the glue."), shows a real terminal transcript of the full loop, quotes measured token-savings numbers, and links an architecture video. `docs/` has architecture (with a phase diagram), comparison vs alternatives, per-topic guides, and every mechanism has a `references/*.md` schema doc.

**DevFlow today:** README is an accurate but dry table inventory. There is no architecture document, no diagram of the pipeline, no comparison with alternatives (Forge, spec-kit, vanilla Claude Code), and no narrative of *why* spec-first + adapters is the right trade.

**Proposal:**

- Rewrite `templates/devflow/README.md` top section as problem → solution → 3-command quickstart with example transcript.
- Add `docs/architecture.md` (repo level): pipeline diagram (mermaid), state model, hook map, adapter contract.
- Add `docs/comparison.md`: DevFlow vs Forge vs GitHub spec-kit vs plain Claude Code — be honest about Forge's autonomy advantage and DevFlow's adapter/gate advantages.

**Effort:** M (writing only).

### P1 — high value, moderate effort

#### 2.7 Complexity scoring → depth profiles and model routing

**Forge:** three coupled references. `complexity-heuristics.md`: signals (files touched, task type, judgment, cross-component, novelty) sum to a 0–20 score. `model-routing.md`: 0–4 → haiku, 5–10 → sonnet, 11+ → opus; per-role min/preferred/max; budget-pressure downgrade (70–90 % used → one tier down); escalation on BLOCKED, de-escalation after 3 consecutive successes. `token-profiles.md`: quick/standard/thorough depth profiles that change rigor (TDD on/off, review iterations, verification depth), not just model.

**DevFlow today:** `references/model-selection.md` is a static per-step guide; some skills pin `model:` in frontmatter (e.g. ship = sonnet). Depth of rigor is constant regardless of change size — a one-line fix pays the same beautify/test/ship overhead as a 30-file feature.

**Proposal:**

1. Port the scoring table into `references/complexity-scoring.md`.
2. `devflow.plan` Step: compute a feature score, record `**Complexity:** N (quick|standard|thorough)` in plan.md frontmatter, and optionally tag heavy slices.
3. Define depth profiles for DevFlow: **quick** (beautify limited to correctness+readability axes, test = happy path + regression only, ship = code-reviewer only), **standard** (current behavior), **thorough** (full 7-axis beautify, ship 5-agent fan-out, verification level 4 mandatory).
4. `devflow.ship` and `devflow.test` read the tag and adjust their fan-out/rigor. Model hints per depth go into the existing `model-selection.md`.

**Effort:** M. This directly attacks DevFlow's biggest practical annoyance: fixed ceremony cost for small changes.

#### 2.8 Tool-output filter hook

**Forge:** `hooks/output-filter.js` + `hooks/test-output-filter.js` (PostToolUse, matcher Bash). Recognizes command classes (install, build, git diff, find, curl, test runners) and, past a per-class threshold (default 2000 chars), replaces output with head + all warning/error lines + tail summary. Zero cost when not applicable. Forge's README claims ~28.9 % session-token reduction from the deterministic layer, of which output filtering is the major share.

**DevFlow today:** caveman compression governs *prose*, but tool output — the single largest context consumer in an implement/test session — enters context raw. `flutter test`, `pnpm build`, and `dart analyze` outputs are exactly the verbose, mostly-redundant classes Forge filters.

**Proposal:** `hooks/post-bash-output-filter.sh` (PostToolUse, matcher Bash), bash/awk implementation keyed to the *adapter command classes* DevFlow already knows (`flutter analyze|test`, `dart format`, `pnpm lint|test|build`, `git diff`): keep first N lines, every line matching `error|warning|FAIL|✗|Exception`, last N lines, plus a `[devflow-filter] kept X of Y lines` marker. Thresholds in one place at the top of the script. Register in `hooks.json` with a short timeout, sync (it must rewrite output).

**Effort:** M (the awk is easy; the test matrix per adapter is the work — pair with 2.11).

#### 2.9 Per-feature checkpoint file

**Forge:** `references/checkpoint-schema.md` — `.forge/progress/{task-id}.json` with `current_step`/`next_step` (validated enum with legal transitions), `artifacts_produced`, `context_bundle` (decisions, constraints, notes), `error_log`, `token_usage`. Created at task start, atomically rewritten at each step, deleted on completion — a surviving file *is* the signal of interrupted work.

**DevFlow today:** `[done]` markers in plan.md say *which files* are complete but preserve none of the *why*: decisions made mid-implement, constraints discovered, errors already tried. After a crash/compaction, that context is re-derived from scratch or lost.

**Proposal:** lightweight `devflow/features/[NNN]_[name]/.checkpoint.json`: `{step, slice, decisions[], errors_tried[], updated_at}`. Written by implement at slice boundaries (a Step 4 sub-bullet) and by test on retry loops; read by `devflow.resume` (2.1) and `devflow.recovery`; deleted by `devflow.pr` on success. Keep the schema to ~6 fields — Forge's full 12-field schema is engine-oriented overkill for a prompt-driven pipeline.

**Effort:** S–M. **Depends on:** pairs naturally with 2.1.

#### 2.10 Machine-readable status

**Forge:** `references/headless-status-schema.md` — a documented `--json` status output with stable fields and exit codes, so CI and scripts can query the loop.

**Proposal:** `devflow.status --json`: emit `.devflow-state.json` enriched with the derived next step and validation of file existence, with a documented schema in `references/status-schema.md` and stable exit codes (0 = healthy, 1 = no pipeline, 2 = inconsistent state). Cheap because `.devflow-state.json` already exists; the skill mostly needs to validate + echo it.

**Effort:** S.

#### 2.11 Self-tests for hook scripts

**Forge:** 745 unit tests (`tests/*.test.cjs`) covering routing, budgets, checkpoints, locks, output filters, recovery classification — the plugin's *logic* is tested, not just its file shapes.

**DevFlow today:** `validate-skills.sh --strict` (structure lint), Tier-2 trigger evals (routing/description collisions), `bash -n` (syntax only). The hooks that manipulate consumer state — `pre-compact.sh` (state JSON generation), `stop-learn-distill.sh` (churn detection + dedup), `post-task-create.sh` (feature numbering), `pre-config-protect.sh` (matcher correctness) — have zero behavioral coverage. A regression in pre-compact silently corrupts every consumer's resume experience.

**Proposal:** `tests/hooks/` with [bats-core](https://github.com/bats-core/bats-core) (or plain bash asserts to stay dependency-free): fixture a fake `devflow/features/001_x/plan.md`, run each hook, assert on the JSON produced. Wire into a `scripts/run-hook-tests.sh` and mention in CLAUDE.md's validation commands. Start with pre-compact.sh (most complex) and stop-learn-distill.sh.

**Effort:** M.

### P2 — valuable, philosophy-shifting or larger

#### 2.12 Gated autonomy: `devflow.run`

**Forge:** the defining feature — `hooks/stop-hook.sh` intercepts every exit, `routeDecision()` picks the next prompt, `<promise>FORGE_COMPLETE</promise>` is the only clean exit. 100-iteration cap, lock heartbeat, budget phases.

**DevFlow today:** deliberately user-gated. But the gates between implement → beautify → test are largely ceremonial — the user almost always says "continue". The genuine decision points are: task/plan approval (upstream) and ship verdicts (downstream).

**Proposal (scoped, opt-in):** `devflow.run [--from implement] [--until ship]`: a skill that executes the middle of the pipeline as one chained session — implement, then beautify, then test, then stop before ship with a consolidated report. Implementation options, in order of preference:

1. *Prompt-level chaining* (no hooks): the run skill invokes the step skills sequentially, honoring each one's input contract; simplest, works on all hosts.
2. *Stop-hook chaining* (Forge-style): a Stop hook reads `.devflow-state.json` + a `.devflow-run.json` marker and re-prompts the next step; only if (1) proves insufficient for long features that exhaust context mid-run (then 2.9's checkpoints make the re-prompt cheap).

Ship's Critical/Required gates stay human. Include an explicit **autonomy policy table** in the skill (what it may do unattended: write code, run adapter commands; what it must never do unattended: commit, push, open PR, edit configs — the pre-config-protect hook already enforces part of this).

**Effort:** L. **Depends on:** 2.1 (state), 2.9 (checkpoints), 2.4 (bounded failure handling — a loop without circuit breakers is a runaway).

#### 2.13 Forward-motion flags

**Forge:** in collaborative execute, any decision the AI would normally pause on becomes a *flag*: pick the best defensible default, write `flags/F<id>.md` with decision/alternatives/rationale, continue; teammates review and override later. The AI never blocks on a sleeping human.

**DevFlow today:** the opposite rule — implement says "conflict → surface options; do not pick silently", which is correct for interactive sessions but deadlocks any autonomous run (2.12).

**Proposal:** make ambiguity handling *mode-dependent*. Interactive (default): current behavior. Under `devflow.run`: pick the defensible default, log a structured flag into plan.md under a `## Decision flags` section (`decision, alternatives, rationale, affected files`), and continue. `devflow.ship` lists open flags in its report so the user reviews every autonomous decision before PR. Do **not** transpose the multi-machine flag routing — only the decide-log-continue pattern.

**Effort:** S once 2.12 exists.

#### 2.14 Context-pressure handoff

**Forge:** token-monitor hook tracks usage; at 60 % context a handoff file is written and the session resumes cleanly in a new one; at budget exhaustion, a graceful `resume.md` handoff instead of mid-task death.

**DevFlow today:** PreCompact snapshot fires only when the host decides to compact — reactive, and the snapshot holds file lists but no working context.

**Proposal:** since bash hooks can't reliably read token counts, do it at the prompt level: implement/test skills get a standing instruction — "when context pressure is noticeable (host warning, or >20 files into a large plan), write `devflow/features/[NNN]/handoff.md` (current slice, next action, open decisions, errors tried) and tell the user to restart with `devflow.resume`." Cheap insurance that pairs with 2.9; skip Forge's numeric budget enforcement entirely.

**Effort:** S.

#### 2.15 Runtime/structural AC verification (level 4)

**Forge:** `verify-structural-acs` executes querySelector-shaped ACs against the built artifact instead of trusting task-registry counts; the visual-verifier agent adds Playwright occlusion/readiness probes for UI claims.

**Proposal:** add an optional **Verify** section to the adapter contract (`ADAPTER.md`): a command that exercises the running artifact (Flutter: `flutter test integration_test`; Angular/Next.js: Playwright smoke spec). The verification step (2.2) uses it as its level-4 check when present, degrades to levels 1–3 when absent. Visual verification (screenshot diffing, occlusion) is explicitly out of scope — too host-dependent.

**Effort:** M–L (per adapter).

#### 2.16 DESIGN.md auto-detection

**Forge:** `skills/design-system/SKILL.md` — brainstorm/plan/execute auto-detect a project DESIGN.md; planner tags UI tasks `design:`, executor loads tokens as constraints, reviewer runs a design-compliance pass; no DESIGN.md = zero behavior change.

**DevFlow today:** adapter theme skills (flutter-theme, angular-theme, nextjs-ui) know *how* to theme, but nothing connects a consumer's own design system document to the pipeline.

**Proposal:** task/plan/beautify check for `DESIGN.md` (or `docs/design.md`) in the consumer root. If present: plan tags UI files, implement loads it alongside constitution.md for UI slices, beautify's UI axis checks token compliance (palette/typography/spacing) instead of generic guidelines. Degrade gracefully when absent.

**Effort:** M.

---

## 3. Deliberately NOT transposed

| Forge feature | Why not |
| --- | --- |
| Collaborative mode (claim leases, Ably/git-polling transports, participant lifecycle) | Heavy Node infrastructure, solves a multi-machine team problem DevFlow's single-driver audience doesn't have. Only the flag *pattern* (2.13) is worth taking. |
| Tool-cache hooks (120 s read/list cache with mtime invalidation) | Requires a Node runtime and careful invalidation; hosts increasingly do context caching themselves. Low payoff for the risk of stale reads. |
| TUI watch dashboard / dev-server lifecycle manager | Engine-class tooling; DevFlow's status skill + stop-notify hook cover the need at 1 % of the complexity. |
| Per-task git worktrees + squash-merge | Only pays off with parallel DAG execution. DevFlow implements sequentially on one branch by design ("no commits during implement"); adopt only if 4.3 + parallel dispatch ever land. |
| Full 100-iteration autonomy with lock files and heartbeats | Contradicts DevFlow's gate philosophy; 2.12's bounded `devflow.run` is the calibrated dose. |
| Cross-model Codex rescue | Host-dependent model switching; noted inside 2.4 as an optional variant, not a core mechanism. |

---

## 4. DevFlow-specific improvements (independent of Forge)

### 4.1 Fix `agent.yaml` catalog drift — and stop maintaining it by hand

The catalog (self-described "updated manually") has already drifted from reality:

- `pipeline.steps` is missing **clarify**, **analyze**, and **blueprint** (all shipped commands per README).
- `skills.core` is missing `devflow-clarify`, `devflow-analyze`, `devflow-blueprint`, `devflow-ship`, and `devflow-status`.
- `skills.adapters.common` is missing `common-caveman` and `common-web-interface-guidelines` (both listed in README).

**Proposal:** generate `agent.yaml` in `scripts/build-plugin.sh` from the filesystem (skills/frontmatter are the source of truth), or at minimum add a drift check to `run-evals.sh` that diffs catalog IDs against `skills/*/SKILL.md` names and fails on mismatch.

### 4.2 Repair `devflow-ship` SKILL.md inconsistencies

- The skill body dispatches **three** agents (code-reviewer, security-auditor, test-engineer) while README, agent.yaml, and the report footer's own promise ("5 agents in parallel") say **five** — accessibility-auditor and docs-reviewer are never dispatched in Step 1.
- Stray empty section separators (`---` twice in a row under Purpose).
- Missing the `## Core Principles` section required by the repo's own operational rules (`## I/O Reference` is present) — worth checking why `validate-skills.sh --strict` doesn't flag it.
- With depth profiles (2.7), ship becomes the natural place to scale fan-out: quick = code-reviewer only; standard = 3 agents; thorough = all 5.

### 4.3 Optional dependency annotations in plan.md

plan.md's File List is strictly sequential. Adding an optional `deps:` annotation per slice (not per file) costs nothing today and enables: smarter resume ordering (2.1), partial re-implementation after backprop (2.3), and — if ever desired — parallel slice execution, which is the precondition for Forge-style worktrees. `devflow.blueprint` already produces a dependency graph at PR level; this reuses the same notation one level down.

---

## 5. Prioritized roadmap

| # | Item | Priority | Effort | Depends on |
| --- | --- | --- | --- | --- |
| 2.5 | Anti-over-engineering guardrails | P0 | S | — |
| 2.4 | Escalation ladder reference | P0 | S | — |
| 4.1 | agent.yaml generation / drift check | P0 | S | — |
| 4.2 | devflow-ship fixes (3 vs 5 agents, sections) | P0 | S | — |
| 2.3 | `devflow.backprop` + gap patterns reference | P0 | S–M | — |
| 2.2 | Goal-backward verification (levels 1–3) | P0 | M | — |
| 2.1 | State machine reference + `devflow.resume` | P0 | M | — |
| 2.6 | README narrative + architecture/comparison docs | P0 | M | — |
| 2.10 | `devflow.status --json` + schema | P1 | S | 2.1 |
| 2.9 | Checkpoint file | P1 | S–M | 2.1 |
| 2.14 | Context-pressure handoff | P1 | S | 2.9 |
| 2.7 | Complexity scoring + depth profiles | P1 | M | — |
| 2.8 | Tool-output filter hook | P1 | M | 2.11 recommended |
| 2.11 | Hook self-tests (bats) | P1 | M | — |
| 4.3 | plan.md `deps:` annotations | P2 | S | — |
| 2.13 | Forward-motion flags (autonomous mode only) | P2 | S | 2.12 |
| 2.16 | DESIGN.md auto-detection | P2 | M | — |
| 2.15 | Adapter Verify target (runtime level 4) | P2 | M–L | 2.2 |
| 2.12 | `devflow.run` gated autonomy | P2 | L | 2.1, 2.4, 2.9 |

**Suggested first wave** (one working session each, no architectural risk): 2.5, 2.4, 4.1, 4.2 — then 2.2 and 2.3, which together give DevFlow the verify-and-backprop loop that is Forge's single most valuable idea.
