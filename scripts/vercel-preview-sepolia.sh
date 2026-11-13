#!/usr/bin/env bash
# Push Sepolia NEXT_PUBLIC_* to Vercel Preview env (not Production).
# Requires: VERCEL_TOKEN, and either .deploy/sepolia.env or env vars set.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${VERCEL_TOKEN:?}"
if [ -f "$ROOT/.deploy/sepolia.env" ]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT/.deploy/sepolia.env"; set +a
fi
: "${NEXT_PUBLIC_SYMP:?}"
: "${NEXT_PUBLIC_USDC:?}"
: "${NEXT_PUBLIC_SEED_SALE:?}"
: "${NEXT_PUBLIC_RPC_URL:?}"
: "${NEXT_PUBLIC_SEED_START:?}"
: "${NEXT_PUBLIC_SEED_END:?}"

cd "$ROOT/landing"
npx --yes vercel@latest link --yes --token "$VERCEL_TOKEN" || true

set_preview() {
  local key="$1" val="$2"
  echo "Setting Preview $key"
  printf '%s' "$val" | npx --yes vercel@latest env add "$key" preview --token "$VERCEL_TOKEN" --force || \
    printf '%s' "$val" | npx --yes vercel@latest env add "$key" preview --token "$VERCEL_TOKEN" || true
}

set_preview NEXT_PUBLIC_CHAIN_ID "${NEXT_PUBLIC_CHAIN_ID:-84532}"
set_preview NEXT_PUBLIC_RPC_URL "$NEXT_PUBLIC_RPC_URL"
set_preview NEXT_PUBLIC_SYMP "$NEXT_PUBLIC_SYMP"
set_preview NEXT_PUBLIC_USDC "$NEXT_PUBLIC_USDC"
set_preview NEXT_PUBLIC_SEED_SALE "$NEXT_PUBLIC_SEED_SALE"
set_preview NEXT_PUBLIC_SEED_START "$NEXT_PUBLIC_SEED_START"
set_preview NEXT_PUBLIC_SEED_END "$NEXT_PUBLIC_SEED_END"

echo "Preview env updated. Redeploy a Preview deployment to pick up values."
echo "Do NOT change Production seed timestamps (2029 window)."
