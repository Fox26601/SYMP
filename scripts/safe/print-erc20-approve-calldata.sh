#!/usr/bin/env bash
# Print ERC-20 approve(spender, amount) calldata for Safe envelope setup.
# Does not send transactions.
#
# Usage:
#   SPENDER=0x... AMOUNT_WEI=... ./scripts/safe/print-erc20-approve-calldata.sh
# Revoke: AMOUNT_WEI=0
# Optional: SYMP_TOKEN=0x...
set -euo pipefail

SPENDER="${SPENDER:-${FLY_SPENDER:-}}"
AMOUNT_WEI="${AMOUNT_WEI:-}"

if [ -z "$SPENDER" ] || [ -z "$AMOUNT_WEI" ]; then
  echo "Usage: SPENDER=0xFlyEOA AMOUNT_WEI=... [SYMP_TOKEN=0xToken] $0" >&2
  echo "Revoke envelope: SPENDER=0xFlyEOA AMOUNT_WEI=0 $0" >&2
  exit 1
fi

if [[ ! "$SPENDER" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo "ERROR: SPENDER must be a 20-byte hex address" >&2
  exit 1
fi
if [[ ! "$AMOUNT_WEI" =~ ^[0-9]+$ ]]; then
  echo "ERROR: AMOUNT_WEI must be an unsigned decimal integer" >&2
  exit 1
fi

# approve(address,uint256) selector = 0x095ea7b3
data=$(SPENDER="$SPENDER" AMOUNT_WEI="$AMOUNT_WEI" python3 - <<'PY'
import os
spender = os.environ["SPENDER"][2:].lower()
amount = int(os.environ["AMOUNT_WEI"])
print("0x095ea7b3" + spender.rjust(64, "0") + format(amount, "064x"))
PY
)

echo "=== ERC-20 approve calldata (dry-run) ==="
echo "Safe UI: New transaction → Transaction Builder / Contract interaction"
if [ -n "${SYMP_TOKEN:-}" ]; then
  echo "To (token contract): $SYMP_TOKEN"
else
  echo "To (token contract): <set SYMP_TOKEN>"
fi
echo "Value (ETH): 0"
echo "Data:"
echo "$data"
echo
echo "Decoded intent: approve($SPENDER, $AMOUNT_WEI)"
if [ "$AMOUNT_WEI" = "0" ]; then
  echo "Note: AMOUNT_WEI=0 revokes the Fly/transfer envelope."
fi
echo "Sign with 2-of-3 owners in Safe{Wallet}. This script did not broadcast."
