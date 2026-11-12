package store

import (
	"context"
	"path/filepath"
	"testing"
)

func TestCreateIdempotent(t *testing.T) {
	dir := t.TempDir()
	s, err := Open(filepath.Join(dir, "t.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	ctx := context.Background()
	p1, created, err := s.CreateOrGet(ctx, "ext-1", "0xabc", 2000)
	if err != nil || !created || p1 == nil {
		t.Fatalf("first: %v created=%v", err, created)
	}
	p2, created2, err := s.CreateOrGet(ctx, "ext-1", "0xabc", 2000)
	if err != nil || created2 {
		t.Fatalf("second should not create: %v %v", err, created2)
	}
	if p1.ID != p2.ID {
		t.Fatalf("id mismatch")
	}
}
