#!/usr/bin/env bash
# setup_new_dev_hr_gate.sh — Dev client, connects to remote HeadroomGate proxy
# Does NOT install: pipx, headroom CLI, systemd, Neo4j, Qdrant
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=false
PROXY_URL="${HEADROOM_PROXY_URL:-}"
API_KEY="${HEADROOM_API_KEY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --proxy-url) PROXY_URL="$2"; shift ;;
    --api-key) API_KEY="$2"; shift ;;
  esac
  shift
done

banner "Mode: Remote dev — HeadroomGate (connect to existing proxy)"
$DRY_RUN && echo "[dry-run] Simulating..." && echo ""

check_prerequisites

# 1. Collect connection data
echo "━━━ 1. Proxy Connection ━━━"
echo "  Ask your team admin:"
echo "    - Proxy URL (e.g. http://10.0.2.2:8787)"
echo "    - Your API key (hr_...)"
echo ""

if [ -z "$PROXY_URL" ]; then
  read -r -p "  Proxy URL [http://10.0.2.2:8787]: " PROXY_URL </dev/tty
  PROXY_URL="${PROXY_URL:-http://10.0.2.2:8787}"
fi
PROXY_URL="${PROXY_URL%/}"

if [ -z "$API_KEY" ]; then
  read -r -p "  Your HEADROOM_API_KEY (hr_...): " API_KEY </dev/tty
fi

if [ -z "$API_KEY" ] || [ "$API_KEY" = "hr_" ]; then
  echo "❌ Invalid HEADROOM_API_KEY. Ask your admin and try again."
  exit 1
fi

echo ""
echo "  Proxy: $PROXY_URL"
echo "  Key:   ${API_KEY:0:10}..."

# 2. Create config
echo ""
echo "━━━ 2. Configuration ━━━"
if $DRY_RUN; then
  echo "[dry-run] Would create $HEADROOM_CONFIG_FILE"
else
  mkdir -p "$HEADROOM_CONFIG_DIR"
  cat > "$HEADROOM_CONFIG_FILE" << INNER
# HeadroomGate — Dev Client Configuration
HEADROOM_API_KEY="${API_KEY}"
HEADROOM_PROXY_URL="${PROXY_URL}"
INNER
  chmod 600 "$HEADROOM_CONFIG_FILE"
  echo "✓ $HEADROOM_CONFIG_FILE"
fi

# 3. Claude Code commands
echo ""
install_claude_commands "$DRY_RUN" "$SCRIPT_DIR/files"
add_claude_permissions "$DRY_RUN"

# 4. DeepClaude commands
install_deepclaude_commands "$DRY_RUN" "$SCRIPT_DIR/files/deepclaude"

# 5. Test connection to remote proxy
echo ""
echo "━━━ 3. Testing Connection ━━━"
if $DRY_RUN; then
  echo "[dry-run] curl -sf $PROXY_URL/health"
else
  if health=$(curl -sf "$PROXY_URL/health" 2>/dev/null); then
    status=$(echo "$health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)
    echo "✓ Proxy responded: $status ($PROXY_URL)"
  else
    echo "  ⚠️  Proxy did not respond at $PROXY_URL"
    echo "      Check the URL and that the admin's proxy is running."
    echo "      deepclaudehr will only work when the proxy is reachable."
  fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Configuration complete!"
echo "  🔐 Dev client — Remote HeadroomGate"
echo ""
echo "  Remote proxy: $PROXY_URL"
echo "  Config:       $HEADROOM_CONFIG_FILE"
echo ""
echo "  Commands:"
echo "    deepclaude       → Claude Code via DeepSeek (direct)"
echo "    deepclaudehr     → Claude Code via HeadroomGate ($PROXY_URL)"
echo ""
echo "  deepclaudehr automatically uses your HEADROOM_API_KEY."
summary_common
