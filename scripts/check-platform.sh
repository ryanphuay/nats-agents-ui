#!/usr/bin/env bash
set -euo pipefail
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
failed=0
check() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "OK: $1"
  else
    echo "Missing executable: $1" >&2
    failed=1
  fi
}
case "$(uname -s)" in
  Darwin|Linux) ;;
  *) echo "Run this demo on macOS, Linux, or inside Windows WSL2." >&2; exit 1 ;;
esac
for tool in git docker kind kubectl helm python3 node npm; do check "$tool"; done
if [ -x "${NSC_BIN:-$DEMO_DIR/.tools/nsc}" ]; then
  echo "OK: NSC"
else
  check nsc
fi
if [ "$failed" -eq 0 ]; then
  echo "Executables found. This does not verify Docker availability, logins, or cluster health."
fi
exit "$failed"
