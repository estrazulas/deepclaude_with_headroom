#!/usr/bin/env bash
# deepclaudehr — Claude Code via Headroom proxy (headroom-connect style)
#
# Supports both modes:
#   - Headroomgate (fork): sources ~/.config/headroom/env for HEADROOM_API_KEY
#   - Original headroom: falls back to DEEPSEEK_API_KEY for passthrough
#
# The proxy handles:
#   auth (who you are) → provider key injection → compression → audit log
#
# Model selection (for accurate DeepSeek pricing in dashboard):
#   deepclaudehr              → deepseek-v4-flash (default)
#   deepclaudehr pro          → deepseek-v4-pro
#   DEEPSEEK_MODEL=deepseek-v4-pro deepclaudehr
set -euo pipefail

HEADROOM_ENV="${HOME}/.config/headroom/env"

# Model selection: first positional arg, then env, then default
MODEL_ARG="${1:-}"
case "${MODEL_ARG}" in
  flash|fl) DEEPSEEK_MODEL="deepseek-v4-flash"; shift ;;
  pro|pr)   DEEPSEEK_MODEL="deepseek-v4-pro";  shift ;;
  *)        DEEPSEEK_MODEL="${DEEPSEEK_MODEL:-deepseek-v4-flash}" ;;
esac

# Source auth config if present (headroomgate fork)
if [ -f "$HEADROOM_ENV" ]; then
  # shellcheck source=/dev/null
  source "$HEADROOM_ENV"
fi

export ANTHROPIC_BASE_URL="${HEADROOM_PROXY_URL:-http://localhost:8787}"

# If HEADROOM_API_KEY is set, use it for proxy auth (headroomgate mode).
# Otherwise pass the DeepSeek key directly (original headroom, no auth).
if [ -n "${HEADROOM_API_KEY:-}" ]; then
  export ANTHROPIC_AUTH_TOKEN="${HEADROOM_API_KEY}"
else
  export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY:-}"
fi

# Clear provider keys so they cannot bypass the proxy
unset DEEPSEEK_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY

echo "deepclaudehr: model=${DEEPSEEK_MODEL}" >&2
exec claude --model "${DEEPSEEK_MODEL}" "$@"
