#!/usr/bin/env bash
# common.sh — shared functions for setup scripts
# Source this file in scripts with: source "$(dirname "$0")/lib/common.sh"
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
    echo "⚠️  ~/.claude not found. Is Claude Code installed?"
    echo "   Run 'claude' at least once to create the directory."
    exit 1
  fi
}

# ---- check CPU features required by Docker containers -----------------------
# Neo4j 5.x and Qdrant need AVX (and AVX2 for optimal vector ops).
# VMs often mask these unless the CPU type is set to "host".
check_cpu_features() {
  local missing=""
  local cpuinfo="/proc/cpuinfo"

  if [ ! -f "$cpuinfo" ]; then
    echo "  ⚠️  Cannot read $cpuinfo — skipping CPU feature check."
    return 0
  fi

  for flag in avx avx2; do
    if ! grep -qw "$flag" "$cpuinfo"; then
      missing="$missing $flag"
    fi
  done

  if [ -n "$missing" ]; then
    echo ""
    echo "  ❌ Missing CPU instruction(s):$missing"
    echo ""
    echo "  The headroom proxy binary requires AVX + AVX2 to run."
    echo "  These instructions aren't available on your CPU (or the VM is masking them)."
    echo ""
    echo "  Common fixes:"
    echo "  • Proxmox  → Set CPU type to 'host' in the VM config"
    echo "  • VirtualBox → Settings → System → Processor → 'Enable Nested VT-x/AMD-V'"
    echo "  • QEMU/KVM → -cpu host (or -cpu qemu64,+avx,+avx2)"
    echo "  • VMware → VM Settings → Processors → 'Expose hardware assisted virtualization'"
    echo "  • Bare metal → Your CPU may be too old; headroom won't run without AVX/AVX2"
    echo ""
    echo "  If you point NEO4J_URI / QDRANT_URL to external instances, you can ignore this."
    echo ""
    if grep -q "hypervisor" "$cpuinfo" 2>/dev/null; then
      echo "  🔍 Detected: running inside a VM — the hypervisor is masking these flags."
      echo "     Enable 'host' CPU passthrough in your VM settings."
      echo ""
    fi
    return 1
  fi

  echo "  ✓ CPU features OK (avx + avx2)"
  return 0
}

# ---- install claude code commands -----------------------------------------
install_claude_commands() {
  local dry="${1:-false}"
  local src_dir="${2:-files}"

  echo "━━━ Installing Claude Code commands ━━━"
  mkdir -p "$BIN_DIR"

  for f in headroom_usage.md; do
    local src="$src_dir/$f"
    local dst="$COMMANDS_DIR/$f"
    [ ! -f "$src" ] && echo "⚠️  $src not found — skipping" && continue
    if $dry; then
      echo "[dry-run] $dst"
    else
      sed "s|/home/[^/]*/\.claude/commands/bin/|\$HOME/.claude/commands/bin/|g; s|\$HOME|$HOME|g" "$src" > "$dst"
      chmod 644 "$dst"
      echo "✓ $dst"
    fi
  done

  for f in bin/headroom_usage; do
    local src="$src_dir/$f"
    local dst="$BIN_DIR/$(basename "$f")"
    [ ! -f "$src" ] && echo "⚠️  $src not found — skipping" && continue
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
  for script_path in "$BIN_DIR/headroom_usage"; do
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
print('✓ Permission:', e)
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
  echo "━━━ Installing DeepClaude ━━━"

  if [ -f "$dc_src/deepclaude.sh" ]; then
    if $dry; then
      echo "[dry-run] Would install: /usr/local/bin/deepclaude (+x)"
      echo "[dry-run] Would install: /usr/local/bin/deepclaudehr (+x)"
    else
      sudo cp "$dc_src/deepclaude.sh" /usr/local/bin/deepclaude
      sudo cp "$dc_src/deepclaudehr.sh" /usr/local/bin/deepclaudehr
      sudo chmod +x /usr/local/bin/deepclaude /usr/local/bin/deepclaudehr
      echo "✓ /usr/local/bin/deepclaude"
      echo "✓ /usr/local/bin/deepclaudehr"
    fi
  else
    echo "⚠️  DeepClaude scripts not found at $dc_src — skipping"
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
    echo "⚠️  Headroom CLI not found in PATH."
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
    echo "  ⚠️  Proxy not up yet — expected for headroomgate."
    echo ""
    echo "  🔍 Diagnostics:"
    echo "    systemctl --user status headroom.service"
    echo "    journalctl --user -u headroom.service -n 30 --no-pager"
    echo "    headroom auth list-users 2>/dev/null || echo 'Neo4j unreachable?'"
    echo "    ls -la ~/.config/headroom/env"
  else
    echo "⚠️  Proxy did not respond after ${attempts}s. Check:"
    echo "   systemctl --user status headroom.service"
    echo "   journalctl --user -u headroom.service -n 20"
  fi
}

# ---- summary common -------------------------------------------------------
summary_common() {
  echo ""
  echo "  Available Claude Code commands:"
  echo "    /headroom_usage  → savings dashboard"
  echo "    (use /reload if they don't appear)"
  echo ""
}
