#!/usr/bin/env bash
# HornyFans feature-flag checklist for SYMP promote.
# Never auto-sets TOKEN_PAYOUT_RAIL=symp. Mainnet "apply" mode needs CONFIRM_MAINNET=1.
#
# Usage:
#   ./scripts/hf-flags.sh              # print checklist (safe)
#   HF_FLAGS_APPLY=1 ./scripts/hf-flags.sh   # gated; still refuses rail flip
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/network.sh
source "$ROOT/scripts/lib/network.sh"
export SYMP_ROOT="$ROOT"
symp_resolve_network || exit $?
symp_load_deploy_env

PAYOUT_BASE_URL="${SYMP_PAYOUT_BASE_URL:-https://${FLY_APP}.fly.dev}"

echo "== HornyFans SYMP flags (NETWORK=$NETWORK) =="
echo
echo "Recommended env (HornyFans host — set manually / via HF deploy secrets):"
echo "  SYMP_PAYOUT_BASE_URL=$PAYOUT_BASE_URL"
echo "  SYMP_PAYOUT_HMAC_SECRET=<same as Fly HMAC_SECRET>"
echo
echo "Flags:"
echo "  [keep] TOKEN_PAYOUT_RAIL=nowpayments   # default until ENABLE_RAIL checklist"
echo "  [never auto] TOKEN_PAYOUT_RAIL=symp    # human flip only — see docs/ENABLE_RAIL.md"
echo
if [ "$NETWORK" = "sepolia" ]; then
  echo "Staging / Sepolia:"
  echo "  - Accrual settle → Fly OK for smoke"
  echo "  - C′ reserve shadow optional"
  echo "  - Do not enable rail for production users"
else
  echo "Mainnet promote (after pool + Fly /health + /v1/quote):"
  echo "  1. Accrual settle path on"
  echo "  2. Optional C′ shadow reserve writer"
  echo "  3. TOKEN_PAYOUT_RAIL stays off until docs/ENABLE_RAIL.md"
fi
echo

if [ "${HF_FLAGS_APPLY:-0}" != "1" ]; then
  echo "Print-only. Set HF_FLAGS_APPLY=1 to run gated apply stub (still no rail flip)."
  exit 0
fi

symp_mainnet_gate "HF flags apply stub" || exit $?

if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
  echo "CHECK-ONLY: HF apply would record checklist; rail remains untouched"
  exit 0
fi

# This repo does not hold HornyFans deploy credentials. Record intent only.
mkdir -p "$ROOT/.deploy"
cat >> "$ROOT/$DEPLOY_ENV_FILE" <<EOF
# hf-flags $(date -u +%Y-%m-%dT%H:%M:%SZ) NETWORK=$NETWORK
SYMP_PAYOUT_BASE_URL=$PAYOUT_BASE_URL
TOKEN_PAYOUT_RAIL_INTENT=nowpayments
HF_RAIL_FLIP=forbidden_by_promote
EOF

echo "Recorded payout URL intent in $ROOT/$DEPLOY_ENV_FILE"
echo "REFUSED automatic TOKEN_PAYOUT_RAIL=symp (by design)."
echo "Operator must flip rail only after docs/ENABLE_RAIL.md."
