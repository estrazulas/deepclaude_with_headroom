#!/usr/bin/env bash
# Instalador Headroom + DeepClaude + Comandos Claude Code
# Uso: bash install.sh [--dry-run] [--full] [--headroom-release <url>] [--headroom-sha256 <hash>]
#                            [--headroom-auth-release <url>] [--headroom-auth-sha256 <hash>]
#   --full                       Instala headroom-ai com todos os extras ([all]) sem perguntar
#   --headroom-release <url>     Usa um release próprio (ex: fork headroomgate) em vez do PyPI oficial
#   --headroom-sha256 <hash>     Verifica integridade do .whl principal antes de instalar
#   --headroom-auth-release <url> Plugin auth .whl URL (headroomgate, geralmente auto-derivado)
#   --headroom-auth-sha256 <hash> Verifica integridade do .whl do plugin auth

set -euo pipefail

DRY_RUN=false
FULL=false
HEADROOM_RELEASE=""  # vazio = instala do PyPI oficial; senão, URL do .whl
HEADROOM_VERSION="0.26.0.1"  # versão pinada que sabemos que funciona
HEADROOM_SHA256=""  # hash esperado do .whl (opcional, recomendado com --headroom-release)
HEADROOM_FORK=false  # detectado automaticamente se o release é headroomgate
HEADROOM_AUTH_RELEASE=""  # URL do plugin auth (headroomgate)
HEADROOM_AUTH_SHA256=""   # hash do plugin auth (opcional)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --full) FULL=true ;;
    --headroom-release)
      HEADROOM_RELEASE="$2"
      shift
      ;;
    --headroom-sha256)
      HEADROOM_SHA256="$2"
      shift
      ;;
    --headroom-auth-release)
      HEADROOM_AUTH_RELEASE="$2"
      shift
      ;;
    --headroom-auth-sha256)
      HEADROOM_AUTH_SHA256="$2"
      shift
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/files"
DC_SRC="$SRC/deepclaude"

COMMANDS_DIR="$HOME/.claude/commands"
BIN_DIR="$COMMANDS_DIR/bin"
SETTINGS="$HOME/.claude/settings.json"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

MODE="light"
EXTRAS="proxy,code,mcp"
if $FULL; then
  MODE="complete"
  EXTRAS="all"
fi

# ---- helper: install headroom-auth plugin (headroomgate fork) ----
_install_auth_plugin() {
  local auth_whl=""
  if [ -n "$HEADROOM_AUTH_RELEASE" ]; then
    if [ -n "$HEADROOM_AUTH_SHA256" ]; then
      local tmp_auth="/tmp/$(basename "$HEADROOM_AUTH_RELEASE")"
      echo "  🔐 Verificando SHA256 do plugin auth..."
      curl -fsSL -o "$tmp_auth" "$HEADROOM_AUTH_RELEASE"
      local local_hash
      local_hash=$(sha256sum "$tmp_auth" | awk '{print $1}')
      if [ "$local_hash" != "$HEADROOM_AUTH_SHA256" ]; then
        echo "❌ ERRO: Hash SHA256 do plugin auth não confere!"
        echo "   Esperado:  $HEADROOM_AUTH_SHA256"
        echo "   Obtido:    $local_hash"
        rm -f "$tmp_auth"
        exit 1
      fi
      echo "✓ SHA256 plugin auth confere ($local_hash)"
      auth_whl="$tmp_auth"
    else
      auth_whl="$HEADROOM_AUTH_RELEASE"
    fi
    echo "  🔌 Instalando plugin headroom-auth..."
    pipx inject headroom-ai "$auth_whl"
    echo "✓ Plugin headroom-auth instalado"
  else
    echo "  ⚠️  URL do plugin auth não fornecida. Use --headroom-auth-release."
  fi
}

echo "╔═══════════════════════════════════════╗"
echo "║   Headroom Installer                  ║"
echo "║   Proxy + MCP + Comandos Claude Code  ║"
echo "╚═══════════════════════════════════════╝"
echo "  Modo: $([ "$MODE" = "complete" ] && echo '🔥 Completo (todos os extras)' || echo '⚡ Leve (proxy + code + mcp)')"
echo ""

