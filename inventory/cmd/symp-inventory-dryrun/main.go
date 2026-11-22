// Command symp-inventory-dryrun evaluates inventory policy against fixture signals.
// It never connects to a wallet or submits transactions.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/Fox26601/SYMP/inventory/internal/policy"
)

func main() {
	policyPath := flag.String("policy", "config/policy.example.yaml", "path to policy YAML")
	signalsPath := flag.String("signals", "fixtures/signals.example.json", "path to signals JSON fixture")
	flag.Parse()

	pdata, err := os.ReadFile(*policyPath)
	if err != nil {
		fail("read policy: %v", err)
	}
	p, err := policy.LoadYAML(pdata)
	if err != nil {
		fail("%v", err)
	}
	if err := p.AssertDryRunDefault(); err != nil {
		fail("%v", err)
	}

	sdata, err := os.ReadFile(*signalsPath)
	if err != nil {
		fail("read signals: %v", err)
	}
	var sig policy.Signals
	if err := json.Unmarshal(sdata, &sig); err != nil {
		fail("parse signals: %v", err)
	}

	plan, err := policy.Evaluate(p, sig)
	if err != nil {
		fail("evaluate: %v", err)
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(plan); err != nil {
		fail("encode: %v", err)
	}
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "symp-inventory-dryrun: "+format+"\n", args...)
	os.Exit(1)
}
