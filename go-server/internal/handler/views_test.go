package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

func TestRecoverPasswordViewDoesNotGrantBearerJWT(t *testing.T) {
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
	defer pool.Close()
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE refresh_token, users, seasons CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	q := db.New(pool)
	auth := service.NewAuth(q, token.NewHelper("test-secret", time.Minute), &config.Config{MaxLoginAttempts: 5})
	email := "legacy-recovery-view@example.test"
	pair, err := auth.Signup(context.Background(), "legacy_recovery_view", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(context.Background(), pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	legacyURL := "legacy-reset-slug"
	security := auth.Security()
	if _, err := security.ContainAccount(context.Background(), service.ContainmentRequest{AccountID: pair.UserID, Reason: "legacy view setup"}); err != nil {
		t.Fatalf("contain account: %v", err)
	}
	// A legacy URL may still be present in an old database row. The adapter
	// must bind it to the current restricted generation before rendering.
	if err := q.SetUserResetPasswordUrl(context.Background(), pair.UserID, legacyURL, time.Now().Add(time.Minute)); err != nil {
		t.Fatalf("set reset URL: %v", err)
	}

	view := NewViews(q, token.NewHelper("test-secret", time.Minute), "", security)
	req := httptest.NewRequest(http.MethodGet, "/public/recover/"+legacyURL, nil)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("url", legacyURL)
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()
	view.RecoverPassword(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("view status = %d, want 200", rec.Code)
	}
	body := rec.Body.String()
	if strings.Contains(body, "Bearer ") || strings.Contains(body, "Authorization") {
		t.Fatal("recovery view granted a broad Bearer token")
	}
	if !strings.Contains(body, "/api/v3/public/auth/recovery/complete") {
		t.Fatal("recovery view does not target the restricted recovery endpoint")
	}
	if _, err := security.ContainAccount(context.Background(), service.ContainmentRequest{AccountID: pair.UserID, Reason: "legacy link fence"}); err != nil {
		t.Fatalf("contain account: %v", err)
	}
	rec = httptest.NewRecorder()
	view.RecoverPassword(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Choose a new password") {
		t.Fatalf("reopened recovery view status/body = %d/%q, want active password form", rec.Code, rec.Body.String())
	}
}

func TestRecoverPasswordViewOpensForNormalAccount(t *testing.T) {
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
	defer pool.Close()
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE refresh_token, users, seasons CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	q := db.New(pool)
	security := service.NewAccountSecurity(q)
	auth := service.NewAuth(q, token.NewHelper("test-secret", time.Minute), &config.Config{MaxLoginAttempts: 5})
	email := "normal-recovery-view@example.test"
	pair, err := auth.Signup(context.Background(), "normal_recovery_view", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(context.Background(), pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	const resetURL = "normal-account-reset-slug"
	if err := q.SetUserResetPasswordUrl(context.Background(), pair.UserID, resetURL, time.Now().Add(time.Minute)); err != nil {
		t.Fatalf("set reset URL: %v", err)
	}
	view := NewViews(q, token.NewHelper("test-secret", time.Minute), "", security)
	req := httptest.NewRequest(http.MethodGet, "/public/recover/"+resetURL, nil)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("url", resetURL)
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()
	view.RecoverPassword(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Choose a new password") || strings.Contains(rec.Body.String(), "This page does not exist") {
		t.Fatalf("normal account recovery view = %d/%q, want password form", rec.Code, rec.Body.String())
	}
	match := regexp.MustCompile(`id="token" value="([^"]+)"`).FindStringSubmatch(rec.Body.String())
	if len(match) != 2 {
		t.Fatal("recovery form has no one-use token")
	}
	if err := service.NewAccountRecovery(q, security).CompleteRecovery(context.Background(), service.RecoveryCompletionRequest{
		Token: match[1], Password: "new-password123",
	}); err != nil {
		t.Fatalf("complete normal account recovery: %v", err)
	}
	if _, err := auth.Login(context.Background(), "normal_recovery_view", "new-password123"); err != nil {
		t.Fatalf("login with reset password: %v", err)
	}
	if _, err := auth.Login(context.Background(), "normal_recovery_view", "password123"); err == nil {
		t.Fatal("old password still works after reset")
	}
}
