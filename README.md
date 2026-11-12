# SymbolicPleasures (SYMP)

Side project: ERC-20 on **Base**, seed sale **1–12 Jan 2029 UTC**, Vercel landing (waitlist → seed), Uniswap v3 pool, and a Go payout service that buys SYMP for creators.

> **Not investment advice.** Contributing USDC is high risk. No company / no MiCA licence — read `docs/LEGAL.md`.

## Layout

```
contracts/   Foundry — SymbolicPleasures, SeedSale, CreatePool
landing/     Next.js — pitch, tokenomics, waitlist, seed UI → Vercel
payout/      Go — HMAC API, Uniswap swap payouts
docs/        Tokenomics, runbooks, HornyFans API
```

## Quick start

### Contracts

```bash
cd contracts
forge test -vv
```

Deploy (owner key, testnet first):

```bash
forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
# set SYMP_TOKEN / USDC_TOKEN then:
forge script script/DeploySeed.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

### Landing

```bash
cd landing
cp .env.example .env.local
npm install
npm run dev
```

Vercel: import `Fox26601/SYMP`, **Root Directory = `landing`**, Production Branch `main`.

Until `2029-01-01` the site is **Waitlist** only (no USDC). Seed UI activates automatically in the window.

### Payout service

```bash
cd payout
go test ./...
go run ./cmd/symp-payout
```

See `.env.example` and `docs/HORNYFANS_API.md`.

## Seed parameters

| Param | Value |
|-------|-------|
| Price | 1000 SYMP = 1 USDC |
| Soft / hard | $2,000 / $10,000 |
| Min / max wallet | $10 / $500 |
| Start | 2029-01-01 00:00:00 UTC (`1861920000`) |
| End | 2029-01-12 23:59:59 UTC (`1862956799`) |

## Docs

- `docs/TOKENOMICS.md` — supply buckets and seed params
- `docs/RUNBOOK.md` — waitlist → seed → pool → payout
- `docs/TESTNET.md` — Base Sepolia deploy + contribute smoke
- `docs/HORNYFANS_API.md` — HMAC payout API for HornyFans
- `docs/LEGAL.md` — disclaimers

## GitHub

Intended remote: `https://github.com/Fox26601/SYMP`

If the empty repo does not exist yet, create it on GitHub, then:

```bash
cd /path/to/SYMP
git remote add origin git@github.com:Fox26601/SYMP.git
git push -u origin main
```

Vercel: Root Directory `landing`, Production Branch `main`.
