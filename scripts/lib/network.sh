#!/usr/bin/env bash
# Shared network selection + mainnet gate for promote scripts.
# Usage: source "$(dirname "$0")/lib/network.sh"  OR  source "$ROOT/scripts/lib/network.sh"
#
# NETWORK=sepolia|mainnet (default: sepolia)
# CONFIRM_MAINNET=1 required for any mainnet broadcast / secret cutover / fund.

symp_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing command: $1" >&2
    return 1
  }
}

symp_resolve_network() {
  NETWORK="${NETWORK:-sepolia}"
  case "$NETWORK" in
    sepolia|base-sepolia|84532)
      NETWORK=sepolia
      CHAIN_ID=84532
      RPC_URL="${BASE_SEPOLIA_RPC_URL:-${RPC_URL:-}}"
      DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-.deploy/sepolia.env}"
      FLY_APP_DEFAULT="${FLY_APP_STAGING:-symp-payout}"
      ;;
    mainnet|base|8453)
      NETWORK=mainnet
      CHAIN_ID=8453
      RPC_URL="${BASE_RPC_URL:-${RPC_URL:-}}"
      DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-.deploy/mainnet.env}"
      FLY_APP_DEFAULT="${FLY_APP_PROD:-symp-payout-prod}"
      ;;
    *)
      echo "ERROR: NETWORK must be sepolia or mainnet (got: $NETWORK)" >&2
      return 1
      ;;
  esac
  FLY_APP="${FLY_APP:-$FLY_APP_DEFAULT}"
  export NETWORK CHAIN_ID RPC_URL DEPLOY_ENV_FILE FLY_APP
}

# Refuse mainnet work unless operator sets CONFIRM_MAINNET=1.
# Returns 2 when refused. Callers should: symp_mainnet_gate "…" || exit $?
symp_mainnet_gate() {
  local action="${1:-mainnet operation}"
  if [ "${NETWORK:-}" != "mainnet" ]; then
    return 0
  fi
  if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
    echo "CHECK-ONLY: would require CONFIRM_MAINNET=1 for: $action"
    return 0
  fi
  if [ "${CONFIRM_MAINNET:-}" != "1" ]; then
    echo "REFUSED: $action on mainnet requires CONFIRM_MAINNET=1" >&2
    echo "  This gate blocks deploy, verify broadcast, CreatePool, fund, and Fly/HF cutover." >&2
    echo "  Sepolia: NETWORK=sepolia (default). No mainnet spend without explicit confirm." >&2
    return 2
  fi
  echo "GATE OK: CONFIRM_MAINNET=1 — proceeding with: $action"
}

symp_load_deploy_env() {
  local root="${SYMP_ROOT:-.}"
  local f="$root/$DEPLOY_ENV_FILE"
  if [ -f "$f" ]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
    echo "Loaded $f"
  fi
}

symp_uniswap_defaults() {
  # USDC: set USDC_TOKEN from env / .deploy / docs/ADDRESSES.md (not hardcoded here).
  if [ "$NETWORK" = "sepolia" ]; then
    export UNISWAP_V3_FACTORY="${UNISWAP_V3_FACTORY:-0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24}"
    export UNISWAP_NPM="${UNISWAP_NPM:-0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2}"
    export UNISWAP_SWAP_ROUTER="${UNISWAP_SWAP_ROUTER:-0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4}"
    export UNISWAP_QUOTER_V2="${UNISWAP_QUOTER_V2:-0xC5290058841028F1614F3A6F0F5816cAd0df5E27}"
  else
    export UNISWAP_V3_FACTORY="${UNISWAP_V3_FACTORY:-0x33128a8fC17869897dcE68Ed026d694621f6FDfD}"
    export UNISWAP_NPM="${UNISWAP_NPM:-0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1}"
    export UNISWAP_SWAP_ROUTER="${UNISWAP_SWAP_ROUTER:-0x2626664c2603336E57B271c5C0b26F421741e481}"
    export UNISWAP_QUOTER_V2="${UNISWAP_QUOTER_V2:-0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a}"
  fi
}

symp_refuse_mainnet_on_staging_fly() {
  if [ "$NETWORK" = "mainnet" ] && [ "$FLY_APP" = "${FLY_APP_STAGING:-symp-payout}" ]; then
    if [ "${SYMP_CHECK_ONLY:-0}" = "1" ]; then
      echo "CHECK-ONLY: would refuse mainnet secrets on staging Fly app '$FLY_APP'"
      return 0
    fi
    echo "REFUSED: mainnet secrets must not go on staging Fly app '$FLY_APP'." >&2
    echo "  Use FLY_APP=${FLY_APP_PROD:-symp-payout-prod} (or set FLY_APP_PROD)." >&2
    return 2
  fi
}
