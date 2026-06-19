#!/usr/bin/env bash
# Headroom + DeepClaude Uninstaller — selective multi-component removal
# Usage: bash uninstall.sh [--dry-run] [--yes]
#   --dry-run  Simulate without executing
#   --yes      Remove everything (no prompts)

set -euo pipefail

DRY_RUN=false
YES=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --yes) YES=true ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"
BIN_DIR="$COMMANDS_DIR/bin"
SETTINGS="$HOME/.claude/settings.json"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
HEADROOM_CONFIG_DIR="$HOME/.config/headroom"
HEADROOM_CONFIG_FILE="$HEADROOM_CONFIG_DIR/env"

echo "╔═══════════════════════════════════════╗"
echo "║   Headroom Uninstaller                ║"
echo "║   Proxy + Auth + DeepClaude + CLI     ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# ── Detect what's installed ──────────────────────────────────────────

declare -A COMPONENTS
declare -A FOUND

COMPONENTS[1]="Headroom Proxy (systemd service)"
FOUND[1]=false
[ -f "$SYSTEMD_USER_DIR/headroom.service" ] && FOUND[1]=true

COMPONENTS[2]="Auth Config ($HEADROOM_CONFIG_DIR)"
FOUND[2]=false
[ -d "$HEADROOM_CONFIG_DIR" ] || [ -f "$HEADROOM_CONFIG_FILE" ] && FOUND[2]=true

COMPONENTS[3]="Headroom CLI (pipx)"
FOUND[3]=false
command -v headroom &>/dev/null && FOUND[3]=true

COMPONENTS[4]="DeepClaude scripts (/usr/local/bin/deepclaude, deepclaudehr)"
FOUND[4]=false
[ -f /usr/local/bin/deepclaude ] || [ -f /usr/local/bin/deepclaudehr ] && FOUND[4]=true

COMPONENTS[5]="Claude Code commands + permissions (headroom_usage)"
FOUND[5]=false
[ -f "$COMMANDS_DIR/headroom_usage.md" ] || [ -f "$BIN_DIR/headroom_usage" ] && FOUND[5]=true

COMPONENTS[6]="DEEPSEEK_API_KEY (in shell rc file)"
FOUND[6]=false
SHELL_RC=""
if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then SHELL_RC="$HOME/.zshrc"
elif [ -n "${BASH:-}" ] || [ -f "$HOME/.bashrc" ]; then SHELL_RC="$HOME/.bashrc"
else SHELL_RC="$HOME/.profile"; fi
grep -qE '# DeepSeek API Key \(headroom installer\)' "$SHELL_RC" 2>/dev/null && FOUND[6]=true

COMPONENTS[7]="Docker containers + volumes (neo4j, qdrant)"
FOUND[7]=false
docker ps --format '{{.Names}}' 2>/dev/null | grep -qE 'neo4j|qdrant' && FOUND[7]=true
docker volume ls --format '{{.Name}}' 2>/dev/null | grep -qE 'neo4j|qdrant' && FOUND[7]=true

COMPONENTS[8]="Headroom cache (~/.headroom, ~/.cache/headroom)"
FOUND[8]=false
[ -d "$HOME/.headroom" ] || [ -d "$HOME/.cache/headroom" ] && FOUND[8]=true

# ── Show menu ────────────────────────────────────────────────────────

echo "  Components found:"
echo ""
any_found=false
for i in $(seq 1 8); do
  if ${FOUND[$i]}; then
    echo "    [$i] ${COMPONENTS[$i]}"
    any_found=true
  else
    echo "    [$i] ${COMPONENTS[$i]} (not found)"
  fi
done

if ! $any_found; then
  echo ""
  echo "  Nothing to uninstall — all components clean."
  exit 0
fi

echo ""
echo "  Enter numbers to REMOVE (space/comma-separated, e.g. '1,3,5')"
echo "  or 'all' for everything, 'q' to cancel."

# ── Get selection ────────────────────────────────────────────────────

SELECTED=()
if $YES; then
  for i in $(seq 1 8); do
    ${FOUND[$i]} && SELECTED+=("$i")
  done
  echo "  --yes: removing all found components"
