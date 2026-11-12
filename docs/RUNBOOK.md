# Runbook

## 1. Waitlist (now → 2028)

1. Deploy landing to Vercel (`landing/` root).
2. Optional: attach Upstash Redis / Vercel KV (`KV_REST_API_*`) for waitlist storage; otherwise local file store on the server filesystem (not durable on serverless — use KV in production).
3. Export waitlist from KV / `.data/waitlist.json` before seed.

## 2. Testnet (Base Sepolia)

1. Fund deployer with Sepolia ETH + test USDC.
2. `forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify`
3. Set `SYMP_TOKEN`, Base Sepolia USDC, run `DeploySeed.s.sol`.
4. Point landing `NEXT_PUBLIC_*` at Sepolia addresses; for UI testing temporarily override `NEXT_PUBLIC_SEED_START` / `END` to “now”.
5. Contribute once; record tx links.

## 3. Mainnet seed (owner only)

1. Deploy token + SeedSale on Base with **production** timestamps (`1861920000`–`1862956799`).
2. Verify on Basescan.
3. Update Vercel env; keep Waitlist until 1 Jan 2029.
4. After soft cap or after end: `finalize`, `withdrawUSDC`, `reclaimUnsold`.
5. `CreatePool.s.sol` with computed `SQRT_PRICE_X96` near $0.001 — **double-check token0/token1 order**.

## 4. Payout hot wallet

1. Fund with USDC + small ETH.
2. Run `symp-payout` with HMAC secret shared with HornyFans.
3. Monitor `/health`.
