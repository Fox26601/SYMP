package api

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

func SignBody(secret string, body []byte) string {
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

func ValidSignature(secret, header string, body []byte) bool {
	want := SignBody(secret, body)
	got := strings.TrimSpace(strings.TrimPrefix(header, "sha256="))
	return hmac.Equal([]byte(want), []byte(got))
}
