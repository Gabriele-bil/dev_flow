# Complexity Scoring & Depth Profiles

Score feature complexity 0–20 at plan time → map to depth profile → downstream steps scale rigor. Fixes fixed-ceremony cost: one-line fix no longer pays 30-file-feature overhead.

Written by `devflow.plan` (Step 4d) into `plan.md` frontmatter: `**Complexity:** N (quick|standard|thorough)`.
Read by `devflow.beautify`, `devflow.test`, `devflow.ship`. Missing tag → treat as `standard` (backward compatible).

## Scoring signals

Score each signal 0–4; sum = total (0–20).

| Signal | 0 | 1 | 2 | 3 | 4 |
| --- | --- | --- | --- | --- | --- |
| Files touched | 1–2 | 3–5 | 6–10 | 11–20 | >20 |
| Task type | copy/config/docs | isolated bugfix | standard feature | cross-layer feature / refactor | migration / architecture change |
| Judgment required | fully specified in `task.md` | minor choices | some design decisions | multiple open decisions | novel architecture judgment |
| Cross-component surface | single file/module | one feature folder | shared components/state | shared contracts + consumers | schema / migrations / public API |
| Novelty | exact repo precedent | close precedent | similar pattern elsewhere | adaptation required | no precedent / new tech |

## Profile mapping

| Total | Profile |
| --- | --- |
| 0–6 | `quick` |
| 7–13 | `standard` |
| 14–20 | `thorough` |

**Profile floor:** feature touches auth, payments, security boundaries, DB migrations, or user-input handling → minimum `standard`, regardless of score.

**User override:** user may pin a different profile during plan review — record as `**Complexity:** N (profile, user-pinned)`.

## Depth profiles

| Step | quick | standard | thorough |
| --- | --- | --- | --- |
| `devflow.beautify` axes | correctness + readability/simplification only | all 8 axes | all 8 axes |
| `devflow.test` scope | happy path + 1 regression case per AC | happy path + ≥1 error path per public surface | standard + edge cases per `testing-patterns.md` |
| Verification (test Step 6b) | levels 1–3 | levels 1–3; level 4 when adapter defines targets | levels 1–4; level 4 mandatory — no adapter target → verdict PARTIAL with note |
| `devflow.ship` fan-out | `code-reviewer` only | `code-reviewer` + `security-auditor` + `test-engineer` | all 5 agents (adds `accessibility-auditor`, `docs-reviewer`) |
| Model hints | `references/model-selection.md` → **Depth profile hints** | same | same |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Scoring after implement ("now we know") | Score at plan time; re-score only via plan.md update with user confirmation |
| `quick` on auth/migration/input-handling feature | Profile floor: minimum `standard` |
| Downgrading profile mid-pipeline to pass a failing gate | Profile fixed at plan; change requires plan.md edit + user confirmation |
| Treating missing tag as `quick` | Missing tag = `standard` |
| Inflating score to justify `thorough` on trivial change | Signals are evidence-based (file count, task type) — cite them |
