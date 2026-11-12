#!/usr/bin/env bash
# Smoke helpers for Base Sepolia (requires cast, forge, funded key).
set -euo pipefail
: "${BASE_SEPOLIA_RPC_URL:?}"
: "${PRIVATE_KEY:?}"
: "${SYMP_TOKEN:?}"
: "${USDC_TOKEN:?}"
: "${SEED_SALE:?}"

AMOUNT_USDC="${1:-10000000}" # 10 USDC default

echo "== approve USDC =="
cast send "$USDC_TOKEN" "approve(address,uint256)" "$SEED_SALE" "$AMOUNT_USDC" \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY"

echo "== contribute =="
cast send "$SEED_SALE" "contribute(uint256)" "$AMOUNT_USDC" \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY"

FROM=$(cast wallet address --private-key "$PRIVATE_KEY")
echo "== SYMP balance of $FROM =="
cast call "$SYMP_TOKEN" "balanceOf(address)(uint256)" "$FROM" --rpc-url "$BASE_SEPOLIA_RPC_URL"
