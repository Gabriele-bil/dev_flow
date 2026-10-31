# Beautify — multi-axis analysis checklist

Per-axis checklist for `devflow.beautify` Step 3 (correctness, security and performance are reviewed by `devflow.ship`, not here). Stack-agnostic defaults; for stack-specific checks follow `ADAPTER.md` and technology skills.

## Readability and simplification

- Names follow conventions; carry intent (no `data`, `result`, `temp` without context)
- No unnecessary nesting, long methods, or nested ternaries (prefer early return)
- **File & change size budget (`size-budget`):** flag any changed source file that exceeds 1,500 lines or grows by >400 net non-test lines in a single change; propose splitting cohesive responsibilities
- Domain/data logic not in presentation components
- **Preserve behavior:** simplifications must not change outputs, errors, side effects, or ordering. If unsure, treat as opinionated and propose first
- **Chesterton's fence:** before removing or inlining code, understand why it exists (performance, platform constraint, history). If unclear, propose instead of deleting
- Duplication: repeated blocks share a helper per `registry.md` patterns (optional extraction if it touches public API — propose first)
- Abstractions earn their complexity; avoid speculative generalization
- **User-facing copy & docstrings:** clear, direct, active voice; zero AI-slop boosters (`seamless`, `robust`, `comprehensive`) or restating headings in opening sentences

## Conventions (architecture compliance)

- Imports are relative and point to the nearest barrel file
- No feature imports another feature directly
- Implemented patterns match `registry.md`
- File placement respects `constitution.md`
- Dependencies flow in the right direction (no new circular patterns)

## UI consistency

- Spacing and padding use design-system tokens/theme values, not arbitrary literals
- Typography uses shared style tokens, not repeated local style objects
- Colors use semantic theme tokens/palette entries, not hardcoded values
- Avoid local style overrides that duplicate global design-system definitions

## Responsiveness and layout

- Required breakpoints/form factors are handled for each affected UI view
- Adaptive branching follows adapter conventions
- Avoid raw viewport/layout literals when shared breakpoint tokens exist

## Accessibility basics

- Interactive elements have descriptive labels (button text, icon semantics, ARIA roles)
- Custom interactive widgets expose accessibility metadata per adapter conventions (see active `ADAPTER.md`)
- Color-only communication has a non-color fallback
- Focus traversal order is logical for keyboard and assistive-technology navigation
- Modal/overlay components manage focus correctly (trap on open, restore on close)

For stack-specific checks, follow **Beautify: accessibility** section of active `ADAPTER.md`.
Full checklist: `$HOME/.gemini/antigravity-cli/plugins/devflow/references/accessibility-checklist.md`
