#!/usr/bin/env bash
# setup_local_hr_gate.sh — HeadroomGate fork, local proxy, with auth
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

banner "Mode: Local proxy — HeadroomGate (with auth + audit)"
$DRY_RUN && echo "[dry-run] Simulating..." && echo ""

check_prerequisites

# Headroom binary requires AVX/AVX2 — check early before anything else
if ! $DRY_RUN; then
  check_cpu_features || exit 1
else
  echo "[dry-run] Would check CPU features (avx + avx2)"
fi

# 1. Claude Code commands
install_claude_commands "$DRY_RUN" "$SCRIPT_DIR/files"
add_claude_permissions "$DRY_RUN"

# 2. Headroom CLI + Auth Plugin
echo ""
echo "━━━ 2. HeadroomGate CLI + Auth Plugin ━━━"

if [ -z "$HEADROOM_RELEASE" ]; then
  echo "  ⚠️  --headroom-release is required for headroomgate."
  echo "  Example: --headroom-release https://github.com/estrazulas/headroomgate/releases/download/v0.27.0.1/headroom_ai-0.27.0.1-....whl"
  exit 1
fi

# Auto-derive auth plugin URL
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
      echo "❌ SHA256 main mismatch! Expected: $HEADROOM_SHA256 Got: $local_hash"
      rm -f "$local_whl"
      exit 1
    fi
    echo "✓ SHA256 main matches"
    INSTALL_TARGET="${local_whl}[$EXTRAS]"
  else
    echo "  ⚠️  No --headroom-sha256. Skipping verification."
    INSTALL_TARGET="${HEADROOM_RELEASE}[$EXTRAS]"
  fi

  pipx install --force "$INSTALL_TARGET"
  echo "✓ headroom $(headroom --version) installed"

  # Auth plugin
  local_auth="/tmp/$(basename "$HEADROOM_AUTH_RELEASE")"
  if [ -n "$HEADROOM_AUTH_SHA256" ]; then
    curl -fsSL -o "$local_auth" "$HEADROOM_AUTH_RELEASE"
    local_hash=$(sha256sum "$local_auth" | awk '{print $1}')
    if [ "$local_hash" != "$HEADROOM_AUTH_SHA256" ]; then
      echo "❌ SHA256 auth mismatch! Expected: $HEADROOM_AUTH_SHA256 Got: $local_hash"
      rm -f "$local_auth"
      exit 1
    fi
    echo "✓ SHA256 auth matches"
    pipx inject headroom-ai "$local_auth"
  else
    pipx inject headroom-ai "$HEADROOM_AUTH_RELEASE"
  fi
  echo "✓ Plugin headroom-auth installed"
fi

# 2b. Auth config
echo ""
echo "━━━ 2b. Auth Config: Neo4j + Encryption ━━━"

export NEO4J_URI="${NEO4J_URI:-bolt://localhost:7687}"
export NEO4J_USER="${NEO4J_USER:-neo4j}"
export NEO4J_PASSWORD="${NEO4J_PASSWORD:-devpassword}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"

# Offer to store the Anthropic provider key in Neo4j (requires NEO4J_* env vars)
_configure_provider_key() {
  echo ""
  echo "  🔑 Store your Anthropic API key in Neo4j so the proxy can use it."
  echo "  (Skip if you don't have it yet — you can run this later manually.)"
  read -r -p "  Store Anthropic provider key now? [Y/n]: " store_key </dev/tty
  store_key="${store_key:-S}"
  if [[ "$store_key" =~ ^[SsYy] ]]; then
    if headroom auth set-provider-key admin anthropic; then
      PROVIDER_KEY_SET=true
      echo "  ✓ Provider key stored for role 'admin' (provider: anthropic)"
    else
      echo "  ⚠️  Failed to store provider key. Run manually later:"
      echo "      headroom auth set-provider-key admin anthropic"
    fi
  else
    echo "  (Skipped. Run later: headroom auth set-provider-key admin anthropic)"
  fi
}

# Auto-generate encryption key if missing (env → config file → generate)
if ! $DRY_RUN && command -v headroom &>/dev/null; then
  if [ -z "${HEADROOM_ENCRYPTION_KEY:-}" ] && [ -f "$HEADROOM_CONFIG_FILE" ]; then
    source "$HEADROOM_CONFIG_FILE" 2>/dev/null || true
  fi
  if [ -z "${HEADROOM_ENCRYPTION_KEY:-}" ]; then
    echo ""
    echo "  🔑 No HEADROOM_ENCRYPTION_KEY found. Generating a new one..."
    ENCRYPTION_KEY=$(headroom auth generate-key 2>/dev/null | { IFS= read -r key; echo "$key"; cat >/dev/null; })
    if [ -n "$ENCRYPTION_KEY" ]; then
      export HEADROOM_ENCRYPTION_KEY="$ENCRYPTION_KEY"
      echo "  ✓ Encryption key generated: ${ENCRYPTION_KEY}"
    fi
  else
    ENCRYPTION_KEY="$HEADROOM_ENCRYPTION_KEY"
  fi
