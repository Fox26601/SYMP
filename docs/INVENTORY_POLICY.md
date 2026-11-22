# Treasury inventory / TWAP-style release (skeleton)

Ops-facing concrete policy lives in the project store doc `symp-inventory-policy.md` (Phase 6). This repo ships a **dry-run** implementation only:

| Path | Purpose |
|------|---------|
| `inventory/config/policy.example.yaml` | Caps, depth/demand knobs, Safe envelope placeholders |
| `inventory/cmd/symp-inventory-dryrun` | Evaluate fixtures → plan JSON |
| `inventory/internal/policy` | Deterministic mode: `PAUSE` / `ADD_LP` / `TWAP_RELEASE` / `HOLD` |

**Not C′ payout.** Do not wire this module to HMAC settle or treasury→creator `transfer`.

**No mainnet execution** in this skeleton (`execution_mode: dry_run` only).
