#!/usr/bin/env bash
set -euo pipefail
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export KUBECONFIG="$DEMO_DIR/kubeconfig"
python3 "$DEMO_DIR/scripts/bootstrap.py"
"$DEMO_DIR/scripts/build-agent-images.sh"
kubectl create namespace nats-demo --dry-run=client -o yaml | kubectl apply -f -
for identity in agent-web agent-echo; do
  kubectl -n nats-demo create secret generic "demo-$identity" \
    --from-file="nats.creds=$DEMO_DIR/.state/$identity.creds" \
    --dry-run=client -o yaml | kubectl apply -f -
done
helm upgrade --install nats-agents-demo "$DEMO_DIR" --namespace nats-demo \
  -f "$DEMO_DIR/.state/auth-values.json" --wait --timeout 5m
kubectl -n nats-demo rollout restart deployment/agent-web-ui deployment/agent-echo
kubectl -n nats-demo rollout status deployment/agent-web-ui --timeout=2m
kubectl -n nats-demo rollout status deployment/agent-echo --timeout=2m
