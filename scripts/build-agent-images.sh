#!/usr/bin/env bash
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$DEMO_DIR/.state/sources"
export DOCKER_CONFIG="$DEMO_DIR/.state/docker-config"
AGENTS_COMMIT=ed2bf3076fc82b54667607a83f6a3fc354acb5c4
LABS_COMMIT=bbc1057d3182006305b1641870d9d6cc6684eeb6
WEB_IMAGE=synadia-agent-web-ui:ed2bf30-focused1
ECHO_IMAGE=synadia-agent-echo:bbc1057

mkdir -p "$SOURCE_DIR" "$DOCKER_CONFIG"

checkout() {
  local repository="$1"
  local commit="$2"
  local destination="$3"
  local source_path="$4"
  if [ ! -d "$destination/.git" ]; then
    git clone --filter=blob:none --no-checkout "$repository" "$destination"
  fi
  git -C "$destination" fetch --depth 1 origin "$commit"
  git -C "$destination" sparse-checkout set "$source_path"
  git -C "$destination" checkout --detach "$commit"
}

if ! docker image inspect "$WEB_IMAGE" >/dev/null 2>&1; then
  checkout https://github.com/synadia-ai/synadia-agents.git "$AGENTS_COMMIT" "$SOURCE_DIR/synadia-agents" examples/agent-web-ui
  python3 "$DEMO_DIR/scripts/patch-agent-web.py" "$SOURCE_DIR/synadia-agents"
  docker build -f "$DEMO_DIR/images/agent-web-ui.Dockerfile" -t "$WEB_IMAGE" "$SOURCE_DIR/synadia-agents"
fi

if ! docker image inspect "$ECHO_IMAGE" >/dev/null 2>&1; then
  checkout https://github.com/synadia-ai/synadia-agents-labs.git "$LABS_COMMIT" "$SOURCE_DIR/synadia-agents-labs" typescript/agent/01-echo
  docker build -f "$DEMO_DIR/images/echo-agent.Dockerfile" -t "$ECHO_IMAGE" \
    "$SOURCE_DIR/synadia-agents-labs/typescript/agent/01-echo"
fi

kind load docker-image --name nats-agents-demo "$WEB_IMAGE" "$ECHO_IMAGE"
