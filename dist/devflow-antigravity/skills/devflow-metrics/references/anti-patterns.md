# devflow-metrics — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Treating estimated USD costs as exact invoices | Pricing tables drift and exclude provider-specific discounts | Treat telemetry costs as relative indicators between features |
| Disabling filter telemetry | Blind to token bloat caused by verbose test outputs | Keep `.devflow-filter-stats.jsonl` active to measure filter ROI |
| Ignoring low pass@1 rates | Hidden build or test flakes slow down pipeline execution | Inspect `.devflow-observe.jsonl` to identify failing tool calls |
| Committing local metric JSONL files | Pollutes git history with developer-specific telemetry | Keep `.devflow-metrics.jsonl` and filter stats gitignored |
