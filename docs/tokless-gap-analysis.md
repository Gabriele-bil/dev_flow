# Tokless Gap Analysis — Token-Efficiency Techniques for DevFlow

Analysis of [tokless](https://github.com/HoangP8/tokless) (local checkout: `~/Developer/tokless`), a Go CLI that installs and wires six token-saving tools into AI coding agents (Claude Code, Cursor, Codex, OpenCode, Copilot, Antigravity, Factory/Droid, Pi). This document catalogs every technique tokless deploys, maps each against what DevFlow already has, and specifies concrete porting proposals with priorities, touchpoints, and validation gates.

**Scope note:** tokless is an *installer* — the techniques live in the tools it wires plus a unified instruction document it writes into each agent's global instructions file. DevFlow is a *pipeline plugin* — it cannot and should not install external tools. What ports is: instruction patterns, decision trees, hook designs, and config-management mechanics. All savings percentages below are upstream claims from the tokless/tool READMEs, not independently verified; the [Measurement appendix](#appendix-measuring-actual-savings) describes how to verify them locally before accepting any proposal.

## Executive summary

| # | Tokless technique | Mechanism class | Claimed savings | DevFlow status | Verdict |
|---|-------------------|-----------------|-----------------|----------------|---------|
| 1 | Owner-managed instruction sections | Config mechanics | n/a (dedup) | ❌ Missing | **Port pattern (P3)** |
| 2 | Principles (karpathy-skills) | Instruction text | n/a (fewer retries) | 🟡 Partial | **Port delta (P1)** |
| 3 | Caveman response style | Instruction text | 65% output tokens | ❌ Out of scope | Document only |
| 4 | Ponytail build discipline | Instruction text | n/a (less code generated) | ❌ Missing | **Port (P1)** |
| 5 | rtk CLI output proxy | PreToolUse hook | 60–90% on dev-ops output | 🟡 Partial (PostToolUse filter) | **Extend existing (P2)** |
| 6 | Codegraph index-first exploration | MCP + decision tree | one call vs. dozens | ❌ Missing | **Port decision tree (P1)** |
| 7 | context-mode sandbox derivation | MCP + decision tree | raw bytes never enter context | 🟡 Partial | **Port guidance (P2)** |
| 8 | Idempotent config editing | Config mechanics | n/a (correctness) | 🟡 Partial | **Port pattern (P3)** |

The highest-leverage ports are the three instruction-level techniques (2, 4, 6): they cost nothing at runtime, require only SKILL.md edits, and attack the two biggest token sinks in agent sessions — exploratory tool-call churn and over-generated code.

---

## Technique catalog

### 1. Unified instruction body with owner-managed sections

**Source:** `internal/tools/tokless_block.go`, `internal/tools/separators.go`

Tokless writes all tool instructions into a single per-agent instructions file (e.g. `~/.claude/CLAUDE.md`) as a sequence of *owner sections* — each tool "owns" one heading. The mechanics:

- `WriteOwner(agent, owner)` / `RemoveOwner(agent, owner)` / `HasOwner(agent, owner)` — fully idempotent; re-running install never duplicates content.
- Sections are identified by registered heading markers (`ownerOf()` against a registry), re-rendered as one body via `ToklessAgentBody(owners)`, and kept in canonical registry order (`sortOwnersByRegistry`).
- Legacy fenced blocks (`<!-- caveman-begin -->`…) from older versions are detected and migrated (`stripLegacy`).
- On conflict with pre-existing user content, an interactive prompt offers overwrite/append; non-interactive runs default to append (`instructionConflictChoice`).
- User content above/below the managed body (head/tail) is preserved byte-for-byte (`fileParts`, `joinFile`).
- `separators.go` normalizes blank lines between any `<!-- *-end -->` / `<!-- *-start -->` marker pairs left by other tools.

**Token relevance:** indirect — prevents duplicated/stale instruction text from accumulating in the context-loaded instructions file.

**Portability:** pattern portable to `devflow-setup` (shell, not Go).

### 2. Principles (karpathy-skills)

**Source:** `internal/util/agent_instructions.md` § "Principles" (upstream: [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills))

Four behavioral rules that reduce retry loops and over-generation:

1. **Think Before Coding** — state assumptions explicitly; if multiple interpretations exist, present them rather than picking silently; if unclear, stop and ask.
2. **Simplicity First** — minimum code that solves the problem; no speculative features, abstractions for single-use code, unrequested configurability, or error handling for impossible scenarios. "If you write 200 lines and it could be 50, rewrite it."
3. **Surgical Changes** — touch only what the request requires; don't improve adjacent code; match existing style; remove only orphans *your* change created; every changed line must trace to the user's request.
4. **Goal-Driven Execution** — transform tasks into verifiable goals before coding ("Fix the bug" → "Write a test that reproduces it, then make it pass"); state a step→verify plan for multi-step work.

**Token relevance:** fewer clarification round-trips, less code churn, smaller diffs to review.

**Portability:** high — pure instruction text. DevFlow already covers rule 1 (devflow-clarify) and rule 4 (acceptance criteria in task.md); rules 2–3 are the gap.

### 3. Caveman response style

**Source:** `agent_instructions.md` § "Response Style (caveman)" (upstream: [caveman](https://github.com/JuliusBrussee/caveman))

Terse prose style: drop articles, filler, pleasantries, hedging, tool-call narration, decorative tables. Keep technical terms, code, commands, paths, and exact error strings verbatim. Auto-clarity exceptions: security warnings, irreversible actions, ambiguous step order revert to normal prose. Claimed 65% output-token reduction across 30+ agents.

**Token relevance:** direct output-token cut on every response.

**Portability:** **out of scope for DevFlow.** Response style is an agent-global concern, not a pipeline concern; it is already delivered as a standalone plugin (this user runs it). Bundling a second style-enforcement layer into DevFlow would conflict with whatever style plugin the consumer already uses. Documented here only so the decision is recorded.

### 4. Ponytail build discipline

**Source:** `agent_instructions.md` § "Build Discipline (ponytail)" (upstream: [ponytail](https://github.com/DietrichGebert/ponytail))

"Lazy senior developer. Lazy means efficient, not careless. The best code is the code never written." A 7-rung ladder, stopping at the first rung that holds:

1. Does this need to exist at all? Speculative need = skip it (YAGNI).
2. Already in this codebase? Reuse the helper/util/type/pattern.
3. Stdlib does it? Use it.
4. Native platform feature covers it? CSS over JS, DB constraint over app code.
5. Already-installed dependency solves it? Never add a dep for what a few lines can do.
6. Can it be one line? One line.
7. Only then: minimum code that works.

Plus supporting rules:

- Bug fix = root cause, not symptom; check callers of the touched function; fix the shared path once.
- Complex request? **Ship the lazy version and question the bigger one in the same response. Never stall.**
- Deliberate simplification with a known ceiling gets one `ponytail:` comment naming ceiling + upgrade path.
- Explicit "do not be lazy about" list: understanding, trust-boundary validation, data-loss error handling, security, accessibility, anything explicitly requested.
- Non-trivial logic leaves ONE runnable check (assert-based self-check or one small test); trivial one-liners need none.

**Token relevance:** the largest single lever on *generated* tokens — less code written means less code reviewed, tested, re-read, and re-edited in every downstream pipeline step.

**Portability:** high — pure instruction text for `devflow-implement` plus a review axis for the code-reviewer agent.

### 5. rtk CLI output proxy

**Source:** `internal/tools/rtk.go` (upstream: [rtk](https://github.com/rtk-ai/rtk))

A Rust proxy binary that rewrites shell commands (`git status` → `rtk git status`) and returns filtered, token-optimized output. Claimed 60–90% savings on dev-ops command output. Wiring is per-agent:

- Claude Code: `settings.json` → `hooks.PreToolUse` matcher on Bash, command rewrite before execution.
- Gemini/Antigravity: `BeforeTool` hook on `run_shell_command`.
- Codex / Copilot / Droid: equivalent per-agent hook files, pre-trusted in config.

The interesting engineering detail is the *surgical unwire*: `removeClaudeRtkHookGroup` removes exactly the tokless-managed hook group and deletes empty parent keys, never clobbering user-defined hooks in the same file.

**Token relevance:** direct input-token cut on every shell command result.

**Portability:** DevFlow already has the complementary half — `hooks/post-bash-output-filter.sh` filters *after* execution via `hookSpecificOutput.updatedToolOutput`. The PostToolUse approach is actually preferable for a plugin (no external binary dependency, no command rewriting risk). Gap is coverage, not mechanism.

### 6. Codegraph index-first exploration

**Source:** `internal/tools/codegraph.go`, `agent_instructions.md` § "Code Index (codegraph)" (upstream: [codegraph](https://github.com/colbymchenry/codegraph))

An MCP server over a prebuilt AST index (`.codegraph/`). The ported asset is not the tool but the **decision tree** in the instructions:

```
.codegraph/ index exists?
├─ YES → codegraph_explore FIRST. Always. Source + blast radius + call path
│        in ONE call.
│        ├─ Use for: how does X work, flow A→B, architecture, who calls Y,
│        │   blast radius, subsystem structure, where is X, reading a file.
│        ├─ grep/search/read ONLY for non-code the index doesn't cover
│        │   (configs, docs, .env) — AFTER the index narrows it down.
│        └─ Trust results — full AST parse, safe to edit from. NO re-grep,
│           NO re-search, NO re-read of what the index returned.
└─ NO  → work normal (read / grep). Don't call the index.
```

The three rules that make it save tokens: (a) index **first**, never as fallback; (b) **trust** results — the re-grep/re-read reflex after a semantic tool call is pure waste; (c) one semantic call replaces a grep→read→grep→read chain.

**Token relevance:** exploratory tool-call churn is typically the biggest input-token sink in implement/plan sessions.

**Portability:** high as *generalized guidance* — consumer projects may have tokensave, codegraph, serena, or nothing. The decision tree ports with a "whatever index this project has" abstraction; the specific tool is detected at session start.

### 7. context-mode sandbox derivation

**Source:** `internal/tools/contextmode.go`, `agent_instructions.md` § "Context Tools (context-mode)" (upstream: context-mode, npm)

MCP server exposing sandbox tools where **raw bytes never enter context** — code runs against the data and only derived results are printed:

| Tool | Role | Replaces |
|------|------|----------|
| `ctx_execute` | Run code in sandbox; only stdout enters context | Bash for analysis tasks |
| `ctx_execute_file` | Process file in sandbox; raw bytes never leave | Read on large files (>200 lines) |
| `ctx_batch_execute` | Run N commands + auto-index output; search in same call | Multiple Bash + grep round-trips |
| `ctx_index` / `ctx_search` | Chunk text into FTS5; multi-strategy queryable | Manual grep over pasted content |
| `ctx_fetch_and_index` | URL → markdown → index, cached 24h | WebFetch + re-read |

Threshold rule: source >~200 lines/KB, multi-source, or worth re-querying → sandbox tools; small file, single section, or verbatim-read-for-editing → direct Read.

**Token relevance:** large-file reads and repeated log dumps are the second-biggest input sink after exploration churn.

**Portability:** the *tool* is an external npm dependency (Node 22+) — out of scope. The *pattern* ("derive, don't dump": batch commands, pipe through filters, state the answer not the log) ports as instruction text into the skills that run heavy commands.

### 8. Idempotent config-editing mechanics

**Source:** `internal/util/jsonc.go`, `internal/util/toml.go`, `rtk.go` unwire functions

Cross-cutting engineering discipline: ordered-map JSON editing that preserves key order and unknown keys; JSONC comment tolerance; surgical add/remove of exactly-owned hook groups; empty-parent cleanup; dry-run mode on every mutating operation.

**Token relevance:** none directly — correctness pattern that prevents config corruption in consumer projects.

**Portability:** partial precedent exists (`hooks/pre-config-protect.sh` guards config files); the add/remove-exactly-what-you-own discipline should be stated in CONTRIBUTING for any future setup-skill work.

---

## Gap analysis

| Tokless technique | DevFlow today | Gap |
|-------------------|---------------|-----|
| Owner-managed sections | `devflow-setup` writes consumer config; `pre-config-protect.sh` guards files | No idempotent owner-fence merge pattern; re-setup risks duplication |
| Principles | `devflow-clarify` (assumptions/Q&A), task.md ACs (goal-driven), CONTRIBUTING quality bar | "Simplicity First" and "Surgical Changes" absent from `devflow-implement`; scope-fidelity review axis exists (commit e7b6c83) but has no generation-side counterpart |
| Caveman style | Not present | Deliberate — out of scope |
| Ponytail ladder | Nothing equivalent | Full gap: no simplicity ladder, no "lazy version + question bigger one", no root-cause-over-symptom rule |
| rtk proxy | `post-bash-output-filter.sh`: head+signal+tail compression, `updatedToolOutput`, env-tunable thresholds | Command-class regex is hardcoded (flutter/dart/pnpm/npm/yarn/ng/git diff\|log); misses pytest, cargo, gradle, docker, generic test runners; adapters can't extend it |
| Index-first tree | Session-start hooks orient pipeline state, not exploration strategy | No index detection, no index-first rule, no "trust results, no re-grep" rule anywhere in skills |
| Sandbox derivation | `post-bash-output-filter.sh` (after the fact); depth profiles limit agent fan-out (commit 66e44fb) | No proactive guidance in skills to batch commands, filter at source, or summarize instead of paste |
| Idempotent config edits | `pre-config-protect.sh` | No documented owner-section discipline for setup writes |
| Session memory (context-mode FTS5) | `.devflow-instincts.yaml` + `session-start-learnings.sh` + `stop-learn-distill.sh` | Roughly equivalent for the pipeline's needs — no action |
| Pre-compaction state save | `pre-compact.sh` → `.devflow-state.json` | DevFlow already ahead here — no action |

---

## Porting proposals

Ordered by leverage-to-effort ratio. Each proposal names its touchpoints and the validation gate that must pass.

### P1a — Build-discipline ladder in `devflow-implement`

Add a "Token & Code Economy" subsection to `templates/devflow/skills/devflow-implement/SKILL.md` Core Principles:

- The 7-rung ladder verbatim (adapted wording), stopping at the first rung that holds.
- Root cause over symptom; check callers of touched functions.
- "Ship the lazy version and flag the bigger question in the same response — never stall."
- Surgical changes: every changed line traces to a plan.md subtask; no adjacent-code improvement; orphans of *this* change removed, pre-existing dead code only mentioned.
- The "do not be lazy about" exclusion list (security, trust boundaries, data-loss handling, accessibility) — aligns with existing security-auditor / accessibility-auditor fan-out axes.

Mirror on the review side: add a *simplicity* check to the `devflow:code-reviewer` agent's axes (flag rungs skipped: "this 40-line helper duplicates stdlib X", "this abstraction has one caller"). The scope-fidelity axis (commit e7b6c83) already catches scope creep; this catches over-engineering inside scope.

**Touchpoints:** `templates/devflow/skills/devflow-implement/SKILL.md`, code-reviewer agent definition under `templates/devflow/`.
**Gates:** `validate-skills.sh --strict`, `run-evals.sh` (description untouched → routing evals must stay green), `build-plugin.sh`.

### P1b — Index-first exploration decision tree

Generalized from tokless's codegraph section, tool-agnostic:

```
Project has a code index (tokensave / codegraph / serena / LSP MCP)?
├─ YES → one semantic query FIRST for any structural question
│        (how does X work, who calls Y, where is Z, blast radius).
│        Trust the result: no re-grep, no re-read of returned source.
│        grep/Read only for what the index doesn't cover (configs, docs).
└─ NO  → grep/Read as usual.
```

Inject at the three points where exploration happens:

- `devflow-discovery/SKILL.md` — detect available index MCPs at session orientation, record in state.
- `devflow-plan/SKILL.md` — planning research step uses index-first rule.
- `devflow-implement/SKILL.md` — pre-edit code reading uses index-first rule.

Keep it as a short shared block (one paragraph + tree) duplicated per skill, or referenced from a shared `references/` doc if the skills already use that pattern — follow whatever CONTRIBUTING prescribes for shared content.

**Touchpoints:** the three SKILL.md files above.
**Gates:** `validate-skills.sh --strict`, `run-evals.sh`, `build-plugin.sh`.

### P2a — Extend `post-bash-output-filter.sh` coverage

Current regex covers the three shipped adapters plus git. Extend:

1. Add generic command classes: `pytest`, `go test`, `cargo (test|build|clippy)`, `gradle|mvn`, `docker (build|compose)`, `tsc`, `eslint`, `jest`, `vitest`.
2. Better: make the class list data-driven — each adapter's definition contributes its command patterns (the hook already keys off "adapter Implement/Test/PR commands" per its header comment), with the generic set as fallback. This keeps new adapters filter-covered without touching the hook.
3. Keep thresholds env-overridable as today (`DEVFLOW_FILTER_*`).

**Touchpoints:** `templates/devflow/hooks/post-bash-output-filter.sh`, adapter definitions under `templates/devflow/adapters/*/`, new behavioral suite in `templates/devflow/hooks/tests/`.
**Gates:** `bash -n`, `run-hook-tests.sh` (add cases: pytest failure output, cargo build noise, under-threshold passthrough), `build-plugin.sh`.

### P2b — "Derive, don't dump" guidance in heavy-command skills

Instruction block for `devflow-implement`, `devflow-test`, and `devflow-ship` (the steps that run builds/tests/diffs):

- Batch related commands into one invocation; filter at source (`| tail -20`, `| grep -E 'FAIL|error'`) instead of dumping full output.
- State the derived answer ("3 tests fail, all in auth_test.py, same root cause"), quote only the decisive lines.
- Source >200 lines needed for a decision → extract the relevant section, never paste wholesale.
- Re-runs of the same check output only the delta.

This is the portable core of context-mode's value without the npm/Node-22 dependency.

**Touchpoints:** the three SKILL.md files; one line in `templates/devflow/CONTRIBUTING.md` quality bar so future skills inherit the rule.
**Gates:** `validate-skills.sh --strict`, `run-evals.sh`, `build-plugin.sh`.

### P3a — Owner-fenced managed sections in `devflow-setup`

When setup writes DevFlow content into consumer files (CLAUDE.md, settings), adopt the tokless merge discipline, shell-ported:

- Wrap DevFlow-owned content in `<!-- devflow:begin -->` / `<!-- devflow:end -->` fences.
- On re-setup: replace exactly the fenced region; preserve user head/tail content byte-for-byte; never append a second copy.
- On conflict (fences absent but DevFlow-looking content present): surface to the user rather than guessing.
- Removal deletes the fenced region and the file if it becomes empty.

**Touchpoints:** `templates/devflow/skills/devflow-setup/SKILL.md`, possibly a helper in `templates/devflow/scripts/`; document the discipline in CONTRIBUTING.
**Gates:** `validate-skills.sh --strict`, hook/script tests if a helper script is added, `build-plugin.sh`.

### P3b — Verify-criteria-first reinforcement

Karpathy rule 4 is mostly covered by task.md acceptance criteria. Small delta: `devflow-implement` should restate, per subtask, the check that will prove it done *before* writing code (test name, command, or observable behavior), so the implement loop is self-verifying rather than clarification-driven. One sentence in the implement skill's step sequence.

**Touchpoints:** `templates/devflow/skills/devflow-implement/SKILL.md`.
**Gates:** `validate-skills.sh --strict`, `build-plugin.sh`.

---

## Non-goals

- **No tool installation.** DevFlow never installs rtk, codegraph, context-mode, or any npm/binary dependency. Tokless owns that problem class.
- **No response-style enforcement.** Caveman-class styling stays a separate, user-chosen plugin.
- **No hard MCP dependency.** Index-first guidance is conditional ("if the project has an index"); every skill must degrade gracefully to grep/Read.
- **No new synchronous heavy hooks** (CLAUDE.md rule: `async: true` + `timeout` for I/O). The filter-hook extension keeps the existing synchronous-but-cheap awk design.
- **No PreToolUse command rewriting.** Rewriting user commands through a proxy binary (rtk's approach) is riskier than post-hoc filtering and adds a binary dependency; DevFlow keeps the PostToolUse design.

## Appendix: measuring actual savings

Accept or reject each proposal on data, not upstream claims:

1. **Baseline:** run one representative feature through the pipeline on the current plugin version; record per-step token usage (Claude Code `/cost`, or caveman-stats if installed, or transcript token counts from `~/.claude/projects/`).
2. **Filter hook (P2a):** compare `wc -c` of raw vs. filtered output on captured fixtures for each new command class — the hook's own test suite can assert compression ratios.
3. **Instruction ports (P1a/P1b/P2b):** A/B the same task with and without the new SKILL.md sections; compare total input+output tokens and tool-call counts (grep/Read call count is the direct proxy for P1b).
4. **Upstream references:** rtk claims 60–90% on command output (`rtk gain` shows measured local numbers if installed); caveman claims 65% output reduction. Treat both as ceilings, not expectations.
5. Log results in the learnings log (`devflow-learn`) so future tuning has a paper trail.
