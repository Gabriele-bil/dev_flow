# awesome-claude-code Review — Improvement Opportunities for DevFlow

Source: [`awesome-claude-code`](https://github.com/hesreallyhim/awesome-claude-code) resource table (`THE_RESOURCES_TABLE_NEW.csv`, 137 entries across 18 categories, snapshot at analysis time). This is a curated pointer list, not vetted code — most entries are small, recently-added community projects. Nothing here should be added as a runtime dependency; DevFlow's "no runtime, auditable markdown/shell" stance (see `docs/comparison.md`) is a deliberate trade-off and should stay that way. The value of this review is **pattern-mining**: what problems these tools chose to solve, and whether DevFlow already solves them, solves them differently, or has a real gap.

Findings are grouped by theme, each with: the gap, the reference tool(s), and a concrete proposal scoped to an existing DevFlow file.

---

## 1. Context-file linting has more failure modes than we check for

**Current state**: `templates/devflow/scripts/validate-skills.sh` checks frontmatter (`name`, `description`) and required sections (`## Purpose`, `## Core Principles`, `## When NOT to Use`, `## I/O Reference`). It does not check content staleness or leakage.

**Reference tools** (Linting category):
- **agnix** — linter/LSP for `CLAUDE.md`/`AGENTS.md`/`SKILL.md`/hooks/MCP config, with autofixes.
- **Ctxlint** — catches *stale references, dead commands, and hardcoded secrets* in agent context files.
- **Schliff** — deterministic 8-dimension quality scorer for instruction files, with anti-gaming detection.

**Gap**: `validate-skills.sh` is structural (does the section exist?), not semantic (does the section still say something true?). A skill can reference a command that was renamed in `templates/devflow/commands/` and the linter stays green.

**Proposal**:
- Add a "dead reference" check to `validate-skills.sh --strict`: grep every `devflow.<verb>` and file-path mention inside a `SKILL.md` against the actual `commands/` and `skills/` directories; fail on orphaned references. This is the single highest-leverage addition — it directly protects the thing `CONTRIBUTING.md` already asks contributors to keep in sync.
- Add a hardcoded-secret grep pass (simple regex for API-key-shaped strings) as a pre-commit-style check, reusing the pattern already established by `pre-config-protect.sh`.
- Schliff's "anti-gaming detection" (catching instruction files that are padded to look thorough without adding constraint) is a good idea for `run-evals.sh`'s collision/trigger checks, but lower priority — skip unless trigger-quality regressions start showing up in practice.

**Priority**: High (dead-reference check), Low (anti-gaming scoring).

---

## 2. No generic destructive-command guard — only config-file protection

**Current state**: `pre-config-protect.sh` guards specific config files. There is no hook that intercepts destructive shell commands in general (`rm -rf`, `git reset --hard`, force-push) the way the top-level CLAUDE.md instructions already ask the *model* to be careful about — but a hook is deterministic where a system-prompt instruction is not.

**Reference tools** (Security category):
- **Claude Code Safety Net** — hook that catches destructive git/filesystem commands before execution, multi-CLI.
- **GouvernAI** — runtime guardrails with tiered auto-approve/gate/block + audit trail.
- **Agent Guard** — secret-leak guardrails via hooks + CI.

**Gap**: DevFlow's safety currently lives entirely in prose (this CLAUDE.md's "Executing actions with care" section). Anthropic's own framework — see item 6 below — is explicit that this is exactly the case where a **hook** beats a **rule**: rules are probabilistic (the model reads and follows them, usually), hooks are deterministic (the command physically cannot run).

**Proposal**: Add `templates/devflow/hooks/pre-bash-destructive-guard.sh` (PreToolUse on `Bash`) that pattern-matches known-destructive commands (`rm -rf`, `git push --force` to protected branches, `git reset --hard`, `git clean -f`) and blocks or requires explicit confirmation, mirroring the logic already in this CLAUDE.md's Git Safety Protocol but enforced mechanically instead of relying on the model reading it. This is additive to `hooks.json`, testable the same way `stop-format-typecheck.sh` is tested in `templates/devflow/hooks/tests/`.

**Priority**: Medium — the model-level instructions already cover this reasonably well; a hook is defense-in-depth, not a fix for an observed failure.

---

## 3. Learning/memory has no outcome calibration

**Current state**: `observe.sh` logs tool calls and retry loops to `.devflow-observe.jsonl`; `stop-learn-distill.sh` + `devflow-learn` skill distill learnings into `.devflow-learnings.jsonl`. This captures *that something happened*, not whether the resulting advice actually worked afterward.

**Reference tools** (Memory & Context Persistence category):
- **presence** — per-repo memory with outcome telemetry and a *calibrated-confidence gate*: "success claims need test evidence; your reverts are remembered."
- **roampal-core** — outcome-based memory; good advice promoted, bad advice demoted over time.
- **Selvedge** — captures the agent's *reasoning* live, as each change is made ("git blame, but for the why").

**Gap**: `devflow-learn` writes a learning when a pattern is distilled, but nothing downgrades or removes a learning that turned out to be wrong (e.g., a fix that was later reverted). Over a long-lived repo, `.devflow-learnings.jsonl` can accumulate stale or actively-wrong guidance with no decay mechanism.