else
  read -r -p "  Remove which? " raw </dev/tty
  raw="${raw:-q}"

  if [[ "$raw" == "q" ]]; then
    echo "  Cancelled."
    exit 0
  fi

  # Normalise: commas → spaces, collapse whitespace
  raw=$(echo "$raw" | tr ',' ' ' | xargs)

  if [[ "$raw" == "all" ]]; then
    for i in $(seq 1 8); do
      ${FOUND[$i]} && SELECTED+=("$i")
    done
  else
    for token in $raw; do
      if [[ "$token" =~ ^[1-8]$ ]] && ${FOUND[$token]}; then
        SELECTED+=("$token")
      fi
    done
  fi
fi

if [ ${#SELECTED[@]} -eq 0 ]; then
  echo "  Nothing selected. Exiting."
  exit 0
fi

echo ""
echo "  Will remove:"
for i in "${SELECTED[@]}"; do
  echo "    - ${COMPONENTS[$i]}"
done
echo ""

if ! $YES && ! $DRY_RUN; then
  read -r -p "  Confirm? [y/N]: " conf </dev/tty
  conf="${conf:-N}"
  if [[ ! "$conf" =~ ^[SsYy] ]]; then
    echo "  Cancelled."
    exit 0
  fi
fi

$DRY_RUN && echo "[dry-run] Simulating..." && echo ""

# ── Helper ───────────────────────────────────────────────────────────

_selected() {
  for s in "${SELECTED[@]}"; do
    [ "$s" == "$1" ] && return 0
  done
  return 1
}

_run() {
  local desc="$1"; shift
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    "$@"
    echo "✓ $desc"
  fi
}

# ── 1. Headroom Proxy ────────────────────────────────────────────────

if _selected 1 && [ -f "$SYSTEMD_USER_DIR/headroom.service" ]; then
  echo "━━━ 1. Headroom Proxy ━━━"
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
fi

# ── 2. Auth Config ───────────────────────────────────────────────────

if _selected 2; then
  echo "━━━ 2. Auth Config ━━━"
  if [ -d "$HEADROOM_CONFIG_DIR" ]; then
    _run "$HEADROOM_CONFIG_DIR removed" rm -rf "$HEADROOM_CONFIG_DIR"
  else
    echo "  Nothing to do (directory not found)"
  fi
fi

# ── 3. Headroom CLI ──────────────────────────────────────────────────

if _selected 3 && command -v headroom &>/dev/null; then
  echo "━━━ 3. Headroom CLI ━━━"
  if $DRY_RUN; then
    echo "[dry-run] pipx uninstall headroom-ai"
  else
    pipx uninstall headroom-ai 2>/dev/null || {
      echo "⚠️  pipx failed. Manual removal..."
      rm -rf "$HOME/.local/share/pipx/venvs/headroom-ai" 2>/dev/null || true
      rm -f "$HOME/.local/bin/headroom" 2>/dev/null || true
    }
    if ! command -v headroom &>/dev/null; then
      echo "✓ headroom CLI removed"
    else
      echo "⚠️  headroom still in PATH. Remove manually: pipx uninstall headroom-ai"
    fi
  fi
fi

# ── 4. DeepClaude ────────────────────────────────────────────────────

if _selected 4; then
  echo "━━━ 4. DeepClaude Scripts ━━━"
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
fi

# ── 5. Claude Code Commands ──────────────────────────────────────────

if _selected 5; then
  echo "━━━ 5. Claude Code Commands ━━━"
  for f in headroom_usage.md; do
    dst="$COMMANDS_DIR/$f"
    if [ -f "$dst" ]; then
      _run "$dst removed" rm -f "$dst"
    else
      echo "  $dst not found"
    fi
  done
  for f in headroom_usage; do
    dst="$BIN_DIR/$f"
    if [ -f "$dst" ]; then
      _run "$dst removed" rm -f "$dst"
    else
      echo "  $dst not found"
    fi
  done

  if [ -f "$SETTINGS" ]; then
    if $DRY_RUN; then
      echo "[dry-run] Would remove headroom_usage permissions from $SETTINGS"
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

# ── 6. DEEPSEEK_API_KEY ──────────────────────────────────────────────

if _selected 6; then
  echo "━━━ 6. DEEPSEEK_API_KEY ━━━"
  if grep -qE '# DeepSeek API Key \(headroom installer\)' "$SHELL_RC" 2>/dev/null; then
    if $DRY_RUN; then
      echo "[dry-run] Would remove DEEPSEEK_API_KEY block from $SHELL_RC"
    else
      sed -i '/^# DeepSeek API Key (headroom installer)$/,/^export DEEPSEEK_API_KEY=/d' "$SHELL_RC"
      echo "✓ DEEPSEEK_API_KEY block removed from $SHELL_RC"
      echo "  Run: source $SHELL_RC (or open a new terminal)"
    fi
  else
    echo "  Nothing to do (DEEPSEEK_API_KEY not found in $SHELL_RC)"
  fi
fi

# ── 7. Docker containers + volumes ───────────────────────────────────

if _selected 7; then
  echo "━━━ 7. Docker (neo4j + qdrant) ━━━"

  # Try project compose first, fall back to headroomgate compose
  COMPOSE_FILE=""
  if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
  elif [ -f "$HOME/git/headroomgate/docker-compose.yml" ]; then
    COMPOSE_FILE="$HOME/git/headroomgate/docker-compose.yml"
  fi

  if [ -n "$COMPOSE_FILE" ] && docker compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep -q . 2>/dev/null; then
    echo "  Found compose project at $COMPOSE_FILE"
    if $DRY_RUN; then
      echo "[dry-run] docker compose -f $COMPOSE_FILE down -v"
    else
      docker compose -f "$COMPOSE_FILE" down -v 2>&1 | sed 's/^/  /'
      echo "✓ Docker containers + volumes removed"
    fi
  else
    # Manual cleanup — stop + remove matching containers/volumes
    echo "  No compose file found. Cleaning up directly..."
    if $DRY_RUN; then
      echo "[dry-run] docker stop/rm containers matching neo4j|qdrant"
      echo "[dry-run] docker volume rm matching neo4j|qdrant"
    else
      for c in $(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE 'neo4j|qdrant' || true); do
        docker stop "$c" 2>/dev/null || true
        docker rm "$c" 2>/dev/null || true
        echo "✓ Container $c removed"
      done
      for v in $(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -iE 'neo4j|qdrant' || true); do
        docker volume rm "$v" 2>/dev/null || true
        echo "✓ Volume $v removed"
      done
    fi
  fi
fi

# ── 8. Cache ─────────────────────────────────────────────────────────

if _selected 8; then
  echo "━━━ 8. Headroom Cache ━━━"
  for d in "$HOME/.headroom" "$HOME/.cache/headroom"; do
    if [ -d "$d" ]; then
      _run "$d removed" rm -rf "$d"
    else
      echo "  $d not found"
    fi
  done
fi

# ── Done ─────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Uninstall complete!"
echo ""

# Nag — check for leftovers
LEFT=""
command -v headroom &>/dev/null && LEFT="$LEFT\n  - headroom CLI still in PATH"
[ -f "$SYSTEMD_USER_DIR/headroom.service" ] && LEFT="$LEFT\n  - $SYSTEMD_USER_DIR/headroom.service"
[ -d "$HEADROOM_CONFIG_DIR" ] && LEFT="$LEFT\n  - $HEADROOM_CONFIG_DIR/ (auth config)"
[ -f "$COMMANDS_DIR/headroom_usage.md" ] && LEFT="$LEFT\n  - $COMMANDS_DIR/headroom_usage.md"
[ -f /usr/local/bin/deepclaude ] && LEFT="$LEFT\n  - /usr/local/bin/deepclaude"
[ -f /usr/local/bin/deepclaudehr ] && LEFT="$LEFT\n  - /usr/local/bin/deepclaudehr"

if [ -n "$LEFT" ]; then
  echo "⚠️  Leftovers found:"
  echo -e "$LEFT"
  echo ""
  echo "  Re-run with those numbers to clean up."
else
  echo "  All selected components removed. Clean!"
fi
