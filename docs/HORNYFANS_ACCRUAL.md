# HornyFans ↔ SYMP USD accrual

HornyFans records **USD IOUs** (`symp_accrual.usd_minor`) when creators earn platform tokens. Settlement after Base mainnet CreatePool:

1. Fund payout hot wallet (USDC + ETH).
2. Admin → **SYMP accruals** → Settle batch (or one).
3. Payout service market-buys SYMP and sends to creator `0x`.
4. Webhook `external_id=symp_accrual:{uuid}` → row `settled`.
5. Only then set HornyFans `TOKEN_PAYOUT_RAIL=symp` for **new** withdrawals (IOU path remains for backlog).

See HornyFans `docs/operations/SYMP_USD_ACCRUAL.md`.
