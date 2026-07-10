# Analyze report template

Used by `devflow.analyze` Step 3 — produce report directly in response. Do not write any files.

```text
## DevFlow Analyze Report
**Feature:** [NNN]_[feature-name]
**Date:** [YYYY-MM-DD]
**Artifacts:** task.md (Status: [value]) · plan.md (Status: ready)

---

### Pass A — Traceability completeness
[PASS — all subtasks have Traceability rows with file mappings]
— or —
- **[SEVERITY]** A: [description]
  → Suggested fix: [one-line resolution]

### Pass B — AC testability
[PASS — all ACs are observable and falsifiable]
— or —
- **[SEVERITY]** B: [description]
  → Suggested fix: [one-line resolution]

### Pass C — Terminology consistency
[PASS — consistent terminology across both documents]
— or —
- **[SEVERITY]** C: [description]
  → Suggested fix: [one-line resolution]

### Pass D — Constitution alignment
[PASS — all file paths respect constitution.md layer rules]
— or —
- **[SEVERITY]** D: [description]
  → Suggested fix: [one-line resolution]

### Pass E — Coverage balance
[PASS — no orphaned ACs or files]
— or —
- **[SEVERITY]** E: [description]
  → Suggested fix: [one-line resolution]

---

### Summary

| Severity | Count |
|----------|-------|
| Critical | N     |
| Required | N     |
| Nit      | N     |

[N blocker(s) (Critical + Required) — resolve before devflow.implement]
— or —
[No blockers — proceed to devflow.implement]
```
