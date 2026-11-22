// Package policy evaluates treasury inventory release decisions.
// It never sends transactions; live execution is out of scope for this skeleton.
package policy

import (
	"fmt"
	"math/big"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// Mode is the deterministic inventory decision for one evaluation tick.
type Mode string

const (
	ModePause       Mode = "PAUSE"
	ModeAddLP       Mode = "ADD_LP"
	ModeTWAPRelease Mode = "TWAP_RELEASE"
	ModeHold        Mode = "HOLD"
)

// Policy is the canonical knob set (see docs/symp-inventory-policy.md).
type Policy struct {
	PolicyVersion  string `yaml:"policy_version"`
	ExecutionMode  string `yaml:"execution_mode"`
	ChainID        int64  `yaml:"chain_id"`
	TWAPWindowSec  int64  `yaml:"twap_window_sec"`
	Caps           Caps   `yaml:"caps"`
	Demand         Demand `yaml:"demand"`
	Depth          Depth  `yaml:"depth"`
	Floors         Floors `yaml:"floors"`
	Envelope       EnvCfg `yaml:"envelope"`
	Identity       Ident  `yaml:"identity"`
}

type Caps struct {
	DailyReleaseSYMP  string `yaml:"daily_release_symp"`
	WeeklyReleaseSYMP string `yaml:"weekly_release_symp"`
	MaxSliceSYMP      string `yaml:"max_slice_symp"`
	SliceIntervalSec  int64  `yaml:"slice_interval_sec"`
	MaxPoolImpactBPS  int64  `yaml:"max_pool_impact_bps"`
}

type Demand struct {
	MinVolume1hUSD     string `yaml:"min_volume_1h_usd"`
	MinVolume24hUSD    string `yaml:"min_volume_24h_usd"`
	MinTWAPPremiumBPS  int64  `yaml:"min_twap_premium_bps"`
	MaxTWAPPremiumBPS  int64  `yaml:"max_twap_premium_bps"`
}

type Depth struct {
	SLOUSD       string `yaml:"slo_usd"`
	CeilingUSD   string `yaml:"ceiling_usd"`
	BandBPS      int64  `yaml:"band_bps"`
	MinAbsorbUSD string `yaml:"min_absorb_usd"`
}

type Floors struct {
	ReserveFloorSYMP string `yaml:"reserve_floor_symp"`
}

type EnvCfg struct {
	SYMP string `yaml:"symp"`
	USDC string `yaml:"usdc"`
}

type Ident struct {
	Service            string `yaml:"service"`
	SeparateFromPayout bool   `yaml:"separate_from_payout"`
}

// Signals are read-only market / treasury inputs for one tick.
// Human-unit SYMP/USDC/USD strings are used for dry-run clarity.
type Signals struct {
	PoolDepthUSD            string `json:"pool_depth_usd"`
	SpotVsTWAPBPS           int64  `json:"spot_vs_twap_bps"`
	Volume1hUSD             string `json:"volume_1h_usd"`
	Volume24hUSD            string `json:"volume_24h_usd"`
	NetCreatorSellUSD24h    string `json:"net_creator_sell_usd_24h"`
	TreasuryFreeSYMP        string `json:"treasury_free_symp"`
	EnvelopeRemainingSYMP   string `json:"envelope_remaining_symp"`
	EnvelopeRemainingUSDC   string `json:"envelope_remaining_usdc"`
	ReleasedTodaySYMP       string `json:"released_today_symp"`
	ReleasedWeekSYMP        string `json:"released_week_symp"`
	KillSwitch              bool   `json:"kill_switch"`
	OracleOK                bool   `json:"oracle_ok"`
}

// Plan is the dry-run / evaluation result. TxHash is always empty in dry-run.
type Plan struct {
	Mode              Mode     `json:"mode"`
	PolicyVersion     string   `json:"policy_version"`
	ExecutionMode     string   `json:"execution_mode"`
	ChainID           int64    `json:"chain_id"`
	Reason            string   `json:"reason"`
	PlannedSYMP       string   `json:"planned_symp,omitempty"`
	PlannedUSDC       string   `json:"planned_usdc,omitempty"`
	SliceCount        int      `json:"slice_count,omitempty"`
	SliceIntervalSec  int64    `json:"slice_interval_sec,omitempty"`
	ImpactBPSEst      int64    `json:"impact_bps_est,omitempty"`
	CapsRemainingDay  string   `json:"caps_remaining_day_symp,omitempty"`
	CapsRemainingWeek string   `json:"caps_remaining_week_symp,omitempty"`
	EnvelopeLeftSYMP  string   `json:"envelope_remaining_symp,omitempty"`
	DryRun            bool     `json:"dry_run"`
	NotCPrimePayout   bool     `json:"not_c_prime_payout"`
	TxHash            *string  `json:"tx_hash"` // always null in skeleton
	Notes             []string `json:"notes,omitempty"`
}

// LoadYAML reads a policy file.
func LoadYAML(data []byte) (*Policy, error) {
	var p Policy
	if err := yaml.Unmarshal(data, &p); err != nil {
		return nil, fmt.Errorf("parse policy yaml: %w", err)
	}
	if p.ExecutionMode == "" {
		p.ExecutionMode = "dry_run"
	}
	if p.Identity.Service == "" {
		p.Identity.Service = "symp-inventory"
	}
	if !p.Identity.SeparateFromPayout {
		return nil, fmt.Errorf("identity.separate_from_payout must be true")
	}
	return &p, nil
}

// AssertDryRunDefault refuses live unless explicitly allowed via env.
func (p *Policy) AssertDryRunDefault() error {
	mode := strings.ToLower(strings.TrimSpace(p.ExecutionMode))
	if mode == "" || mode == "dry_run" {
		return nil
	}
	if mode == "live" && os.Getenv("SYMP_INVENTORY_ALLOW_LIVE") == "1" {
		return fmt.Errorf("live mode is not implemented in this skeleton (no chain execution)")
	}
	return fmt.Errorf("execution_mode=%q refused: skeleton is dry-run only (set execution_mode: dry_run)", p.ExecutionMode)
}

// Evaluate returns a deterministic inventory plan. Never submits txs.
func Evaluate(p *Policy, s Signals) (*Plan, error) {
	if p == nil {
		return nil, fmt.Errorf("nil policy")
	}
	plan := &Plan{
		PolicyVersion:   p.PolicyVersion,
		ExecutionMode:   p.ExecutionMode,
		ChainID:         p.ChainID,
		DryRun:          true,
		NotCPrimePayout: true,
		TxHash:          nil,
		Notes: []string{
			"NOT C′ payout: inventory must not call payout HMAC or treasury→creator transfer",
			"skeleton: no SendTransaction path",
		},
	}

	if s.KillSwitch {
		plan.Mode = ModePause
		plan.Reason = "kill_switch"
		return plan, nil
	}
	if !s.OracleOK {
		plan.Mode = ModePause
		plan.Reason = "oracle_not_ok"
		return plan, nil
	}

	dailyCap, err := parseDecimal(p.Caps.DailyReleaseSYMP)
	if err != nil {
		return nil, fmt.Errorf("daily cap: %w", err)
	}
	weeklyCap, err := parseDecimal(p.Caps.WeeklyReleaseSYMP)
	if err != nil {
		return nil, fmt.Errorf("weekly cap: %w", err)
	}
	maxSlice, err := parseDecimal(p.Caps.MaxSliceSYMP)
	if err != nil {
		return nil, fmt.Errorf("max slice: %w", err)
	}
	floor, err := parseDecimal(p.Floors.ReserveFloorSYMP)
	if err != nil {
		return nil, fmt.Errorf("reserve floor: %w", err)
	}
	free, err := parseDecimal(s.TreasuryFreeSYMP)
	if err != nil {
		return nil, fmt.Errorf("treasury free: %w", err)
	}
	envSYMP, err := parseDecimal(s.EnvelopeRemainingSYMP)
	if err != nil {
		return nil, fmt.Errorf("envelope symp: %w", err)
	}
	envUSDC, err := parseDecimal(s.EnvelopeRemainingUSDC)
	if err != nil {
		return nil, fmt.Errorf("envelope usdc: %w", err)
	}
	releasedDay, err := parseDecimal(defaultZero(s.ReleasedTodaySYMP))
	if err != nil {
		return nil, err
	}
	releasedWeek, err := parseDecimal(defaultZero(s.ReleasedWeekSYMP))
	if err != nil {
		return nil, err
	}

	dayLeft := subNonNeg(dailyCap, releasedDay)
	weekLeft := subNonNeg(weeklyCap, releasedWeek)
	plan.CapsRemainingDay = formatDec(dayLeft)
	plan.CapsRemainingWeek = formatDec(weekLeft)
	plan.EnvelopeLeftSYMP = formatDec(envSYMP)

	if free.Cmp(floor) < 0 {
		plan.Mode = ModePause
		plan.Reason = "treasury_below_reserve_floor"
		return plan, nil
	}
	if envSYMP.Sign() <= 0 {
		plan.Mode = ModePause
		plan.Reason = "envelope_symp_empty"
		return plan, nil
	}
	if dayLeft.Sign() <= 0 || weekLeft.Sign() <= 0 {
		plan.Mode = ModePause
		plan.Reason = "release_caps_exhausted"
		return plan, nil
	}

	vol1h, err := parseDecimal(s.Volume1hUSD)
	if err != nil {
		return nil, err
	}
	vol24h, err := parseDecimal(s.Volume24hUSD)
	if err != nil {
		return nil, err
	}
	min1h, err := parseDecimal(p.Demand.MinVolume1hUSD)
	if err != nil {
		return nil, err
	}
	min24h, err := parseDecimal(p.Demand.MinVolume24hUSD)
	if err != nil {
		return nil, err
	}
	depth, err := parseDecimal(s.PoolDepthUSD)
	if err != nil {
		return nil, err
	}
	slo, err := parseDecimal(p.Depth.SLOUSD)
	if err != nil {
		return nil, err
	}
	ceiling, err := parseDecimal(p.Depth.CeilingUSD)
	if err != nil {
		return nil, err
	}
	minAbsorb, err := parseDecimal(p.Depth.MinAbsorbUSD)
	if err != nil {
		return nil, err
	}

	demandOK := vol1h.Cmp(min1h) >= 0 && vol24h.Cmp(min24h) >= 0
	depthLow := depth.Cmp(slo) < 0
	depthOKAbsorb := depth.Cmp(minAbsorb) >= 0
	premium := s.SpotVsTWAPBPS

	// Headroom above floor for any release/add.
	headroom := new(big.Rat).Sub(free, floor)
	if headroom.Sign() <= 0 {
		plan.Mode = ModePause
		plan.Reason = "no_headroom_above_floor"
		return plan, nil
	}

	if depthLow && demandOK && envUSDC.Sign() > 0 && premium <= p.Demand.MaxTWAPPremiumBPS {
		if depth.Cmp(ceiling) >= 0 {
			plan.Mode = ModeHold
			plan.Reason = "depth_at_or_above_ceiling"
			return plan, nil
		}
		// Size toward SLO gap, capped by envelope / headroom / daily.
		gap := new(big.Rat).Sub(slo, depth)
		if gap.Sign() < 0 {
			gap = big.NewRat(0, 1)
		}
		// Rough: 1 USD depth gap ≈ 1 SYMP at $1 reference for dry-run sizing only.
		size := minRats(gap, envSYMP, headroom, dayLeft, weekLeft, maxSlice)
		if size.Sign() <= 0 {
			plan.Mode = ModeHold
			plan.Reason = "add_lp_size_zero"
			return plan, nil
		}
		usdcPair := minRats(size, envUSDC) // 1:1 USDC human for skeleton
		plan.Mode = ModeAddLP
		plan.Reason = "depth_below_slo_with_demand"
		plan.PlannedSYMP = formatDec(size)
		plan.PlannedUSDC = formatDec(usdcPair)
		plan.ImpactBPSEst = 0
		return plan, nil
	}

	if demandOK && depthOKAbsorb &&
		premium >= p.Demand.MinTWAPPremiumBPS &&
		premium <= p.Demand.MaxTWAPPremiumBPS {
		size := minRats(maxSlice, envSYMP, headroom, dayLeft, weekLeft)
		if size.Sign() <= 0 {
			plan.Mode = ModeHold
			plan.Reason = "twap_size_zero"
			return plan, nil
		}
		// Crude impact estimate: size / depth * 10000 bps, capped reporting.
		impact := int64(0)
		if depth.Sign() > 0 {
			ratio := new(big.Rat).Quo(size, depth)
			bps := new(big.Rat).Mul(ratio, big.NewRat(10000, 1))
			impact = ratToInt64Floor(bps)
		}
		if impact > p.Caps.MaxPoolImpactBPS {
			// Shrink once to impact limit.
			if depth.Sign() > 0 && p.Caps.MaxPoolImpactBPS > 0 {
				lim := new(big.Rat).Mul(depth, big.NewRat(p.Caps.MaxPoolImpactBPS, 10000))
				size = minRats(size, lim)
				impact = p.Caps.MaxPoolImpactBPS
			}
			if size.Sign() <= 0 || impact > p.Caps.MaxPoolImpactBPS {
				plan.Mode = ModePause
				plan.Reason = "impact_circuit_breaker"
				plan.ImpactBPSEst = impact
				return plan, nil
			}
		}
		slices := 1
		if p.Caps.SliceIntervalSec > 0 && size.Cmp(maxSlice) > 0 {
			// Cap already applied via maxSlice in minRats; keep single planned batch meta.
			slices = 1
		}
		// If daily room >> max slice, report how many slices until day cap (informational).
		if maxSlice.Sign() > 0 {
			n := new(big.Rat).Quo(minRats(dayLeft, weekLeft, envSYMP, headroom), maxSlice)
			slices = int(ratToInt64Floor(n))
			if slices < 1 {
				slices = 1
			}
			if slices > 48 {
				slices = 48
			}
		}
		plan.Mode = ModeTWAPRelease
		plan.Reason = "demand_ok_depth_absorbs"
		plan.PlannedSYMP = formatDec(size)
		plan.SliceCount = slices
		plan.SliceIntervalSec = p.Caps.SliceIntervalSec
		plan.ImpactBPSEst = impact
		return plan, nil
	}

	plan.Mode = ModeHold
	if !demandOK {
		plan.Reason = "demand_below_floor"
	} else if depthLow {
		plan.Reason = "depth_low_but_no_usdc_or_premium_out_of_band"
	} else {
		plan.Reason = "no_action_needed"
	}
	return plan, nil
}

func defaultZero(s string) string {
	if strings.TrimSpace(s) == "" {
		return "0"
	}
	return s
}

func parseDecimal(s string) (*big.Rat, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, fmt.Errorf("empty decimal")
	}
	r := new(big.Rat)
	if _, ok := r.SetString(s); !ok {
		return nil, fmt.Errorf("invalid decimal %q", s)
	}
	return r, nil
}

func formatDec(r *big.Rat) string {
	if r == nil {
		return "0"
	}
	return r.FloatString(6)
}

func subNonNeg(a, b *big.Rat) *big.Rat {
	out := new(big.Rat).Sub(a, b)
	if out.Sign() < 0 {
		return big.NewRat(0, 1)
	}
	return out
}

func minRats(vals ...*big.Rat) *big.Rat {
	if len(vals) == 0 {
		return big.NewRat(0, 1)
	}
	m := new(big.Rat).Set(vals[0])
	for _, v := range vals[1:] {
		if v.Cmp(m) < 0 {
			m.Set(v)
		}
	}
	return m
}

func ratToInt64Floor(r *big.Rat) int64 {
	if r == nil {
		return 0
	}
	f, _ := new(big.Float).SetRat(r).Int64()
	return f
}
