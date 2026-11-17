# devflow-plan — anti-patterns and rationalizations

Full catalog of planning anti-patterns, symptoms, and required fixes.

## Anti-Patterns Catalog

| Anti-Pattern | Fix |
| --- | --- |
| Writing plan without reading `task.md` | Always start with `task.md` |
| File list in layer order (all models → services → UI) | Order by user-visible increment; checkpoint per slice |
| No Traceability row for a subtask | Every subtask → at least one file + criterion |
| File List entry with no Traceability row (gold-plating) | Remove it or map to a subtask; new scope goes through `devflow.task` |
| Open questions with Status `ready` | Leave open; escalate to user; never guess |
| Reuse audit skipped ("implement will figure it out") | Audit in Step 3; document in Architecture decisions |
| New component without checking shared/ | ≥70% coverage rule; extend first |
| Dependencies without explicit ordering | Sort file list; document rationale in Architecture decisions |
| Architecture decisions made during implement | All decisions in `plan.md` before implement |
| Adapter sections omitted | Apply every required section from the adapter plan step file |
| No implementation checkpoints on long plans | ≥2 checkpoints for plans >5 files |
| Complexity score skipped or guessed | Score per `complexity-scoring.md` signals in Step 4d; downstream steps default to `standard` without it |
| Entry 1 is discovery work ("find where X lives") | Resolve locations during planning (Step 1/4); entry `001` starts building (or fail-first regression test for `fix/`) |
| Copy-pasting prior art verbatim or ignoring docs/ADRs | Prior art models shape, not content — verify settings line-by-line; accepted docs/ADRs outrank prior art |
| Orphaned callers/tests after deletion or incomplete rename sweep | Trace deletion last-users transitively; grep docs, `AGENTS.md`/`CLAUDE.md`, CI, scripts, config in all case/separator forms |
| Staged migration/backfill without stop-point walk or incompatible split release | Walk step, abort, timeout, re-run residual state; keep separately released BE/FE/schema backward-compatible or state release order |

## Planning Guardrails (Step 4 & Step 4b)

1. **Run prescribed checks while planning:** each 4-part brief `Test` command that is cheap and safe (read/validate only, one package/module, ~1–2 min, zero shared writes) runs on today's code; rescope pre-existing failures in the entry's brief. State-changing or expensive commands are checked for binary/flag resolution only; side outputs stay in scratch/gitignored paths.
2. **Deletion cascade:** for every deleted symbol or file, search what it was the last user of and repeat transitively for newly orphaned pieces; unresolvable runtime references become Open questions. Tests deleted with code receive a per-behavior verdict (keep assertions covering surviving behavior).
3. **Rename/move sweep:** grep docs, `AGENTS.md`/`CLAUDE.md`, CI workflows, build scripts, and config for the old name in every case/separator form; list every hit as a **File List** entry.
4. **Release compatibility:** when parts deploy separately (backend/frontend, service/callers, schema/code), prefer optional additive changes defaulting to old behavior; remove old paths only once no live version reads them, or state the required release order in **Architecture decisions**.
5. **Overlapping open PRs & branches:** read-only check of open PRs (`gh pr list --search <path>` when `gh` available) and recently active branches touching **File List** paths; note overlaps in the entry with how the change keeps rebase small.
6. **Staged live-state stop points:** for migrations, data backfills, and swaps, walk each stop point — step, abort, timeout, lost worker, re-run — and record residual state and recovery advice.
7. **First entry is never discovery:** `"find where X lives"` belongs in planning research (Step 1/4), never in **File List**. For `fix/` features, `### 001.` is the fail-first regression test.
8. **Prior art models shape, not content:** verify settings and conventions copied from an analogue line-by-line against the new target; accepted docs/ADRs outrank prior art unless an override is recorded.

## Critical checks

- No plan without reading `task.md` and active ADRs
- File list ordered by vertical slice, not architectural layer
- Every subtask mapped in Traceability (no gold-plating)
- Architecture decisions (and ADR alignment) locked before implement
- Complexity score scored per `complexity-scoring.md` signals in Step 4d
