#!/usr/bin/env bash
# Headroom + DeepClaude + Claude Code Commands Uninstaller
# Usage: bash uninstall.sh [--dry-run] [--keep-config] [--yes]
#   --dry-run      Simulate uninstall without executing anything
#   --keep-config  Keep DEEPSEEK_API_KEY and Claude Code commands
#   --yes          Skip confirmation prompt (non-interactive)

set -euo pipefail

DRY_RUN=false
KEEP_CONFIG=false
YES=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --keep-config) KEEP_CONFIG=true ;;
    --yes) YES=true ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"
BIN_DIR="$COMMANDS_DIR/bin"
SETTINGS="$HOME/.claude/settings.json"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "╔═══════════════════════════════════════╗"
echo "║   Headroom Uninstaller                ║"
echo "║   Proxy + MCP + Claude Code Commands  ║"
echo "╚═══════════════════════════════════════╝"
echo ""

if ! $YES; then
  read -r -p "  Uninstall headroom, deepclaude and commands? [y/N]: " resp </dev/tty
  resp="${resp:-N}"
  if [[ ! "$resp" =~ ^[SsYy] ]]; then
    echo "  Cancelled."
    exit 0
  fi
fi

$DRY_RUN && echo "[dry-run] Simulating uninstall..." && echo ""

# ═══════════════════════════════════════════
# 1. HEADROOM PROXY (systemd service)
# ═══════════════════════════════════════════

echo "━━━ 1. Removing Headroom Proxy (systemd) ━━━"

if [ -f "$SYSTEMD_USER_DIR/headroom.service" ]; then
  if $DRY_RUN; then
    echo "[dry-run] systemctl --user stop headroom.service"
    echo "[dry-run] systemctl --user disable headroom.service"
    echo "[dry-run] rm $SYSTEMD_USER_DIR/headroom.service"
    echo "[dry-run] systemctl --user daemon-reload"
  else
    systemctl --user stop headroom.service 2>/dev/null || true
    systemctl --user disable headroom.service 2>/dev/null || true
    rm -f "$SYSTEMD_USER_DIR/headroom.service"
    systemctl --user daemon-reload
    echo "✓ headroom.service removed"
  fi
else
  echo "  Nothing to do (service not found)"
fi

# ═══════════════════════════════════════════
# 1b. HEADROOM AUTH CONFIG (headroomgate)
# ═══════════════════════════════════════════

echo ""
echo "━━━ 1b. Auth Config (headroomgate) ━━━"

HEADROOM_CONFIG_DIR="$HOME/.config/headroom"
if [ -d "$HEADROOM_CONFIG_DIR" ]; then
  if $KEEP_CONFIG; then
    echo "  --keep-config: auth config preserved"
  elif $DRY_RUN; then
    echo "[dry-run] rm -rf $HEADROOM_CONFIG_DIR"
  else
    rm -rf "$HEADROOM_CONFIG_DIR"
    echo "✓ $HEADROOM_CONFIG_DIR removed"
  fi
else
  echo "  Nothing to do (auth config not found)"
fi

# ═══════════════════════════════════════════
# 2. HEADROOM CLI (pipx)
# ═══════════════════════════════════════════

echo ""
echo "━━━ 2. Removing Headroom CLI ━━━"

if command -v headroom &>/dev/null; then
  if $DRY_RUN; then
    echo "[dry-run] pipx uninstall headroom-ai"
  else
    pipx uninstall headroom-ai 2>/dev/null || {
      echo "⚠️  pipx uninstall failed. Attempting manual removal..."
      pipx_run_dir="$HOME/.local/share/pipx/venvs/headroom-ai"
      pipx_bin="$HOME/.local/bin/headroom"
      rm -rf "$pipx_run_dir" 2>/dev/null || true
      rm -f "$pipx_bin" 2>/dev/null || true
    }
    if ! command -v headroom &>/dev/null; then
      echo "✓ headroom CLI removed"
    else
      echo "⚠️  headroom is still in PATH. Remove manually:"
      echo "   pipx uninstall headroom-ai"
    fi
  fi
else
  echo "  Nothing to do (headroom not found)"
fi

# ═══════════════════════════════════════════
# 3. DEEPCLAUDE
# ═══════════════════════════════════════════

echo ""
echo "━━━ 3. Removing DeepClaude ━━━"

for bin in /usr/local/bin/deepclaude /usr/local/bin/deepclaudehr; do
  if [ -f "$bin" ]; then
    if $DRY_RUN; then
      echo "[dry-run] sudo rm $bin"
    else
      sudo rm -f "$bin"
      echo "✓ $bin removed"
    fi
  else
    echo "  $bin not found"
  fi
