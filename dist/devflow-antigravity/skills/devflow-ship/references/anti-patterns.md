# devflow-ship — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Skipping ship gate ("tests passed") | Tests prove behavior; ship gate proves merge readiness across quality, security, coverage |
| Running reviewers sequentially | Fan-out is the design; sequential loses independent perspectives |
| Auto-proceeding on Critical issue | Critical = block; fix or escalate; never auto-proceed |
| Merging reports mentally without synthesis | Written synthesis is the audit trail |
| Dispatching fewer agents than profile requires | Fan-out per depth profile table: `quick` = 1, `standard` = 3, `thorough` = 5 |
| Downgrading profile at ship to shrink fan-out | Profile fixed at plan; change requires plan.md edit + user confirmation |
| Synthesizing before all agents complete | Wait for all dispatched reports before Step 3 |
| Downgrading severity in synthesis | Report as declared; escalate if disputed |
| Omitting decision flags from the report | Every `## Decision flags` entry surfaces in **Open Decision Flags** — autonomous decisions get human review before PR |
| Auto-routing to `devflow.pr` under `devflow.run` | Run mode under `devflow.run` stops before PR; `devflow.auto` chains through `devflow.pr` |
| Re-running after fixing only some Critical issues | Fix all Critical; re-run full gate from Step 1 |
| Looping Step 4b without asking outside run mode | Interactive sessions ask per Step 4; loop only after user chooses fix |
| Fixing findings then setting `shipped` on old `verification.md` | Every fix iteration re-runs implement → beautify → test (Step 6b) — `tested → shipped` needs fresh verification |
| Grader loop bypassing the Critical hard-stop | Critical always stops immediately regardless of run mode or remaining iteration budget — Step 4b only ever engages for Required-only verdicts |
| Unbounded grader retries | Respect `ship_grader_iterations` (default 2); reaching the cap surfaces the report instead of looping again |
| Shrinking fan-out on a Step 4b re-run | Re-run uses the same depth profile as the original dispatch — same rule as any other re-run |
