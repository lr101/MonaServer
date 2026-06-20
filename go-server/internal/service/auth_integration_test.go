package service

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/token"
)

func testDSN(t *testing.T) string {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	return dsn
}

func setup(t *testing.T) *Auth {
	t.Helper()
	dsn := testDSN(t)
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	t.Cleanup(pool.Close)
	// reset users/refresh tables between tests
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE refresh_token, users CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	q := db.New(pool)
	tok := token.NewHelper("test-secret", time.Minute)
	cfg := &config.Config{MaxLoginAttempts: 5}
	return NewAuth(q, tok, cfg)
}

func TestAuthSignupLoginRefresh(t *testing.T) {
	svc := setup(t)
	ctx := context.Background()

	pair, err := svc.Signup(ctx, "alice", "pw12345", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if pair.AccessToken == "" || pair.RefreshToken.String() == "" {
		t.Fatal("empty tokens")
	}

	// duplicate username -> conflict
	if _, err := svc.Signup(ctx, "alice", "pw", nil); err == nil {
		t.Fatal("expected duplicate username error")
	}

	// login
	lp, err := svc.Login(ctx, "alice", "pw12345")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	if lp.UserID != pair.UserID {
		t.Fatalf("user id mismatch: %v vs %v", lp.UserID, pair.UserID)
	}

	// wrong password
	if _, err := svc.Login(ctx, "alice", "bad"); err == nil {
		t.Fatal("expected wrong password error")
	}

	// refresh
	rp, err := svc.Refresh(ctx, pair.RefreshToken)
	if err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if rp.UserID != pair.UserID {
		t.Fatalf("refresh user id mismatch")
	}

	// GetUsername works for JWT middleware path
	name, err := svc.GetUsername(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("getusername: %v", err)
	}
	if name != "alice" {
		t.Fatalf("got %q", name)
	}
}
