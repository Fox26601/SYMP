#!/usr/bin/env bash
# Set Fly payout secrets from deploy env. Staging (Sepolia) vs prod (mainnet) are different apps.
# Mainnet: CONFIRM_MAINNET=1 and FLY_APP must not be the staging app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"
export SYMP_ROOT="$ROOT"
symp_resolve_network || exit $?
symp_mainnet_gate "Fly secrets cutover" || exit $?
symp_refuse_mainnet_on_staging_fly || exit $?
symp_load_deploy_env
symp_uniswap_defaults

ONCHAIN_RPC_URL="${ONCHAIN_RPC_URL:-$RPC_URL}"

if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
  echo "CHECK-ONLY: would fly secrets set on app=$FLY_APP chain=$CHAIN_ID"
  echo "  SYMP_TOKEN=${SYMP_TOKEN:-unset} USDC_TOKEN=${USDC_TOKEN:-unset}"
  echo "  UNISWAP_SWAP_ROUTER=$UNISWAP_SWAP_ROUTER UNISWAP_QUOTER_V2=$UNISWAP_QUOTER_V2"
  exit 0
fi

: "${FLY_APP:?}"
: "${SYMP_TOKEN:?}"
: "${USDC_TOKEN:?}"
: "${ONCHAIN_RPC_URL:?ONCHAIN_RPC_URL or RPC_URL required}"
: "${HMAC_SECRET:?HMAC_SECRET required}"
: "${PAYOUT_PRIVATE_KEY:?PAYOUT_PRIVATE_KEY required}"
: "${CALLBACK_URL:?CALLBACK_URL required}"

symp_require_cmd fly || exit $?

echo "Setting secrets on Fly app: $FLY_APP (NETWORK=$NETWORK CHAIN_ID=$CHAIN_ID)"
fly secrets set -a "$FLY_APP" \
  "HMAC_SECRET=$HMAC_SECRET" \
  "ONCHAIN_RPC_URL=$ONCHAIN_RPC_URL" \
  "ONCHAIN_CHAIN_ID=$CHAIN_ID" \
  "PAYOUT_PRIVATE_KEY=$PAYOUT_PRIVATE_KEY" \
  "CALLBACK_URL=$CALLBACK_URL" \
  "SYMP_TOKEN=$SYMP_TOKEN" \
  "USDC_TOKEN=$USDC_TOKEN" \
  "UNISWAP_SWAP_ROUTER=$UNISWAP_SWAP_ROUTER" \
  "UNISWAP_QUOTER_V2=$UNISWAP_QUOTER_V2"

echo "Secrets set. Probe: curl -sS https://$FLY_APP.fly.dev/health"
