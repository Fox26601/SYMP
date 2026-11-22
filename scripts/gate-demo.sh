#!/usr/bin/env bash
# Prove mainnet gate refuses without CONFIRM_MAINNET=1 (no spend).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"

export NETWORK=mainnet
export CONFIRM_MAINNET=
symp_resolve_network

set +e
symp_mainnet_gate "gate-demo"
rc=$?
set -e
if [ "$rc" -eq 2 ]; then
  echo "gate-demo OK: refused mainnet without CONFIRM_MAINNET=1 (exit 2)"
  exit 0
fi
echo "gate-demo FAILED: expected exit 2, got $rc" >&2
exit 1
