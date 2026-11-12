package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

type Status string

const (
	StatusQueued     Status = "queued"
	StatusSubmitted  Status = "submitted"
	StatusCompleted  Status = "completed"
	StatusFailed     Status = "failed"
)

type Payout struct {
	ID            string    `json:"id"`
	ExternalID    string    `json:"external_id"`
	ToAddress     string    `json:"to_address"`
	USDMinor      int64     `json:"usd_minor"`
	Status        Status    `json:"status"`
	TxHash        string    `json:"tx_hash"`
	SympAmount    string    `json:"symp_amount"`
	FailureReason string    `json:"failure_reason"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type Store struct {
	db *sql.DB
}

func Open(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	s := &Store{db: db}
	if err := s.migrate(); err != nil {
		_ = db.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	_, err := s.db.Exec(`
CREATE TABLE IF NOT EXISTS payouts (
  id TEXT PRIMARY KEY,
  external_id TEXT NOT NULL UNIQUE,
  to_address TEXT NOT NULL,
  usd_minor INTEGER NOT NULL,
  status TEXT NOT NULL,
  tx_hash TEXT NOT NULL DEFAULT '',
  symp_amount TEXT NOT NULL DEFAULT '',
  failure_reason TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
`)
	return err
}

func (s *Store) CreateOrGet(ctx context.Context, externalID, to string, usdMinor int64) (*Payout, bool, error) {
	now := time.Now().UTC().Format(time.RFC3339Nano)
	id := fmt.Sprintf("po_%d", time.Now().UnixNano())
	res, err := s.db.ExecContext(ctx, `
INSERT OR IGNORE INTO payouts (id, external_id, to_address, usd_minor, status, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?)`, id, externalID, to, usdMinor, StatusQueued, now, now)
	if err != nil {
		return nil, false, err
	}
	n, _ := res.RowsAffected()
	p, err := s.ByExternalID(ctx, externalID)
	return p, n > 0, err
}

func (s *Store) ByExternalID(ctx context.Context, externalID string) (*Payout, error) {
	row := s.db.QueryRowContext(ctx, `
SELECT id, external_id, to_address, usd_minor, status, tx_hash, symp_amount, failure_reason, created_at, updated_at
FROM payouts WHERE external_id = ?`, externalID)
	return scan(row)
}

func (s *Store) ByID(ctx context.Context, id string) (*Payout, error) {
	row := s.db.QueryRowContext(ctx, `
SELECT id, external_id, to_address, usd_minor, status, tx_hash, symp_amount, failure_reason, created_at, updated_at
FROM payouts WHERE id = ?`, id)
	return scan(row)
}

func (s *Store) ListQueued(ctx context.Context, limit int) ([]Payout, error) {
	rows, err := s.db.QueryContext(ctx, `
SELECT id, external_id, to_address, usd_minor, status, tx_hash, symp_amount, failure_reason, created_at, updated_at
FROM payouts WHERE status = ? ORDER BY created_at ASC LIMIT ?`, StatusQueued, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Payout
	for rows.Next() {
		p, err := scanRows(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, rows.Err()
}

func (s *Store) MarkSubmitted(ctx context.Context, id, txHash string) error {
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := s.db.ExecContext(ctx, `UPDATE payouts SET status=?, tx_hash=?, updated_at=? WHERE id=?`, StatusSubmitted, txHash, now, id)
	return err
}

func (s *Store) MarkCompleted(ctx context.Context, id, sympAmount string) error {
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := s.db.ExecContext(ctx, `UPDATE payouts SET status=?, symp_amount=?, updated_at=? WHERE id=?`, StatusCompleted, sympAmount, now, id)
	return err
}

func (s *Store) MarkFailed(ctx context.Context, id, reason string) error {
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := s.db.ExecContext(ctx, `UPDATE payouts SET status=?, failure_reason=?, updated_at=? WHERE id=?`, StatusFailed, reason, now, id)
	return err
}

func (s *Store) GetMeta(ctx context.Context, key string) (string, error) {
	var v string
	err := s.db.QueryRowContext(ctx, `SELECT value FROM meta WHERE key=?`, key).Scan(&v)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return v, err
}

func (s *Store) SetMeta(ctx context.Context, key, value string) error {
	_, err := s.db.ExecContext(ctx, `INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value`, key, value)
	return err
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scan(row rowScanner) (*Payout, error) {
	var p Payout
	var created, updated string
	if err := row.Scan(&p.ID, &p.ExternalID, &p.ToAddress, &p.USDMinor, &p.Status, &p.TxHash, &p.SympAmount, &p.FailureReason, &created, &updated); err != nil {
		return nil, err
	}
	p.CreatedAt, _ = time.Parse(time.RFC3339Nano, created)
	p.UpdatedAt, _ = time.Parse(time.RFC3339Nano, updated)
	return &p, nil
}

func scanRows(rows *sql.Rows) (*Payout, error) { return scan(rows) }
