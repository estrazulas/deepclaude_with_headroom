#!/usr/bin/env bash
# setup_local_hr_only.sh — Headroom original (PyPI), local proxy, no auth
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=false
FULL=false
HEADROOM_VERSION="0.27.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --full) FULL=true ;;
  esac
  shift
done

EXTRAS="proxy,code,mcp"
if $FULL; then EXTRAS="all"; fi

banner "Mode: Local proxy — Headroom original (no auth)"
$DRY_RUN && echo "[dry-run] Simulating..." && echo ""

check_prerequisites

# 1. Claude Code commands
install_claude_commands "$DRY_RUN" "$SCRIPT_DIR/files"
add_claude_permissions "$DRY_RUN"

# 2. Headroom CLI (PyPI)
echo ""
echo "━━━ 2. Headroom CLI (PyPI) ━━━"
INSTALL_TARGET="headroom-ai[$EXTRAS]==$HEADROOM_VERSION"
if command -v headroom &>/dev/null; then
  echo "✓ headroom $(headroom --version) already installed"
else
  echo "  Installing $INSTALL_TARGET..."
  if $DRY_RUN; then
    echo "[dry-run] pipx install '$INSTALL_TARGET'"
  elif $FULL; then
    pipx install "$INSTALL_TARGET" 2>/dev/null || {
      sudo apt update && sudo apt install -y pipx && pipx ensurepath
      pipx install "$INSTALL_TARGET"
    }
  else
    read -r -p "  Install headroom-ai with pipx? [Y/n]: " resp </dev/tty
    resp="${resp:-S}"
    if [[ "$resp" =~ ^[SsYy] ]]; then
      pipx install "$INSTALL_TARGET" 2>/dev/null || {
        sudo apt update && sudo apt install -y pipx && pipx ensurepath
        pipx install "$INSTALL_TARGET"
      }
    else
      echo "  Later: pipx install '$INSTALL_TARGET'"
    fi
  fi
  command -v headroom &>/dev/null && echo "✓ headroom $(headroom --version) installed"
fi

# 3. Systemd service (no auth)
echo ""
echo "━━━ 3. Headroom Proxy (systemd) ━━━"
if [ -f "$SCRIPT_DIR/files/deepclaude/headroom.service" ]; then
  mkdir -p "$SYSTEMD_USER_DIR"
  if $DRY_RUN; then
    echo "[dry-run] Would copy headroom.service"
    echo "[dry-run] systemctl daemon-reload + enable + start"
  else
    systemctl --user stop headroom.service 2>/dev/null || true
    cp "$SCRIPT_DIR/files/deepclaude/headroom.service" "$SYSTEMD_USER_DIR/headroom.service"
    sed -i 's| __HEADROOM_EXTRA_ARGS__||' "$SYSTEMD_USER_DIR/headroom.service"
    sed -i '/^__HEADROOM_ENVIRONMENT_FILE__$/d' "$SYSTEMD_USER_DIR/headroom.service"
    systemctl --user daemon-reload
    systemctl --user enable headroom.service
    if command -v headroom &>/dev/null; then
      systemctl --user restart headroom.service 2>/dev/null || systemctl --user start headroom.service
      echo "✓ headroom.service installed"
    fi
  fi
else
  echo "⚠️  headroom.service not found"
fi

# 4. DEEPSEEK_API_KEY
echo ""
echo "━━━ 4. DEEPSEEK_API_KEY ━━━"
SHELL_RC=$(detect_shell_rc)
if grep -qE '^export DEEPSEEK_API_KEY=' "$SHELL_RC" 2>/dev/null; then
  echo "✓ DEEPSEEK_API_KEY already configured in $SHELL_RC"
else
  echo "  DeepSeek API Key is required for the proxy to communicate with DeepSeek."
  echo "  Sign up at: https://platform.deepseek.com"
  echo ""
  if $DRY_RUN; then
    echo "[dry-run] Would ask: enter your API Key"
  else
    read -r -p "  Enter your DeepSeek API Key (sk-...): " USER_KEY </dev/tty
    USER_KEY="${USER_KEY:-}"
    if [ -z "$USER_KEY" ]; then
      echo "  ⚠️  No key provided. Configure later:"
      echo "     echo 'export DEEPSEEK_API_KEY=\"sk-...\"' >> $SHELL_RC"
    else
      USER_KEY="$(echo "$USER_KEY" | tr -d "'\"" | xargs)"
      {
        echo ""
        echo "# DeepSeek API Key (headroom installer)"
        echo "export DEEPSEEK_API_KEY=\"$USER_KEY\""
      } >> "$SHELL_RC"
      echo "✓ Key saved to $SHELL_RC"
      export DEEPSEEK_API_KEY="$USER_KEY"
    fi
  fi
fi

# 5. DeepClaude
install_deepclaude_commands "$DRY_RUN" "$SCRIPT_DIR/files/deepclaude"

# 6. Health check
if command -v headroom &>/dev/null; then
  health_check "$DRY_RUN" false
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Installation complete!"
echo "  🔓 Headroom original (no auth)"
echo ""
echo "  Proxy:  systemctl --user status headroom.service"
echo "  Health: curl localhost:8787/health"
echo ""
echo "  Commands:"
echo "    deepclaude       → Claude Code via DeepSeek (direct)"
echo "    deepclaudehr     → Claude Code via Headroom proxy"
summary_common
