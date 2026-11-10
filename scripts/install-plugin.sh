#!/usr/bin/env bash
# install-plugin.sh — Unified installation script for DevFlow plugin.
# Installs DevFlow across Antigravity CLI and Claude Code environments.
#
# Usage: bash scripts/install-plugin.sh [target] [options]
#
# Targets:
#   antigravity, agy, gemini   Install to Antigravity (global ~/.gemini or workspace .agents)
#   claude, claudecode         Configure/install for Claude Code
#   all                        Install across all detected platforms (default)
#
# Options:
#   -t, --target <name>        Target platform: antigravity | claude | all
#   -m, --mode <link|copy>     Install mode: link (symlink, default) or copy (directory copy)
#   -s, --scope <scope>        Antigravity scope: global (default) or workspace
#   -w, --workspace-dir <dir>  Target workspace path for workspace scope (default: pwd)
#   -b, --build                Rebuild plugin before installation
#   -v, --validate             Validate plugin integrity before installation
#   -u, --uninstall            Uninstall DevFlow from specified target(s)
#   -n, --dry-run              Show actions without modifying filesystem
#   -h, --help                 Display this help message
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILDERS_DIR="$SCRIPT_DIR/builders"
DIST_DIR="$ROOT_DIR/dist/devflow"
AGY_DIST_DIR="$ROOT_DIR/dist/devflow-antigravity"

source "$BUILDERS_DIR/common.sh"

TARGET="all"
MODE="link"
SCOPE="global"
WORKSPACE_DIR="$(pwd)"
DO_BUILD=false
DO_VALIDATE=false
UNINSTALL=false
DRY_RUN=false

show_help() {
  cat <<'EOF'
DevFlow Unified Plugin Installer

Usage:
  bash scripts/install-plugin.sh [target] [options]

Targets:
  antigravity, agy, gemini   Install to Antigravity (global ~/.gemini or workspace .agents)
  claude, claudecode         Configure/install for Claude Code
  all                        Install/configure for all detected platforms (default)

Options:
  -t, --target <name>        Target platform (antigravity | claude | all)
  -m, --mode <link|copy>     Install mode: link (symlink, default) or copy
  -s, --scope <scope>        Scope for Antigravity: global (default) or workspace
  -w, --workspace-dir <dir>  Workspace directory for workspace scope (default: current directory)
  -b, --build                Rebuild dist/devflow before installing
  -v, --validate             Run validation checks before installing
  -u, --uninstall            Uninstall DevFlow from target platform(s)
  -n, --dry-run              Preview actions without executing
  -h, --help                 Show this help message

Examples:
  bash scripts/install-plugin.sh antigravity
  bash scripts/install-plugin.sh antigravity --scope workspace
  bash scripts/install-plugin.sh claude
  bash scripts/install-plugin.sh all --build --validate
  bash scripts/install-plugin.sh --uninstall --target antigravity
EOF
}

# Parse positional arguments and flags
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--target)
      TARGET="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -s|--scope)
      SCOPE="$2"
      shift 2
      ;;
    -w|--workspace-dir)
      WORKSPACE_DIR="$2"
      shift 2
      ;;
    -b|--build)
      DO_BUILD=true
      shift
      ;;
    -v|--validate)
      DO_VALIDATE=true
      shift
      ;;
    -u|--uninstall)
      UNINSTALL=true
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      if [[ -z "${POSITIONAL[*]:-}" ]] && [[ "$1" =~ ^(antigravity|agy|gemini|claude|claudecode|all)$ ]]; then
        TARGET="$1"
        shift
      else
        echo "Unknown argument: $1"
        show_help
        exit 1
      fi
      ;;
  esac
done

# Normalize target name
case "$TARGET" in
  antigravity|agy|gemini)
    TARGET="antigravity"
    ;;
  claude|claudecode)
    TARGET="claude"
    ;;
  all)
    TARGET="all"
    ;;
  *)
    fail "Unknown target: $TARGET. Choose: antigravity | claude | all"
    ;;
esac

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} $*"
  else
    "$@"
  fi
}

# ── Build Step ───────────────────────────────────────────────────────────────
ensure_build() {
  if [ "$UNINSTALL" = true ]; then
    return 0
  fi

  if [ "$DO_BUILD" = true ] || [ ! -d "$DIST_DIR" ]; then
    step "Building plugin via scripts/build-plugin.sh..."
    if [ "$DRY_RUN" = true ]; then
      echo -e "  ${YELLOW}[DRY-RUN]${NC} bash $ROOT_DIR/scripts/build-plugin.sh"
    else
      bash "$ROOT_DIR/scripts/build-plugin.sh"
    fi
  fi
}

# ── Validation Step ──────────────────────────────────────────────────────────
validate_plugin() {
  if [ "$UNINSTALL" = true ] || [ "$DO_VALIDATE" != true ]; then
    return 0
  fi

  step "Validating plugin integrity..."
  if [ -f "$ROOT_DIR/templates/devflow/scripts/validate-skills.sh" ]; then
    bash "$ROOT_DIR/templates/devflow/scripts/validate-skills.sh" --strict
  fi

  if command -v agy >/dev/null 2>&1 && [ -d "$AGY_DIST_DIR" ]; then
    agy plugin validate "$AGY_DIST_DIR"
  fi
  ok "Validation passed"
}

