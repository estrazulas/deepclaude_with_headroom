#!/usr/bin/env bash
# setup_new_dev_hr_gate.sh — Dev client, conecta em proxy HeadroomGate remoto
# NÃO instala: pipx, headroom CLI, systemd, Neo4j, Qdrant
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

banner "Modo: Dev remoto — HeadroomGate (conecta em proxy existente)"
$DRY_RUN && echo "[dry-run] Simulando..." && echo ""

check_prerequisites

# 1. Coletar dados de conexão
echo "━━━ 1. Conexão com o proxy ━━━"
echo "  Peça ao admin da sua equipe:"
echo "    - URL do proxy (ex: http://10.0.2.2:8787)"
echo "    - Sua API key (hr_...)"
echo ""

if [ -z "$PROXY_URL" ]; then
  read -r -p "  URL do proxy [http://10.0.2.2:8787]: " PROXY_URL </dev/tty
  PROXY_URL="${PROXY_URL:-http://10.0.2.2:8787}"
fi
PROXY_URL="${PROXY_URL%/}"

if [ -z "$API_KEY" ]; then
  read -r -p "  Sua HEADROOM_API_KEY (hr_...): " API_KEY </dev/tty
fi

if [ -z "$API_KEY" ] || [ "$API_KEY" = "hr_" ]; then
  echo "❌ HEADROOM_API_KEY inválida. Peça ao admin e tente novamente."
  exit 1
fi

echo ""
echo "  Proxy: $PROXY_URL"
echo "  Key:   ${API_KEY:0:10}..."

# 2. Criar config
echo ""
echo "━━━ 2. Configuração ━━━"
if $DRY_RUN; then
  echo "[dry-run] Criaria $HEADROOM_CONFIG_FILE"
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

# 5. Testar conexão com proxy remoto
echo ""
echo "━━━ 3. Testando conexão ━━━"
if $DRY_RUN; then
  echo "[dry-run] curl -sf $PROXY_URL/health"
else
  if health=$(curl -sf "$PROXY_URL/health" 2>/dev/null); then
    status=$(echo "$health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)
    echo "✓ Proxy respondeu: $status ($PROXY_URL)"
  else
    echo "  ⚠️  Proxy não respondeu em $PROXY_URL"
    echo "      Verifique a URL e se o proxy do admin está rodando."
    echo "      O deepclaudehr só funcionará quando o proxy estiver acessível."
  fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Configuração concluída!"
echo "  🔐 Dev cliente — HeadroomGate remoto"
echo ""
echo "  Proxy remoto: $PROXY_URL"
echo "  Config:       $HEADROOM_CONFIG_FILE"
echo ""
echo "  Comandos:"
echo "    deepclaude       → Claude Code via DeepSeek (direto)"
echo "    deepclaudehr     → Claude Code via HeadroomGate ($PROXY_URL)"
echo ""
echo "  O deepclaudehr já usa sua HEADROOM_API_KEY automaticamente."
summary_common
