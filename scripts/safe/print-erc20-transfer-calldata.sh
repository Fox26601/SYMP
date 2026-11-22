#!/usr/bin/env bash
# Print ERC-20 transfer(to, amount) calldata for Safe Transaction Builder.
# Does not send transactions.
#
# Usage:
#   TO=0x... AMOUNT_WEI=1000000000000000000 ./scripts/safe/print-erc20-transfer-calldata.sh
# Optional: SYMP_TOKEN=0x... (printed as suggested Safe "To" address)
set -euo pipefail

TO="${TO:-}"
AMOUNT_WEI="${AMOUNT_WEI:-}"

if [ -z "$TO" ] || [ -z "$AMOUNT_WEI" ]; then
  echo "Usage: TO=0xRecipient AMOUNT_WEI=... [SYMP_TOKEN=0xToken] $0" >&2
  echo "Example: TO=0x0000000000000000000000000000000000000001 AMOUNT_WEI=1 $0" >&2
  exit 1
fi

if [[ ! "$TO" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo "ERROR: TO must be a 20-byte hex address" >&2
  exit 1
fi
if [[ ! "$AMOUNT_WEI" =~ ^[0-9]+$ ]]; then
  echo "ERROR: AMOUNT_WEI must be an unsigned decimal integer" >&2
  exit 1
fi

# transfer(address,uint256) selector = 0xa9059cbb
data=$(TO="$TO" AMOUNT_WEI="$AMOUNT_WEI" python3 - <<'PY'
import os
to = os.environ["TO"][2:].lower()
amount = int(os.environ["AMOUNT_WEI"])
print("0xa9059cbb" + to.rjust(64, "0") + format(amount, "064x"))
PY
)

echo "=== ERC-20 transfer calldata (dry-run) ==="
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
echo "Decoded intent: transfer($TO, $AMOUNT_WEI)"
echo "Sign with 2-of-3 owners in Safe{Wallet}. This script did not broadcast."
