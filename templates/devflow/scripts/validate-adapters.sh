#!/bin/bash
# devflow adapter validator
# Checks all adapters under templates/devflow/adapters/ against ADAPTER.schema.md.
# Usage: bash templates/devflow/scripts/validate-adapters.sh [--strict]
# Exit 0: all ok (or only warnings)
# Exit 1: one or more adapters missing required files or sections

STRICT=false
if [[ "$1" == "--strict" ]]; then
  STRICT=true
fi

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTERS_DIR="$PLUGIN_ROOT/adapters"

if [[ ! -d "$ADAPTERS_DIR" ]]; then
  echo "ERROR: adapters directory not found at $ADAPTERS_DIR"
  exit 1
fi

ADAPTER_DIRS=()
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  BN=$(basename "$dir")
  # Exclude hidden directories (e.g. .devflow-fetch-cache) and 'common' (shared skill library)
  if [[ "$BN" != .* && "$BN" != "common" && -d "$dir" ]]; then
    ADAPTER_DIRS+=("$dir")
  fi
done < <(find "$ADAPTERS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

TOTAL=${#ADAPTER_DIRS[@]}
OK=0
ERRORS=0
WARNINGS=0

echo "Validating $TOTAL adapter(s) against ADAPTER.schema.md..."
echo ""

for ADAPTER_PATH in "${ADAPTER_DIRS[@]}"; do
  ADAPTER_NAME=$(basename "$ADAPTER_PATH")
  ADAPTER_ERRORS=()
  ADAPTER_WARNINGS=()

  # ── 1. Check Directory & File Layout ──────────────────────────────────────────
  ADAPTER_MD="$ADAPTER_PATH/ADAPTER.md"
  if [[ ! -f "$ADAPTER_MD" ]]; then
    ADAPTER_ERRORS+=("missing core file: ADAPTER.md")
  fi

  STEPS_DIR="$ADAPTER_PATH/steps"
  if [[ ! -d "$STEPS_DIR" ]]; then
    ADAPTER_ERRORS+=("missing steps directory: steps/")
  else
    REQUIRED_STEPS=("setup.md" "plan.md" "implement.md" "beautify.md" "test.md" "pr.md")
    for STEP in "${REQUIRED_STEPS[@]}"; do
      if [[ ! -f "$STEPS_DIR/$STEP" ]]; then
        ADAPTER_ERRORS+=("steps/ missing required file: steps/$STEP")
      fi
    done
  fi

  TEMPLATES_DIR="$ADAPTER_PATH/templates"
  if [[ ! -d "$TEMPLATES_DIR" ]]; then
    ADAPTER_ERRORS+=("missing templates directory: templates/")
  else
    REQUIRED_TEMPLATES=("AGENTS.template.md" "REGISTRY.template.md" "CONSTITUTION.template.md")
    for TMPL in "${REQUIRED_TEMPLATES[@]}"; do
      if [[ ! -f "$TEMPLATES_DIR/$TMPL" ]]; then
        ADAPTER_ERRORS+=("templates/ missing required file: templates/$TMPL")
      fi
    done
  fi

  SKILLS_DIR="$ADAPTER_PATH/skills"
  if [[ ! -d "$SKILLS_DIR" ]]; then
    ADAPTER_ERRORS+=("missing skills directory: skills/")
  else
    SKILLS_COUNT=$(find "$SKILLS_DIR" -name "SKILL.md" | wc -l | tr -d ' ')
    if [[ "$SKILLS_COUNT" -eq 0 ]]; then
      ADAPTER_ERRORS+=("skills/ directory contains 0 SKILL.md files")
    fi
  fi

  # ── 2. Check Core ADAPTER.md Sections ────────────────────────────────────────
  if [[ -f "$ADAPTER_MD" ]]; then
    if ! grep -qE '^## Technology skills' "$ADAPTER_MD"; then
      ADAPTER_ERRORS+=("ADAPTER.md missing required section: '## Technology skills'")
    fi

    if ! grep -qE '^## MCP' "$ADAPTER_MD"; then
      ADAPTER_ERRORS+=("ADAPTER.md missing required section: '## MCP'")
    fi

    if ! grep -qE '^## Step files' "$ADAPTER_MD"; then
      ADAPTER_ERRORS+=("ADAPTER.md missing required section: '## Step files'")
    fi

    # Dead references in ADAPTER.md
    while IFS= read -r REF; do
      [[ -z "$REF" ]] && continue
      REF_PATH="${REF#@devflow/}"
      [[ "$REF_PATH" == *"..."* ]] && continue
      if [[ ! -e "$PLUGIN_ROOT/$REF_PATH" ]]; then
        ADAPTER_ERRORS+=("ADAPTER.md dead reference: $REF (file not found)")
      fi
    done < <(grep -Eo '@devflow/[A-Za-z0-9/_.-]+' "$ADAPTER_MD" | sort -u)
  fi

  # ── 3. Check steps/setup.md ──────────────────────────────────────────────────
  SETUP_MD="$STEPS_DIR/setup.md"
  if [[ -f "$SETUP_MD" ]]; then
    if ! grep -qE '^## Setup: templates' "$SETUP_MD"; then
      ADAPTER_ERRORS+=("steps/setup.md missing required section: '## Setup: templates'")
    fi
    if ! grep -qE '^## Setup dependencies' "$SETUP_MD"; then
      ADAPTER_WARNINGS+=("steps/setup.md missing recommended section: '## Setup dependencies'")
    fi
  fi

  # ── 4. Check steps/plan.md ───────────────────────────────────────────────────
  PLAN_MD="$STEPS_DIR/plan.md"
  if [[ -f "$PLAN_MD" ]]; then
    if ! grep -qE '^## Plan: extra sections and templates' "$PLAN_MD"; then
      ADAPTER_ERRORS+=("steps/plan.md missing required section: '## Plan: extra sections and templates'")
    fi
    if ! grep -qiE '### (Plan: )?dependency ordering' "$PLAN_MD"; then
      ADAPTER_ERRORS+=("steps/plan.md missing required subsection: 'Dependency ordering'")
    fi
  fi

  # ── 5. Check steps/implement.md ──────────────────────────────────────────────
  IMPL_MD="$STEPS_DIR/implement.md"
  if [[ -f "$IMPL_MD" ]]; then
    if ! grep -qE '^## Implement: skill load decision matrix' "$IMPL_MD"; then
      ADAPTER_ERRORS+=("steps/implement.md missing required section: '## Implement: skill load decision matrix'")
    fi
    if ! grep -qE '^## Implement: commands and checklist' "$IMPL_MD"; then
      ADAPTER_ERRORS+=("steps/implement.md missing required section: '## Implement: commands and checklist'")
    fi
    if ! grep -qE '^### Pre-handoff checklist \(implement\)' "$IMPL_MD"; then
      ADAPTER_ERRORS+=("steps/implement.md missing required subsection: '### Pre-handoff checklist (implement)'")
    fi
  fi

  # ── 6. Check steps/beautify.md ───────────────────────────────────────────────
  BEAUTIFY_MD="$STEPS_DIR/beautify.md"
  if [[ -f "$BEAUTIFY_MD" ]]; then
    if ! grep -qE '^## Beautify: commands' "$BEAUTIFY_MD"; then
      ADAPTER_ERRORS+=("steps/beautify.md missing required section: '## Beautify: commands'")
    fi
    if ! grep -qiE '### Beautify: .*review axes' "$BEAUTIFY_MD"; then
      ADAPTER_ERRORS+=("steps/beautify.md missing review axes section ('### Beautify: [stack]-specific review axes')")
    fi
    if ! grep -qiE '### Beautify: .*accessibility' "$BEAUTIFY_MD"; then
      ADAPTER_ERRORS+=("steps/beautify.md missing accessibility section ('### Beautify: accessibility checks')")
    fi
    if ! grep -qE '^### Beautify: performance profiling trigger' "$BEAUTIFY_MD"; then
      ADAPTER_ERRORS+=("steps/beautify.md missing performance trigger section ('### Beautify: performance profiling trigger')")
    fi
  fi

  # ── 7. Check steps/test.md ───────────────────────────────────────────────────
  TEST_MD="$STEPS_DIR/test.md"
  if [[ -f "$TEST_MD" ]]; then
    if ! grep -qE '^### Coverage threshold' "$TEST_MD"; then
      ADAPTER_ERRORS+=("steps/test.md missing required subsection: '### Coverage threshold'")
    fi
    if ! grep -qE '^### Placement' "$TEST_MD"; then
      ADAPTER_ERRORS+=("steps/test.md missing required subsection: '### Placement'")
    fi
    if ! grep -qE '^### Commands' "$TEST_MD"; then
      ADAPTER_ERRORS+=("steps/test.md missing required subsection: '### Commands'")
    fi

    if [[ "$STRICT" == true ]]; then
      if ! grep -qE 'test-coverage-threshold:[[:space:]]*[0-9]+' "$TEST_MD"; then
        ADAPTER_WARNINGS+=("steps/test.md coverage threshold line missing numeric value ('test-coverage-threshold: NN')")
      fi
    fi
  fi

  # ── 8. Check steps/pr.md ─────────────────────────────────────────────────────
  PR_MD="$STEPS_DIR/pr.md"
  if [[ -f "$PR_MD" ]]; then
    if ! grep -qE '^## PR: verification' "$PR_MD"; then
      ADAPTER_ERRORS+=("steps/pr.md missing required section: '## PR: verification'")
    fi
    if ! grep -qE '^### PR body checklist' "$PR_MD"; then
      ADAPTER_ERRORS+=("steps/pr.md missing required subsection: '### PR body checklist'")
    fi
  fi

  # ── 9. Strict Mode Quality Checks ────────────────────────────────────────────
  if [[ "$STRICT" == true ]]; then
    # Verify templates have essential structure
    AGENTS_TMPL="$TEMPLATES_DIR/AGENTS.template.md"
    if [[ -f "$AGENTS_TMPL" ]]; then
      if ! grep -qE '\{\{mcp-baseline\}\}' "$AGENTS_TMPL"; then
        ADAPTER_WARNINGS+=("templates/AGENTS.template.md missing '{{mcp-baseline}}' placeholder")
      fi
    fi

    # Verify code blocks in commands are not empty
    for CF in "$IMPL_MD" "$TEST_MD" "$PR_MD"; do
      if [[ -f "$CF" ]]; then
        REL_CF="${CF#"$PLUGIN_ROOT/"}"
        if grep -q '```bash[[:space:]]*```' "$CF"; then
          ADAPTER_WARNINGS+=("$REL_CF contains empty bash code block")
        fi
      fi
    done
  fi

  # ── Output for this adapter ──────────────────────────────────────────────────
  if [[ ${#ADAPTER_ERRORS[@]} -gt 0 ]]; then
    echo "✗ adapters/$ADAPTER_NAME"
    for ERR in "${ADAPTER_ERRORS[@]}"; do
      echo "    ERROR: $ERR"
    done
    for WARN in "${ADAPTER_WARNINGS[@]}"; do
      echo "    WARN: $WARN"
    done
    ERRORS=$((ERRORS + 1))
  elif [[ ${#ADAPTER_WARNINGS[@]} -gt 0 ]]; then
    echo "⚠ adapters/$ADAPTER_NAME"
    for WARN in "${ADAPTER_WARNINGS[@]}"; do
      echo "    WARN: $WARN"
    done
    WARNINGS=$((WARNINGS + 1))
  else
    echo "✓ adapters/$ADAPTER_NAME"
    OK=$((OK + 1))
  fi
done

# ── Check common/ library ─────────────────────────────────────────────────────
COMMON_DIR="$ADAPTERS_DIR/common"
if [[ -d "$COMMON_DIR" ]]; then
  COMMON_SKILLS=$(find "$COMMON_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$COMMON_SKILLS" -gt 0 ]]; then
    echo "✓ adapters/common (shared library: $COMMON_SKILLS skills)"
  else
    echo "⚠ adapters/common (shared library: no skills found)"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

echo ""
echo "Results: $OK ok, $ERRORS error(s), $WARNINGS warning(s)"

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
exit 0