fi

_write_config() {
  mkdir -p "$HEADROOM_CONFIG_DIR"
  cat > "$HEADROOM_CONFIG_FILE" << INNER
# HeadroomGate Auth Configuration
# Read by headroom.service and deepclaudehr.
HEADROOM_API_KEY="${API_KEY}"
HEADROOM_ENCRYPTION_KEY="${ENCRYPTION_KEY}"
HEADROOM_PROXY_URL="http://localhost:8787"
NEO4J_URI="${NEO4J_URI}"
NEO4J_USER="${NEO4J_USER}"
NEO4J_PASSWORD="${NEO4J_PASSWORD}"
QDRANT_URL="${QDRANT_URL}"
INNER
  chmod 600 "$HEADROOM_CONFIG_FILE"
}

_try_connect() {
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

# Check if Neo4j has existing users
_db_has_users() {
  if command -v headroom &>/dev/null; then
    # If auth CLI works, users exist
    headroom auth list-users 2>/dev/null | grep -q . && return 0
  fi
  return 1
}

# Offer to start Neo4j + Qdrant via docker compose
_start_services() {
  if ! docker info &>/dev/null; then
    return 1
  fi
  local compose_file="$SCRIPT_DIR/docker-compose.yml"
  if [ ! -f "$compose_file" ]; then
    return 1
  fi
  echo ""
  echo "  🐳 Docker detected. I can start Neo4j + Qdrant for you."
  read -r -p "  Start containers now? [Y/n]: " start_svc </dev/tty
  start_svc="${start_svc:-S}"
  if [[ ! "$start_svc" =~ ^[SsYy] ]]; then
    return 1
  fi
  echo "  Starting Neo4j + Qdrant..."
  docker compose -f "$compose_file" up -d 2>&1 | sed 's/^/  /'
  echo "  Waiting for Neo4j (max 30s)..."
  local waited=0
  while [ $waited -lt 30 ]; do
    if _try_connect; then
      echo "  ✓ Neo4j ready (${waited}s)"
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done
  echo "  ⚠️  Neo4j not ready after 30s"
  return 1
}

# Ensure encryption key is set — generate if still a placeholder
_ensure_encryption_key() {
  if [[ "$ENCRYPTION_KEY" == "YOUR_ENCRYPTION_KEY_HERE" || -z "$ENCRYPTION_KEY" ]]; then
    echo ""
    echo "  🔑 Encryption key not set. Generating a new one..."
    ENCRYPTION_KEY=$(headroom auth generate-key 2>/dev/null | { IFS= read -r key; echo "$key"; cat >/dev/null; })
    if [ -n "$ENCRYPTION_KEY" ]; then
      export HEADROOM_ENCRYPTION_KEY="$ENCRYPTION_KEY"
      echo "  ✓ Encryption key generated: ${ENCRYPTION_KEY}"
    else
      echo "  ⚠️  Could not generate encryption key. Run manually: headroom auth generate-key"
      ENCRYPTION_KEY="YOUR_ENCRYPTION_KEY_HERE"
    fi
  fi
}

if $DRY_RUN; then
  echo "[dry-run] Would ask: already have Neo4j + encryption key?"
  echo "[dry-run] If yes: ask for existing credentials and keys"
  echo "[dry-run] If no: detect Neo4j reachable, offer auto bootstrap"
  echo "[dry-run] Would create $HEADROOM_CONFIG_FILE"
else
  API_KEY="YOUR_HEADROOM_API_KEY_HERE"
  ENCRYPTION_KEY="YOUR_ENCRYPTION_KEY_HERE"

  echo ""
  echo "  If you've already configured Neo4j, you can provide the keys."
  echo "  If not, the installer can bootstrap now (init-db,"
  echo "  create admin, generate API key + encryption key)."
  echo ""
  read -r -p "  Already have Neo4j + encryption key configured? [Y/n]: " has_existing </dev/tty
  has_existing="${has_existing:-S}"

  if [[ "$has_existing" =~ ^[SsYy] ]]; then
    # ---- Existing setup: ask for keys ----
    echo ""
    read -r -p "  NEO4J_URI [$NEO4J_URI]: " input </dev/tty; NEO4J_URI="${input:-$NEO4J_URI}"
    read -r -p "  NEO4J_USER [$NEO4J_USER]: " input </dev/tty; NEO4J_USER="${input:-$NEO4J_USER}"
    read -r -p "  NEO4J_PASSWORD [$NEO4J_PASSWORD]: " input </dev/tty; NEO4J_PASSWORD="${input:-$NEO4J_PASSWORD}"
    read -r -p "  QDRANT_URL [$QDRANT_URL]: " input </dev/tty; QDRANT_URL="${input:-$QDRANT_URL}"
    echo ""
    read -r -p "  HEADROOM_ENCRYPTION_KEY [$ENCRYPTION_KEY]: " input </dev/tty
    ENCRYPTION_KEY="${input:-$ENCRYPTION_KEY}"
    export HEADROOM_ENCRYPTION_KEY="$ENCRYPTION_KEY"
    read -r -p "  HEADROOM_API_KEY (hr_..., Enter if none): " input </dev/tty
    [ -n "$input" ] && API_KEY="$input"

    _write_config
    echo "✓ $HEADROOM_CONFIG_FILE"

    if _try_connect; then
      echo "  ✓ Neo4j connected ($NEO4J_URI) — proxy ready"
    else
      echo "  ⚠️  Neo4j not reachable. Check: $NEO4J_URI"
    fi
  else
    # ---- Fresh / empty Neo4j: offer bootstrap ----
    echo ""
    if _try_connect; then
      echo "  ✓ Neo4j connected ($NEO4J_URI)"
      echo ""
      echo "  No users found. I can bootstrap now:"
      echo "    - init-db (constraints + roles)"
      echo "    - create-user admin --role admin"
      echo "    - create-key admin (generates API key)"
      echo "    - Write everything to $HEADROOM_CONFIG_FILE"
      echo ""
      echo "  (Bootstrap = create database schema, admin user, and API key)"
      read -r -p "  Run auto bootstrap? [Y/n]: " do_bootstrap </dev/tty
      do_bootstrap="${do_bootstrap:-S}"

      if [[ "$do_bootstrap" =~ ^[SsYy] ]]; then
        echo ""
        headroom auth init-db -y 2>&1 | sed 's/^/  /'
        headroom auth create-user admin --role admin --team admin 2>&1 | sed 's/^/  /'
        API_KEY=$(headroom auth create-key admin 2>&1 | grep -oP 'hr_[a-f0-9]+' || echo "")
        _ensure_encryption_key
        _write_config
        echo ""
        echo "  ✓ Bootstrap complete!"
        echo "  API_KEY:        ${API_KEY}"
        echo "  ENCRYPTION_KEY: ${ENCRYPTION_KEY}"
        PROVIDER_KEY_SET=false
        _configure_provider_key
      else
        _write_config
        echo "  ✓ $HEADROOM_CONFIG_FILE (template)"
      fi
    else
      # Neo4j not reachable — try docker compose, then manual entry
      _start_services || {
        echo ""
        echo "  🗄️  Enter Neo4j connection details manually:"
        echo ""
        read -r -p "  NEO4J_URI [$NEO4J_URI]: " input </dev/tty; NEO4J_URI="${input:-$NEO4J_URI}"
        read -r -p "  NEO4J_USER [$NEO4J_USER]: " input </dev/tty; NEO4J_USER="${input:-$NEO4J_USER}"
        read -r -p "  NEO4J_PASSWORD [$NEO4J_PASSWORD]: " input </dev/tty; NEO4J_PASSWORD="${input:-$NEO4J_PASSWORD}"
        read -r -p "  QDRANT_URL [$QDRANT_URL]: " input </dev/tty; QDRANT_URL="${input:-$QDRANT_URL}"
      }

      if _try_connect; then
        echo "  ✓ Neo4j connected!"
        echo ""
        echo "  (Bootstrap = create database schema, admin user, and API key)"
        read -r -p "  Run bootstrap now? [Y/n]: " do_bootstrap </dev/tty
        do_bootstrap="${do_bootstrap:-S}"
        if [[ "$do_bootstrap" =~ ^[SsYy] ]]; then
          headroom auth init-db -y 2>&1 | sed 's/^/  /'
          headroom auth create-user admin --role admin --team admin 2>&1 | sed 's/^/  /'
          API_KEY=$(headroom auth create-key admin 2>&1 | grep -oP 'hr_[a-f0-9]+' || echo "")
          _ensure_encryption_key
          _write_config
          echo "  ✓ Bootstrap complete!"
          echo "  API_KEY:        ${API_KEY}"
          echo "  ENCRYPTION_KEY: ${ENCRYPTION_KEY}"
          PROVIDER_KEY_SET=false
          _configure_provider_key
        else
          _write_config
          echo "  ✓ $HEADROOM_CONFIG_FILE (template)"
        fi
      else
        _write_config
        echo "  ⚠️  Still no connection. Edit later: $HEADROOM_CONFIG_FILE"
      fi
    fi
  fi
fi

# 3. Systemd service (WITH auth)
echo ""
echo "━━━ 3. Headroom Proxy (systemd) ━━━"
if [ -f "$SCRIPT_DIR/files/deepclaude/headroom.service" ]; then
  mkdir -p "$SYSTEMD_USER_DIR"
  if $DRY_RUN; then
    echo "[dry-run] Would copy headroom.service with auth"
    echo "[dry-run] systemctl daemon-reload + enable + start"
  else
    systemctl --user stop headroom.service 2>/dev/null || true
    cp "$SCRIPT_DIR/files/deepclaude/headroom.service" "$SYSTEMD_USER_DIR/headroom.service"
    sed -i 's| __HEADROOM_EXTRA_ARGS__| --proxy-extension headroom-auth --log-messages|' "$SYSTEMD_USER_DIR/headroom.service"
    sed -i 's|__HEADROOM_ENVIRONMENT_FILE__|EnvironmentFile=%h/.config/headroom/env|' "$SYSTEMD_USER_DIR/headroom.service"
    sed -i 's|HEADROOM_HOST=127.0.0.1|HEADROOM_HOST=0.0.0.0|' "$SYSTEMD_USER_DIR/headroom.service"
    systemctl --user daemon-reload
    systemctl --user enable headroom.service
    if command -v headroom &>/dev/null; then
      systemctl --user restart headroom.service 2>/dev/null || systemctl --user start headroom.service 2>/dev/null || true
      echo "✓ headroom.service installed (auth + log-messages)"
    fi
  fi
else
  echo "⚠️  headroom.service not found"
fi

# 4. DEEPSEEK_API_KEY (skipped on headroomgate)
echo ""
echo "━━━ 4. DEEPSEEK_API_KEY ━━━"
echo "✓ HeadroomGate: provider key in Neo4j (headroom auth set-provider-key)"
echo "  The 'deepclaude' command (direct) will need the key later."

# 5. DeepClaude
install_deepclaude_commands "$DRY_RUN" "$SCRIPT_DIR/files/deepclaude"

# 6. Health check
if command -v headroom &>/dev/null; then
  health_check "$DRY_RUN" true
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Installation complete!"
echo "  🔐 HeadroomGate (auth + audit)"
echo ""
echo "  Proxy:  systemctl --user status headroom.service"
echo "  Health: curl localhost:8787/health"
echo ""
  # Check if bootstrap was completed or needs manual steps
  if [ -f "$HEADROOM_CONFIG_FILE" ] && grep -q 'hr_[a-f0-9]\{64\}' "$HEADROOM_CONFIG_FILE" 2>/dev/null; then
    echo "  🛡️  Auth bootstrap: DONE"
    echo "  ════════════════════════════════════"
    echo "  API key and encryption key are in $HEADROOM_CONFIG_FILE"
    if ${PROVIDER_KEY_SET:-false}; then
      echo "  🔑 Provider key: DONE"
      echo ""
      echo "  The proxy is ready. Restart if you haven't already:"
      echo "    systemctl --user restart headroom.service"
    else
      echo ""
      echo "  Next: store your provider key and restart the proxy:"
      echo "    headroom auth set-provider-key admin anthropic"
      echo "    systemctl --user restart headroom.service"
    fi
  else
    echo "  🛡️  Auth bootstrap: PENDING"
    echo "  ════════════════════════════════════"
    echo "  The proxy needs an admin user + API key. Run:"
    echo ""
    echo "  export NEO4J_URI=$NEO4J_URI NEO4J_USER=$NEO4J_USER NEO4J_PASSWORD=$NEO4J_PASSWORD"
    echo "  headroom auth init-db -y"
    echo "  headroom auth create-user admin --role admin --team admin"
    echo "  headroom auth create-key admin           ← save the hr_..."
    echo "  headroom auth generate-key               ← save the key"
    echo "  headroom auth set-provider-key admin anthropic"
    echo ""
    echo "  Then edit $HEADROOM_CONFIG_FILE with the keys and:"
    echo "  systemctl --user restart headroom.service"
  fi
echo ""
echo "  Commands:"
echo "    deepclaude       → Claude Code via DeepSeek (direct)"
echo "    deepclaudehr     → Claude Code via HeadroomGate proxy"
summary_common
