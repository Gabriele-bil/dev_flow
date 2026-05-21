---
name: devflow.lint-skills
description: Validate all SKILL.md files for required structure (frontmatter, sections, style). Use to check plugin quality before releasing.
argument-hint: [--strict]
---

Run `bash @devflow/scripts/validate-skills.sh${ $ARGUMENTS ? " " + $ARGUMENTS : "" }` and show the full output to the user.

If `$ARGUMENTS` contains `--strict`, pass `--strict` to the script to enable style checks (filler phrases, empty sections).

After showing output, act on results:

**If exit 0 (no errors):** Confirm all skill files pass structural validation. If warnings are present, list them and suggest fixes (see below).

**If exit 1 (errors present):** List each failing file and its errors. For each error type, apply the fix:

- `missing YAML frontmatter` → Add `---` block at top of file with at least `name:` and `description:` fields.
- `frontmatter missing required field: name` → Add `name: <kebab-case-skill-name>` inside the `---` block.
- `frontmatter field 'name' is not kebab-case` → Rename value to lowercase letters and hyphens only, e.g. `my-skill-name`.
- `frontmatter missing required field: description` → Add `description: <one-line summary of what the skill does>` inside the `---` block.
- `frontmatter field 'description' is empty` → Provide a non-empty value for `description:`.
- `missing section "## Purpose"` → Add `## Purpose` heading with one line: what the skill does and which pipeline step it covers.
- `missing section "## When NOT to Use"` → Add `## When NOT to Use` heading with bullet conditions that route elsewhere.
- `missing section "## Workflow"` → Add `## Workflow` heading with numbered steps and concrete actions.
- `missing section "## I/O Reference"` → Add `## I/O Reference` heading with a table of reads, writes, and next step.

**Warning fixes (shown when present):**

- `style: line(s) starting with 'This section...' or 'Note that...'` → Rewrite using caveman-compress: drop filler, keep verbs and technical terms.
- `style: empty section` → Either add content under the heading or remove it entirely.

Do not modify files unless the user explicitly asks to fix them.
