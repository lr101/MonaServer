package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
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
	pair, err := auth.Signup(context.Background(), "legacy_recovery_view", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	legacyURL := "legacy-reset-slug"
	if err := q.SetUserResetPasswordUrl(context.Background(), pair.UserID, legacyURL, time.Now().Add(time.Minute)); err != nil {
		t.Fatalf("set reset URL: %v", err)
	}

	view := NewViews(q, token.NewHelper("test-secret", time.Minute), "")
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
	if _, err := auth.Security().ContainAccount(context.Background(), service.ContainmentRequest{AccountID: pair.UserID, Reason: "legacy link fence"}); err != nil {
		t.Fatalf("contain account: %v", err)
	}
	rec = httptest.NewRecorder()
	view.RecoverPassword(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "404") {
		t.Fatalf("contained recovery view status/body = %d/%q, want 404 page", rec.Code, rec.Body.String())
	}
}
