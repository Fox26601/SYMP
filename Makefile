# SYMP public build / deploy helpers.
# Default NETWORK=sepolia. Mainnet targets refuse unless CONFIRM_MAINNET=1.
#
# Examples:
#   make deploy NETWORK=sepolia
#   make gate-demo
#   make deploy NETWORK=mainnet CONFIRM_MAINNET=1

NETWORK ?= sepolia
CONFIRM_MAINNET ?=
export NETWORK CONFIRM_MAINNET

SCRIPTS := scripts
CHECK_ONLY ?= 0
export SYMP_CHECK_ONLY=$(CHECK_ONLY)

.PHONY: help deploy verify create-pool fund \
	deploy-sepolia gate-demo \
	check-deploy check-verify check-create-pool check-fund \
	fly-secrets hf-flags promote check

help:
	@echo "SYMP Makefile — NETWORK=$(NETWORK)"
	@echo "  make deploy             deploy token + SeedSale"
	@echo "  make verify             Basescan verify"
	@echo "  make create-pool        Uniswap CreatePool"
	@echo "  make fund               fund Liquidity/Treasury/Ops wallets"
	@echo "  make check-deploy|…     dry probe (SYMP_CHECK_ONLY=1)"
	@echo "  make gate-demo          prove mainnet refuses without CONFIRM_MAINNET=1"
	@echo "Mainnet requires CONFIRM_MAINNET=1."
	@echo "Private Fly/HF/promote ops live outside this public repo."

deploy:
	@$(SCRIPTS)/deploy-network.sh

verify:
	@$(SCRIPTS)/verify-contracts.sh

create-pool:
	@$(SCRIPTS)/create-pool.sh

fund:
	@$(SCRIPTS)/fund-buckets.sh

check-deploy check-verify check-create-pool check-fund:
	@$(MAKE) CHECK_ONLY=1 $(patsubst check-%,%,$@)

deploy-sepolia:
	@$(SCRIPTS)/deploy-sepolia.sh

gate-demo:
	@$(SCRIPTS)/gate-demo.sh

# Private-ops targets removed from the public tree.
fly-secrets hf-flags promote check:
	@echo "moved private: $@ is not published in this repo"
	@exit 1
