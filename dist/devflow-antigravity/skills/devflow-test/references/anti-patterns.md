# devflow-test — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Writing tests after PR is open | Tests are a pre-condition for `devflow.pr` |
| Manual-only testing | Automated tests required for PR checklist |
| Skipping trivial files | A trivial test beats no test; untestable → document why |
| Skipping integration tests | They cover user flows unit tests can't |
| Marking failing tests as passing after 3 retries | Stop and report; never falsify the summary |
| Testing implementation internals | Test inputs → outputs; mock only system boundaries |
| 100% coverage with no assertions | Every test must assert at least one specific output |
| Flaky test fixed with `retry(3)` | Fix root cause; use deterministic setup |
| Happy-path-only tests | ≥1 error path per public function (`standard`+ profiles; `quick` = happy + regression per AC) |
| Pasting test output into the report | Stamp lines carry counts + log path; the log is the evidence (`token-economy.md`) |
| Skipping `testing-patterns.md` for novel scenarios | Read `$HOME/.gemini/antigravity-cli/plugins/devflow/references/testing-patterns.md` first |
| Skipping verification because tests pass | Tests are forward-looking; Step 6b proves each AC exists, is real, is wired |
| Setting `tested` with FAIL verdicts in verification.md | FAIL = not tested; fix or route to `devflow.backprop` |
