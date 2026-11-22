# Safe script stubs

Dry-run helpers for Phase 2 custody. **No broadcasting. No mainnet spend.**

| Script | Purpose |
|--------|---------|
| `create-safe-checklist.sh` | Ceremony + dual-Safe create checklist; optional env echo |
| `print-erc20-transfer-calldata.sh` | `transfer(address,uint256)` calldata for Safe UI |
| `print-erc20-approve-calldata.sh` | `approve(address,uint256)` calldata for Fly envelope |

Operator SOP: [`docs/SAFE_CUSTODY.md`](../../docs/SAFE_CUSTODY.md).

Create and sign real Safe txs in [Safe{Wallet}](https://app.safe.global) (Sepolia practice OK; mainnet only after explicit gate).
