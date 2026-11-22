package policy

import (
	"os"
	"testing"
)

func samplePolicy() *Policy {
	return &Policy{
		PolicyVersion: "test",
		ExecutionMode: "dry_run",
		ChainID:       84532,
		Caps: Caps{
			DailyReleaseSYMP:  "50000",
			WeeklyReleaseSYMP: "200000",
			MaxSliceSYMP:      "5000",
			SliceIntervalSec:  300,
			MaxPoolImpactBPS:  25,
		},
		Demand: Demand{
			MinVolume1hUSD:    "500",
			MinVolume24hUSD:   "2000",
			MinTWAPPremiumBPS: 0,
			MaxTWAPPremiumBPS: 300,
		},
		Depth: Depth{
			SLOUSD:       "10000",
			CeilingUSD:   "50000",
			BandBPS:      200,
			MinAbsorbUSD: "5000",
		},
		Floors: Floors{ReserveFloorSYMP: "1000000"},
		Envelope: EnvCfg{
			SYMP: "100000",
			USDC: "5000",
		},
		Identity: Ident{Service: "symp-inventory", SeparateFromPayout: true},
	}
}

func TestKillSwitchPause(t *testing.T) {
	s := Signals{
		PoolDepthUSD: "3000", SpotVsTWAPBPS: 10,
		Volume1hUSD: "1000", Volume24hUSD: "5000",
		TreasuryFreeSYMP: "5000000", EnvelopeRemainingSYMP: "100000",
		EnvelopeRemainingUSDC: "5000", KillSwitch: true, OracleOK: true,
	}
	plan, err := Evaluate(samplePolicy(), s)
	if err != nil {
		t.Fatal(err)
	}
	if plan.Mode != ModePause || plan.Reason != "kill_switch" {
		t.Fatalf("got %+v", plan)
	}
	if !plan.NotCPrimePayout || !plan.DryRun || plan.TxHash != nil {
		t.Fatalf("safety flags: %+v", plan)
	}
}

func TestAddLPWhenDepthLow(t *testing.T) {
	s := Signals{
		PoolDepthUSD: "3500", SpotVsTWAPBPS: 40,
		Volume1hUSD: "1200", Volume24hUSD: "8500",
		TreasuryFreeSYMP: "5000000", EnvelopeRemainingSYMP: "100000",
		EnvelopeRemainingUSDC: "5000", OracleOK: true,
	}
	plan, err := Evaluate(samplePolicy(), s)
	if err != nil {
		t.Fatal(err)
	}
	if plan.Mode != ModeAddLP {
		t.Fatalf("want ADD_LP, got %s (%s)", plan.Mode, plan.Reason)
	}
	if plan.PlannedSYMP == "" || plan.PlannedUSDC == "" {
		t.Fatalf("missing planned sizes: %+v", plan)
	}
}

func TestTWAPWhenDepthOK(t *testing.T) {
	s := Signals{
		PoolDepthUSD: "12000", SpotVsTWAPBPS: 20,
		Volume1hUSD: "1200", Volume24hUSD: "8500",
		TreasuryFreeSYMP: "5000000", EnvelopeRemainingSYMP: "100000",
		EnvelopeRemainingUSDC: "5000", OracleOK: true,
	}
	plan, err := Evaluate(samplePolicy(), s)
	if err != nil {
		t.Fatal(err)
	}
	if plan.Mode != ModeTWAPRelease {
		t.Fatalf("want TWAP_RELEASE, got %s (%s)", plan.Mode, plan.Reason)
	}
	if plan.SliceCount < 1 {
		t.Fatalf("slice_count: %+v", plan)
	}
}

func TestDemandFloorHold(t *testing.T) {
	s := Signals{
		PoolDepthUSD: "12000", SpotVsTWAPBPS: 20,
		Volume1hUSD: "10", Volume24hUSD: "100",
		TreasuryFreeSYMP: "5000000", EnvelopeRemainingSYMP: "100000",
		EnvelopeRemainingUSDC: "5000", OracleOK: true,
	}
	plan, err := Evaluate(samplePolicy(), s)
	if err != nil {
		t.Fatal(err)
	}
	if plan.Mode != ModeHold || plan.Reason != "demand_below_floor" {
		t.Fatalf("got %+v", plan)
	}
}

func TestLoadYAMLRequiresSeparateIdentity(t *testing.T) {
	_, err := LoadYAML([]byte("execution_mode: dry_run\nidentity:\n  separate_from_payout: false\n"))
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestAssertDryRunBlocksLive(t *testing.T) {
	p := samplePolicy()
	p.ExecutionMode = "live"
	_ = os.Unsetenv("SYMP_INVENTORY_ALLOW_LIVE")
	if err := p.AssertDryRunDefault(); err == nil {
		t.Fatal("expected refuse live")
	}
}
