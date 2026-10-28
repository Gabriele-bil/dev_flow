# Antigravity CLI hook payloads

Captured from `agy` 1.2.14 (`agy -p`, workspace `.agents/hooks.json`, a dump
hook per event) on 2026-10-28; paths replaced by `__WS__` / `__HOME__`.

- Events that fired: `SessionStart`, `PreInvocation`, `PostInvocation`, `Stop`
  (`PostInvocation` has the same shape as `PreInvocation`).
- `PreToolUse` / `PostToolUse` did not fire in print mode on 1.2.14 for
  `write_file` / `read_file` with any matcher, so no tool-event fixture exists
  yet — tool payload fields in `lib/payload.sh` (`toolName`, `toolInput`,
  `Path`, `CommandLine`, …) are best-effort until one is captured.
- No event name in the payload: the generated `hooks.json` passes it as
  `DEVFLOW_EVENT`. Hook cwd is the directory holding `hooks.json`; the project
  is `workspacePaths[0]`. Env: `ANTIGRAVITY_CONVERSATION_ID`.
- Tool names seen in the transcript: `write_file`, `read_file`.
