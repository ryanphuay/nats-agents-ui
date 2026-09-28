#!/usr/bin/env bash
set -euo pipefail
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUN_BIN="${BUN_BIN:-$DEMO_DIR/.tools/bun/node_modules/.bin/bun}"
export npm_config_cache="$DEMO_DIR/.state/npm-cache"
if [ ! -x "$BUN_BIN" ]; then
  npm install --prefix "$DEMO_DIR/.tools/bun" bun@1.4.2
fi
if [ ! -f "${NATS_CREDS:-$DEMO_DIR/.state/agent-openrouter.creds}" ]; then
  python3 "$DEMO_DIR/scripts/bootstrap.py"
fi
(cd "$DEMO_DIR/agents/openrouter" && npm ci --ignore-scripts)
echo "OpenRouter agent prepared. Set OPENROUTER_API_KEY before starting it."