if [ ! -d "$HOME/.claude" ]; then
  echo "⚠️  ~/.claude não encontrado. O Claude Code está instalado?"
  echo "   Execute 'claude' ao menos uma vez para criar o diretório."
  exit 1
fi
$DRY_RUN && echo "[dry-run] Simulando instalação..." && echo ""

# ═══════════════════════════════════════════
# 1. COMANDOS CLAUDE CODE
# ═══════════════════════════════════════════

echo "━━━ 1. Instalando comandos Claude Code ━━━"

mkdir -p "$BIN_DIR"

for f in mem.md headroom_usage.md; do
  src="$SRC/$f"
  dst="$COMMANDS_DIR/$f"
  [ ! -f "$src" ] && echo "⚠️  $src não encontrado — pulando" && continue
  if $DRY_RUN; then
    echo "[dry-run] $dst"
  else
    # Ajusta path absoluto para o $HOME da máquina destino
    sed "s|/home/[^/]*/\.claude/commands/bin/|\$HOME/.claude/commands/bin/|g; s|\$HOME|$HOME|g" "$src" > "$dst"
    chmod 644 "$dst"
    echo "✓ $dst"
  fi
done

for f in bin/mem bin/headroom_usage; do
  src="$SRC/$f"
  dst="$BIN_DIR/$(basename "$f")"
  [ ! -f "$src" ] && echo "⚠️  $src não encontrado — pulando" && continue
  if $DRY_RUN; then
    echo "[dry-run] $dst (+x)"
  else
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "✓ $dst"
  fi
done

# Permissions — Bash tool + ! (inline shell execution em comandos markdown)
if ! $DRY_RUN; then
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
fi

# ═══════════════════════════════════════════
# 2. HEADROOM CLI (pipx)
# ═══════════════════════════════════════════

echo ""
echo "━━━ 2. Instalando Headroom CLI ━━━"

# Se --headroom-release foi passado, usa essa URL em vez do PyPI
if [ -n "$HEADROOM_RELEASE" ]; then
  echo "  🌐 Release próprio: $HEADROOM_RELEASE"

  # --- Detect headroomgate fork ---
  if echo "$HEADROOM_RELEASE" | grep -qi "headroomgate"; then
    HEADROOM_FORK=true
    # Inclui dependências do auth (neo4j, cryptography, etc.)
    [ "$EXTRAS" != "all" ] && EXTRAS="${EXTRAS},auth"
    echo "  🔐 Release com auth detectado (headroomgate)"
    # Auto-derivar URL do plugin auth se não fornecida explicitamente
    if [ -z "$HEADROOM_AUTH_RELEASE" ]; then
      HEADROOM_AUTH_RELEASE=$(echo "$HEADROOM_RELEASE" | sed 's|/headroom_ai-[^/]*$|/headroom_auth-0.1.0-py3-none-any.whl|')
      echo "  → Plugin auth: $(basename "$HEADROOM_AUTH_RELEASE")"
    fi
  else
    echo "  ℹ️  Release customizado (headroom original, sem autenticação)"
  fi

  # --- SHA256 verification (A) ---
  if [ -n "$HEADROOM_SHA256" ]; then
    TMP_WHL="/tmp/$(basename "$HEADROOM_RELEASE")"
    echo "  🔐 Verificando SHA256..."
    if $DRY_RUN; then
      echo "[dry-run] Baixaria $HEADROOM_RELEASE → validaria SHA256=$HEADROOM_SHA256"
      INSTALL_TARGET="${HEADROOM_RELEASE}[$EXTRAS]"
    else
      curl -fsSL -o "$TMP_WHL" "$HEADROOM_RELEASE"
      LOCAL_HASH=$(sha256sum "$TMP_WHL" | awk '{print $1}')
      if [ "$LOCAL_HASH" != "$HEADROOM_SHA256" ]; then
        echo "❌ ERRO: Hash SHA256 do arquivo não confere!"
        echo "   Esperado:  $HEADROOM_SHA256"
        echo "   Obtido:    $LOCAL_HASH"
        echo "   O arquivo pode ter sido adulterado ou corrompido."
        rm -f "$TMP_WHL"
        exit 1
      fi
      echo "✓ SHA256 confere ($LOCAL_HASH)"
      INSTALL_TARGET="${TMP_WHL}[$EXTRAS]"
    fi
  else
    echo "  ⚠️  Nenhum --headroom-sha256 fornecido. Pulando verificação de integridade."
    INSTALL_TARGET="${HEADROOM_RELEASE}[$EXTRAS]"
  fi
