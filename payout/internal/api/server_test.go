package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthOmitsWalletAndBalances(t *testing.T) {
	s := &Server{Version: "test"}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	s.Router().ServeHTTP(rr, req)
	if rr.Code != 200 {
		t.Fatalf("status %d", rr.Code)
	}
	var out map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if out["ok"] != true {
		t.Fatalf("ok=%v", out["ok"])
	}
	if out["status"] != "up" {
		t.Fatalf("status=%v", out["status"])
	}
	if out["version"] != "test" {
		t.Fatalf("version=%v", out["version"])
	}
	if _, ok := out["uptime_s"]; !ok {
		t.Fatal("missing uptime_s")
	}
	for _, leak := range []string{"from", "usdc", "eth_wei", "balance"} {
		if _, ok := out[leak]; ok {
			t.Fatalf("health leaked field %q", leak)
		}
	}
}

func TestGetPayoutRequiresHMAC(t *testing.T) {
	s := &Server{Secret: "test-secret"}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/payouts/missing", nil)
	s.Router().ServeHTTP(rr, req)
	if rr.Code != 401 {
		t.Fatalf("unauthenticated status %d want 401", rr.Code)
	}

	// Wrong signature must also fail before store lookup.
	rr2 := httptest.NewRecorder()
	req2 := httptest.NewRequest(http.MethodGet, "/v1/payouts/missing", nil)
	req2.Header.Set("X-Symp-Signature", "deadbeef")
	s.Router().ServeHTTP(rr2, req2)
	if rr2.Code != 401 {
		t.Fatalf("bad signature status %d want 401", rr2.Code)
	}
}
func TestPayoutHMACRejectsEmptySecret(t *testing.T) {
	s := &Server{Secret: ""}
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/payouts/x", nil)
	s.Router().ServeHTTP(rr, req)
	if rr.Code != 503 {
		t.Fatalf("status %d want 503", rr.Code)
	}
}
