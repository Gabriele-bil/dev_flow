#!/bin/bash
# devflow skill validator
# Checks all SKILL.md files for required structure.
# Usage: bash scripts/validate-skills.sh [--strict]
# Exit 0: all ok (or only warnings)
# Exit 1: one or more SKILL.md missing required sections/frontmatter

STRICT=false
if [[ "$1" == "--strict" ]]; then
  STRICT=true
fi

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SKILL_FILES=()
while IFS= read -r f; do
  SKILL_FILES+=("$f")
done < <(find "$PLUGIN_ROOT" -name "SKILL.md" | sort)

TOTAL=${#SKILL_FILES[@]}
OK=0
ERRORS=0
WARNINGS=0

echo "Validating $TOTAL skill files..."
echo ""

for FILE in "${SKILL_FILES[@]}"; do
  # Relative path for display
  REL="${FILE#"$PLUGIN_ROOT/"}"

  FILE_ERRORS=()
  FILE_WARNINGS=()

  # ── skip-validation check ────────────────────────────────────────────────────
  if grep -qE '^skip-validation:[[:space:]]*true' "$FILE"; then
    echo "✓ $REL (skip-validation)"
    OK=$((OK + 1))
    continue
  fi

  # ── Frontmatter check ────────────────────────────────────────────────────────
  FIRST_LINE=$(head -1 "$FILE")
  if [[ "$FIRST_LINE" != "---" ]]; then
    FILE_ERRORS+=("missing YAML frontmatter (file must start with ---)")
  else
    # Extract frontmatter block (between first and second ---)
    FRONTMATTER=$(awk '/^---/{count++; if(count==2) exit; next} count==1' "$FILE")

    # name: must be present and non-empty
    NAME_LINE=$(echo "$FRONTMATTER" | grep -E '^name:')
    if [[ -z "$NAME_LINE" ]]; then
      FILE_ERRORS+=("frontmatter missing required field: name")
    else
      NAME_VALUE=$(echo "$NAME_LINE" | sed 's/^name:[[:space:]]*//' | tr -d '"'"'")
      if [[ -z "$NAME_VALUE" ]]; then
        FILE_ERRORS+=("frontmatter field 'name' is empty")
      elif ! echo "$NAME_VALUE" | grep -qE '^[a-z][a-z0-9-]*$'; then
        FILE_ERRORS+=("frontmatter field 'name' is not kebab-case: $NAME_VALUE")
      fi
    fi

    # description: must be present and non-empty
    DESC_LINE=$(echo "$FRONTMATTER" | grep -E '^description:')
    if [[ -z "$DESC_LINE" ]]; then
      FILE_ERRORS+=("frontmatter missing required field: description")
    else
      DESC_VALUE=$(echo "$DESC_LINE" | sed 's/^description:[[:space:]]*//')
      if [[ -z "$DESC_VALUE" ]]; then
        FILE_ERRORS+=("frontmatter field 'description' is empty")
      fi
    fi

    # disable-model-invocation: warning if absent
    if ! echo "$FRONTMATTER" | grep -qE '^disable-model-invocation:'; then
      FILE_WARNINGS+=("missing disable-model-invocation: true in frontmatter")
    fi
  fi

  # ── Required sections check ──────────────────────────────────────────────────
  # Adapter skills (adapters/*/skills/) use numbered-section reference format:
  # only ## I/O Reference is required. Core skills (skills/) require full set.
  if echo "$REL" | grep -q "^adapters/"; then
    # Adapter skill: require only I/O Reference
    if ! grep -qF "## I/O Reference" "$FILE"; then
      FILE_ERRORS+=("missing section \"## I/O Reference\"")
    fi
  else
    # Core skill: require Purpose + I/O Reference; Workflow OR any Step heading
    for SECTION in "## Purpose" "## I/O Reference"; do
      if ! grep -qF "$SECTION" "$FILE"; then
        FILE_ERRORS+=("missing section \"$SECTION\"")
      fi
    done
    # Accept "## Workflow" or any "## Step N" as workflow section
    if ! grep -qF "## Workflow" "$FILE" && ! grep -qE "^## Step [0-9]" "$FILE"; then
      FILE_ERRORS+=("missing workflow section (add \"## Workflow\" or numbered \"## Step N\" headings)")
    fi
    # When NOT to Use: warning only (some meta-skills intentionally omit it)
    if ! grep -qF "## When NOT to Use" "$FILE"; then
      FILE_WARNINGS+=("missing recommended section \"## When NOT to Use\"")
    fi
  fi

  # ── Style checks (--strict only) ─────────────────────────────────────────────
  if [[ "$STRICT" == true ]]; then
    # Lines starting with "This section..." or "Note that..."
    if grep -qiE '^(This section|Note that)' "$FILE"; then
      MATCHES=$(grep -inE '^(This section|Note that)' "$FILE" | head -3 | sed 's/^/      /')
      FILE_WARNINGS+=("style: line(s) starting with 'This section...' or 'Note that...' (caveman-compress violation)")
    fi

    # Empty sections: a ## heading followed immediately by another ## heading or EOF
    LINES=$(wc -l < "$FILE")
    while IFS= read -r LINE_NUM_CONTENT; do
      LINE_NUM=$(echo "$LINE_NUM_CONTENT" | cut -d: -f1)
      HEADING=$(echo "$LINE_NUM_CONTENT" | cut -d: -f2-)
      NEXT_LINE_NUM=$((LINE_NUM + 1))
      if [[ $NEXT_LINE_NUM -gt $LINES ]]; then
        FILE_WARNINGS+=("style: empty section at end of file: $HEADING")
      else
        NEXT_CONTENT=$(sed -n "${NEXT_LINE_NUM}p" "$FILE")
        if [[ -z "$NEXT_CONTENT" ]]; then
          # Allow one blank line, check the line after
          NEXT_LINE_NUM=$((LINE_NUM + 2))
          NEXT_CONTENT=$(sed -n "${NEXT_LINE_NUM}p" "$FILE")
        fi
        if echo "$NEXT_CONTENT" | grep -qE '^##'; then
          FILE_WARNINGS+=("style: empty section: $HEADING")
        fi
      fi
    done < <(grep -nE '^## ' "$FILE")
  fi

  # ── Output for this file ─────────────────────────────────────────────────────
  if [[ ${#FILE_ERRORS[@]} -gt 0 ]]; then
    echo "✗ $REL"
    for ERR in "${FILE_ERRORS[@]}"; do
      echo "    ERROR: $ERR"
    done
    for WARN in "${FILE_WARNINGS[@]}"; do
      echo "    WARN: $WARN"
    done
    ERRORS=$((ERRORS + 1))
  elif [[ ${#FILE_WARNINGS[@]} -gt 0 ]]; then
    echo "⚠ $REL"
    for WARN in "${FILE_WARNINGS[@]}"; do
      echo "    WARN: $WARN"
    done
    WARNINGS=$((WARNINGS + 1))
  else
    echo "✓ $REL"
    OK=$((OK + 1))
  fi
done

echo ""
echo "Results: $OK ok, $ERRORS error(s), $WARNINGS warning(s)"

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
exit 0
