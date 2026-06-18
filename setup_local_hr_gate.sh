#!/usr/bin/env bash
# setup_local_hr_gate.sh — HeadroomGate fork, proxy local, com auth
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=false
FULL=false
HEADROOM_RELEASE=""
HEADROOM_SHA256=""
HEADROOM_AUTH_RELEASE=""
HEADROOM_AUTH_SHA256=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --full) FULL=true ;;
    --headroom-release) HEADROOM_RELEASE="$2"; shift ;;
    --headroom-sha256) HEADROOM_SHA256="$2"; shift ;;
    --headroom-auth-release) HEADROOM_AUTH_RELEASE="$2"; shift ;;
    --headroom-auth-sha256) HEADROOM_AUTH_SHA256="$2"; shift ;;
  esac
  shift
done

EXTRAS="proxy,code,mcp"
if $FULL; then EXTRAS="all"; fi
EXTRAS="${EXTRAS},auth"

banner "Modo: Proxy local — HeadroomGate (com auth + auditoria)"
$DRY_RUN && echo "[dry-run] Simulando..." && echo ""

check_prerequisites

# 1. Claude Code commands
install_claude_commands "$DRY_RUN" "$SCRIPT_DIR/files"
add_claude_permissions "$DRY_RUN"

# 2. Headroom CLI + Auth Plugin
echo ""
echo "━━━ 2. HeadroomGate CLI + Plugin Auth ━━━"

if [ -z "$HEADROOM_RELEASE" ]; then
  echo "  ⚠️  --headroom-release é obrigatório para headroomgate."
  echo "  Ex: --headroom-release https://github.com/estrazulas/headroomgate/releases/download/v0.26.0.1/headroom_ai-0.26.0.1-....whl"
  exit 1
fi

# Auto-derivar auth plugin URL
if [ -z "$HEADROOM_AUTH_RELEASE" ]; then
  HEADROOM_AUTH_RELEASE=$(echo "$HEADROOM_RELEASE" | sed 's|/headroom_ai-[^/]*$|/headroom_auth-0.1.0-py3-none-any.whl|')
fi

echo "  🌐 Main: $(basename "$HEADROOM_RELEASE")"
echo "  🔌 Plugin: $(basename "$HEADROOM_AUTH_RELEASE")"

if $DRY_RUN; then
  [ -n "$HEADROOM_SHA256" ] && echo "[dry-run] SHA256 main: $HEADROOM_SHA256"
  [ -n "$HEADROOM_AUTH_SHA256" ] && echo "[dry-run] SHA256 auth: $HEADROOM_AUTH_SHA256"
  echo "[dry-run] pipx install --force '${HEADROOM_RELEASE}[$EXTRAS]'"
  echo "[dry-run] pipx inject headroom-ai <auth-plugin>"
else
  # SHA256 main
  local_whl="/tmp/$(basename "$HEADROOM_RELEASE")"
  if [ -n "$HEADROOM_SHA256" ]; then
    curl -fsSL -o "$local_whl" "$HEADROOM_RELEASE"
    local_hash=$(sha256sum "$local_whl" | awk '{print $1}')
    if [ "$local_hash" != "$HEADROOM_SHA256" ]; then
      echo "❌ SHA256 main não confere! Esperado: $HEADROOM_SHA256 Obtido: $local_hash"
      rm -f "$local_whl"
      exit 1
    fi
    echo "✓ SHA256 main confere"
    INSTALL_TARGET="${local_whl}[$EXTRAS]"
  else
    echo "  ⚠️  Sem --headroom-sha256. Pulando verificação."
    INSTALL_TARGET="${HEADROOM_RELEASE}[$EXTRAS]"
  fi

  pipx install --force "$INSTALL_TARGET"
  echo "✓ headroom $(headroom --version) instalado"

  # Auth plugin
  local_auth="/tmp/$(basename "$HEADROOM_AUTH_RELEASE")"
  if [ -n "$HEADROOM_AUTH_SHA256" ]; then
    curl -fsSL -o "$local_auth" "$HEADROOM_AUTH_RELEASE"
    local_hash=$(sha256sum "$local_auth" | awk '{print $1}')
    if [ "$local_hash" != "$HEADROOM_AUTH_SHA256" ]; then
      echo "❌ SHA256 auth não confere! Esperado: $HEADROOM_AUTH_SHA256 Obtido: $local_hash"
      rm -f "$local_auth"
      exit 1
    fi
    echo "✓ SHA256 auth confere"
    pipx inject headroom-ai "$local_auth"
  else
    pipx inject headroom-ai "$HEADROOM_AUTH_RELEASE"
  fi
  echo "✓ Plugin headroom-auth instalado"
fi

# 2b. Auth config
echo ""
echo "━━━ 2b. Configuração Auth — Neo4j + Qdrant ━━━"

NEO4J_URI="${NEO4J_URI:-bolt://localhost:7687}"
NEO4J_USER="${NEO4J_USER:-neo4j}"
NEO4J_PASSWORD="${NEO4J_PASSWORD:-devpassword}"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"

_write_config() {
  mkdir -p "$HEADROOM_CONFIG_DIR"
  cat > "$HEADROOM_CONFIG_FILE" << INNER
# HeadroomGate Auth Configuration
# Lido por headroom.service e deepclaudehr.
HEADROOM_API_KEY="YOUR_HEADROOM_API_KEY_HERE"
HEADROOM_ENCRYPTION_KEY="YOUR_ENCRYPTION_KEY_HERE"
HEADROOM_PROXY_URL="http://localhost:8787"
NEO4J_URI="${NEO4J_URI}"
NEO4J_USER="${NEO4J_USER}"
NEO4J_PASSWORD="${NEO4J_PASSWORD}"
QDRANT_URL="${QDRANT_URL}"
INNER
  chmod 600 "$HEADROOM_CONFIG_FILE"
}

