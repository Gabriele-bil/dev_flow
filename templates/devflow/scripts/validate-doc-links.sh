#!/bin/bash
# devflow doc-link integrity validator
# Checks that file paths, markdown links, and devflow.<verb> mentions
# referenced in README/CONTRIBUTING/docs actually resolve to something real.
# Usage: bash scripts/validate-doc-links.sh
# Exit 0: all references resolve
# Exit 1: one or more dead references found

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
DIST_ROOT="$REPO_ROOT/dist/devflow"

# Docs excluded from scanning: comparative/gap-analysis write-ups that cite
# *other* projects' internal file paths as sources — those paths never
# resolve inside this repo by design, not by drift.
DOC_EXCLUDE=("docs/tokless-gap-analysis.md")

DOC_FILES=()
for f in "$REPO_ROOT/README.md" "$REPO_ROOT/CONTRIBUTING.md" \
         "$PLUGIN_ROOT/README.md" "$PLUGIN_ROOT/CONTRIBUTING.md" \
         "$PLUGIN_ROOT/ETHOS.md" "$PLUGIN_ROOT/AGENTS.md"; do
  [[ -f "$f" ]] && DOC_FILES+=("$f")
done
while IFS= read -r f; do
  REL_CANDIDATE="${f#"$REPO_ROOT"/}"
  SKIP=0
  for ex in "${DOC_EXCLUDE[@]}"; do
    [[ "$REL_CANDIDATE" == "$ex" ]] && SKIP=1
  done
  [[ $SKIP -eq 1 ]] || DOC_FILES+=("$f")
done < <(find "$REPO_ROOT/docs" -name "*.md" 2>/dev/null | sort)

TOTAL=${#DOC_FILES[@]}
ERRORS=0
CHECKED=0

VALID_VERBS=$( { ls "$REPO_ROOT/templates/devflow/commands" 2>/dev/null | sed 's/\.md$//'; \
  ls "$REPO_ROOT/templates/devflow/skills" 2>/dev/null | sed -E 's/^devflow-/devflow./'; } | sort -u)

echo "Validating doc links in $TOTAL file(s)..."
echo ""

# True if $1 resolves against any plausible base: absolute, @devflow/-prefixed
# (plugin root), relative to the referencing doc's own directory, relative to
# the plugin source root, or relative to the built dist/devflow/ output (some
# shipped READMEs link paths relative to their post-build location).
exists_anywhere() {
  local target="$1" doc_dir="$2"
  if [[ "$target" == @devflow/* ]]; then
    [[ -e "$PLUGIN_ROOT/${target#@devflow/}" ]] && return 0
    return 1
  fi
  if [[ "$target" == /* ]]; then
    [[ -e "$REPO_ROOT$target" ]] && return 0
    return 1
  fi
  [[ -e "$doc_dir/$target" ]] && return 0
  [[ -e "$REPO_ROOT/$target" ]] && return 0
  [[ -e "$PLUGIN_ROOT/$target" ]] && return 0
  [[ -e "$DIST_ROOT/$target" ]] && return 0
  return 1
}

for FILE in "${DOC_FILES[@]}"; do
  REL="${FILE#"$REPO_ROOT"/}"
  FILE_ERRORS=()
  DOC_DIR="$(dirname "$FILE")"

  # ── Markdown link targets: [text](target) ──
  while IFS= read -r TARGET; do
    [[ -z "$TARGET" ]] && continue
    [[ "$TARGET" =~ ^(https?|mailto): ]] && continue
    [[ "$TARGET" == \#* ]] && continue
    CLEAN_TARGET="${TARGET%%#*}"
    [[ -z "$CLEAN_TARGET" ]] && continue
    [[ "$CLEAN_TARGET" == *"..."* ]] && continue
    CHECKED=$((CHECKED + 1))
    exists_anywhere "$CLEAN_TARGET" "$DOC_DIR" || FILE_ERRORS+=("dead link: ($TARGET) -> no such file")
  done < <(grep -oE '\]\([^)]+\)' "$FILE" | sed -E 's/^\]\(//; s/\)$//')

  # ── Inline-code repo-relative paths: `path/to/thing.ext` (incl. @devflow/...) ──
  while IFS= read -r TARGET; do
    [[ -z "$TARGET" ]] && continue
    [[ "$TARGET" == *"..."* ]] && continue
    # bare "devflow/..." and "docs/product.md" denote paths inside a
    # CONSUMER project's own tree (created at runtime by devflow.setup) —
    # never resolvable inside this plugin source repo, not a real finding.
    [[ "$TARGET" == devflow/* ]] && continue
    [[ "$TARGET" == "docs/product.md" ]] && continue
    CHECKED=$((CHECKED + 1))
    exists_anywhere "$TARGET" "$DOC_DIR" || FILE_ERRORS+=("dead path reference: \`$TARGET\` -> no such file")
  done < <(grep -oE '`(@devflow/)?[A-Za-z0-9_./-]*/[A-Za-z0-9_./-]+\.(sh|md|json|yml|yaml)`' "$FILE" | tr -d '`' | sort -u)

  # ── devflow.<verb> mentions must be a real command or skill ──
  while IFS= read -r VERB; do
    [[ -z "$VERB" ]] && continue
    CHECKED=$((CHECKED + 1))
    echo "$VALID_VERBS" | grep -qxF "$VERB" || FILE_ERRORS+=("dead reference: $VERB (no matching command or skill)")
  done < <(grep -Eo 'devflow\.[a-z][a-z-]*' "$FILE" | sort -u)

  if [[ ${#FILE_ERRORS[@]} -gt 0 ]]; then
    echo "✗ $REL"
    for ERR in "${FILE_ERRORS[@]}"; do
      echo "    ERROR: $ERR"
    done
    ERRORS=$((ERRORS + 1))
  else
    echo "✓ $REL"
  fi
done

echo ""
echo "Results: checked $CHECKED reference(s) across $TOTAL file(s), $ERRORS file(s) with dead references"

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
exit 0
