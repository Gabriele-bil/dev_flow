# devflow-metrics — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Treating estimated USD costs as exact invoices | Pricing tables drift and exclude provider-specific discounts | Treat telemetry costs as relative indicators between features |
| Disabling filter telemetry | Blind to token bloat caused by verbose test outputs | Keep `.devflow-metrics/filter-stats.jsonl` active to measure filter ROI |
| Ignoring low pass@1 rates | Hidden build or test flakes slow down pipeline execution | Inspect `.devflow-metrics/tools.jsonl` (`by_tool` error %) to identify failing tool calls |
| Committing local metric JSONL files | Pollutes git history with developer-specific telemetry | Keep `.devflow-metrics/` gitignored (init/setup add it; `devflow.doctor --fix` repairs it) |
| Reading one session's numbers as a trend | A single long session skews averages (context, duration) | Compare windows with `--since`, and per `plugin_version` before/after a skill change |
| Sharing raw telemetry files | Rows carry feature names, file-free but project-specific | Share the `--json` aggregate, not the folder |
