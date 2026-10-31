# Antigravity CLI hook payloads

Captured on 2026-10-28 (`agy -p`, workspace `.agents/hooks.json`, a dump hook
per event): lifecycle events on 1.2.14, tool events on 1.4.9. Paths replaced
by `__WS__` / `__HOME__`.

- Events that fired: `SessionStart`, `PreInvocation`, `PostInvocation`, `Stop`
  (`PostInvocation` has the same shape as `PreInvocation`).
- Tool events carry `toolCall: {name, args}` (`args.Path`, `args.Content`);
  PostToolUse adds `error` ("" on success) and no tool output. Tool events
  need the nested entry form `{matcher, hooks: [{command}]}` — a flat
  `{matcher, command}` entry is accepted by the parser but never runs.
- `{"decision":"deny","reason":"..."}` on stdout blocks the call; the reason
  reaches the model as "tool call denied by pre-tool hook: <reason>".
- `run_command` args (`CommandLine`) inferred from the tool schema, not
  captured (print mode cannot approve shell commands).
- No event name in the payload: the generated `hooks.json` passes it as
  `DEVFLOW_EVENT`. Hook cwd is the directory holding `hooks.json`; the project
  is `workspacePaths[0]`. Env: `ANTIGRAVITY_CONVERSATION_ID`.
- Tool names seen in the transcript: `write_file`, `read_file`.
