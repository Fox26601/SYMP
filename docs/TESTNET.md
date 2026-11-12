# Base Sepolia testnet deploy

Goal: deploy token + SeedSale, exercise contribute, record Basescan links. Production timestamps stay `1861920000`–`1862956799`; for UI/tests override seed window via env.

## Prerequisites

- Sepolia ETH on deployer
- Base Sepolia USDC (Circle faucet or mint mock if using `MockUSDC` from tests)
- `BASE_SEPOLIA_RPC_URL`, `PRIVATE_KEY`, optional `BASESCAN_API_KEY`

## Steps

```bash
cd contracts
export BASE_SEPOLIA_RPC_URL=…
export PRIVATE_KEY=0x…
export SYMP_RECIPIENT=$(cast wallet address --private-key $PRIVATE_KEY)
export SYMP_TREASURY=$SYMP_RECIPIENT

forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
# note SYMP token address from broadcast logs → SYMP_TOKEN=

export SYMP_TOKEN=0x…
export USDC_TOKEN=0x…   # Base Sepolia USDC or MockUSDC you deployed
export SEED_START=$(date -u -d '1 minute' +%s)   # open soon for smoke
export SEED_END=$(date -u -d '7 days' +%s)

forge script script/DeploySeed.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
# note SeedSale address → SEED_SALE=
```

Fund SeedSale with 100M SYMP (DeploySeed should transfer if script does; otherwise):

```bash
cast send $SYMP_TOKEN "transfer(address,uint256)" $SEED_SALE 100000000000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Approve + contribute (10 USDC = 10_000_000 units @ 6 decimals):

```bash
cast send $USDC_TOKEN "approve(address,uint256)" $SEED_SALE 10000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $SEED_SALE "contribute(uint256)" 10000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Landing preview

Vercel Preview or local:

```
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_RPC_URL=$BASE_SEPOLIA_RPC_URL
NEXT_PUBLIC_SYMP=$SYMP_TOKEN
NEXT_PUBLIC_USDC=$USDC_TOKEN
NEXT_PUBLIC_SEED_SALE=$SEED_SALE
NEXT_PUBLIC_SEED_START=$SEED_START
NEXT_PUBLIC_SEED_END=$SEED_END
```

Record: token tx, SeedSale tx, contribute tx (Basescan Sepolia).

## Note on mainnet window

Mainnet SeedSale **must** use plan constants `start=1861920000`, `end=1862956799`. Do not leave testnet-open timestamps on Base mainnet.