_try_connect_neo4j() {
  local py=""
  if [ -x "$HOME/.local/share/pipx/venvs/headroom-ai/bin/python" ]; then
    py="$HOME/.local/share/pipx/venvs/headroom-ai/bin/python"
  elif command -v python3 &>/dev/null; then
    py="python3"
  fi
  if [ -n "$py" ]; then
    if $py -c "
try:
    from neo4j import GraphDatabase
    d = GraphDatabase.driver('$NEO4J_URI', auth=('$NEO4J_USER', '$NEO4J_PASSWORD'))
    d.verify_connectivity()
    print('OK')
except:
    pass
" 2>/dev/null | grep -q OK; then
      return 0
    fi
  fi
  return 1
}

_ask_db_credentials() {
  echo ""
  echo "  🗄️  Neo4j não acessível em $NEO4J_URI (user: $NEO4J_USER)."
  echo "      Informe os dados ou Enter para manter:"
  echo ""
  read -r -p "  NEO4J_URI [$NEO4J_URI]: " input </dev/tty; NEO4J_URI="${input:-$NEO4J_URI}"
  read -r -p "  NEO4J_USER [$NEO4J_USER]: " input </dev/tty; NEO4J_USER="${input:-$NEO4J_USER}"
  read -r -p "  NEO4J_PASSWORD [$NEO4J_PASSWORD]: " input </dev/tty; NEO4J_PASSWORD="${input:-$NEO4J_PASSWORD}"
  read -r -p "  QDRANT_URL [$QDRANT_URL]: " input </dev/tty; QDRANT_URL="${input:-$QDRANT_URL}"
  _write_config
}

if $DRY_RUN; then
  echo "[dry-run] Criaria $HEADROOM_CONFIG_FILE"
else
  _write_config
  echo "✓ $HEADROOM_CONFIG_FILE"
  if [ "$NEO4J_URI" != "bolt://localhost:7687" ] || [ "$QDRANT_URL" != "http://localhost:6333" ]; then
    echo "  ℹ️  Neo4j/Qdrant detectados do ambiente"
  fi
  if _try_connect_neo4j; then
    echo "  ✓ Neo4j conectado ($NEO4J_URI)"
  else
    _ask_db_credentials
    if _try_connect_neo4j; then
      echo "  ✓ Neo4j conectado ($NEO4J_URI)"
    else
      echo "  ⚠️  Ainda sem conexão. Edite depois: $HEADROOM_CONFIG_FILE"
    fi
  fi
fi

# 3. Systemd service (COM auth)
echo ""
echo "━━━ 3. Headroom Proxy (systemd) ━━━"
if [ -f "$SCRIPT_DIR/files/deepclaude/headroom.service" ]; then
  mkdir -p "$SYSTEMD_USER_DIR"
  if $DRY_RUN; then
    echo "[dry-run] Copiaria headroom.service com auth"
    echo "[dry-run] systemctl daemon-reload + enable + start"
  else
    systemctl --user stop headroom.service 2>/dev/null || true
    cp "$SCRIPT_DIR/files/deepclaude/headroom.service" "$SYSTEMD_USER_DIR/headroom.service"
    sed -i 's| __HEADROOM_EXTRA_ARGS__| --proxy-extension headroom-auth --log-messages|' "$SYSTEMD_USER_DIR/headroom.service"
    sed -i 's|__HEADROOM_ENVIRONMENT_FILE__|EnvironmentFile=%h/.config/headroom/env|' "$SYSTEMD_USER_DIR/headroom.service"
    systemctl --user daemon-reload
    systemctl --user enable headroom.service
    if command -v headroom &>/dev/null; then
      systemctl --user restart headroom.service 2>/dev/null || systemctl --user start headroom.service 2>/dev/null || true
      echo "✓ headroom.service instalado (auth + log-messages)"
    fi
  fi
else
  echo "⚠️  headroom.service não encontrado"
fi

# 4. DEEPSEEK_API_KEY (pulado no headroomgate)
echo ""
echo "━━━ 4. DEEPSEEK_API_KEY ━━━"
echo "✓ HeadroomGate: provider key no Neo4j (headroom auth set-provider-key)"
echo "  O comando 'deepclaude' (direto) precisará da chave depois."

# 5. DeepClaude
install_deepclaude_commands "$DRY_RUN" "$SCRIPT_DIR/files/deepclaude"

# 6. Health check
if command -v headroom &>/dev/null; then
  health_check "$DRY_RUN" true
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Instalação concluída!"
echo "  🔐 HeadroomGate (auth + auditoria)"
echo ""
echo "  Proxy:  systemctl --user status headroom.service"
echo "  Health: curl localhost:8787/health"
echo ""
echo "  🛡️  BOOTSTRAP AUTH:"
echo "  ════════════════════════════════════"
echo "  export NEO4J_URI=$NEO4J_URI NEO4J_USER=$NEO4J_USER NEO4J_PASSWORD=$NEO4J_PASSWORD"
echo "  headroom auth init-db"
echo "  headroom auth create-user admin --role admin --team admin"
echo "  headroom auth create-key admin           ← salve o hr_..."
echo "  headroom auth generate-key               ← salve a chave"
echo "  headroom auth set-provider-key admin anthropic"
echo ""
echo "  Edite ~/.config/headroom/env com as chaves e reinicie:"
echo "  systemctl --user restart headroom.service"
echo ""
echo "  Comandos:"
echo "    deepclaude       → Claude Code via DeepSeek (direto)"
echo "    deepclaudehr     → Claude Code via HeadroomGate proxy"
summary_common