# ── Install / Uninstall: Antigravity ─────────────────────────────────────────
install_antigravity() {
  # dist/devflow-antigravity/ is the Antigravity build (root hooks.json,
  # rules/). Global scope is discovered by agy under ~/.gemini/config/plugins/<name>/
  # while internal staging scripts resolve ~/.gemini/antigravity-cli/plugins/<name>/.
  local TARGET_DIRS=()
  if [ "$SCOPE" = "workspace" ]; then
    TARGET_DIRS=("$WORKSPACE_DIR/.agents/plugins/devflow")
  else
    TARGET_DIRS=(
      "$HOME/.gemini/config/plugins/devflow"
      "$HOME/.gemini/antigravity-cli/plugins/devflow"
    )
  fi

  [ -d "$AGY_DIST_DIR" ] || fail "Missing $AGY_DIST_DIR — run with --build first"

  if [ "$UNINSTALL" = true ]; then
    step "Uninstalling DevFlow from Antigravity ($SCOPE)..."
    if [ "$SCOPE" != "workspace" ] && command -v agy >/dev/null 2>&1; then
      run_cmd agy plugin uninstall devflow || warn "agy plugin uninstall reported an error"
    fi
    for t_dir in "${TARGET_DIRS[@]}"; do
      if [ -d "$t_dir" ] || [ -L "$t_dir" ]; then
        run_cmd rm -rf "$t_dir"
        ok "DevFlow removed from $t_dir"
      fi
    done
    return 0
  fi

  step "Installing DevFlow to Antigravity ($SCOPE)..."

  if [ "$SCOPE" != "workspace" ] && [ "$MODE" = "copy" ] && command -v agy >/dev/null 2>&1; then
    run_cmd agy plugin install "$AGY_DIST_DIR"
    # Also ensure internal staging path is linked/copied
    run_cmd mkdir -p "$(dirname "$HOME/.gemini/antigravity-cli/plugins/devflow")"
    run_cmd rm -rf "$HOME/.gemini/antigravity-cli/plugins/devflow"
    run_cmd ln -sfn "$HOME/.gemini/config/plugins/devflow" "$HOME/.gemini/antigravity-cli/plugins/devflow"
    ok "DevFlow installed with agy plugin install"
    return 0
  fi

  for t_dir in "${TARGET_DIRS[@]}"; do
    run_cmd mkdir -p "$(dirname "$t_dir")"
    run_cmd rm -rf "$t_dir"
    if [ "$MODE" = "link" ]; then
      run_cmd ln -sfn "$AGY_DIST_DIR" "$t_dir"
      ok "DevFlow linked: $t_dir → $AGY_DIST_DIR"
    else
      run_cmd cp -R "$AGY_DIST_DIR" "$t_dir"
      ok "DevFlow copied to $t_dir"
    fi
  done

  local VALIDATION_TARGET="${TARGET_DIRS[0]}"
  if command -v agy >/dev/null 2>&1 && [ "$DRY_RUN" = false ]; then
    echo ""
    echo "  Running 'agy plugin validate' on installed target..."
    agy plugin validate "$VALIDATION_TARGET" || warn "agy validation reported notices (see above)"
  fi
}

# ── Install / Configure: Claude Code ────────────────────────────────────────
install_claude() {
  if [ "$UNINSTALL" = true ]; then
    step "Uninstalling DevFlow from Claude Code..."
    local CLAUDE_PLUGIN_DIR="$HOME/.claude/plugins/devflow"
    if [ -d "$CLAUDE_PLUGIN_DIR" ] || [ -L "$CLAUDE_PLUGIN_DIR" ]; then
      run_cmd rm -rf "$CLAUDE_PLUGIN_DIR"
      ok "DevFlow removed from $CLAUDE_PLUGIN_DIR"
    fi
    echo "  To uninstall from marketplace, run in Claude Code:"
    echo "    /plugin uninstall devflow@devflow"
    return 0
  fi

  step "Claude Code Configuration:"

  # Link locally if ~/.claude/plugins exists
  if [ -d "$HOME/.claude/plugins" ]; then
    local CLAUDE_PLUGIN_DIR="$HOME/.claude/plugins/devflow"
    run_cmd mkdir -p "$HOME/.claude/plugins"
    if [ "$MODE" = "link" ]; then
      run_cmd rm -rf "$CLAUDE_PLUGIN_DIR"
      run_cmd ln -sfn "$DIST_DIR" "$CLAUDE_PLUGIN_DIR"
      ok "Local plugin linked at $CLAUDE_PLUGIN_DIR"
    else
      run_cmd rm -rf "$CLAUDE_PLUGIN_DIR"
      run_cmd cp -R "$DIST_DIR" "$CLAUDE_PLUGIN_DIR"
      ok "Local plugin copied to $CLAUDE_PLUGIN_DIR"
    fi
  fi

  echo ""
  echo "  Option 1: MarketPlace Installation (Recommended for production):"
  echo "    /plugin marketplace add Gabriele-bil/dev_flow"
  echo "    /plugin install devflow@devflow"
  echo ""
  echo "  Option 2: Local Session Flag (Recommended for development):"
  echo "    claude --plugin-dir $DIST_DIR"
}

# ── Main Dispatch ────────────────────────────────────────────────────────────
main() {
  ensure_build
  validate_plugin

  case "$TARGET" in
    antigravity)
      install_antigravity
      ;;
    claude)
      install_claude
      ;;
    all)
      local INSTALLED_ANY=false

      # Antigravity: check ~/.gemini or agy
      if [ -d "$HOME/.gemini" ] || command -v agy >/dev/null 2>&1; then
        install_antigravity
        INSTALLED_ANY=true
      fi

      # Claude Code: check ~/.claude or claude binary
      if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
        install_claude
        INSTALLED_ANY=true
      fi

      if [ "$INSTALLED_ANY" = false ]; then
        warn "No target platforms detected automatically (~/.gemini, ~/.claude)."
        echo "Installing to Antigravity global config by default..."
        install_antigravity
      fi
      ;;
  esac

  echo ""
  ok "Installation flow completed successfully."
}

main
