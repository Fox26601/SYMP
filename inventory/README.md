# SYMP inventory policy (skeleton)

Treasury **liquidity inventory** dry-run engine. Separate from `payout/` (C′ / Fly settle).

- Policy knobs: `config/policy.example.yaml`
- Evaluator: `internal/policy`
- CLI: `cmd/symp-inventory-dryrun` — prints a plan JSON, **no chain writes**

Canonical policy: project doc `symp-inventory-policy.md` (ops store). Framing: treasury ops / liquidity management — not C′ creator payout, not airdrop/pump.

```bash
cd inventory
go test ./...
go run ./cmd/symp-inventory-dryrun \
  -policy config/policy.example.yaml \
  -signals fixtures/signals.example.json
```

`execution_mode: live` is refused by this skeleton.
