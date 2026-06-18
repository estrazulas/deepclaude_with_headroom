#!/usr/bin/env bash
# install.sh — Launcher interativo para os 3 modos de instalação
# Uso: bash install.sh
# Ou direto: bash setup_local_hr_only.sh | setup_local_hr_gate.sh | setup_new_dev_hr_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
    read -r -p "  Instalar com todos os extras (--full)? [s/N]: " full_resp </dev/tty
    ARGS=""
    [[ "$full_resp" =~ ^[SsYy] ]] && ARGS="--full"
    exec bash "$SCRIPT_DIR/setup_local_hr_only.sh" $ARGS
    ;;
  2)
    echo ""
    read -r -p "  Instalar com todos os extras (--full)? [s/N]: " full_resp </dev/tty
    ARGS=""
    [[ "$full_resp" =~ ^[SsYy] ]] && ARGS="--full"

    read -r -p "  URL do release headroomgate: " release_url </dev/tty
    [ -n "$release_url" ] && ARGS="$ARGS --headroom-release \"$release_url\""

    read -r -p "  SHA256 do wheel principal (Enter para pular): " sha_main </dev/tty
    [ -n "$sha_main" ] && ARGS="$ARGS --headroom-sha256 \"$sha_main\""

    read -r -p "  SHA256 do plugin auth (Enter para pular): " sha_auth </dev/tty
    [ -n "$sha_auth" ] && ARGS="$ARGS --headroom-auth-sha256 \"$sha_auth\""

    read -r -p "  URL do plugin auth (Enter para auto-derivar): " auth_url </dev/tty
    [ -n "$auth_url" ] && ARGS="$ARGS --headroom-auth-release \"$auth_url\""

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
