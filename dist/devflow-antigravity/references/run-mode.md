# Run Mode Contract

Single source for unattended execution. Orchestrators: `devflow.run` (middle pipeline) and `devflow.auto` (idea → PR, = run with the `task → pr` preset). Step skills (`task`, `clarify`, `plan`, `analyze`, `implement`, `beautify`, `test`, `ship`) switch behavior on marker presence only.

## Marker

`.devflow-run.json` at project root — schema + lifecycle: `$HOME/.gemini/antigravity-cli/plugins/devflow/references/state-machine.md` → **Run marker**. Presence = run mode. No marker = interactive rules, whatever the user said earlier.

- Armed only by an orchestrator's Step 0 — never by a step skill, never mid-conversation.
- `devflow.run`: armed after one explicit user confirmation.
- `devflow.auto`: armed immediately; every input needing the user (idea text, monorepo `--app`, stale-marker cleanup) collected **before** arming.
- Stale marker found before arming → ask user: delete, or route `devflow.recovery`.
- Arm with `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" run arm …` (refuses a stale marker, appends `.devflow-run.json` to `.gitignore`); disarm with `run disarm`.

## Autonomy policy

| Action | `run` | `auto` |
| --- | --- | --- |
| Write/edit files in `plan.md` File List scope | ✅ | ✅ |
| Write `task.md` / `plan.md` (task, clarify, plan steps) | — | ✅ |
| Adapter format/analyze/codegen/test commands | ✅ | ✅ |
| `plan.md` Status, `[done]`, `## Deviations`, `## Decision flags`; `.checkpoint.json`; state snippet | ✅ | ✅ |
| Switch/create feature branch per `devflow-task` / `devflow-implement` | ✅ | ✅ |
| Beautify **certain** improvements (opinable → flag, never applied) | ✅ | ✅ |
| Ship fan-out + Required-only fix loop (`devflow-ship` Step 4b, bounded) | `--until ship` | ✅ |
| `git commit` / `push` / open PR — only via `devflow-pr` | ❌ | ✅ |
| Edit `devflow/config.md`, CI/tooling configs | ❌ | ❌ |
| Install deps not in plan; delete files outside plan scope | ❌ | ❌ |

## Decision flags

Where a step would pause (ambiguity, conflict with code/registry, opinable improvement, open question): pick most defensible default, append to `plan.md` (create section on first flag), continue.

```markdown
## Decision flags

- **F1** — decision: [chosen]; alternatives: [rejected options]; rationale: [why defensible]; files: `path/a`, `path/b`
```

Precedence: repo precedent > `constitution.md` > adapter convention (`devflow.task`: repo precedent > `docs/product.md` > conservative reading → `## Assumptions & Risks`). No precedent for product behavior → most conservative behavior (fail closed / no-op) + flag; never invent product rules. Flags surface in `devflow.ship` **Open Decision Flags** and the PR body.

## Discrepancy classes

| Major — hard stop (both orchestrators) | Minor — flag + continue |
| --- | --- |
| Constitution Gate Critical/Required (`devflow-plan` Step 0b) | Ambiguity / unspecified behavior |
| `devflow.analyze` Critical | `devflow.analyze` Required / Nit (`auto`: waiver flag) |
| `escalation-ladder.md` Level 5 block | Beautify opinable proposal |
| `devflow.ship` Critical | Ship Required at loop cap — `run`: surface report; `auto`: exceptions flag → PR body |
| Step input contract fails | Idea vs codebase mismatch → `## Deviations` + flag |
| Missing monorepo App; brainstorm-scale idea (`auto`) | |

## Step dispatch

While armed, the orchestrator runs each pipeline step in a `step-runner` subagent (`$HOME/.gemini/antigravity-cli/plugins/devflow/agents/step-runner.md`), one per step: the step's skill body and tool output stay in that subagent, and `plan.md`, `.devflow-state.json`, the stamps and the reports carry everything to the next step. Same mechanism on both hosts.

| | Claude Code | Antigravity CLI |
| --- | --- | --- |
| Tool | Agent, `subagent_type: "devflow:step-runner"` | `invoke_subagent`, subagent `step-runner` |
| Model | per-call `model` from `$HOME/.gemini/antigravity-cli/plugins/devflow/references/model-selection.md` → Decision Table (run/auto column) | session model |
| Workspace | shared (default) | `Workspace: 'inherit'` — a branched worktree would keep the step's edits out of the project |

- **Prompt** — only: `Skill: <absolute path of skills/devflow-<step>/SKILL.md> · Feature: <NNN_name or "none yet"> · Arguments: <args or none> · Orchestrator: <devflow.run | devflow.auto>`. Wait for the subagent's final message before anything else.
- **Result** — its `RESULT:` line. `ok` → confirm with `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" status` that `plan.md` reached the step's exit status (otherwise treat as `stopped`); `stopped` / `failed` → stop the run and carry its `REPORT:` block into the final report.
- **Stay in the orchestrator's context**: `devflow.ship` (it dispatches the reviewer subagents, and subagents cannot dispatch subagents) and `devflow.pr`.
- **No subagent support** on the host → run the step skills inline, in order, and write `Mode: single context` in the final report.

## Step behavior while armed

- Notify blocks emitted, never waited on — control returns to the orchestrator.
- Input contracts never forced; failure → orchestrator stops.
- Context pressure → handoff per `state-machine.md` → **Handoff file**, stop.

## Disarm

Owning orchestrator deletes `.devflow-run.json` on **every** exit path — complete, contract failure, major discrepancy, handoff. Stale marker next session → `devflow.resume` asks; never silently re-armed.
