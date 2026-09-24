---
name: devflow.doctor
description: Pre-flight diagnostic check for DevFlow — verifies MCP servers, CLI toolchains, active adapter configuration, and pipeline state integrity. Supports --json and --fix.
argument-hint: [--json] [--fix]
disable-model-invocation: true
---

Use `@devflow/skills/devflow-doctor/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Run environment diagnostics across MCP baseline, CLI toolchain, and pipeline state.
- If `--json` flag is provided, output raw machine-readable JSON directly.
- If `--fix` flag is provided, automatically repair safe runtime files.
- Provide clear remediation commands for any missing tools or unconfigured MCP servers.
