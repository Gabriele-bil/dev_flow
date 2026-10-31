# devflow-worktree — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Creating a worktree without checking `.devflow-worktrees.json` for overlap | Step 4 overlap detection is mandatory, not optional |
| Hardcoding port 3000 regardless of adapter | Resolve adapter base port from the table, then add the offset |
| Leaving a stale entry in `.devflow-worktrees.json` after manual `git worktree remove` | `remove` subcommand must update both git and the state file together |
| Branching a worktree from a dirty working tree without asking | Input contract requires clean status or explicit user override |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Only one worktree active, skip offset math" | Next worktree created later still needs a free slot — always write the offset, even at 0 |
| "User didn't ask for port isolation, just a worktree" | Two worktrees on the default port collide the moment both dev servers run — assign offset unconditionally when the adapter has a dev server |
| "Feature name matches an existing worktree, just reuse it silently" | Silent reuse hides that work is already in progress there — always report the existing worktree and let the user decide |
| "Removing a worktree with uncommitted changes is fine, `--force` handles it" | `--force` discards that work — confirm with the user first |
