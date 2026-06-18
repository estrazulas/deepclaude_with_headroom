#!/usr/bin/env bash
# deepclaudehr — Claude Code via Headroom proxy (headroom-connect style)
#
# Supports both modes:
#   - Headroomgate (fork): sources ~/.config/headroom/env for HEADROOM_API_KEY
#   - Original headroom: falls back to DEEPSEEK_API_KEY for passthrough
#
# The proxy handles:
#   auth (who you are) → provider key injection → compression → audit log
set -euo pipefail

HEADROOM_ENV="${HOME}/.config/headroom/env"

# Source auth config if present (headroomgate fork)
if [ -f "$HEADROOM_ENV" ]; then
  # shellcheck source=/dev/null
  source "$HEADROOM_ENV"
fi

export ANTHROPIC_BASE_URL="http://localhost:8787"

# If HEADROOM_API_KEY is set, use it for proxy auth (headroomgate mode).
# Otherwise pass the DeepSeek key directly (original headroom, no auth).
if [ -n "${HEADROOM_API_KEY:-}" ]; then
  export ANTHROPIC_AUTH_TOKEN="${HEADROOM_API_KEY}"
else
  export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY:-}"
fi

# Clear provider keys so they cannot bypass the proxy
unset DEEPSEEK_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY

exec claude "$@"
