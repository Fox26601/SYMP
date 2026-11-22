#!/usr/bin/env bash
# Transfer tokenomics buckets from deployer balance after SeedSale funding (100M already in sale).
# Defaults (18 decimals): Liquidity 500M, Treasury 300M, Ops 100M.
# Mainnet refuses without CONFIRM_MAINNET=1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"
export SYMP_ROOT="$ROOT"
symp_resolve_network || exit $?
symp_mainnet_gate "fund tokenomics buckets" || exit $?
symp_load_deploy_env

# Amounts in wei (ether units). Override via env if needed.
LIQUIDITY_AMOUNT="${LIQUIDITY_AMOUNT:-500000000000000000000000000}" # 500M
TREASURY_AMOUNT="${TREASURY_AMOUNT:-300000000000000000000000000}"   # 300M
OPS_AMOUNT="${OPS_AMOUNT:-100000000000000000000000000}"             # 100M

LIQUIDITY_WALLET="${LIQUIDITY_WALLET:-}"
TREASURY_WALLET="${TREASURY_WALLET:-${SYMP_TREASURY:-}}"
OPS_WALLET="${OPS_WALLET:-}"

if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
  echo "CHECK-ONLY: fund buckets on NETWORK=$NETWORK"
  echo "  LIQUIDITY_WALLET=${LIQUIDITY_WALLET:-unset} amount=$LIQUIDITY_AMOUNT"
  echo "  TREASURY_WALLET=${TREASURY_WALLET:-unset} amount=$TREASURY_AMOUNT"
  echo "  OPS_WALLET=${OPS_WALLET:-unset} amount=$OPS_AMOUNT"
  exit 0
fi

: "${PRIVATE_KEY:?}"
: "${RPC_URL:?}"
: "${SYMP_TOKEN:?}"

transfer() {
  local to="$1" amount="$2" label="$3"
  if [ -z "$to" ]; then
    echo "SKIP $label (wallet unset)"
    return 0
  fi
  echo "== transfer $label → $to ($amount) =="
  cast send "$SYMP_TOKEN" "transfer(address,uint256)" "$to" "$amount" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
}

transfer "$LIQUIDITY_WALLET" "$LIQUIDITY_AMOUNT" "Liquidity"
transfer "$TREASURY_WALLET" "$TREASURY_AMOUNT" "Treasury"
transfer "$OPS_WALLET" "$OPS_AMOUNT" "Ops"

echo "Fund done. Update docs/ADDRESSES.md bucket rows when wallets are final."
