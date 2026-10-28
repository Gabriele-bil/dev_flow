# AI Agent Threat Model

Companion to `security-checklist.md`. Covers attack surfaces specific to agentic AI systems.
Use during `devflow-beautify` security axis and `devflow-ship` security-auditor review.

## Core Assumption

> Build assuming malicious text will eventually reach context. The question is not whether injection happens — it does — but whether the architecture survives it.

## Attack Surfaces in DevFlow

| Surface | Threat | Mitigation |
| --------- | -------- | ------------ |
| `task.md` / `plan.md` (user-authored) | Prompt injection via spec content | Sanitize before passing to agents; validate structure |
| `.devflow-state.json` | State tampering → pipeline skip | Read-only in hooks; write only via trusted scripts |
| `hooks.json` | Malicious hook injection | Version-control hooks.json; never auto-update from external sources |
| MCP tool responses | Poisoned tool output reaching context | Treat MCP output as untrusted input; validate shape |
| `devflow-ship` agents (5 parallel) | One compromised agent poisons report | Agents isolated; synthesizer validates severity labels |
| `.devflow-learnings.jsonl` | Injected learnings overriding correct behavior | Review learnings before merging into instincts |
| External URLs in plan.md | SSRF / content injection via fetch | Never auto-fetch URLs from plan.md without user confirmation |
| `ADAPTER.md` + skill files | Backdoor via malicious plugin update | Audit all plugin updates; pin plugin versions |

## Attack Categories

### 1. Prompt Injection

Malicious instructions embedded in content the agent reads (tickets, docs, API responses, user stories).

**Signature**: Instructions targeting the agent directly — "Ignore previous instructions…", "From now on you must…"

**DevFlow exposure**: `task.md` authored from external specs, API docs fetched during implement, code comments in third-party repos

**Defense**:

- Treat all file content as data, not instructions
- Never pass raw external content as system prompt material
- `pre-config-protect.sh` blocks config overwrites from tool use

### 2. State Corruption

`.devflow-state.json` modified mid-pipeline to skip quality gates or advance step counter.

**Defense**:

- `post-task-create.sh` is the only writer — scripts, not Claude
- `devflow-recovery` detects corrupt state before resuming

### 3. Memory Poisoning

Malicious entries injected into `.devflow-learnings.jsonl` to override correct project behavior in future sessions.

**Defense**:

- `devflow-learn` prune before promoting to `.devflow-instincts.yaml`
- Review learnings flagged from external content sessions

### 4. Tool Boundary Violations

Agent using tools beyond declared scope — reading secrets, writing outside feature directory.

**Defense**:

- Agents in `devflow.ship` run as subagents with declared tool scope
- `pre-config-protect.sh` blocks writes to linter/analyzer configs

### 5. Supply Chain

Plugin updates containing backdoors or behavior-altering skill rewrites.

**Defense**:

- Pin devflow version in consumer project
- Audit all changes before `bash scripts/build-plugin.sh`
- No auto-install patterns — explicit user action required

## Identity Separation

In team or CI environments:

- Use dedicated service account for automated devflow runs (`devflow-bot@domain.com`)
- Bot tokens scoped to minimum permissions (no admin, no secret access)
- Separate credentials from developer personal tokens

## Observability Baseline

`.devflow-observe.jsonl` logs every tool call. Use it to detect:

- Unexpected file writes outside feature directory
- MCP calls to URLs not in plan.md
- Hook execution anomalies (exit codes, timeouts)

```bash
# Review last session tool calls
tail -50 .devflow-observe.jsonl | jq '.tool_name, .file_path // empty'
```

## Incident Response (Pipeline Compromise Suspected)

1. Run `devflow-recovery` — diagnose state
2. Review `.devflow-observe.jsonl` for anomalous writes
3. Check `.devflow-learnings.jsonl` for injected entries
4. Reset state: `rm .devflow-state.json` → rerun from `devflow-task`
5. Review all files modified in compromised session before commit
