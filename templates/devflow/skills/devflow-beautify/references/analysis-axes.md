# Beautify — multi-axis analysis checklist

Full per-axis checklist for `devflow.beautify` Step 3. Stack-agnostic defaults; for stack-specific checks follow `ADAPTER.md` and technology skills.

## Correctness

- ACs from `task.md` met (not just `plan.md` behavior)
- Edge cases and error paths handled (null, empty, loading/error UI, async failure)
- State updates consistent (no races or stale UI assumptions)

## Readability and simplification

- Names follow conventions; carry intent (no `data`, `result`, `temp` without context)
- No unnecessary nesting, long methods, or nested ternaries (prefer early return)
- Domain/data logic not in presentation components
- **Preserve behavior:** simplifications must not change outputs, errors, side effects, or ordering. If unsure, treat as opinionated and propose first
- **Chesterton's fence:** before removing or inlining code, understand why it exists (performance, platform constraint, history). If unclear, propose rather than delete
- Duplication: repeated blocks that should share a helper per `registry.md` patterns (optional extraction if it touches public API — propose first)
- Abstractions should earn their complexity; avoid speculative generalization

## Architecture compliance

- Imports are relative and point to the nearest barrel file
- No feature imports another feature directly
- Implemented patterns match `registry.md`
- File placement respects `constitution.md`
- Dependencies flow in the right direction (no new circular patterns)

## Security

- User and external input validated or normalized at boundaries before use in logic, storage, or queries
- No secrets, tokens, or private keys committed in client code or logs
- Auth-sensitive operations align with project data-layer patterns. For deep review, load adapter data/auth skill from `ADAPTER.md`.
- Full checklist: `@devflow/references/security-checklist.md`

## Performance (heuristics - default pass)

- Avoid unnecessary object recreation in hot paths where immutable/static alternatives exist
- Reactive subscriptions are not broader than needed
- Expensive operations are not executed in render loops or high-frequency callbacks
- Prefer lazy/streamed collection rendering over eager full rendering for large or unbounded datasets when applicable

### Performance: measure when needed

Default beautify relies on the checks above. **Profile only when** the plan calls out performance or you flag a **Critical** / high-risk hotspot.

- Use profiling tools defined by the active adapter before large refactors
- Investigate user-visible latency/jank by checking render/update scope before micro-optimizations
- Heavy CPU work should not run on critical UI/request paths when adapter guidance suggests background/off-main execution

Do not add blanket memoization or rendering boundaries everywhere - overuse hurts as much as underuse.

## UI consistency

- Spacing and padding use design-system tokens/theme values, not arbitrary literals
- Typography uses shared style tokens, not repeated local style objects
- Colors use semantic theme tokens/palette entries, not hardcoded values
- Avoid local style overrides that duplicate global design-system definitions

## Responsiveness and layout

- Required breakpoints/form factors are handled for each affected UI view
- Adaptive branching follows adapter conventions
- Avoid raw viewport/layout literals when shared breakpoint tokens exist

## Accessibility

- Interactive elements have descriptive labels (button text, icon semantics, ARIA roles)
- Custom interactive widgets expose accessibility metadata per adapter conventions (see active `ADAPTER.md`)
- Color-only communication has a non-color fallback
- Focus traversal order is logical for keyboard and assistive-technology navigation
- Modal/overlay components manage focus correctly (trap on open, restore on close)

For stack-specific checks, follow **Beautify: accessibility** section of active `ADAPTER.md`.
Full checklist: `@devflow/references/accessibility-checklist.md`
