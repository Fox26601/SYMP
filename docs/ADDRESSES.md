# Address registry

Canonical chain → address map for landing `NEXT_PUBLIC_*` and contract scripts.
Update this file **after** Basescan verify. Do not invent mainnet addresses.

**No mainnet spend from this registry alone.** Mainnet deploy scripts require `CONFIRM_MAINNET=1`.

## Base Sepolia (`84532`)

| Role | Address | Notes |
|------|---------|-------|
| SYMP token | `0x94F2a91c17f61A89C758dCbc4f31670f12CEBd64` | [Basescan](https://sepolia.basescan.org/address/0x94F2a91c17f61A89C758dCbc4f31670f12CEBd64) |
| SeedSale | `0x328712acC177834a95E8F899cE693F3694200771` | [Basescan](https://sepolia.basescan.org/address/0x328712acC177834a95E8F899cE693F3694200771) |
| USDC | `[REDACTED]` | Circle Base Sepolia USDC <!-- pragma: allowlist secret --> |
| SYMP/USDC pool (0.3%) | `0xa6d4E2e5650C03f8449433f1dF950447ABAEBb46` | Created via CreatePool smoke |
| Deployer / recipient | `0xeD9E9fC3A1610CF4524907f86f99d443A14e5Ee9` | Ops EOA (test) |
| Payout hot wallet | `0x56F6a3dC1E841536c171C35DeC9953a68892acfd` | Limited float (test) |
| Uniswap v3 Factory | `0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24` | Base Sepolia |
| NonfungiblePositionManager | `0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2` | Base Sepolia |
| SwapRouter02 | `0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4` | Base Sepolia |
| QuoterV2 | `0xC5290058841028F1614F3A6F0F5816cAd0df5E27` | Base Sepolia |

Local artifact (gitignored): `.deploy/sepolia.env` from `./scripts/deploy-sepolia.sh`.

## Base mainnet (`8453`) — TBD

| Role | Address | Notes |
|------|---------|-------|
| SYMP token | `TBD` | After gated deploy + verify |
| SeedSale | `TBD` | Production window `1861920000`–`1862956799` only |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | Circle native USDC on Base <!-- pragma: allowlist secret --> |
| SYMP/USDC pool (0.3%) | `TBD` | After gated CreatePool |
| Deployer / recipient | `TBD` | Prefer Safe / hardware |
| Treasury bucket | `TBD` | 30% / 300M |
| Liquidity bucket | `TBD` | 50% / 500M |
| Ops bucket | `TBD` | 10% / 100M |
| Payout hot wallet | `TBD` | Limited float only |
| Uniswap v3 Factory | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | Base |
| NonfungiblePositionManager | `0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1` | Base |
| SwapRouter02 | `0x2626664c2603336E57B271c5C0b26F421741e481` | Base |
| QuoterV2 | `0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a` | Base |
