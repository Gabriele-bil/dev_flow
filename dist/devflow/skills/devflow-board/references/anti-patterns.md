# devflow-board — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Hand-editing `devflow/board/board-data.js` | Overwritten on next `--sync` hook trigger | Edit source `task.md` / `plan.md` and let `board.sh --sync` regenerate the manifest |
| Using `fetch()` only without `board-data.js` script tag | Browser CORS blocks `fetch()` when opening `devflow/board/index.html` via `file://` | Always emit `board-data.js` (`window.__DEVFLOW_BOARD_DATA__`) alongside `board-data.json` |
| Running synchronous heavy board builds inside `PreToolUse` hooks | Adds latency to every tool call | Run `board.sh --sync --quiet` only in async `PostToolUse` / `Stop` hooks |
| Rendering unescaped raw Markdown HTML in the drawer | Risks broken DOM or script injection from code snippets inside specs | Escape HTML entities before applying Markdown/Gherkin formatting |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Write a custom HTML dashboard tailored to this repo's stack" | Forbidden. Every project must use the exact `@devflow/skills/devflow-board/assets/board-template.html` via `board.sh` |
| "Add drag-and-drop card moving or checkbox toggling in the browser" | Board is strictly static and read-only; state changes happen exclusively through DevFlow pipeline commands |
| "Recreate `devflow/board/index.html` from scratch on every hook event" | Once initialized, hooks run `board.sh --sync --quiet` to update only `board-data.js` |
| "Require npm/vite/webpack in the consumer project to build the board" | Zero consumer build dependencies allowed; `index.html` + `board-data.js` run directly on `file://` or static HTTP |
