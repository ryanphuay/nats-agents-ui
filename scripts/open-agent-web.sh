#!/usr/bin/env bash
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec kubectl --kubeconfig "$DEMO_DIR/kubeconfig" -n nats-demo \
  port-forward service/agent-web-ui 3300:3300