done

# ═══════════════════════════════════════════
# 4. CLAUDE CODE COMMANDS + PERMISSIONS
# ═══════════════════════════════════════════

if $KEEP_CONFIG; then
  echo ""
  echo "━━━ 4. Claude Code Commands ━━━"
  echo "  --keep-config: commands preserved"
else
  echo ""
  echo "━━━ 4. Removing Claude Code commands ━━━"

  # Remove command markdown files
  for f in headroom_usage.md; do
    dst="$COMMANDS_DIR/$f"
    if [ -f "$dst" ]; then
      if $DRY_RUN; then
        echo "[dry-run] rm $dst"
      else
        rm -f "$dst"
        echo "✓ $dst removed"
      fi
    else
      echo "  $dst not found"
    fi
  done

  # Remove command scripts
  for f in headroom_usage; do
    dst="$BIN_DIR/$f"
    if [ -f "$dst" ]; then
      if $DRY_RUN; then
        echo "[dry-run] rm $dst"
      else
        rm -f "$dst"
        echo "✓ $dst removed"
      fi
    else
      echo "  $dst not found"
    fi
  done

  # Remove permissions from settings.json
  if [ -f "$SETTINGS" ]; then
    if $DRY_RUN; then
      echo "[dry-run] Would remove Bash(headroom_usage) entries from $SETTINGS"
    else
      python3 -c "
import json
with open('$SETTINGS') as f:
    cfg = json.load(f)
allow = cfg.get('permissions', {}).get('allow', [])
before = len(allow)
cfg['permissions']['allow'] = [e for e in allow if 'headroom_usage' not in e]
after = len(cfg['permissions']['allow'])
with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
print(f'✓ Permissions removed: {before - after} entry(s) ({before} → {after})')
"
    fi
  fi
fi

# ═══════════════════════════════════════════
# 5. DEEPSEEK_API_KEY
# ═══════════════════════════════════════════

if $KEEP_CONFIG; then
  echo ""
  echo "━━━ 5. DEEPSEEK_API_KEY ━━━"
  echo "  --keep-config: key preserved"
else
  echo ""
  echo "━━━ 5. Removing DEEPSEEK_API_KEY ━━━"

  SHELL_RC=""
  if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -n "${BASH:-}" ] || [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  fi
  if [ -z "$SHELL_RC" ] || [ ! -f "$SHELL_RC" ]; then
    SHELL_RC="$HOME/.profile"
  fi

  if grep -qE '# DeepSeek API Key \(headroom installer\)' "$SHELL_RC" 2>/dev/null; then
    if $DRY_RUN; then
      echo "[dry-run] Would remove DEEPSEEK_API_KEY block from $SHELL_RC"
    else
      # Remove everything between the DeepSeek comment and the next empty line (or EOF)
      sed -i '/^# DeepSeek API Key (headroom installer)$/,/^export DEEPSEEK_API_KEY=/d' "$SHELL_RC"
      echo "✓ DEEPSEEK_API_KEY block removed from $SHELL_RC"
      echo "  Run: source $SHELL_RC (or open a new terminal)"
    fi
  else
    echo "  Nothing to do (DEEPSEEK_API_KEY block not found in $SHELL_RC)"
  fi
fi

# ═══════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Uninstall complete!"
echo ""

# Nag — check for leftovers
LEFT=""
command -v headroom &>/dev/null && LEFT="$LEFT\n  - headroom CLI still in PATH"
[ -f "$SYSTEMD_USER_DIR/headroom.service" ] && LEFT="$LEFT\n  - $SYSTEMD_USER_DIR/headroom.service"
[ -d "$HOME/.config/headroom" ] && LEFT="$LEFT\n  - $HOME/.config/headroom/ (config auth)"
[ -f "$COMMANDS_DIR/headroom_usage.md" ] && LEFT="$LEFT\n  - $COMMANDS_DIR/headroom_usage.md"
[ -f /usr/local/bin/deepclaude ] && LEFT="$LEFT\n  - /usr/local/bin/deepclaude"

if [ -n "$LEFT" ]; then
  echo "⚠️  Leftovers found:"
  echo -e "$LEFT"
fi

if ! $DRY_RUN && ! $KEEP_CONFIG; then
  echo "  To fully clean up, also remove (if desired):"
  echo "    rm -rf ~/.headroom   # proxy cache and data"
  echo "    rm -rf ~/.cache/headroom"
  echo "    rm -rf ~/.config/headroom  # auth config (headroomgate)"
fi
