# devflow-pr — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Opening PR with failing tests | Fix or document failures with root cause first |
| Ticking checklist without running commands | Every item must reflect actual command output |
| Skipping `registry.md` update for new patterns | Undocumented patterns → inconsistency |
| `git add .` / `git add -A` | Stage expected paths only; review `git diff --cached --stat` |
| Deleting images/files by wildcard to "clean up" | Delete only session files this pipeline created; leave the rest unstaged and report |
| Committing screenshot files to repo working tree | Capture to `/tmp/` only; never stage |
| Embedding a local image path in the PR body | Never renders on GitHub; report path in Step 6 for manual upload |
| Failing PR creation on headless CI | Skip screenshot capture cleanly when no display available |
| Commit type differing from branch prefix | Derive from `**Branch:**` (`doc` → `docs`) |
| PR body without task reference | Include `Closes TASK-NNN` |
| Force-pushing an open PR | Creates follow-up commit instead |
| Skipping `devflow.ship` | Ship gate prevents broken code reaching main |
