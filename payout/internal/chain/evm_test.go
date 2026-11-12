package chain

import (
	"math/big"
	"testing"
)

func TestUSDMinorToUSDC(t *testing.T) {
	got := USDMinorToUSDC(2000) // $20.00
	want := big.NewInt(20_000_000)
	if got.Cmp(want) != 0 {
		t.Fatalf("got %s want %s", got, want)
	}
}

func TestIsETHAddress(t *testing.T) {
	if !IsETHAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0") {
		t.Fatal("expected true")
	}
	if IsETHAddress("TXYZ") {
		t.Fatal("expected false")
	}
}
