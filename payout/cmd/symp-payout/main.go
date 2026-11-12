package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/Fox26601/SYMP/payout/internal/api"
	"github.com/Fox26601/SYMP/payout/internal/chain"
	"github.com/Fox26601/SYMP/payout/internal/store"
)

func main() {
	dbPath := env("SQLITE_PATH", "payout.db")
	st, err := store.Open(dbPath)
	if err != nil {
		log.Fatal(err)
	}
	defer st.Close()

	var ch *chain.Client
	if os.Getenv("ONCHAIN_RPC_URL") != "" {
		ch, err = chain.NewFromEnv()
		if err != nil {
			log.Printf("chain disabled: %v", err)
		}
	}

	srv := &api.Server{
		Store:  st,
		Chain:  ch,
		Secret: os.Getenv("HMAC_SECRET"),
		MaxUSD: intEnv("MAX_PAYOUT_USD", 500),
		Daily:  intEnv("DAILY_LIMIT_USD", 2000),
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go srv.WorkerLoop(ctx)

	addr := env("HTTP_ADDR", ":8088")
	httpSrv := &http.Server{Addr: addr, Handler: srv.Router()}
	go func() {
		log.Printf("symp-payout listening on %s", addr)
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig
	cancel()
	shctx, shcancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shcancel()
	_ = httpSrv.Shutdown(shctx)
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func intEnv(k string, def int64) int64 {
	v := os.Getenv(k)
	if v == "" {
		return def
	}
	n, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		return def
	}
	return n
}