else
  INSTALL_TARGET="headroom-ai[$EXTRAS]==$HEADROOM_VERSION"
fi

if command -v headroom &>/dev/null; then
  if [ -n "$HEADROOM_RELEASE" ]; then
    echo "  Headroom já instalado. Atualizando para release customizada..."
    if $DRY_RUN; then
      echo "[dry-run] pipx install --force '$INSTALL_TARGET'"
      $HEADROOM_FORK && echo "[dry-run] pipx inject headroom-ai <plugin-auth>"
    else
      pipx install --force "$INSTALL_TARGET"
      echo "✓ headroom $(headroom --version) atualizado"
      # Fork: inject auth plugin
      if $HEADROOM_FORK; then
        _install_auth_plugin
      fi
    fi
  else
    echo "✓ headroom $(headroom --version) já instalado"
  fi
else
  echo "  Headroom CLI é necessário para o proxy de compressão."
  echo ""
  if $DRY_RUN; then
    echo "[dry-run] Instalaria headroom-ai[$EXTRAS]"
    $HEADROOM_FORK && echo "[dry-run] pipx inject headroom-ai <plugin-auth>"
  elif $FULL; then
    echo "  Modo completo: instalando headroom-ai[all]..."
    if command -v pipx &>/dev/null; then
      pipx install "$INSTALL_TARGET"
    else
      echo "  pipx não encontrado. Instalando pipx primeiro..."
      sudo apt update && sudo apt install -y pipx
      pipx ensurepath
      pipx install "$INSTALL_TARGET"
    fi
    if command -v headroom &>/dev/null; then
      echo "✓ headroom $(headroom --version) instalado (completo)"
    else
      echo "⚠️  Instalado, mas não está no PATH. Execute: source ~/.bashrc"
    fi
    # Fork: inject auth plugin
    if $HEADROOM_FORK; then _install_auth_plugin; fi
  else
    if command -v pipx &>/dev/null; then
      read -r -p "  Instalar headroom-ai com pipx? [S/n]: " resp </dev/tty
      resp="${resp:-S}"
      if [[ "$resp" =~ ^[SsYy] ]]; then
        echo "  Instalando headroom-ai[proxy,code,mcp]..."
        pipx install "$INSTALL_TARGET"
        if command -v headroom &>/dev/null; then
          echo "✓ headroom $(headroom --version) instalado"
        else
          echo "⚠️  Instalado, mas não está no PATH. Execute: source ~/.bashrc"
        fi
        if $HEADROOM_FORK; then _install_auth_plugin; fi
      else
        echo "  Depois: pipx install '$INSTALL_TARGET'"
      fi
    else
      read -r -p "  pipx não encontrado. Instalar? [S/n]: " resp </dev/tty
      resp="${resp:-S}"
      if [[ "$resp" =~ ^[SsYy] ]]; then
        sudo apt update && sudo apt install -y pipx
        pipx ensurepath
        echo "✓ pipx instalado. Instalando headroom-ai[proxy,code,mcp]..."
        pipx install "$INSTALL_TARGET"
        echo "✓ headroom instalado. Execute 'source ~/.bashrc' para atualizar o PATH."
        if $HEADROOM_FORK; then _install_auth_plugin; fi
      else
        echo ""
        echo "  Passos manuais:"
        echo "    sudo apt install pipx && pipx ensurepath"
        echo "    pipx install '$INSTALL_TARGET'"
      fi
    fi
  fi
fi

