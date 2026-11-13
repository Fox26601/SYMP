# Runbook

## Agent secrets (Sepolia)

Add to the Cloud Agent / host environment (never commit):

| Name | Required |
|------|----------|
| `PRIVATE_KEY` | yes (deployer) |
| `BASE_SEPOLIA_RPC_URL` | yes |
| `BASESCAN_API_KEY` | optional (verify) |
| `USDC_TOKEN` | yes for SeedSale (Base Sepolia USDC or Mock) |
| `VERCEL_TOKEN` | for Preview env |
| `FLY_API_TOKEN` | for payout host |

Check: `./scripts/check-agent-secrets.sh`

## 1. Waitlist (now → 2028)

1. Deploy landing to Vercel (`landing/` root). Live: https://symp-six.vercel.app
2. Upstash / Vercel KV (`KV_REST_API_*`) for durable waitlist.
3. Export waitlist from KV / `.data/waitlist.json` before seed.
4. **Production** seed window stays `1861920000`–`1862956799` (2029-01-01 … 2029-01-12 UTC). Do not change Production timestamps for Sepolia demos.

## 2. Testnet (Base Sepolia)

1. Fund deployer with Sepolia ETH + test USDC.
2. `./scripts/deploy-sepolia.sh` (writes `.deploy/sepolia.env`).
3. Or manual: `forge script script/Deploy.s.sol` then `DeploySeed.s.sol` with open `SEED_START`/`SEED_END`.
4. Preview landing: `./scripts/vercel-preview-sepolia.sh` (Preview only).
5. Contribute: `./scripts/testnet-smoke.sh` — record Basescan tx links.

## 3. Host `symp-payout` (Fly)

```bash
cd payout
fly apps create symp-payout   # once
fly volumes create symp_payout_data --region iad --size 1
fly secrets set \
  HMAC_SECRET=… \
  ONCHAIN_RPC_URL=… \
  ONCHAIN_CHAIN_ID=8453 \
  PAYOUT_PRIVATE_KEY=… \
  CALLBACK_URL=https://yoursite.com/webhooks/symp \
  SYMP_TOKEN=… USDC_TOKEN=… UNISWAP_SWAP_ROUTER=… UNISWAP_QUOTER_V2=…
fly deploy
curl -sS https://symp-payout.fly.dev/health
```

Share `HMAC_SECRET` with HornyFans as `SYMP_PAYOUT_HMAC_SECRET`; set `SYMP_PAYOUT_BASE_URL`.

Local smoke without Fly:

```bash
cd payout && HMAC_SECRET=dev HTTP_ADDR=:8088 go run ./cmd/symp-payout &
curl -sS http://127.0.0.1:8088/health
```

## 4. Mainnet seed (owner only) — 2029

1. Deploy token + SeedSale on Base with **production** timestamps (`SEED_START=1861920000`, `SEED_END=1862956799`).
2. Verify on Basescan; update Vercel **Production** `NEXT_PUBLIC_*` addresses only (keep waitlist until window opens).
3. After soft cap or end: `finalize`, `withdrawUSDC`, `reclaimUnsold`.
4. `CreatePool.s.sol` near $0.001 — **double-check token0/token1** and `SQRT_PRICE_X96`.
5. Export waitlist; UI disclaimer: settlement as available, no yield promise.

## 5. Settle USD IOUs + live rail

1. Fund payout hot wallet from seed USDC / Ops.
2. HornyFans admin → **SYMP accruals** → Settle batch (`external_id=symp_accrual:{id}`).
3. Confirm webhook marks rows `settled`.
4. Set HornyFans `TOKEN_PAYOUT_RAIL=symp` for **new** withdrawals only after pool + payout healthy.
5. Monitor `/health`; top up USDC.

See also: `docs/HORNYFANS_ACCRUAL.md`, `docs/TESTNET.md`, `docs/TOKENOMICS.md`.
