#!/usr/bin/env bash
# install.sh — Launcher para os 3 modos de instalação
# Interativo: bash install.sh
# Direto:     bash install.sh --headroom-release URL ...
#             bash install.sh --proxy-url URL --api-key KEY ...
#             bash install.sh --full
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Se já tem flags, vai direto pro modo apropriado
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
      echo "Flag desconhecida: $1"
      exit 1 ;;
  esac
done

# Se tem flags suficientes, roda direto (array forwarding)
if [ -n "$AUTO_MODE" ]; then
  case "$AUTO_MODE" in
    1) exec bash "$SCRIPT_DIR/setup_local_hr_only.sh" "${FORWARD_ARGS[@]}" ;;
    2) exec bash "$SCRIPT_DIR/setup_local_hr_gate.sh" "${FORWARD_ARGS[@]}" ;;
    3) exec bash "$SCRIPT_DIR/setup_new_dev_hr_gate.sh" "${FORWARD_ARGS[@]}" ;;
  esac
fi

# === Modo interativo (sem flags) ===

echo "╔═══════════════════════════════════════╗"
echo "║   Headroom + DeepClaude Installer     ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "  Escolha o modo de instalação:"
echo ""
echo "  1) Proxy local — Headroom original"
echo "     Compressão, cache, code-aware, MCP."
echo "     Instala do PyPI oficial. Sem auth."
echo ""
echo "  2) Proxy local — HeadroomGate"
echo "     Tudo do (1) + API keys, usuários, auditoria,"
echo "     rate limiting, search semântico."
echo "     Instala do seu release customizado."
echo ""
echo "  3) Dev remoto — HeadroomGate (cliente)"
echo "     Conecta em um proxy HeadroomGate já rodando."
echo "     NÃO instala proxy, Neo4j, nem Qdrant."
echo "     Só configura o cliente (wrapper + API key)."
echo ""

read -r -p "  Qual modo? [1-3]: " MODE </dev/tty

case "$MODE" in
  1)
    echo ""
    read -r -p "  Instalar com todos os extras (--full)? [s/N]: " resp </dev/tty
    ARGS=""
    [[ "$resp" =~ ^[SsYy] ]] && ARGS="--full"
    exec bash "$SCRIPT_DIR/setup_local_hr_only.sh" $ARGS
    ;;
  2)
    echo ""
    read -r -p "  Instalar com todos os extras (--full)? [s/N]: " resp </dev/tty
    ARGS=""
    [[ "$resp" =~ ^[SsYy] ]] && ARGS="--full"

    read -r -p "  URL do release headroomgate: " release_url </dev/tty
    [ -n "$release_url" ] && ARGS="$ARGS --headroom-release \"$release_url\""

    read -r -p "  SHA256 do wheel principal (Enter p/ pular): " sha </dev/tty
    [ -n "$sha" ] && ARGS="$ARGS --headroom-sha256 \"$sha\""

    read -r -p "  SHA256 do plugin auth (Enter p/ pular): " sha </dev/tty
    [ -n "$sha" ] && ARGS="$ARGS --headroom-auth-sha256 \"$sha\""

    read -r -p "  URL do plugin auth (Enter p/ auto-derivar): " auth </dev/tty
    [ -n "$auth" ] && ARGS="$ARGS --headroom-auth-release \"$auth\""

    eval exec bash "$SCRIPT_DIR/setup_local_hr_gate.sh" $ARGS
    ;;
  3)
    echo ""
    read -r -p "  URL do proxy [http://10.0.2.2:8787]: " proxy_url </dev/tty
    proxy_url="${proxy_url:-http://10.0.2.2:8787}"

    read -r -p "  Sua HEADROOM_API_KEY (hr_..., peça ao admin): " api_key </dev/tty

    exec bash "$SCRIPT_DIR/setup_new_dev_hr_gate.sh" \
      --proxy-url "$proxy_url" \
      --api-key "$api_key"
    ;;
  *)
    echo "Opção inválida. Use 1, 2 ou 3."
    exit 1
    ;;
esac
