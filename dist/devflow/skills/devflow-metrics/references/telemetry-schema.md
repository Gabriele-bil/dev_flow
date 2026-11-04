# devflow-metrics — local telemetry schema

All telemetry lives in `.devflow-metrics/` at the workspace root. It is local only: hooks append JSONL rows, nothing is sent anywhere, and the folder is gitignored (`devflow.init`, `devflow.setup` and the first hook write add `.devflow-metrics/` to `.gitignore`; `devflow.doctor --fix` repairs a missing entry).

| Variable | Effect |
| --- | --- |
| `DEVFLOW_METRICS_DIR=<path>` | Relocate the folder (no `.gitignore` entry is added for a custom path) |
| `DEVFLOW_METRICS_DIR=off` | Disable all telemetry |
| `DEVFLOW_METRICS_LOG`, `DEVFLOW_TIMINGS_LOG`, `DEVFLOW_FILTER_STATS`, `DEVFLOW_MODEL_SWITCH_LOG` | Redirect one file (`off` disables it) |
| `DEVFLOW_PRICING_JSON` | Override the USD/MTok table used for cost estimates |

Each file rotates to `<file>.1` past 2 MiB; `metrics.sh` reads both. Root-level logs from before 2.1 (`.devflow-metrics.jsonl`, `.devflow-timings.jsonl`, `.devflow-filter-stats.jsonl`, `.devflow-model-switch.jsonl`) move into the folder on first use.

Privacy: no prompt text, file content or tool output is stored — only sizes, names and counts. `filter-stats.jsonl` keeps the first 60 characters of filtered shell commands.

## Files

| File | Writer (event) | One row per |
| --- | --- | --- |
| `turns.jsonl` | `stop-metrics.sh` (Stop) | model turn with token usage |
| `timings.jsonl` | `stop-metrics.sh`, `post-task-create.sh` | devflow command turn (board timeline) |
| `tools.jsonl` | `observe.sh post` (PostToolUse / PostToolUseFailure) | tool call |
| `context.jsonl` | `lib/emit.sh` `df_context` (any hook) | context injection by a devflow hook |
| `sessions.jsonl` | `metrics-collect.sh` (SessionStart, PreCompact, SessionEnd) | session start, compaction, session end |
| `prompts.jsonl` | `metrics-collect.sh prompt` (UserPromptSubmit) | user prompt |
| `subagents.jsonl` | `metrics-collect.sh subagent-stop` (SubagentStop) | finished subagent |
| `filter-stats.jsonl` | `post-bash-output-filter.sh` | filtered shell output |
| `model-switch.jsonl` | `post-model-switch.sh` | model switch |
| `.pending/` | `observe.sh pre` | in-flight tool call start (ms), removed by `post`; stale marks swept at session start |

Common fields: `ts` (UTC ISO-8601), `session`, `host` (`claude` / `antigravity`), `step` (`.devflow-state.json` `next_step`), `feature`, `command` (devflow command the turn belongs to: from the typed `/devflow.<step>`, the Skill tool loading `devflow-<step>`, or the artefact being written).

### turns.jsonl

`input_tokens`, `output_tokens`, `cache_creation_tokens`, `cache_read_tokens` (tokens read from the prompt cache), `thinking_tokens`, `api_calls`, `context_tokens` (prompt size of the turn's last model call — the context window in use), `peak_context_tokens`, `tool_calls` (`{name: count}`), `skills` (Skill tool inputs), `slash_commands`, `compactions`, `web_searches`, `model`, `estimated_cost_usd`, `duration_ms` / `duration_sec`, `started_at`, `ended_at`, `plugin_version`. Usage counts only transcript lines appended since the previous Stop, so rows sum without double counting.

Duration source, first available: UserPromptSubmit mark → first tool call of the turn (devflow projects) → first transcript timestamp of the turn (≤ 6 h).

### tools.jsonl

`tool`, `kind` (`shell`, `write`, `edit`, `read`, `fetch`, `subagent`, `other`), `duration_ms` (pre→post, matched by `tool_use_id`; Antigravity: `conversationId-stepIdx`), `is_error`, `output_chars` / `output_tokens_est` (tool output returned to the model, before the bash filter), `skill`, `subagent_type`, `mcp_server`, `agent_type` (set when a subagent made the call).

### context.jsonl

`hook` (script name), `event`, `chars`, `est_tokens` (chars / 4). Covers every `df_context` call: session orientation, instincts, post-edit instinct hints, soft warnings.

### sessions.jsonl

- `session_start`: `source` (`startup`, `resume`, `clear`, `compact`), `model`, `plugin_version`, `adapter`, `devflow_active`
- `compact`: `trigger` (`auto` / `manual`), `context_tokens` at compaction, `tool_calls_in_session`
- `session_end`: `reason`

### prompts.jsonl

`chars`, `est_tokens`, `slash_command` (first word when the prompt starts with `/`), `command` (devflow step when the slash command is a devflow one).

### subagents.jsonl

`agent_type`, `agent_id`, `model`, `api_calls`, token fields as in `turns.jsonl`, `peak_context_tokens`, `tool_calls`, `duration_ms`, `estimated_cost_usd`, `command` active in the parent session. Subagent usage lives in its own transcript, so these tokens are not part of `turns.jsonl`.

## Host coverage

| Signal | Claude Code | Antigravity CLI |
| --- | --- | --- |
| Turn tokens, cost | yes | tokens (no price table → cost omitted) |
| Context per turn, thinking, tool mix, skills | yes | context + tool mix |
| Tool rows with duration | yes | yes (no output size: payload carries none) |
| Context injected by hooks | yes | yes |
| Session start | yes | yes |
| Prompts, compactions, session end, subagents | yes | no (events not available) |
