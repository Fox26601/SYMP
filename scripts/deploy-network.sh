#!/usr/bin/env bash
# Deploy SymbolicPleasures + SeedSale. Default NETWORK=sepolia.
# Mainnet refuses without CONFIRM_MAINNET=1. Never spends without broadcast intent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"
export SYMP_ROOT="$ROOT"
symp_resolve_network || exit $?
symp_mainnet_gate "deploy SYMP + SeedSale" || exit $?
symp_uniswap_defaults

if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
  echo "CHECK-ONLY: skip forge broadcast for NETWORK=$NETWORK"
  exit 0
fi

: "${PRIVATE_KEY:?PRIVATE_KEY required}"
: "${RPC_URL:?RPC_URL / BASE_SEPOLIA_RPC_URL / BASE_RPC_URL required}"

cd "$ROOT/contracts"
export SYMP_RECIPIENT="${SYMP_RECIPIENT:-$(cast wallet address --private-key "$PRIVATE_KEY")}"
export SYMP_TREASURY="${SYMP_TREASURY:-$SYMP_RECIPIENT}"
echo "Deployer/recipient=$SYMP_RECIPIENT NETWORK=$NETWORK CHAIN_ID=$CHAIN_ID"

if [ "$NETWORK" = "mainnet" ]; then
  export SEED_START="${SEED_START:-1861920000}"
  export SEED_END="${SEED_END:-1862956799}"
  if [ "$SEED_START" != "1861920000" ] || [ "$SEED_END" != "1862956799" ]; then
    echo "REFUSED: mainnet SeedSale must use production timestamps 1861920000–1862956799" >&2
    exit 2
  fi
else
  export SEED_START="${SEED_START:-$(date -u -d '1 minute' +%s 2>/dev/null || python3 -c 'import time;print(int(time.time())+60)')}"
  export SEED_END="${SEED_END:-$(date -u -d '7 days' +%s 2>/dev/null || python3 -c 'import time;print(int(time.time())+7*86400)')}"
fi

VERIFY_ARGS=()
if [ -n "${BASESCAN_API_KEY:-}" ]; then
  VERIFY_ARGS+=(--verify --etherscan-api-key "$BASESCAN_API_KEY")
fi

forge script script/Deploy.s.sol \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  "${VERIFY_ARGS[@]}" | tee /tmp/symp-deploy.log

if [ -z "${SYMP_TOKEN:-}" ]; then
  SYMP_TOKEN="$(rg -o 'SymbolicPleasures\s+(0x[a-fA-F0-9]+)' /tmp/symp-deploy.log -r '$1' | tail -1 || true)"
fi
: "${SYMP_TOKEN:?Set SYMP_TOKEN from deploy log}"
: "${USDC_TOKEN:?Set USDC_TOKEN}"

export SYMP_TOKEN USDC_TOKEN SEED_START SEED_END
forge script script/DeploySeed.s.sol \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  "${VERIFY_ARGS[@]}" | tee /tmp/symp-seed.log

if [ -z "${SEED_SALE:-}" ]; then
  SEED_SALE="$(rg -o 'SeedSale\s+(0x[a-fA-F0-9]+)' /tmp/symp-seed.log -r '$1' | tail -1 || true)"
fi
: "${SEED_SALE:?Set SEED_SALE from deploy log}"

mkdir -p "$ROOT/.deploy"
OUT="$ROOT/$DEPLOY_ENV_FILE"
cat > "$OUT" <<EOF
NETWORK=$NETWORK
CHAIN_ID=$CHAIN_ID
RPC_URL=$RPC_URL
SYMP_TOKEN=$SYMP_TOKEN
USDC_TOKEN=$USDC_TOKEN
SEED_SALE=$SEED_SALE
SEED_START=$SEED_START
SEED_END=$SEED_END
NEXT_PUBLIC_CHAIN_ID=$CHAIN_ID
NEXT_PUBLIC_RPC_URL=$RPC_URL
NEXT_PUBLIC_SYMP=$SYMP_TOKEN
NEXT_PUBLIC_USDC=$USDC_TOKEN
NEXT_PUBLIC_SEED_SALE=$SEED_SALE
NEXT_PUBLIC_SEED_START=$SEED_START
NEXT_PUBLIC_SEED_END=$SEED_END
EOF
echo "Wrote $OUT"
echo "Update docs/ADDRESSES.md after Basescan verify."
