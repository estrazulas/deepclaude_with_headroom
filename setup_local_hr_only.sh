#!/usr/bin/env bash
# setup_local_hr_only.sh — Headroom original (PyPI), proxy local, sem auth
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=false
FULL=false
HEADROOM_VERSION="0.25.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --full) FULL=true ;;
  esac
  shift
done

EXTRAS="proxy,code,mcp"
if $FULL; then EXTRAS="all"; fi

banner "Modo: Proxy local — Headroom original (sem auth)"
$DRY_RUN && echo "[dry-run] Simulando..." && echo ""

check_prerequisites

# 1. Claude Code commands
install_claude_commands "$DRY_RUN" "$SCRIPT_DIR/files"
add_claude_permissions "$DRY_RUN"

# 2. Headroom CLI (PyPI)
echo ""
echo "━━━ 2. Headroom CLI (PyPI) ━━━"
INSTALL_TARGET="headroom-ai[$EXTRAS]==$HEADROOM_VERSION"
if command -v headroom &>/dev/null; then
  echo "✓ headroom $(headroom --version) já instalado"
else
  echo "  Instalando $INSTALL_TARGET..."
  if $DRY_RUN; then
    echo "[dry-run] pipx install '$INSTALL_TARGET'"
  elif $FULL; then
    pipx install "$INSTALL_TARGET" 2>/dev/null || {
      sudo apt update && sudo apt install -y pipx && pipx ensurepath
      pipx install "$INSTALL_TARGET"
    }
  else
    read -r -p "  Instalar headroom-ai com pipx? [S/n]: " resp </dev/tty
    resp="${resp:-S}"
    if [[ "$resp" =~ ^[SsYy] ]]; then
      pipx install "$INSTALL_TARGET" 2>/dev/null || {
        sudo apt update && sudo apt install -y pipx && pipx ensurepath
        pipx install "$INSTALL_TARGET"
      }
    else
      echo "  Depois: pipx install '$INSTALL_TARGET'"
    fi
  fi
  command -v headroom &>/dev/null && echo "✓ headroom $(headroom --version) instalado"
fi

# 3. Systemd service (sem auth)
echo ""
echo "━━━ 3. Headroom Proxy (systemd) ━━━"
if [ -f "$SCRIPT_DIR/files/deepclaude/headroom.service" ]; then
  mkdir -p "$SYSTEMD_USER_DIR"
  if $DRY_RUN; then
    echo "[dry-run] Copiaria headroom.service"
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
      echo "✓ headroom.service instalado"
    fi
  fi
else
  echo "⚠️  headroom.service não encontrado"
fi

# 4. DEEPSEEK_API_KEY
echo ""
echo "━━━ 4. DEEPSEEK_API_KEY ━━━"
SHELL_RC=$(detect_shell_rc)
if grep -qE '^export DEEPSEEK_API_KEY=' "$SHELL_RC" 2>/dev/null; then
  echo "✓ DEEPSEEK_API_KEY já configurada em $SHELL_RC"
else
  echo "  DeepSeek API Key é necessária para o proxy se comunicar com a DeepSeek."
  echo "  Cadastre-se em: https://platform.deepseek.com"
  echo ""
  if $DRY_RUN; then
    echo "[dry-run] Perguntaria: digite sua API Key"
  else
    read -r -p "  Digite sua DeepSeek API Key (sk-...): " USER_KEY </dev/tty
    USER_KEY="${USER_KEY:-}"
    if [ -z "$USER_KEY" ]; then
      echo "  ⚠️  Nenhuma chave. Configure depois:"
      echo "     echo 'export DEEPSEEK_API_KEY=\"sk-...\"' >> $SHELL_RC"
    else
      USER_KEY="$(echo "$USER_KEY" | tr -d "'\"" | xargs)"
      {
        echo ""
        echo "# DeepSeek API Key (instalador headroom)"
        echo "export DEEPSEEK_API_KEY=\"$USER_KEY\""
      } >> "$SHELL_RC"
      echo "✓ Chave salva em $SHELL_RC"
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
echo "  ✅ Instalação concluída!"
echo "  🔓 Headroom original (sem auth)"
echo ""
echo "  Proxy:  systemctl --user status headroom.service"
echo "  Health: curl localhost:8787/health"
echo ""
echo "  Comandos:"
echo "    deepclaude       → Claude Code via DeepSeek (direto)"
echo "    deepclaudehr     → Claude Code via Headroom proxy"
summary_common
