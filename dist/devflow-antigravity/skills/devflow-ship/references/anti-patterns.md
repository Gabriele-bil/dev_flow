# devflow-ship — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Skipping ship gate ("tests passed") | Tests prove behavior; ship gate proves code quality + security before merge |
| Dispatching reviewers sequentially | One packet, all roster agents in parallel |
| Auto-proceeding on Critical issue | Critical = block; fix or escalate; never auto-proceed |
| Downgrading profile at ship to shrink roster | Profile fixed at plan; change requires plan.md edit + user confirmation |
| Downgrading severity in synthesis | Report as declared; disputes go to **Reviewer Disagreements** |
| Omitting decision flags from the report | Every `## Decision flags` entry surfaces in **Open Decision Flags** |
| Auto-routing to `devflow.pr` under `devflow.run` | `devflow.run` stops before PR; only `devflow.auto` chains into `devflow.pr` |
| Fixing findings then setting `shipped` on old `verification.md` | Every fix iteration re-runs implement `--fix` → test |
| Grader loop bypassing the Critical hard-stop | Step 4b engages only for Required-only verdicts |
| Unbounded grader retries | Respect `ship_grader_iterations` (default 2) via `run bump` |
| Changing roster on a Step 4b re-run | Same roster as the first dispatch |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Small diff, skip security-auditor on standard" | Roster is set by profile, not by diff size — `quick` already covers the small cases |
| "Coverage looks thin, add a test-engineer pass" | Coverage is gated by `devflow.test` (`verification.md` per AC); gaps there → `devflow.backprop`, not ship |
| "Fix is one line, patch inline and mark shipped" | Any edit after test invalidates `verification.md` — walk the fix loop |
