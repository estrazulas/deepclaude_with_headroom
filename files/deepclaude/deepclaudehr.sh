#!/usr/bin/env bash
# deepclaudehr — DeepClaude via Headroom proxy
set -euo pipefail
exec deepclaude --headroom "$@"
