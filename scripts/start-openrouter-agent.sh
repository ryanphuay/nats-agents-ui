#!/usr/bin/env bash
set -euo pipefail
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUN_BIN="${BUN_BIN:-$DEMO_DIR/.tools/bun/node_modules/.bin/bun}"
if [ -z "${OPENROUTER_API_KEY:-}" ] && [ -f "$DEMO_DIR/.state/openrouter-api-key" ]; then
  export OPENROUTER_API_KEY="$(cat "$DEMO_DIR/.state/openrouter-api-key")"
fi
: "${OPENROUTER_API_KEY:?Set OPENROUTER_API_KEY or save it in .state/openrouter-api-key}"
export NATS_URL="${NATS_URL:-nats://127.0.0.1:15222}"
export NATS_CREDS="${NATS_CREDS:-$DEMO_DIR/.state/agent-openrouter.creds}"
if [ ! -x "$BUN_BIN" ] || [ ! -d "$DEMO_DIR/agents/openrouter/node_modules" ] || [ ! -f "$NATS_CREDS" ]; then
  "$DEMO_DIR/scripts/prepare-openrouter-agent.sh"
fi
exec "$BUN_BIN" "$DEMO_DIR/agents/openrouter/index.ts"
