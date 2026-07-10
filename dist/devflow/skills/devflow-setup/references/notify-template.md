# Setup notify-user template

Used by `devflow.setup` Step 8 — respond with this format after setup completes.

```text
✅ Setup complete

AGENTS.md: [created|updated|overwritten]
REGISTRY.md: [created|updated|overwritten]
docs/product.md: [created|updated|overwritten]
constitution.md: [created|updated|overwritten]

Template source: [adapter|fallback]
Manual placeholders: [N]
- [file]: [placeholder]

Questionnaire fields asked: [N]
Auto-inferred fields: [N]
User-provided fields: [N]

Dependency install:
- adapter: [adapter]
- manager: [pnpm|yarn|npm|flutter]
- installed runtime deps: [N]
- installed dev deps: [N]
- commands:
  - [command 1]
  - [command 2]

Next: run devflow.task
```
