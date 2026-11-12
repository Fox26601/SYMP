# HornyFans integration API

Payout service base URL example: `https://payout.example.com`

## Auth

HMAC-SHA256 of raw body, hex, header `X-Symp-Signature` (optional `sha256=` prefix). Shared `HMAC_SECRET`.

## Endpoints

### `GET /v1/quote?usd_minor=2000`

Returns estimated SYMP out for USD cents.

### `POST /v1/payouts`

```json
{ "external_id": "token_withdrawal:uuid", "usd_minor": 2000, "to_address": "0x..." }
```

Idempotent on `external_id`.

### `GET /v1/payouts/{id}`

Status: `queued` | `submitted` | `completed` | `failed`.

### Webhook `CALLBACK_URL`

POST JSON + `X-Symp-Signature` when status becomes `completed` or `failed`.

## HornyFans wiring

Env on HornyFans:

```
TOKEN_PAYOUT_RAIL=symp
SYMP_PAYOUT_BASE_URL=https://payout.example.com
SYMP_PAYOUT_HMAC_SECRET=<same as HMAC_SECRET>
CALLBACK_URL=https://yoursite.com/webhooks/symp   # on payout service
```

Approve path calls `POST /v1/payouts` instead of NOWPayments when `TOKEN_PAYOUT_RAIL=symp`. Webhook `POST /webhooks/symp` maps status → `token_withdrawal` completed/failed (+ refund on failure). Creators store ticker `symp` and a Base `0x` address.
