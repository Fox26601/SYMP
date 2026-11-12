package api

import (
	"context"
	"encoding/json"
	"io"
	"math/big"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/Fox26601/SYMP/payout/internal/chain"
	"github.com/Fox26601/SYMP/payout/internal/store"
	"github.com/ethereum/go-ethereum/common"
	"github.com/go-chi/chi/v5"
)

type Server struct {
	Store  *store.Store
	Chain  *chain.Client
	Secret string
	MaxUSD int64
	Daily  int64
}

func (s *Server) Router() http.Handler {
	r := chi.NewRouter()
	r.Get("/health", s.health)
	r.Get("/v1/quote", s.quote)
	r.With(s.requireHMAC).Post("/v1/payouts", s.createPayout)
	r.Get("/v1/payouts/{id}", s.getPayout)
	return r
}

func (s *Server) requireHMAC(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			writeErr(w, 400, "bad_body")
			return
		}
		r.Body = io.NopCloser(strings.NewReader(string(body)))
		if s.Secret != "" && !ValidSignature(s.Secret, r.Header.Get("X-Symp-Signature"), body) {
			writeErr(w, 401, "bad_signature")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	out := map[string]any{"ok": true}
	if s.Chain != nil {
		if bal, err := s.Chain.BalanceUSDC(r.Context()); err == nil {
			out["usdc"] = bal.String()
		}
		if eth, err := s.Chain.BalanceETH(r.Context()); err == nil {
			out["eth_wei"] = eth.String()
		}
		out["from"] = s.Chain.From.Hex()
	}
	writeJSON(w, 200, out)
}

func (s *Server) quote(w http.ResponseWriter, r *http.Request) {
	minor, _ := strconv.ParseInt(r.URL.Query().Get("usd_minor"), 10, 64)
	if minor <= 0 || s.Chain == nil {
		writeErr(w, 400, "bad_amount")
		return
	}
	in := chain.USDMinorToUSDC(minor)
	out, err := s.Chain.QuoteExactIn(r.Context(), in)
	if err != nil {
		writeJSON(w, 502, map[string]any{"ok": false, "error": "quote_failed", "message": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "usd_minor": minor, "usdc_in": in.String(), "symp_out": out.String()})
}

func (s *Server) createPayout(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ExternalID string `json:"external_id"`
		USDMinor   int64  `json:"usd_minor"`
		ToAddress  string `json:"to_address"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeErr(w, 400, "invalid_json")
		return
	}
	body.ExternalID = strings.TrimSpace(body.ExternalID)
	body.ToAddress = strings.TrimSpace(body.ToAddress)
	if body.ExternalID == "" || body.USDMinor <= 0 || !chain.IsETHAddress(body.ToAddress) {
		writeErr(w, 400, "invalid_params")
		return
	}
	if s.MaxUSD > 0 && body.USDMinor > s.MaxUSD*100 {
		writeErr(w, 400, "over_max")
		return
	}
	p, created, err := s.Store.CreateOrGet(r.Context(), body.ExternalID, common.HexToAddress(body.ToAddress).Hex(), body.USDMinor)
	if err != nil {
		writeErr(w, 500, "store_error")
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "created": created, "payout": p})
}

func (s *Server) getPayout(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	p, err := s.Store.ByID(r.Context(), id)
	if err != nil {
		p, err = s.Store.ByExternalID(r.Context(), id)
	}
	if err != nil {
		writeErr(w, 404, "not_found")
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "payout": p})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, err string) {
	writeJSON(w, code, map[string]any{"ok": false, "error": err})
}

func (s *Server) WorkerLoop(ctx context.Context) {
	slipBPS := int64(100)
	if v := strings.TrimSpace(os.Getenv("SLIPPAGE_BPS")); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil && n >= 0 {
			slipBPS = n
		}
	}
	t := time.NewTicker(3 * time.Second)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if s.Chain == nil {
				continue
			}
			list, err := s.Store.ListQueued(ctx, 5)
			if err != nil {
				continue
			}
			for _, p := range list {
				s.processOne(ctx, p, slipBPS)
			}
		}
	}
}

func (s *Server) processOne(ctx context.Context, p store.Payout, slipBPS int64) {
	amountIn := chain.USDMinorToUSDC(p.USDMinor)
	quoted, err := s.Chain.QuoteExactIn(ctx, amountIn)
	if err != nil {
		_ = s.Store.MarkFailed(ctx, p.ID, "quote: "+err.Error())
		s.callback(p.ID, "failed")
		return
	}
	minOut := new(big.Int).Mul(quoted, big.NewInt(10000-slipBPS))
	minOut.Div(minOut, big.NewInt(10000))
	hash, err := s.Chain.SwapUSDCForSYMP(ctx, amountIn, minOut, common.HexToAddress(p.ToAddress))
	if err != nil {
		_ = s.Store.MarkFailed(ctx, p.ID, "swap: "+err.Error())
		s.callback(p.ID, "failed")
		return
	}
	_ = s.Store.MarkSubmitted(ctx, p.ID, hash.Hex())
	cctx, cancel := context.WithTimeout(ctx, 3*time.Minute)
	defer cancel()
	rcpt, err := s.Chain.WaitMined(cctx, hash)
	if err != nil || rcpt == nil || rcpt.Status != 1 {
		reason := "receipt_failed"
		if err != nil {
			reason = err.Error()
		}
		_ = s.Store.MarkFailed(ctx, p.ID, reason)
		s.callback(p.ID, "failed")
		return
	}
	_ = s.Store.MarkCompleted(ctx, p.ID, quoted.String())
	s.callback(p.ID, "completed")
}

func (s *Server) callback(id, status string) {
	url := strings.TrimSpace(os.Getenv("CALLBACK_URL"))
	if url == "" {
		return
	}
	p, err := s.Store.ByID(context.Background(), id)
	if err != nil {
		return
	}
	body, _ := json.Marshal(map[string]any{
		"id": p.ID, "external_id": p.ExternalID, "status": status,
		"tx_hash": p.TxHash, "symp_amount": p.SympAmount, "failure_reason": p.FailureReason,
	})
	req, _ := http.NewRequest(http.MethodPost, url, strings.NewReader(string(body)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Symp-Signature", SignBody(s.Secret, body))
	cli := &http.Client{Timeout: 15 * time.Second}
	resp, err := cli.Do(req)
	if err == nil {
		_ = resp.Body.Close()
	}
}
