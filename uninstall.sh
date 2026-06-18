#!/usr/bin/env bash
# Desinstalador Headroom + DeepClaude + Comandos Claude Code
# Uso: bash uninstall.sh [--dry-run] [--keep-config] [--yes]
#   --dry-run      Simula a desinstalação sem executar nada
#   --keep-config  Mantém DEEPSEEK_API_KEY e comandos Claude Code
#   --yes          Não pergunta confirmação (não interativo)

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
echo "║   Proxy + MCP + Comandos Claude Code  ║"
echo "╚═══════════════════════════════════════╝"
echo ""

if ! $YES; then
  read -r -p "  Desinstalar headroom, deepclaude e comandos? [s/N]: " resp </dev/tty
  resp="${resp:-N}"
  if [[ ! "$resp" =~ ^[SsYy] ]]; then
    echo "  Cancelado."
    exit 0
  fi
fi

$DRY_RUN && echo "[dry-run] Simulando desinstalação..." && echo ""

# ═══════════════════════════════════════════
# 1. HEADROOM PROXY (systemd service)
# ═══════════════════════════════════════════

echo "━━━ 1. Removendo Headroom Proxy (systemd) ━━━"

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
    echo "✓ headroom.service removido"
  fi
else
  echo "  Nada a fazer (serviço não encontrado)"
fi

# ═══════════════════════════════════════════
# 1b. HEADROOM AUTH CONFIG (headroomgate)
# ═══════════════════════════════════════════

echo ""
echo "━━━ 1b. Config Auth (headroomgate) ━━━"

HEADROOM_CONFIG_DIR="$HOME/.config/headroom"
if [ -d "$HEADROOM_CONFIG_DIR" ]; then
  if $KEEP_CONFIG; then
    echo "  --keep-config: config auth preservada"
  elif $DRY_RUN; then
    echo "[dry-run] rm -rf $HEADROOM_CONFIG_DIR"
  else
    rm -rf "$HEADROOM_CONFIG_DIR"
    echo "✓ $HEADROOM_CONFIG_DIR removido"
  fi
else
  echo "  Nada a fazer (config auth não encontrada)"
fi

# ═══════════════════════════════════════════
# 2. HEADROOM CLI (pipx)
# ═══════════════════════════════════════════

echo ""
echo "━━━ 2. Removendo Headroom CLI ━━━"

if command -v headroom &>/dev/null; then
  if $DRY_RUN; then
    echo "[dry-run] pipx uninstall headroom-ai"
  else
    pipx uninstall headroom-ai 2>/dev/null || {
      echo "⚠️  pipx uninstall falhou. Tentando remover manualmente..."
      pipx_run_dir="$HOME/.local/share/pipx/venvs/headroom-ai"
      pipx_bin="$HOME/.local/bin/headroom"
      rm -rf "$pipx_run_dir" 2>/dev/null || true
      rm -f "$pipx_bin" 2>/dev/null || true
    }
    if ! command -v headroom &>/dev/null; then
      echo "✓ headroom CLI removido"
    else
      echo "⚠️  headroom ainda está no PATH. Remova manualmente:"
      echo "   pipx uninstall headroom-ai"
    fi
  fi
else
  echo "  Nada a fazer (headroom não encontrado)"
fi

# ═══════════════════════════════════════════
# 3. DEEPCLAUDE
# ═══════════════════════════════════════════

echo ""
echo "━━━ 3. Removendo DeepClaude ━━━"

for bin in /usr/local/bin/deepclaude /usr/local/bin/deepclaudehr; do
  if [ -f "$bin" ]; then
    if $DRY_RUN; then
      echo "[dry-run] sudo rm $bin"
    else
      sudo rm -f "$bin"
      echo "✓ $bin removido"
    fi
  else
    echo "  $bin não encontrado"
  fi
done

# ═══════════════════════════════════════════
# 4. COMANDOS CLAUDE CODE + PERMISSIONS
# ═══════════════════════════════════════════

if $KEEP_CONFIG; then
  echo ""
  echo "━━━ 4. Comandos Claude Code ━━━"
  echo "  --keep-config: comandos preservados"
