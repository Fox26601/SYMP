# Safe custody (Phase 2)

Operator SOP for Gnosis Safe treasury + LP NFT custody on Base.  
**No irreversible mainnet spend** from this document alone. Base Sepolia practice is OK. Mainnet create/fund/transfer/approve requires an explicit operator **«делай mainnet»** gate (see store runbook + `docs/ENABLE_RAIL.md`).

Store mirror (operator RU): Project doc `symp-safe-custody-runbook.md`.

## Goals

1. Two Safes on Base (and Sepolia mirrors for practice):
   - **Treasury Safe** — ~300M SYMP bucket (C′ settle source + inventory envelopes).
   - **LP NFT Safe** — Uniswap v3 position NFT + fee harvest (when pool exists).
2. **2-of-3** hardware-wallet owners; key ceremony + rotate.
3. Fly / transfer hot key = **limited spender** only — never an EOA holding the full 300M.
4. Script stubs under `scripts/safe/` are **dry-run by default** (print checklist / calldata; no broadcast).

## Wallet roles

| Wallet | Holds | Signers |
|--------|-------|---------|
| Treasury Safe | SYMP treasury + ETH gas float | 3 HW, threshold 2 |
| LP NFT Safe | Uniswap v3 NFT, collected fees | 3 HW, threshold 2 |
| Fly / transfer EOA | Gas + session rights inside envelope | Hot key (`PAYOUT_PRIVATE_KEY`) |
| Deployer | Idle after cutover | Offline / burned |

Never: Fly key as Safe owner; deployer as long-lived treasury holder; single EOA with full bucket.

## Create Safe (Sepolia practice)

1. Initialize three hardware wallets; record **public** addresses only (`OWNER_1..3`).
2. Open [Safe{Wallet}](https://app.safe.global) → **Base Sepolia**.
3. Create Safe → owners = three addresses → threshold **2** → deploy (Sepolia ETH on one owner).
4. Repeat for a second Safe; label `SYMP-Treasury-Sepolia` / `SYMP-LP-Sepolia`.
5. Run `./scripts/safe/create-safe-checklist.sh` and fill the printed registry fields.
6. Smoke: send dust Sepolia SYMP to Treasury Safe → 2-of-3 ERC-20 transfer out → Basescan confirm.

Mainnet Base (8453): same steps **only after** mainnet gate.

## Key ceremony

1. Generate seeds **on device**; offline paper/metal backup; no cloud photos/chat.
2. Export public addresses; witness verifies screen ↔ paper ↔ Safe UI.
3. Create Safe; all three owners confirm in UI.
4. Sepolia 2-of-3 dust transfer before any mainnet funding.
5. Record ceremony date, firmware, owner set, creation txs (public data only).

### Rotate

Triggers: lost device, personnel change, suspected seed compromise, scheduled rotate.

1. Ceremony for `OWNER_NEW`.
2. Safe Settings → `swapOwner` / `addOwnerWithThreshold` / `removeOwner` (needs 2 signatures).
3. Practice on Sepolia first; mainnet only behind gate.
4. Update registry; wipe retired device per policy.
5. On compromise: revoke Fly envelope first (`approve(0)` / spending-limit reset), then rotate owner.

## Move treasury bucket to Safe

### Sepolia (allowed now)

```text
EOA_HOLDER --SYMP.transfer--> SAFE_TREASURY_SEPOLIA
Safe 2-of-3 --SYMP.transfer--> test creator 0x
```

Use `scripts/safe/print-erc20-transfer-calldata.sh` to build Safe UI calldata.

### Mainnet (gated)

1. Treasury + LP Safes live; ceremony recorded.
2. Dust ETH on Safes for gas.
3. Transfer full treasury SYMP EOA → Treasury Safe (chunk + recon if needed).
4. Recon `balanceOf(Safe)` vs tokenomics / C′ reserves.
5. Idle deployer; enable limited spender **before** mass settles.
6. After pool mint: `safeTransferFrom` LP NFT → LP Safe.

## Limited spender (Fly / C′ transfer)

Do **not** put 300M on the Fly hot wallet.

| Pattern | How | Kill switch |
|---------|-----|-------------|
| **A. ERC-20 approve envelope** (default v1) | Safe `approve(FLY_EOA, DAILY_ENVELOPE_WEI)`; Fly `transferFrom` within cap | Safe `approve(0)` |
| **B. Allowance / spending-limit module** | Delegate Fly EOA with amount + reset window | Remove delegate / module |
| **C. Queued Safe txs only** | Fly writes intents; owners sign each batch | Stop signing |

Knobs (env / registry — addresses and caps only):

| Name | Meaning |
|------|---------|
| `SAFE_TREASURY` | Treasury Safe address |
| `SAFE_LP` | LP NFT Safe address |
| `FLY_SPENDER` | Hot payout / transfer EOA |
| `DAILY_ENVELOPE_SYMP_WEI` | Max envelope |

## Mainnet gate

**Allowed without gate:** this SOP, Sepolia Safes, dry-run scripts, sealed public address registry.

**Blocked without «делай mainnet»:** mainnet Safe funding with real SYMP, large envelopes, LP NFT move with real liquidity, rail flip.

## Registry template

Copy into `.deploy/safe-registry.env` (gitignored via `.deploy/`) after ceremony:

```bash
# Public addresses only — never seeds or private keys
SAFE_TREASURY_SEPOLIA=
SAFE_LP_SEPOLIA=
SAFE_TREASURY_MAINNET=
SAFE_LP_MAINNET=
OWNER_1=
OWNER_2=
OWNER_3=
FLY_SPENDER_SEPOLIA=
FLY_SPENDER_MAINNET=
SYMP_TOKEN_SEPOLIA=0x94F2a91c17f61A89C758dCbc4f31670f12CEBd64
DAILY_ENVELOPE_SYMP_WEI=
CEREMONY_DATE=
```

## Scripts

| Script | Behavior |
|--------|----------|
| `scripts/safe/create-safe-checklist.sh` | Prints create/ceremony checklist; validates optional env; **no chain txs** |
| `scripts/safe/print-erc20-transfer-calldata.sh` | Prints `transfer(to,amount)` calldata for Safe Transaction builder |
| `scripts/safe/print-erc20-approve-calldata.sh` | Prints `approve(spender,amount)` calldata for envelope setup |

All refuse to broadcast. There is no `--broadcast` flag on these stubs.

## Incident shortcuts

| Event | Action |
|-------|--------|
| Fly key leak | Revoke allowance; rotate Fly key; halt settle |
| One HW lost | Still 2-of-3; schedule owner rotate |
| Two HW lost | Safe frozen — IR + counsel |
| Unexpected outbound | Revoke envelopes; export Safe history; recon |

## See also

- `docs/RUNBOOK.md` — waitlist → seed → pool → payout
- `docs/TOKENOMICS.md` — 300M treasury bucket
- `docs/ENABLE_RAIL.md` — rail gates
- Store: `symp-safe-custody-runbook.md`, `symp-automation-infra.md`, `symp-treasury-c-prime.md`
