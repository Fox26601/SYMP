#!/usr/bin/env bash
# Run CreatePool.s.sol (Uniswap v3 0.3% + optional LP mint).
# Mainnet refuses without CONFIRM_MAINNET=1. Requires SQRT_PRICE_X96 + SYMP_LP_AMOUNT.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"
export SYMP_ROOT="$ROOT"
symp_resolve_network || exit $?
symp_mainnet_gate "CreatePool + LP mint" || exit $?
symp_load_deploy_env
symp_uniswap_defaults

export USDC_LP_AMOUNT="${USDC_LP_AMOUNT:-0}"

if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
  echo "CHECK-ONLY: would CreatePool NETWORK=$NETWORK SYMP=${SYMP_TOKEN:-unset} USDC=${USDC_TOKEN:-unset}"
  echo "  SQRT_PRICE_X96=${SQRT_PRICE_X96:-unset} SYMP_LP_AMOUNT=${SYMP_LP_AMOUNT:-unset} USDC_LP_AMOUNT=$USDC_LP_AMOUNT"
  exit 0
fi

: "${PRIVATE_KEY:?}"
: "${RPC_URL:?}"
: "${SYMP_TOKEN:?}"
: "${USDC_TOKEN:?}"
: "${UNISWAP_V3_FACTORY:?}"
: "${UNISWAP_NPM:?}"
: "${SQRT_PRICE_X96:?Set SQRT_PRICE_X96 (verify token0/token1 order before mainnet)}"
: "${SYMP_LP_AMOUNT:?Set SYMP_LP_AMOUNT}"

export UNISWAP_V3_FACTORY UNISWAP_NPM SYMP_TOKEN USDC_TOKEN SQRT_PRICE_X96 SYMP_LP_AMOUNT

cd "$ROOT/contracts"
forge script script/CreatePool.s.sol \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast | tee /tmp/symp-pool.log

POOL="$(rg -o 'pool\s+(0x[a-fA-F0-9]+)' /tmp/symp-pool.log -r '$1' | tail -1 || true)"
if [ -n "$POOL" ]; then
  mkdir -p "$ROOT/.deploy"
  {
    echo "POOL=$POOL"
    echo "UNISWAP_V3_FACTORY=$UNISWAP_V3_FACTORY"
    echo "UNISWAP_NPM=$UNISWAP_NPM"
    echo "UNISWAP_SWAP_ROUTER=$UNISWAP_SWAP_ROUTER"
    echo "UNISWAP_QUOTER_V2=$UNISWAP_QUOTER_V2"
  } >> "$ROOT/$DEPLOY_ENV_FILE"
  echo "Appended POOL=$POOL to $ROOT/$DEPLOY_ENV_FILE"
  echo "Record pool in docs/ADDRESSES.md after confirm."
fi
