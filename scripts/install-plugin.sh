#!/usr/bin/env bash
# install-plugin.sh — Unified installation script for DevFlow plugin.
# Installs DevFlow across Antigravity, Cursor, and Claude Code environments.
#
# Usage: bash scripts/install-plugin.sh [target] [options]
#
# Targets:
#   antigravity, agy, gemini   Install to Antigravity (global ~/.gemini or workspace .agents)
#   cursor                     Install to Cursor (~/.cursor/plugins/local/devflow)
#   claude, claudecode         Configure/install for Claude Code
#   all                        Install across all detected platforms (default)
#
# Options:
#   -t, --target <name>        Target platform: antigravity | cursor | claude | all
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
  cursor                     Install to Cursor (~/.cursor/plugins/local/devflow)
  claude, claudecode         Configure/install for Claude Code
  all                        Install/configure for all detected platforms (default)

Options:
  -t, --target <name>        Target platform (antigravity | cursor | claude | all)
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
  bash scripts/install-plugin.sh cursor --mode link
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
      if [[ -z "${POSITIONAL[*]:-}" ]] && [[ "$1" =~ ^(antigravity|agy|gemini|cursor|claude|claudecode|all)$ ]]; then
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
  cursor)
    TARGET="cursor"
    ;;
  claude|claudecode)
    TARGET="claude"
    ;;
  all)
    TARGET="all"
    ;;
  *)
    fail "Unknown target: $TARGET. Choose: antigravity | cursor | claude | all"
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

  if command -v agy >/dev/null 2>&1 && [ -d "$DIST_DIR" ]; then
    agy plugin validate "$DIST_DIR"
  fi
  ok "Validation passed"
}

# ── Install / Uninstall: Antigravity ─────────────────────────────────────────
install_antigravity() {
  local TARGET_DIR
  if [ "$SCOPE" = "workspace" ]; then
    TARGET_DIR="$WORKSPACE_DIR/.agents/plugins/devflow"
  else
    TARGET_DIR="$HOME/.gemini/config/plugins/devflow"
  fi

  if [ "$UNINSTALL" = true ]; then
    step "Uninstalling DevFlow from Antigravity ($SCOPE: $TARGET_DIR)..."
    if [ -d "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
      run_cmd rm -rf "$TARGET_DIR"
      ok "DevFlow removed from $TARGET_DIR"
    else
      warn "DevFlow directory not found at $TARGET_DIR"
    fi
    return 0
  fi

  step "Installing DevFlow to Antigravity ($SCOPE: $TARGET_DIR)..."

  local TARGET_PARENT
  TARGET_PARENT="$(dirname "$TARGET_DIR")"
  run_cmd mkdir -p "$TARGET_PARENT"

  if [ "$MODE" = "link" ]; then
    run_cmd rm -rf "$TARGET_DIR"
    run_cmd mkdir -p "$TARGET_DIR"

    # Link all component directories and top-level files
    for ITEM in skills agents commands adapters references contexts hooks; do
      if [ -d "$DIST_DIR/$ITEM" ]; then
        run_cmd ln -sfn "$DIST_DIR/$ITEM" "$TARGET_DIR/$ITEM"
      fi
    done

    for FILE in config.md ETHOS.md AGENTS.md agent.yaml README.md; do
      if [ -f "$DIST_DIR/$FILE" ]; then
        run_cmd ln -sf "$DIST_DIR/$FILE" "$TARGET_DIR/$FILE"
      fi
    done

    # Antigravity requires plugin.json at the root of the plugin directory
    if [ -f "$DIST_DIR/plugin.json" ]; then
      run_cmd cp "$DIST_DIR/plugin.json" "$TARGET_DIR/plugin.json"
    elif [ -f "$DIST_DIR/.antigravity-plugin/plugin.json" ]; then
      run_cmd cp "$DIST_DIR/.antigravity-plugin/plugin.json" "$TARGET_DIR/plugin.json"
    fi

    # Antigravity requires hooks.json at the root of the plugin directory with ANTIGRAVITY_PLUGIN_ROOT
    if [ -f "$DIST_DIR/hooks/hooks.antigravity.json" ]; then
      run_cmd cp "$DIST_DIR/hooks/hooks.antigravity.json" "$TARGET_DIR/hooks.json"
    fi

    ok "DevFlow linked to $TARGET_DIR"
  else
    run_cmd rm -rf "$TARGET_DIR"
    run_cmd cp -R "$DIST_DIR" "$TARGET_DIR"

    # Ensure root plugin.json & hooks.json for Antigravity
    if [ -f "$DIST_DIR/hooks/hooks.antigravity.json" ]; then
      run_cmd cp "$DIST_DIR/hooks/hooks.antigravity.json" "$TARGET_DIR/hooks.json"
    fi
    if [ -f "$DIST_DIR/.antigravity-plugin/plugin.json" ]; then
      run_cmd cp "$DIST_DIR/.antigravity-plugin/plugin.json" "$TARGET_DIR/plugin.json"
    fi

    ok "DevFlow copied to $TARGET_DIR"
  fi

  # Validate installed directory if agy CLI is present
  if command -v agy >/dev/null 2>&1 && [ "$DRY_RUN" = false ]; then
    echo ""
    echo "  Running 'agy plugin validate' on installed target..."
    agy plugin validate "$TARGET_DIR" || warn "agy validation reported notices (see above)"
  fi
}

# ── Install / Uninstall: Cursor ──────────────────────────────────────────────
install_cursor() {
  local TARGET_DIR="$HOME/.cursor/plugins/local/devflow"

  if [ "$UNINSTALL" = true ]; then
    step "Uninstalling DevFlow from Cursor ($TARGET_DIR)..."
    if [ -d "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
      run_cmd rm -rf "$TARGET_DIR"
      ok "DevFlow removed from Cursor"
    else
      warn "DevFlow directory not found at $TARGET_DIR"
    fi
    return 0
  fi

  step "Installing DevFlow to Cursor ($TARGET_DIR)..."

  local TARGET_PARENT="$HOME/.cursor/plugins/local"
  run_cmd mkdir -p "$TARGET_PARENT"

  if [ "$MODE" = "link" ]; then
    run_cmd rm -rf "$TARGET_DIR"
    run_cmd ln -sfn "$DIST_DIR" "$TARGET_DIR"
    ok "DevFlow linked: $TARGET_DIR → $DIST_DIR"
  else
    run_cmd rm -rf "$TARGET_DIR"
    run_cmd cp -R "$DIST_DIR" "$TARGET_DIR"
    ok "DevFlow copied to $TARGET_DIR"
  fi

  echo "  Note: Reload Cursor window to activate changes (Cmd+Shift+P > Developer: Reload Window)"
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
    cursor)
      install_cursor
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

      # Cursor: check ~/.cursor
      if [ -d "$HOME/.cursor" ]; then
        install_cursor
        INSTALLED_ANY=true
      fi

      # Claude Code: check ~/.claude or claude binary
      if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
        install_claude
        INSTALLED_ANY=true
      fi

      if [ "$INSTALLED_ANY" = false ]; then
        warn "No target platforms detected automatically (~/.gemini, ~/.cursor, ~/.claude)."
        echo "Installing to Antigravity global config by default..."
        install_antigravity
      fi
      ;;
  esac

  echo ""
  ok "Installation flow completed successfully."
}

main