else
  echo ""
  echo "━━━ 4. Removendo comandos Claude Code ━━━"

  # Remove command markdown files
  for f in mem.md headroom_usage.md; do
    dst="$COMMANDS_DIR/$f"
    if [ -f "$dst" ]; then
      if $DRY_RUN; then
        echo "[dry-run] rm $dst"
      else
        rm -f "$dst"
        echo "✓ $dst removido"
      fi
    else
      echo "  $dst não encontrado"
    fi
  done

  # Remove command scripts
  for f in mem headroom_usage; do
    dst="$BIN_DIR/$f"
    if [ -f "$dst" ]; then
      if $DRY_RUN; then
        echo "[dry-run] rm $dst"
      else
        rm -f "$dst"
        echo "✓ $dst removido"
      fi
    else
      echo "  $dst não encontrado"
    fi
  done

  # Remove permissions from settings.json
  if [ -f "$SETTINGS" ]; then
    if $DRY_RUN; then
      echo "[dry-run] Removeria entradas Bash(mem) e Bash(headroom_usage) de $SETTINGS"
    else
      python3 -c "
import json
with open('$SETTINGS') as f:
    cfg = json.load(f)
allow = cfg.get('permissions', {}).get('allow', [])
before = len(allow)
cfg['permissions']['allow'] = [e for e in allow if 'mem' not in e and 'headroom_usage' not in e]
after = len(cfg['permissions']['allow'])
with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
print(f'✓ Permissões removidas: {before - after} entrada(s) ({before} → {after})')
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
  echo "  --keep-config: chave preservada"
else
  echo ""
  echo "━━━ 5. Removendo DEEPSEEK_API_KEY ━━━"

  SHELL_RC=""
  if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -n "${BASH:-}" ] || [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  fi
  if [ -z "$SHELL_RC" ] || [ ! -f "$SHELL_RC" ]; then
    SHELL_RC="$HOME/.profile"
  fi

  if grep -qE '# DeepSeek API Key \(instalador headroom\)' "$SHELL_RC" 2>/dev/null; then
    if $DRY_RUN; then
      echo "[dry-run] Removeria bloco DEEPSEEK_API_KEY de $SHELL_RC"
    else
      # Remove everything between the DeepSeek comment and the next empty line (or EOF)
      sed -i '/^# DeepSeek API Key (instalador headroom)$/,/^export DEEPSEEK_API_KEY=/d' "$SHELL_RC"
      echo "✓ Bloco DEEPSEEK_API_KEY removido de $SHELL_RC"
      echo "  Execute: source $SHELL_RC (ou abra um novo terminal)"
    fi
  else
    echo "  Nada a fazer (bloco DEEPSEEK_API_KEY não encontrado em $SHELL_RC)"
  fi
fi

# ═══════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Desinstalação concluída!"
echo ""

# Nag — check for leftovers
LEFT=""
command -v headroom &>/dev/null && LEFT="$LEFT\n  - headroom CLI ainda no PATH"
[ -f "$SYSTEMD_USER_DIR/headroom.service" ] && LEFT="$LEFT\n  - $SYSTEMD_USER_DIR/headroom.service"
[ -d "$HOME/.config/headroom" ] && LEFT="$LEFT\n  - $HOME/.config/headroom/ (config auth)"
[ -f "$COMMANDS_DIR/headroom_usage.md" ] && LEFT="$LEFT\n  - $COMMANDS_DIR/headroom_usage.md"
[ -f /usr/local/bin/deepclaude ] && LEFT="$LEFT\n  - /usr/local/bin/deepclaude"

if [ -n "$LEFT" ]; then
  echo "⚠️  Resquícios encontrados:"
  echo -e "$LEFT"
fi

if ! $DRY_RUN && ! $KEEP_CONFIG; then
  echo "  Para limpar completamente, remova também (se desejar):"
  echo "    rm -rf ~/.headroom   # cache e dados do proxy"
  echo "    rm -rf ~/.cache/headroom"
  echo "    rm -rf ~/.config/headroom  # config auth (headroomgate)"
fi