# --- Post-install verification (C) ---
if ! $DRY_RUN && command -v headroom &>/dev/null; then
  INSTALLED_VER=$(headroom --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [ -z "$INSTALLED_VER" ]; then
    echo "⚠️  Não foi possível verificar a versão instalada do headroom."
  elif [ -n "$HEADROOM_RELEASE" ]; then
    echo "✓ Post-check: headroom $INSTALLED_VER (release customizada)"
  elif [ "$INSTALLED_VER" != "$HEADROOM_VERSION" ]; then
    echo "⚠️  Versão instalada ($INSTALLED_VER) ≠ esperada ($HEADROOM_VERSION)."
    echo "   Execute 'headroom --version' para confirmar."
  else
    echo "✓ Post-check: headroom $INSTALLED_VER instalado corretamente"
  fi
fi

# ═══════════════════════════════════════════
# 2b. CONFIG AUTH (apenas headroomgate fork)
# ═══════════════════════════════════════════

HEADROOM_CONFIG_DIR="$HOME/.config/headroom"
HEADROOM_CONFIG_FILE="$HEADROOM_CONFIG_DIR/env"

if $HEADROOM_FORK && ! $DRY_RUN; then
  echo ""
  echo "━━━ 2b. Configuração Auth (headroomgate) ━━━"
  mkdir -p "$HEADROOM_CONFIG_DIR"
  if [ ! -f "$HEADROOM_CONFIG_FILE" ]; then
    cat > "$HEADROOM_CONFIG_FILE" << 'INNER'
# Headroom Auth Configuration (instalado por deepclaude_with_headroom)
# Este arquivo é lido por headroom.service e deepclaudehr.
#
# Após a instalação, configure a autenticação:
#   1. Certifique-se de que Neo4j + Qdrant estão rodando
#   2. Execute os comandos abaixo para criar o admin e gerar as chaves
#   3. Substitua os placeholders abaixo pelas chaves geradas
#   4. Reinicie o proxy: systemctl --user restart headroom.service
#
# --- Placeholders (substitua pelos valores reais) ---
HEADROOM_API_KEY="YOUR_HEADROOM_API_KEY_HERE"
HEADROOM_ENCRYPTION_KEY="YOUR_ENCRYPTION_KEY_HERE"
INNER
    chmod 600 "$HEADROOM_CONFIG_FILE"
    echo "✓ $HEADROOM_CONFIG_FILE (template criado)"
  else
    echo "✓ $HEADROOM_CONFIG_FILE já existe (preservado)"
  fi

  # --- Optional: Neo4j + Qdrant setup ---
  echo ""
  echo "  🗄️  O headroomgate precisa de Neo4j + Qdrant para auth e auditoria."
  echo "      Se ainda não tem, configure agora ou depois manualmente."
  echo ""
  read -r -p "  Configurar Neo4j + Qdrant com Docker? [S/n]: " setup_db </dev/tty
  setup_db="${setup_db:-S}"
  if [[ "$setup_db" =~ ^[SsYy] ]]; then
    echo ""
    echo "  Certifique-se de ter o Docker instalado."
    echo "  Clone o repositório headroomgate e suba os containers:"
    echo ""
    echo "    git clone https://github.com/estrazulas/headroomgate.git /tmp/headroomgate"
    echo "    cd /tmp/headroomgate && docker compose up -d neo4j qdrant"
    echo ""
    echo "  Aguarde ~10s para o Neo4j inicializar e continue com o bootstrap."
  else
    echo "  (pulado — configure Neo4j + Qdrant manualmente depois)"
  fi
elif $HEADROOM_FORK && $DRY_RUN; then
  echo ""
  echo "━━━ 2b. Configuração Auth (headroomgate) ━━━"
  echo "[dry-run] Criaria $HEADROOM_CONFIG_FILE (template)"
  echo "[dry-run] Perguntaria sobre Neo4j + Qdrant"
fi

# ═══════════════════════════════════════════
# 3. HEADROOM PROXY (systemd service)
# ═══════════════════════════════════════════

echo ""
echo "━━━ 3. Configurando Headroom Proxy (systemd) ━━━"

if [ -f "$DC_SRC/headroom.service" ]; then
  mkdir -p "$SYSTEMD_USER_DIR"
  if $DRY_RUN; then
    echo "[dry-run] Copiaria: $SYSTEMD_USER_DIR/headroom.service"
    echo "[dry-run] Rodaria: systemctl --user daemon-reload && enable headroom"
  else
    # Stop any existing instance (may be in a restart loop from a broken config)
    systemctl --user stop headroom.service 2>/dev/null || true
    cp "$DC_SRC/headroom.service" "$SYSTEMD_USER_DIR/headroom.service"
    # Adapt service for fork (auth) or original (no auth)
    if $HEADROOM_FORK; then
      sed -i 's| __HEADROOM_EXTRA_ARGS__| --proxy-extension headroom-auth --log-messages|' "$SYSTEMD_USER_DIR/headroom.service"
      sed -i 's|__HEADROOM_ENVIRONMENT_FILE__|EnvironmentFile=%h/.config/headroom/env|' "$SYSTEMD_USER_DIR/headroom.service"
      echo "✓ headroom.service: auth plugin + log-messages ativados"
    else
      sed -i 's| __HEADROOM_EXTRA_ARGS__||' "$SYSTEMD_USER_DIR/headroom.service"
      sed -i '/^__HEADROOM_ENVIRONMENT_FILE__$/d' "$SYSTEMD_USER_DIR/headroom.service"
      echo "✓ headroom.service: modo padrão (sem auth)"
    fi
    systemctl --user daemon-reload
    systemctl --user enable headroom.service
    if command -v headroom &>/dev/null; then
      systemctl --user restart headroom.service 2>/dev/null || systemctl --user start headroom.service
      sleep 2
      if systemctl --user is-active --quiet headroom.service 2>/dev/null; then
        echo "✓ headroom.service instalado e em execução"
      else
        echo "⚠️  headroom.service não subiu. Verificar:"
        echo "   journalctl --user -u headroom.service -n 20"
      fi
    else
      echo "✓ headroom.service instalado (início manual após instalar headroom CLI)"
    fi
  fi
else
  echo "⚠️  headroom.service não encontrado em $DC_SRC — pulando"
fi

# ═══════════════════════════════════════════
# 4. DEEPSEEK_API_KEY
# ═══════════════════════════════════════════

echo ""
echo "━━━ 4. Configurando DEEPSEEK_API_KEY ━━━"

SHELL_RC=""
if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "${BASH:-}" ] || [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
fi
if [ -z "$SHELL_RC" ] || [ ! -f "$SHELL_RC" ]; then
  SHELL_RC="$HOME/.profile"
fi

if $HEADROOM_FORK; then
  echo "✓ Headroomgate: chave do provider fica no Neo4j (headroom auth set-provider-key)"
  echo "  O comando 'deepclaude' (direto, sem proxy) precisará de DEEPSEEK_API_KEY."
  echo "  Configure depois: echo 'export DEEPSEEK_API_KEY=\"sk-...\"' >> $SHELL_RC"
elif grep -qE '^export DEEPSEEK_API_KEY=' "$SHELL_RC" 2>/dev/null; then
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
      echo "  Execute: source $SHELL_RC"
      export DEEPSEEK_API_KEY="$USER_KEY"
      echo "✓ DEEPSEEK_API_KEY ativa na sessão atual"
    fi
  fi
fi

# ═══════════════════════════════════════════
# 5. DEEPCLAUDE
# ═══════════════════════════════════════════

echo ""
echo "━━━ 5. Instalando DeepClaude ━━━"

if [ -f "$DC_SRC/deepclaude.sh" ]; then
  if $DRY_RUN; then
    echo "[dry-run] Instalaria: /usr/local/bin/deepclaude (+x)"
    echo "[dry-run] Instalaria: /usr/local/bin/deepclaudehr (+x)"
  else
    sudo cp "$DC_SRC/deepclaude.sh" /usr/local/bin/deepclaude
    sudo cp "$DC_SRC/deepclaudehr.sh" /usr/local/bin/deepclaudehr
    sudo chmod +x /usr/local/bin/deepclaude /usr/local/bin/deepclaudehr
    echo "✓ /usr/local/bin/deepclaude"
    echo "✓ /usr/local/bin/deepclaudehr"
  fi
else
  echo "⚠️  Scripts deepclaude não encontrados em $DC_SRC — pulando"
fi

# ═══════════════════════════════════════════
# 6. HEALTH CHECK
# ═══════════════════════════════════════════

echo ""
echo "━━━ 6. Health Check ━━━"

if command -v headroom &>/dev/null; then
  # Wait up to 10s for the proxy to become ready
  ATTEMPTS=0
  HEALTH=""
  while [ $ATTEMPTS -lt 10 ]; do
    HEALTH=$(curl -sf http://localhost:8787/health 2>/dev/null || echo "")
    [ -n "$HEALTH" ] && break
    sleep 1
    ATTEMPTS=$((ATTEMPTS + 1))
  done
  if [ -n "$HEALTH" ]; then
    STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)
    echo "✓ Headroom proxy: $STATUS (localhost:8787)"
  else
    echo "⚠️  Proxy não respondeu após ${ATTEMPTS}s. Verificar:"
    echo "   systemctl --user status headroom.service"
    echo "   journalctl --user -u headroom.service -n 20"
  fi
else
  echo "⚠️  Headroom CLI não encontrado no PATH."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Instalação concluída!"
echo "  Modo: $([ "$MODE" = "complete" ] && echo '🔥 Completo' || echo '⚡ Leve (proxy + code + mcp)')"
if $HEADROOM_FORK; then
  echo "  🔐 Auth: headroomgate (plugin instalado)"
else
  echo "  🔓 Auth: desabilitado (headroom original)"
fi
echo ""
echo "  Headroom proxy:"
echo "    systemctl --user status headroom.service"
echo "    curl localhost:8787/health"
echo "    /headroom_usage (dentro do Claude Code)"
echo ""
echo "  DeepClaude:"
echo "    deepclaude       → Claude Code via DeepSeek"
echo "    deepclaudehr     → Claude Code via Headroom proxy"
if $HEADROOM_FORK; then
  echo ""
  echo "  🛡️  BOOTSTRAP AUTH (headroomgate):"
  echo "  ════════════════════════════════════"
  echo "  Antes de usar deepclaudehr, configure a autenticação:"
  echo ""
  echo "  1. Certifique-se de que Neo4j + Qdrant estão rodando"
  echo "     (se pulou a config anterior, veja docker-compose no repo headroomgate)"
  echo ""
  echo "  2. Inicialize o banco e crie o admin:"
  echo "     headroom auth init-db"
  echo "     headroom auth create-user admin --role admin --team admin"
  echo ""
  echo "  3. Gere a chave de API do admin:"
  echo "     headroom auth create-key admin"
  echo "     → Copie o hr_... gerado"
  echo ""
  echo "  4. Configure a chave do provider (DeepSeek):"
  echo "     headroom auth set-provider-key admin anthropic"
  echo "     → Cole sua chave sk-... da DeepSeek"
  echo ""
  echo "  5. Gere a chave de criptografia:"
  echo "     headroom auth generate-key"
  echo ""
  echo "  6. Edite ~/.config/headroom/env com as chaves reais"
  echo ""
  echo "  7. Reinicie o proxy com auth:"
  echo "     systemctl --user restart headroom.service"
  echo ""
  echo "  8. Teste: deepclaudehr \"Hello\""
  echo "  ════════════════════════════════════"
elif [ -z "$HEADROOM_RELEASE" ]; then
  echo ""
  echo "  ⚠️  Você instalou o Headroom original (sem autenticação)."
  echo "    O headroomgate oferece recursos adicionais:"
  echo "      🔐 Autenticação de usuários com API key"
  echo "      📋 Auditoria de requisições (quem fez o quê)"
  echo "      👥 Gerenciamento de usuários e permissões"
  echo "      🔑 Criptografia de chaves de provedores"
  echo ""
  echo "    Para instalar com auth, use:"
  echo "      bash install.sh --headroom-release <URL_DO_HEADROOMGATE>"
fi
echo ""
echo "  Comandos Claude Code disponíveis:"
echo "    /mem               → listar memórias"
echo "    /headroom_usage  → dashboard de economia"
echo "    (use /reload se não aparecerem)"
echo ""
