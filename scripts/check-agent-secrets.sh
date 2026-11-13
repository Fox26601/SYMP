#!/usr/bin/env bash
# Exit 0 when deploy secrets present; print missing names otherwise.
set -euo pipefail
missing=0
need() {
  local n="$1"
  if [ -z "${!n:-}" ]; then
    echo "MISSING $n"
    missing=1
  else
    echo "OK $n"
  fi
}
need PRIVATE_KEY
need BASE_SEPOLIA_RPC_URL
if [ -n "${BASESCAN_API_KEY:-}" ]; then echo "OK BASESCAN_API_KEY"; else echo "OPTIONAL BASESCAN_API_KEY"; fi
if [ -n "${VERCEL_TOKEN:-}" ]; then echo "OK VERCEL_TOKEN"; else echo "OPTIONAL VERCEL_TOKEN"; fi
if [ -n "${FLY_API_TOKEN:-}" ]; then echo "OK FLY_API_TOKEN"; else echo "OPTIONAL FLY_API_TOKEN"; fi
exit "$missing"
