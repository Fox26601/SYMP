#!/usr/bin/env bash
# Print dual-Safe create + ceremony checklist. Never broadcasts.
# Usage: ./scripts/safe/create-safe-checklist.sh
set -euo pipefail

echo "=== SYMP Safe create checklist (dry-run) ==="
echo "Network practice: Base Sepolia (84532). Mainnet Base (8453) only after gate."
echo "Policy: 2-of-3 hardware wallets. Two Safes: Treasury + LP NFT."
echo

echo "--- Pre-ceremony ---"
echo "[ ] Three HW initialized; firmware current; seeds offline only"
echo "[ ] OWNER_1 / OWNER_2 / OWNER_3 public addresses recorded + witnessed"
echo "[ ] Deployer EOA and Fly PAYOUT_PRIVATE_KEY are NOT Safe owners"
echo

echo "--- Create (per Safe) ---"
echo "[ ] Safe{Wallet} → correct network"
echo "[ ] Owners = 3 HW addresses; threshold = 2"
echo "[ ] No modules/guards unless reviewed"
echo "[ ] Label: SYMP-Treasury-{chain} then SYMP-LP-{chain}"
echo "[ ] Record creation tx + Safe address"
echo

echo "--- Smoke (Sepolia OK) ---"
echo "[ ] Fund Treasury Safe with dust ETH + dust SYMP"
echo "[ ] 2-of-3 ERC-20 transfer out; Basescan confirm"
echo "[ ] Optional: print calldata via scripts/safe/print-erc20-*.sh"
echo

echo "--- Envelope (after Safe funded) ---"
echo "[ ] Choose pattern A approve / B spending limit / C queued-only"
echo "[ ] Cap DAILY_ENVELOPE_SYMP_WEI; Fly is limited spender only"
echo "[ ] Kill switch rehearsed: approve(0) or revoke delegate"
echo

echo "--- Mainnet gate ---"
echo "[ ] Explicit operator go («делай mainnet») before Base mainnet fund/transfer"
echo "[ ] No 300M move / large approve without gate"
echo

echo "--- Optional env (public addresses only) ---"
for n in OWNER_1 OWNER_2 OWNER_3 SAFE_TREASURY SAFE_LP FLY_SPENDER SYMP_TOKEN DAILY_ENVELOPE_SYMP_WEI; do
  if [ -n "${!n:-}" ]; then
    echo "SET  $n=${!n}"
  else
    echo "UNSET $n"
  fi
done

echo
echo "Done. No transactions were sent."
