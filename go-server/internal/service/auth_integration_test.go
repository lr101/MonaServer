package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/token"
)

func TestLoginUpgradesLegacyPasswordHash(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "legacy_password_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	sum := sha256.Sum256([]byte("password123"))
	legacy := hex.EncodeToString(sum[:])
	if _, err := q.Pool().Exec(ctx, `UPDATE users SET password = $2 WHERE id = $1`, pair.UserID, legacy); err != nil {
		t.Fatalf("store legacy password: %v", err)
	}
	if _, err := auth.Login(ctx, "legacy_password_user", "password123"); err != nil {
		t.Fatalf("login with legacy password: %v", err)
	}
	stored, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get upgraded user: %v", err)
	}
	if !strings.HasPrefix(stored.Password, "{bcrypt}$2") {
		t.Fatalf("password hash was not upgraded: %q", stored.Password)
	}
}

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
	cfg := &config.Config{MaxLoginAttempts: 5, RefreshTokenExpiry: time.Hour}
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
	rp, err := svc.Refresh(ctx, pair.RefreshToken, pair.UserID)
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

func TestRefreshRejectsAndDeletesExpiredToken(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "expired_refresh", "pw12345", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if _, err := q.Pool().Exec(ctx,
		`UPDATE refresh_token SET last_active_date = NOW() - INTERVAL '2 hours' WHERE token = $1`,
		pair.RefreshToken,
	); err != nil {
		t.Fatalf("age refresh token: %v", err)
	}

	if _, err := auth.Refresh(ctx, pair.RefreshToken, pair.UserID); err == nil {
		t.Fatal("expired refresh token should be rejected")
	}
	var count int
	if err := q.Pool().QueryRow(ctx,
		`SELECT COUNT(*) FROM refresh_token WHERE token = $1`, pair.RefreshToken,
	).Scan(&count); err != nil {
		t.Fatalf("count refresh token: %v", err)
	}
	if count != 0 {
		t.Fatalf("expired refresh token still exists, count = %d", count)
	}
}

func TestSignupCreatesEmailConfirmationToken(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "new-user@example.com"
	pair, err := auth.Signup(ctx, "confirmation_user", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	user, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get user: %v", err)
	}
	if user.EmailConfirmationUrl == nil || *user.EmailConfirmationUrl == "" {
		t.Fatal("signup did not create an email confirmation token")
	}
	if user.EmailConfirmed {
		t.Fatal("new signup should remain unconfirmed until the confirmation link is used")
	}
}

func TestSignupRollsBackWhenConfirmationMailFails(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	failingMail := NewEmail(&config.Config{
		MailHost: "127.0.0.1", MailPort: 1, MailUsername: "sender@example.com",
		MailPassword: "password", MailFrom: "sender@example.com", AppURL: "https://api.example.com",
	}, nil)
	auth := NewAuth(q, token.NewHelper("test-secret", time.Minute), &config.Config{
		MaxLoginAttempts: 5, RefreshTokenExpiry: time.Hour,
	}, failingMail)
	email := "failed-signup@example.com"
	if _, err := auth.Signup(ctx, "failed_signup", "password123", &email); err == nil {
		t.Fatal("signup should fail when the confirmation email cannot be sent")
	}
	stored, err := q.GetUserByUsername(ctx, "failed_signup")
	if err != nil {
		t.Fatalf("look up failed signup: %v", err)
	}
	if stored != nil {
		t.Fatal("failed signup left a user row behind")
	}
}