**Proposal**: Read `templates/devflow/skills/devflow-learn/SKILL.md` and check whether it already has a revert-detection step — if not, add one: when `observe.sh` sees a `git revert` or `git reset` touching files a recent learning referenced, tag that learning `contested` instead of deleting it outright (matches presence's "reverts are remembered" framing, and is cheap to compute from data `observe.sh` already logs).

**Priority**: Medium — real gap, but scoped work; needs a look at the current `devflow-learn` SKILL.md content before committing to exact mechanics (didn't fully verify absence of this logic).

---

## 4. Multi-agent review has no conflict-resolution step

**Current state**: `devflow.ship` dispatches `code-reviewer`, `security-auditor`, and `test-engineer` in parallel and "synthesizes reports." `accessibility-auditor` and `docs-reviewer` also exist in `templates/devflow/agents/` but aren't in the ship command's fixed fan-out list.

**Reference tools** (Agent Orchestration category):
- **Agent Collab Skills** — task splitter, output reconciler, *adversarial debate*, shared memory, acceptance gate.
- **gstack** — end-to-end "software factory" lifecycle agents.

**Gap**: When `code-reviewer` and `security-auditor` disagree (e.g., one flags a pattern as fine, the other as a vulnerability), it's unclear from the command file how `devflow.ship` resolves that — "synthesizes" could mean anything from a real reconciliation step to just concatenating both reports.

**Proposal**: Check `templates/devflow/skills/devflow-ship/SKILL.md` for an explicit reconciliation rule; if none exists, add one: on direct contradiction between two specialist reports, escalate to the user rather than silently picking one side (matches the existing "bounded escalation ladder" DevFlow already claims in `docs/comparison.md`, so this is closing a real inconsistency between documented philosophy and implementation, not importing something new).

**Priority**: Medium — verify first, this may already be handled.

---

## 5. No observability surface for the JSONL logs that already exist

**Current state**: `.devflow-observe.jsonl` and `.devflow-learnings.jsonl` are headless — written by hooks, read by `devflow-learn`/`devflow-status`, never surfaced as a human-readable timeline.

**Reference tools** (Observability & Monitoring category, 22 entries):
- **Multi-Agent Observability** — dashboard tracing hook events, tool calls, and task handoffs across concurrent agents (Bun/SQLite/WebSocket/Vue).

**Gap**: Debugging a bad DevFlow run currently means reading raw JSONL by hand. `devflow.status` likely already surfaces a summary — worth confirming it includes retry-loop counts from `observe.sh`'s `RETRY_THRESHOLD`/`RETRY_WINDOW` logic.

**Proposal**: Low priority, and explicitly **against** importing a Bun/SQLite/WebSocket stack — that contradicts DevFlow's no-runtime positioning. If a gap is confirmed, the DevFlow-native fix is a `jq`-based pretty-printer subcommand in `devflow.status`, not a dashboard.

**Priority**: Low.

---

## 6. No written framework for "skill vs. hook vs. rule" — worth citing, not building

**Reference** (From Anthropic category):
- **"Steering Claude Code: Skills, Hooks, Rules, Subagents and More"** — Anthropic's own framework, organized around *deterministic vs. probabilistic control* and context isolation.

**Observation**: This isn't a code gap, it's a documentation opportunity. `templates/devflow/CONTRIBUTING.md` sets the quality bar for skill content but (unverified — worth checking) may not state *when a new mechanism should be a hook instead of a skill*. Item 2 above is a concrete instance of exactly this question.

**Proposal**: Add a short section to `CONTRIBUTING.md` — "Choosing a mechanism" — codifying: hooks for anything that must be deterministic (safety, formatting, config protection), skills for anything that needs judgment/context, commands as thin dispatchers (matches the existing `devflow.ship.md` pattern of "use SKILL.md and execute it exactly"). Cite Anthropic's framework as the source of the distinction.

**Priority**: Low, cheap, high clarity value for future contributors.

---

## Summary table

| # | Gap | Reference tool(s) | File(s) to touch | Priority | Status |
|---|---|---|---|---|---|
| 1 | No dead-reference/secret check in skill linting | agnix, Ctxlint, Schliff | `scripts/validate-skills.sh` | High | ✅ Applied |
| 2 | No generic destructive-command hook | Claude Code Safety Net, GouvernAI, Agent Guard | `hooks/pre-bash-destructive-guard.sh` (new), `hooks/hooks.json` | Medium | ✅ Applied |
| 3 | Learnings never decay on revert | presence, roampal-core | `skills/devflow-learn/SKILL.md`, `hooks/observe.sh` | Medium | ✅ Applied |
| 4 | Ship-gate conflict resolution undocumented | Agent Collab Skills | `skills/devflow-ship/SKILL.md` | Medium | ✅ Applied |
| 5 | JSONL logs are headless | Multi-Agent Observability | `commands/devflow.status.md` | Low | ✅ Applied |
| 6 | No documented skill/hook/rule decision rule | Anthropic "Steering Claude Code" | `CONTRIBUTING.md` | Low | ✅ Applied |

## Explicitly not recommended

- Any of the memory/observability tools as **MCP dependencies** — DevFlow's differentiator vs. Forge/spec-kit is zero runtime; adding an MCP server for memory reintroduces exactly the dependency surface that positioning avoids.
- Ralph-style autonomous looping features — DevFlow already ships `ralph-loop` as an opt-in skill; the gated, step-by-step model is a deliberate product choice per `docs/comparison.md`, not a gap to close.
- Voice/Telegram/remote-notification integrations (Remote Control category, 8 entries) — `stop-notify.sh`'s local macOS notification is proportionate to DevFlow's single-host scope; broadening it is scope creep without a stated user need.
