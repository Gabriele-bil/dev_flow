# Setup notify-user template

Used by `devflow.setup` Step 8 — respond with this format after setup completes.

```text
✅ Setup complete

Mode: [single-app|monorepo]
Apps: [N configured (web→nextjs, mobile→flutter, …)]   <!-- monorepo only, omit line in single-app -->

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

Dependency install:  <!-- monorepo: repeat this block once per app, headed "- app: [name]" -->
- adapter: [adapter]
- manager: [pnpm|yarn|npm|flutter]
- installed runtime deps: [N]
- installed dev deps: [N]
- commands:
  - [command 1]
  - [command 2]

Next: run devflow.task
```
