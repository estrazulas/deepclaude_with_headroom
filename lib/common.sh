#!/usr/bin/env bash
# common.sh — funções compartilhadas pelos scripts de setup
# Source este arquivo nos scripts: source "$(dirname "$0")/lib/common.sh"
set -euo pipefail

# ---- paths ----------------------------------------------------------------
COMMANDS_DIR="$HOME/.claude/commands"
BIN_DIR="$COMMANDS_DIR/bin"
SETTINGS="$HOME/.claude/settings.json"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
HEADROOM_CONFIG_DIR="$HOME/.config/headroom"
HEADROOM_CONFIG_FILE="$HEADROOM_CONFIG_DIR/env"

# ---- banner ---------------------------------------------------------------
banner() {
  echo "╔═══════════════════════════════════════╗"
  echo "║   Headroom + DeepClaude Installer     ║"
  echo "╚═══════════════════════════════════════╝"
  echo "  $1"
  echo ""
}

# ---- check prerequisites --------------------------------------------------
check_prerequisites() {
  if [ ! -d "$HOME/.claude" ]; then
    echo "⚠️  ~/.claude não encontrado. O Claude Code está instalado?"
    echo "   Execute 'claude' ao menos uma vez para criar o diretório."
    exit 1
  fi
}

# ---- install claude code commands -----------------------------------------
install_claude_commands() {
  local dry="${1:-false}"
  local src_dir="${2:-files}"

  echo "━━━ Instalando comandos Claude Code ━━━"
  mkdir -p "$BIN_DIR"

  for f in mem.md headroom_usage.md; do
    local src="$src_dir/$f"
    local dst="$COMMANDS_DIR/$f"
    [ ! -f "$src" ] && echo "⚠️  $src não encontrado — pulando" && continue
    if $dry; then
      echo "[dry-run] $dst"
    else
      sed "s|/home/[^/]*/\.claude/commands/bin/|\$HOME/.claude/commands/bin/|g; s|\$HOME|$HOME|g" "$src" > "$dst"
      chmod 644 "$dst"
      echo "✓ $dst"
    fi
  done

  for f in bin/mem bin/headroom_usage; do
    local src="$src_dir/$f"
    local dst="$BIN_DIR/$(basename "$f")"
    [ ! -f "$src" ] && echo "⚠️  $src não encontrado — pulando" && continue
    if $dry; then
      echo "[dry-run] $dst (+x)"
    else
      cp "$src" "$dst"
      chmod +x "$dst"
      echo "✓ $dst"
    fi
  done
}

# ---- add claude code permissions ------------------------------------------
add_claude_permissions() {
  local dry="${1:-false}"
  $dry && return

  [ ! -f "$SETTINGS" ] && echo '{}' > "$SETTINGS"
  for script_path in "$BIN_DIR/mem" "$BIN_DIR/headroom_usage"; do
    for entry in "Bash($script_path *)" "Bash(!$script_path *)"; do
      if ! grep -qF "$entry" "$SETTINGS" 2>/dev/null; then
        python3 -c "
import json
with open('$SETTINGS') as f:
    cfg = json.load(f)
cfg.setdefault('permissions', {}).setdefault('allow', [])
e = '$entry'
if e not in cfg['permissions']['allow']:
    cfg['permissions']['allow'].append(e)
with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
print('✓ Permissão:', e)
"
      fi
    done
  done
}

# ---- install deepclaude commands ------------------------------------------
install_deepclaude_commands() {
  local dry="${1:-false}"
  local dc_src="${2:-files/deepclaude}"

  echo ""
  echo "━━━ Instalando DeepClaude ━━━"

  if [ -f "$dc_src/deepclaude.sh" ]; then
    if $dry; then
      echo "[dry-run] Instalaria: /usr/local/bin/deepclaude (+x)"
      echo "[dry-run] Instalaria: /usr/local/bin/deepclaudehr (+x)"
    else
      sudo cp "$dc_src/deepclaude.sh" /usr/local/bin/deepclaude
      sudo cp "$dc_src/deepclaudehr.sh" /usr/local/bin/deepclaudehr
      sudo chmod +x /usr/local/bin/deepclaude /usr/local/bin/deepclaudehr
      echo "✓ /usr/local/bin/deepclaude"
      echo "✓ /usr/local/bin/deepclaudehr"
    fi
  else
    echo "⚠️  Scripts deepclaude não encontrados em $dc_src — pulando"
  fi
}

# ---- detect shell rc file -------------------------------------------------
detect_shell_rc() {
  if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
    echo "$HOME/.zshrc"
  elif [ -n "${BASH:-}" ] || [ -f "$HOME/.bashrc" ]; then
    echo "$HOME/.bashrc"
  elif [ -f "$HOME/.profile" ]; then
    echo "$HOME/.profile"
  else
    echo "$HOME/.profile"
  fi
}

# ---- health check ---------------------------------------------------------
health_check() {
  local dry="${1:-false}"
  local is_fork="${2:-false}"

  echo ""
  echo "━━━ Health Check ━━━"

  if ! command -v headroom &>/dev/null && ! $is_fork; then
    echo "⚠️  Headroom CLI não encontrado no PATH."
    return
  fi

  local attempts=0 health=""
  while [ $attempts -lt 30 ]; do
    health=$(curl -sf http://localhost:8787/health 2>/dev/null || echo "")
    [ -n "$health" ] && break
    sleep 1
    attempts=$((attempts + 1))
  done

  if [ -n "$health" ]; then
    local status
    status=$(echo "$health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)
    echo "✓ Headroom proxy: $status (localhost:8787)"
  elif $is_fork; then
    echo "  ⚠️  Proxy ainda não subiu — esperado no headroomgate."
    echo "      Complete o bootstrap (headroom auth init-db, create-user, etc.)"
    echo "      e reinicie: systemctl --user restart headroom.service"
  else
    echo "⚠️  Proxy não respondeu após ${attempts}s. Verificar:"
    echo "   systemctl --user status headroom.service"
    echo "   journalctl --user -u headroom.service -n 20"
  fi
}

# ---- summary common -------------------------------------------------------
summary_common() {
  echo ""
  echo "  Comandos Claude Code disponíveis:"
  echo "    /mem               → listar memórias"
  echo "    /headroom_usage  → dashboard de economia"
  echo "    (use /reload se não aparecerem)"
  echo ""
}
