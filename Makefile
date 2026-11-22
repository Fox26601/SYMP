# SYMP promote / check targets.
# Default NETWORK=sepolia. Mainnet targets refuse unless CONFIRM_MAINNET=1.
#
# Examples:
#   make check
#   make deploy NETWORK=sepolia
#   make promote NETWORK=mainnet          # refuses without CONFIRM_MAINNET=1
#   make promote NETWORK=mainnet CONFIRM_MAINNET=1   # explicit gate
#   make check-only create-pool NETWORK=mainnet      # dry probe (no broadcast)

NETWORK ?= sepolia
CONFIRM_MAINNET ?=
export NETWORK CONFIRM_MAINNET

SCRIPTS := scripts
CHECK_ONLY ?= 0
export SYMP_CHECK_ONLY=$(CHECK_ONLY)

.PHONY: help check promote \
	deploy verify create-pool fund fly-secrets hf-flags \
	deploy-sepolia gate-demo \
	check-deploy check-verify check-create-pool check-fund check-fly-secrets check-hf-flags

help:
	@echo "SYMP Makefile — NETWORK=$(NETWORK)"
	@echo "  make check              readiness (no broadcast)"
	@echo "  make deploy             deploy token + SeedSale"
	@echo "  make verify             Basescan verify"
	@echo "  make create-pool        Uniswap CreatePool"
	@echo "  make fund               fund Liquidity/Treasury/Ops wallets"
	@echo "  make fly-secrets        set Fly app secrets"
	@echo "  make hf-flags           HF flag checklist (no rail flip)"
	@echo "  make promote            check → deploy → verify → create-pool → fund → fly → hf"
	@echo "  make check-deploy|check-verify|…  dry probe (SYMP_CHECK_ONLY=1)"
	@echo "  make gate-demo          prove mainnet refuses without CONFIRM_MAINNET=1"
	@echo "Mainnet requires CONFIRM_MAINNET=1. Staging Fly ≠ prod (see docs/ADDRESSES.md)."

check:
	@$(SCRIPTS)/promote-check.sh

deploy:
	@$(SCRIPTS)/deploy-network.sh

verify:
	@$(SCRIPTS)/verify-contracts.sh

create-pool:
	@$(SCRIPTS)/create-pool.sh

fund:
	@$(SCRIPTS)/fund-buckets.sh

fly-secrets:
	@$(SCRIPTS)/fly-secrets.sh

hf-flags:
	@$(SCRIPTS)/hf-flags.sh

check-deploy check-verify check-create-pool check-fund check-fly-secrets check-hf-flags:
	@$(MAKE) CHECK_ONLY=1 $(patsubst check-%,%,$@)

# Full promote path. Stops at mainnet gate inside each script.
promote: check
	@$(SCRIPTS)/deploy-network.sh
	@$(SCRIPTS)/verify-contracts.sh
	@$(SCRIPTS)/create-pool.sh
	@$(SCRIPTS)/fund-buckets.sh
	@$(SCRIPTS)/fly-secrets.sh
	@HF_FLAGS_APPLY=1 $(SCRIPTS)/hf-flags.sh

deploy-sepolia:
	@$(SCRIPTS)/deploy-sepolia.sh

gate-demo:
	@$(SCRIPTS)/gate-demo.sh
