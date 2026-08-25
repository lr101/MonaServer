package handler

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

func setupAuthServicer(t *testing.T) (*AuthServicer, *service.Auth) {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	t.Cleanup(pool.Close)
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE refresh_token, users, seasons CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	q := db.New(pool)
	auth := service.NewAuth(q, token.NewHelper("test-secret", time.Minute), &config.Config{
		MaxLoginAttempts:   5,
		RefreshTokenExpiry: time.Hour,
	})
	return NewAuthServicer(auth, q, nil, ""), auth
}

func TestRefreshTokenRejectsTokenOwnedByAnotherUser(t *testing.T) {
	servicer, auth := setupAuthServicer(t)
	ctx := context.Background()
	owner, err := auth.Signup(ctx, "refresh_owner", "password123", nil)
	if err != nil {
		t.Fatalf("signup owner: %v", err)
	}
	other, err := auth.Signup(ctx, "refresh_other", "password123", nil)
	if err != nil {
		t.Fatalf("signup other: %v", err)
	}

	resp, err := servicer.RefreshToken(ctx, genserver.RefreshTokenRequestDto{
		RefreshToken: owner.RefreshToken.String(),
		UserId:       other.UserID.String(),
	})
	if err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if resp.Code != 400 {
		t.Fatalf("refresh response status = %d, want 400", resp.Code)
	}
}

func TestPasswordRecoveryUsesTenMinuteExpiryAndReportsMailFailure(t *testing.T) {
	baseServicer, auth := setupAuthServicer(t)
	ctx := context.Background()
	email := "recovery@example.com"
	if _, err := auth.Signup(ctx, "recovery_user", "password123", &email); err != nil {
		t.Fatalf("signup: %v", err)
	}
	failingMail := service.NewEmail(&config.Config{
		MailHost: "127.0.0.1", MailPort: 1, MailUsername: "sender@example.com",
		MailPassword: "password", MailFrom: "sender@example.com", AppURL: "https://api.example.com",
	}, nil)
	servicer := NewAuthServicer(auth, baseServicer.q, failingMail, "")
	resp, err := servicer.RequestPasswordRecovery(ctx, "recovery_user")
	if err != nil {
		t.Fatalf("failed recovery request: %v", err)
	}
	if resp.Code != 400 {
		t.Fatalf("failed mail status = %d, want 400", resp.Code)
	}
	stored, err := baseServicer.q.GetUserByUsername(ctx, "recovery_user")
	if err != nil {
		t.Fatalf("get user after failed mail: %v", err)
	}
	if stored.ResetPasswordUrl != nil || stored.ResetPasswordExpiration != nil {
		t.Fatal("failed recovery mail left a recovery token behind")
	}

	host, port, received := startSMTPRecorder(t)
	workingMail := service.NewEmail(&config.Config{
		MailHost: host, MailPort: port, MailUsername: "sender@example.com",
		MailPassword: "password", MailFrom: "sender@example.com", AppURL: "https://api.example.com",
	}, nil)
	servicer = NewAuthServicer(auth, baseServicer.q, workingMail, "")
	before := time.Now()
	resp, err = servicer.RequestPasswordRecovery(ctx, "recovery_user")
	if err != nil {
		t.Fatalf("working recovery request: %v", err)
	}
	if resp.Code != 200 {
		t.Fatalf("working mail status = %d, want 200", resp.Code)
	}
	select {
	case <-received:
	case <-time.After(time.Second):
		t.Fatal("recovery email was not sent before the request completed")
	}
	stored, err = baseServicer.q.GetUserByUsername(ctx, "recovery_user")
	if err != nil {
		t.Fatalf("get user after recovery: %v", err)
	}
	if stored.ResetPasswordExpiration == nil {
		t.Fatal("recovery expiration is missing")
	}
	wantMin := before.Add(9*time.Minute + 50*time.Second)
	wantMax := before.Add(10*time.Minute + 10*time.Second)
	if stored.ResetPasswordExpiration.Before(wantMin) || stored.ResetPasswordExpiration.After(wantMax) {
		t.Fatalf("recovery expiration = %s, want about ten minutes after %s", stored.ResetPasswordExpiration, before)
	}
}
