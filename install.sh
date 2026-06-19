#!/usr/bin/env bash
# install.sh — Launcher for the 3 installation modes
# Interactive: bash install.sh
# Direct:      bash install.sh --headroom-release URL ...
#             bash install.sh --proxy-url URL --api-key KEY ...
#             bash install.sh --full
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Route to mode if flags are present
AUTO_MODE=""
FORWARD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --headroom-release)
      AUTO_MODE=2
      FORWARD_ARGS+=("--headroom-release" "$2")
      shift 2 ;;
    --headroom-sha256)
      [ -z "$AUTO_MODE" ] && AUTO_MODE=2
      FORWARD_ARGS+=("--headroom-sha256" "$2")
      shift 2 ;;
    --headroom-auth-release)
      [ -z "$AUTO_MODE" ] && AUTO_MODE=2
      FORWARD_ARGS+=("--headroom-auth-release" "$2")
      shift 2 ;;
    --headroom-auth-sha256)
      [ -z "$AUTO_MODE" ] && AUTO_MODE=2
      FORWARD_ARGS+=("--headroom-auth-sha256" "$2")
      shift 2 ;;
    --proxy-url)
      AUTO_MODE=3
      FORWARD_ARGS+=("--proxy-url" "$2")
      shift 2 ;;
    --api-key)
      [ -z "$AUTO_MODE" ] && AUTO_MODE=3
      FORWARD_ARGS+=("--api-key" "$2")
      shift 2 ;;
    --full)
      [ -z "$AUTO_MODE" ] && AUTO_MODE=1
      FORWARD_ARGS+=("--full")
      shift ;;
    --dry-run)
      FORWARD_ARGS+=("--dry-run")
      shift ;;
    *)
      echo "Unknown flag: $1"
      exit 1 ;;
  esac
done

# If enough flags are present, run directly (array forwarding)
if [ -n "$AUTO_MODE" ]; then
  case "$AUTO_MODE" in
    1) exec bash "$SCRIPT_DIR/setup_local_hr_only.sh" "${FORWARD_ARGS[@]}" ;;
    2) exec bash "$SCRIPT_DIR/setup_local_hr_gate.sh" "${FORWARD_ARGS[@]}" ;;
    3) exec bash "$SCRIPT_DIR/setup_new_dev_hr_gate.sh" "${FORWARD_ARGS[@]}" ;;
  esac
fi

# === Interactive mode (no flags) ===

echo "╔═══════════════════════════════════════╗"
echo "║   Headroom + DeepClaude Installer     ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "  Choose installation mode:"
echo ""
echo "  1) Local proxy — Headroom original"
echo "     Compression, cache, code-aware, MCP."
echo "     Installed from official PyPI. No auth."
echo ""
echo "  2) Local proxy — HeadroomGate"
echo "     Everything from (1) + API keys, users, audit,"
echo "     rate limiting, semantic search."
echo "     Installed from your custom release."
echo ""
echo "  3) Remote dev — HeadroomGate (client)"
echo "     Connects to an already running HeadroomGate proxy."
echo "     Does NOT install proxy, Neo4j, or Qdrant."
echo "     Only configures the client (wrapper + API key)."
echo ""

read -r -p "  Which mode? [1-3]: " MODE </dev/tty

case "$MODE" in
  1)
    echo ""
    read -r -p "  Install with all extras (--full)? [y/N]: " resp </dev/tty
    ARGS=""
    [[ "$resp" =~ ^[SsYy] ]] && ARGS="--full"
    exec bash "$SCRIPT_DIR/setup_local_hr_only.sh" $ARGS
    ;;
  2)
    echo ""
    read -r -p "  Install with all extras (--full)? [y/N]: " resp </dev/tty
    ARGS=""
    [[ "$resp" =~ ^[SsYy] ]] && ARGS="--full"

    read -r -p "  HeadroomGate release URL: " release_url </dev/tty
    [ -n "$release_url" ] && ARGS="$ARGS --headroom-release \"$release_url\""

    read -r -p "  Main wheel SHA256 (Enter to skip): " sha </dev/tty
    [ -n "$sha" ] && ARGS="$ARGS --headroom-sha256 \"$sha\""

    read -r -p "  Auth plugin SHA256 (Enter to skip): " sha </dev/tty
    [ -n "$sha" ] && ARGS="$ARGS --headroom-auth-sha256 \"$sha\""

    read -r -p "  Auth plugin URL (Enter to auto-derive): " auth </dev/tty
    [ -n "$auth" ] && ARGS="$ARGS --headroom-auth-release \"$auth\""

    eval exec bash "$SCRIPT_DIR/setup_local_hr_gate.sh" $ARGS
    ;;
  3)
    echo ""
    read -r -p "  Proxy URL [http://10.0.2.2:8787]: " proxy_url </dev/tty
    proxy_url="${proxy_url:-http://10.0.2.2:8787}"

    read -r -p "  Your HEADROOM_API_KEY (hr_..., ask your admin): " api_key </dev/tty

    exec bash "$SCRIPT_DIR/setup_new_dev_hr_gate.sh" \
      --proxy-url "$proxy_url" \
      --api-key "$api_key"
    ;;
  *)
    echo "Invalid option. Use 1, 2 or 3."
    exit 1
    ;;
esac
