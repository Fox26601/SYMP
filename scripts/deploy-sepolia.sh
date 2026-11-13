#!/usr/bin/env bash
# Deploy SymbolicPleasures + SeedSale on Base Sepolia. Records addresses under .deploy/sepolia.env
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/check-agent-secrets.sh
cd contracts
export SYMP_RECIPIENT="${SYMP_RECIPIENT:-$(cast wallet address --private-key "$PRIVATE_KEY")}"
export SYMP_TREASURY="${SYMP_TREASURY:-$SYMP_RECIPIENT}"
echo "Deployer/recipient=$SYMP_RECIPIENT"

VERIFY_ARGS=()
if [ -n "${BASESCAN_API_KEY:-}" ]; then
  VERIFY_ARGS+=(--verify --etherscan-api-key "$BASESCAN_API_KEY")
fi

forge script script/Deploy.s.sol --rpc-url "$BASE_SEPOLIA_RPC_URL" --broadcast "${VERIFY_ARGS[@]}" | tee /tmp/symp-deploy.log

# Best-effort parse token address from broadcast; operator may set SYMP_TOKEN manually.
if [ -z "${SYMP_TOKEN:-}" ]; then
  SYMP_TOKEN="$(rg -o 'SymbolicPleasures\s+(0x[a-fA-F0-9]+)' /tmp/symp-deploy.log -r '$1' | tail -1 || true)"
fi
: "${SYMP_TOKEN:?Set SYMP_TOKEN from deploy log}"
: "${USDC_TOKEN:?Set USDC_TOKEN (Base Sepolia USDC or MockUSDC)}"

export SEED_START="${SEED_START:-$(date -u -d '1 minute' +%s 2>/dev/null || python3 -c 'import time;print(int(time.time())+60)')}"
export SEED_END="${SEED_END:-$(date -u -d '7 days' +%s 2>/dev/null || python3 -c 'import time;print(int(time.time())+7*86400)')}"
export SYMP_TOKEN USDC_TOKEN

forge script script/DeploySeed.s.sol --rpc-url "$BASE_SEPOLIA_RPC_URL" --broadcast "${VERIFY_ARGS[@]}" | tee /tmp/symp-seed.log
if [ -z "${SEED_SALE:-}" ]; then
  SEED_SALE="$(rg -o 'SeedSale\s+(0x[a-fA-F0-9]+)' /tmp/symp-seed.log -r '$1' | tail -1 || true)"
fi
: "${SEED_SALE:?Set SEED_SALE from deploy log}"

mkdir -p "$ROOT/.deploy"
cat > "$ROOT/.deploy/sepolia.env" <<EOF
BASE_SEPOLIA_RPC_URL=$BASE_SEPOLIA_RPC_URL
SYMP_TOKEN=$SYMP_TOKEN
USDC_TOKEN=$USDC_TOKEN
SEED_SALE=$SEED_SALE
SEED_START=$SEED_START
SEED_END=$SEED_END
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_RPC_URL=$BASE_SEPOLIA_RPC_URL
NEXT_PUBLIC_SYMP=$SYMP_TOKEN
NEXT_PUBLIC_USDC=$USDC_TOKEN
NEXT_PUBLIC_SEED_SALE=$SEED_SALE
NEXT_PUBLIC_SEED_START=$SEED_START
NEXT_PUBLIC_SEED_END=$SEED_END
EOF
echo "Wrote $ROOT/.deploy/sepolia.env"
