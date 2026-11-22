#!/usr/bin/env bash
# Readiness check for promote path (no broadcast, no Fly secret writes, no HF flips).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"
export SYMP_ROOT="$ROOT"
symp_resolve_network
symp_uniswap_defaults
symp_load_deploy_env

echo "== promote-check NETWORK=$NETWORK CHAIN_ID=$CHAIN_ID =="
echo "FLY_APP default: $FLY_APP"
echo "deploy env file: $DEPLOY_ENV_FILE"

fail=0
need_var() {
  local n="$1"
  if [ -z "${!n:-}" ]; then
    echo "MISSING $n"
    fail=1
  else
    echo "OK $n"
  fi
}

need_var PRIVATE_KEY
if [ "$NETWORK" = "sepolia" ]; then
  need_var BASE_SEPOLIA_RPC_URL
else
  need_var BASE_RPC_URL
  if [ "${CONFIRM_MAINNET:-}" = "1" ]; then
    echo "OK CONFIRM_MAINNET=1 (gate would pass)"
  else
    echo "GATE would REFUSE mainnet without CONFIRM_MAINNET=1"
  fi
fi

if [ -n "${BASESCAN_API_KEY:-}" ]; then echo "OK BASESCAN_API_KEY"; else echo "OPTIONAL BASESCAN_API_KEY"; fi
if [ -n "${FLY_API_TOKEN:-}" ]; then echo "OK FLY_API_TOKEN"; else echo "OPTIONAL FLY_API_TOKEN"; fi

# Known Sepolia registry values when env empty
if [ "$NETWORK" = "sepolia" ]; then
  SYMP_TOKEN="${SYMP_TOKEN:-0x94F2a91c17f61A89C758dCbc4f31670f12CEBd64}"
  SEED_SALE="${SEED_SALE:-0x328712acC177834a95E8F899cE693F3694200771}"
fi

for n in SYMP_TOKEN USDC_TOKEN UNISWAP_V3_FACTORY UNISWAP_NPM UNISWAP_SWAP_ROUTER UNISWAP_QUOTER_V2; do
  need_var "$n"
done

if [ "$NETWORK" = "mainnet" ]; then
  if [ "${SYMP_TOKEN:-TBD}" = "TBD" ] || [ -z "${SYMP_TOKEN:-}" ]; then
    echo "MAINNET SYMP_TOKEN still TBD in registry — deploy first after gate"
  fi
  if [ "${SEED_SALE:-TBD}" = "TBD" ] || [ -z "${SEED_SALE:-}" ]; then
    echo "MAINNET SEED_SALE still TBD"
  fi
  echo "Seed window must be SEED_START=1861920000 SEED_END=1862956799 on mainnet"
fi

echo "-- scripts present --"
for s in deploy-network.sh verify-contracts.sh create-pool.sh fund-buckets.sh fly-secrets.sh hf-flags.sh; do
  if [ -x "$ROOT/scripts/$s" ] || [ -f "$ROOT/scripts/$s" ]; then
    echo "OK scripts/$s"
  else
    echo "MISSING scripts/$s"
    fail=1
  fi
done

if [ -f "$ROOT/docs/ADDRESSES.md" ]; then
  echo "OK docs/ADDRESSES.md"
else
  echo "MISSING docs/ADDRESSES.md"
  fail=1
fi

echo "-- dry gate probe --"
SYMP_CHECK_ONLY=1 symp_mainnet_gate "promote-check probe"
SYMP_CHECK_ONLY=1 symp_refuse_mainnet_on_staging_fly

if [ "$fail" -ne 0 ]; then
  echo "promote-check FAILED"
  exit 1
fi
echo "promote-check OK (no on-chain actions)"
