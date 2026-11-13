# Enable `TOKEN_PAYOUT_RAIL=symp`

Do **not** enable until all of:

1. Base mainnet CreatePool live and quoteable.
2. `symp-payout` `/health` green with USDC + ETH balances.
3. HornyFans `SYMP_PAYOUT_BASE_URL` + `SYMP_PAYOUT_HMAC_SECRET` set.
4. Backlog `symp_accrual` rows settled (or consciously deferred).

Then set HornyFans:

```
TOKEN_PAYOUT_RAIL=symp
```

Default / prod until then: `nowpayments`. New token withdrawals use the rail; historical IOUs stay on the admin settle path.
