# Goal-Backward Verification

Four-level verification run by `devflow.test` (Step 6b) after tests pass. Works **backwards from the spec**: start from each acceptance criterion in `task.md`, not from what was implemented. A stubbed function with a passing unit test and clean review sails through forward-looking checks — this catches it.

## The four levels

| Level | Question | How to check |
| --- | --- | --- |
| **1 — Existence** | Do expected files, symbols, routes, migrations exist? | File on disk; symbol defined (grep declaration); route/migration present |
| **2 — Substantive** | Real code, not stubs? | Scan implementing files for stub signals (table below) |
| **3 — Wired** | Reachable in the running app? | Symbol imported/used **outside** its defining file; route registered; provider/middleware applied; UI reachable via navigation. Dead code = not satisfied |
| **4a — Runtime (CLI/Headless)** | Does backend/CLI behave end-to-end? | Run adapter **Verify (runtime)** command covering the AC (`ADAPTER.md` → **Test → Verify (runtime)**); fallback: integration targets from **Test → Commands**. No matching target → mark `N/A` |
| **4b — Browser/UI Workflow** | Does UI render and flow end-to-end in browser? | Web/UI adapters (`nextjs`, `angular`, `flutter`): run E2E/Playwright target or execute browser session to verify mounting, DOM presence, critical interactions, and zero console errors |

Levels 1–3 are pure static inspection (grep/read — cheap). Level 4a executes backend/CLI runtime targets. Level 4b executes browser/UI workflow verification for Web and UI adapters.

## Level 2 stub signals

| Signal | Example |
| --- | --- |
| Placeholder comments | `// TODO`, `// implement this`, `FIXME`, `HACK` |
| Hardcoded returns | `return true;`, `return [];`, `return "test"` where logic is expected |
| Empty error handling | empty `catch`/`except` block, swallowed error |
| Unimplemented throws | `UnimplementedError`, `NotImplementedException`, `throw new Error("not implemented")` |
| Disabled tests | `skip`, `xit`, `xdescribe`, `@Ignore` on tests covering the AC |
| Placeholder UI | lorem ipsum copy, empty `Container()`, `<div>placeholder</div>` |

## Level 3 rules

- Import from a barrel/re-export file alone does NOT count as wired — find a real call/render site.
- Route handler defined but not registered = not wired.
- Feature flag permanently off = not wired; note the flag in the report.

## Level 4b: UI/Browser & Mobile Workflow Verification (Web & Mobile Adapters)

Applicable when the adapter is Web/UI (`nextjs`, `angular`) or Mobile (`flutter`) and the acceptance criterion touches routes, screens, components, forms, or user-visible workflows.

### 4 Core UI & Runtime Verification Checks

1. **Mounting & Clean Runtime**: Target route or mobile screen mounts without unhandled runtime exceptions, crash logs, or fatal console errors.
2. **DOM / Widget Tree Presence**: Critical elements specified in the AC (form fields, submit buttons, state badges, headers) are rendered in the DOM or Flutter widget tree with accessible identifiers (`key`, semantics, ARIA, `testID`).
3. **Interactive Path & State Transition**: User interaction (typing into input, clicking/tapping submit, modal open/close, gestures) triggers the expected state change and visual confirmation.
4. **Responsive / Form Factor Adaptability**: Layout renders correctly across target viewport widths or device form factors if mandated by AC (e.g. mobile drawer vs desktop sidebar, phone vs tablet).

### Tooling & Execution Options

- **Automated Web E2E:** Execute adapter-defined browser specs (e.g. `pnpm exec playwright test --grep "[feature]"`, `npm run e2e`).
- **Automated Mobile E2E:** Execute mobile flows using Maestro (`maestro test .maestro/[feature].yaml`) or Flutter integration tests (`flutter test integration_test/features/[feature]/ -d emulator-[ID]`).
- **Interactive Browser/Device Agent:** In agentic environments equipped with browser or emulator tools (e.g. Antigravity `browser_subagent`, Chrome DevTools MCP, or emulator driver), navigate to dev server or launch app on emulator, execute the user interaction flow, verify console logs/device state, and record verification evidence.
- **No browser/device runner available:** If no automated E2E exists and no browser/device tool is configured or running, mark `L4b: N/A` (verdict PARTIAL).

## Procedure (per AC)

1. Locate implementing file(s) via `plan.md` → **Traceability** table (mandatory — makes this lookup free).
2. Run levels in order; first failing level stops the chain for that AC.
3. Record verdict: **PASS** (all applicable levels pass) · **FAIL** (any of 1–3 fails, or 4a/4b executes and fails) · **PARTIAL** (1–3 pass, 4a/4b is `N/A`).
4. AC with no Traceability row → **FAIL** (missing requirement — candidate for `devflow.backprop`).

## Report template — `verification.md`

Write to `devflow/features/[NNN]_[feature-name]/verification.md`:

```markdown
# Verification - [Feature Name]

**Feature:** [NNN]_[feature-name]
**Date:** [YYYY-MM-DD]
**Result:** PASS | FAIL   (FAIL if any AC verdict is FAIL)

| # | Acceptance criterion | Files (Traceability) | L1 | L2 | L3 | L4a | L4b | Verdict |
|---|---------------------|----------------------|----|----|----|-----|-----|---------|
| 1 | [criterion] | `path/file.ext` | ✅ | ✅ | ✅ | ✅ | ✅ | PASS |

## Failures
(only if any FAIL)
- **AC [#]** failed **L[N]**: [evidence — file:line, stub signal, console error, missing registration] → [fix pointer]
```

## Gate rule

`devflow.test` sets `plan.md` `**Status:** tested` only when tests pass AND `verification.md` **Result** is not FAIL. `devflow.ship` input contract requires `verification.md` present with zero FAIL verdicts.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Verifying forward from File List ("all files written = done") | Start from each AC; files are evidence, not the goal |
| Counting a passing unit test as Level 3 | Unit test imports the symbol directly; wiring means the app reaches it |
| Marking PARTIAL as PASS in summary | PARTIAL is explicit: runtime unproven; report it as such |
| Skipping verification because review was clean | Review is forward-looking; verification is goal-backward — different failure classes |
