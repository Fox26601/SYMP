package api

import "testing"

func TestSignAndValid(t *testing.T) {
	secret := "test-secret"
	body := []byte(`{"external_id":"x"}`)
	sig := SignBody(secret, body)
	if !ValidSignature(secret, sig, body) {
		t.Fatal("expected valid")
	}
	if !ValidSignature(secret, "sha256="+sig, body) {
		t.Fatal("expected valid with prefix")
	}
	if ValidSignature(secret, "deadbeef", body) {
		t.Fatal("expected invalid")
	}
}
