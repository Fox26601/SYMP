#!/usr/bin/env bash
# Re-verify deployed contracts on Basescan (read constructor from broadcast when possible).
# Mainnet: CONFIRM_MAINNET=1 required (API verify is cheap but keeps promote path gated).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"
export SYMP_ROOT="$ROOT"
symp_resolve_network || exit $?
symp_mainnet_gate "verify contracts on Basescan" || exit $?
symp_load_deploy_env
symp_uniswap_defaults

if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
  echo "CHECK-ONLY: would verify SYMP_TOKEN=${SYMP_TOKEN:-unset} SEED_SALE=${SEED_SALE:-unset} on chain $CHAIN_ID"
  exit 0
fi

: "${RPC_URL:?RPC_URL required}"
: "${SYMP_TOKEN:?SYMP_TOKEN required}"
: "${BASESCAN_API_KEY:?BASESCAN_API_KEY required for verify}"

cd "$ROOT/contracts"
# Prefer forge verify via last broadcast when present; else operator-supplied addresses.
if [ -d broadcast ]; then
  echo "Attempting forge verify from broadcast artifacts…"
  forge verify-contract "$SYMP_TOKEN" src/SymbolicPleasures.sol:SymbolicPleasures \
    --chain-id "$CHAIN_ID" \
    --etherscan-api-key "$BASESCAN_API_KEY" \
    --watch || true
  if [ -n "${SEED_SALE:-}" ]; then
    forge verify-contract "$SEED_SALE" src/SeedSale.sol:SeedSale \
      --chain-id "$CHAIN_ID" \
      --etherscan-api-key "$BASESCAN_API_KEY" \
      --watch || true
  fi
else
  echo "No contracts/broadcast — set constructor args manually if verify fails."
  forge verify-contract "$SYMP_TOKEN" src/SymbolicPleasures.sol:SymbolicPleasures \
    --chain-id "$CHAIN_ID" \
    --etherscan-api-key "$BASESCAN_API_KEY" \
    --watch
fi
echo "Verify done. Confirm links in docs/ADDRESSES.md."
