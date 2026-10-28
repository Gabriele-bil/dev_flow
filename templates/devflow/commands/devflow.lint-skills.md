---
name: devflow.lint-skills
description: Validate all SKILL.md files for required structure (frontmatter, sections, style). Use to check plugin quality before releasing.
argument-hint: "[--strict]"
---

Run `bash @devflow/scripts/validate-skills.sh` — append `--strict` only when `$ARGUMENTS` contains `--strict` (adds style, dead-reference, and size checks). Show the result summary and every `ERROR`/`WARN` line, not the full `✓` list.

If `$ARGUMENTS` is empty, run without `--strict`.

Exit 1 → list each failing file with its errors and the fix (missing frontmatter field → add it; missing section → add the heading with real content per `CONTRIBUTING.md`; dead reference → fix the path or verb). Warnings → suggest caveman-compress rewrites or extraction to `references/`.

Do not modify files unless the user explicitly asks.
