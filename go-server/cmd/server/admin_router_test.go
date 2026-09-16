package main

import (
	"context"
	"encoding/base32"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/handler"
	"github.com/lrprojects/monaserver/internal/password"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

func TestRealAdminRouterUsesBrowserSessionBoundary(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("db pool: %v", err)
	}
	t.Cleanup(pool.Close)
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `TRUNCATE TABLE users CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	q := db.New(pool)
	hash, err := password.Hash("password123")
	if err != nil {
		t.Fatalf("password hash: %v", err)
	}
	if _, err := q.CreateUser(ctx, "router-operator", hash, nil, nil); err != nil {
		t.Fatalf("create operator: %v", err)
	}
	admin := service.NewAdminAuth(q, service.AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"),
		HMACKey:       []byte("router-admin-quota-key"),
		AdminOrigin:   "https://admin.example",
	})
	enrollment, err := admin.EnrollAdminOperator(ctx, "router-operator", []string{"users.read", "campaign.email"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	secret, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode enrollment: %v", err)
	}

	cfg := &config.Config{WebAdminAPI: true, AdminOrigin: "https://admin.example"}
	tok := token.NewHelper("consumer-router-secret", time.Minute)
	r := chi.NewRouter()
	r.Use(globalCORS(cfg.AdminOrigin))
	registerAdminV2Routes(r, genserver.NewAdminAPIController(handler.NewAdminServicer(q, nil, nil)), admin, cfg.AdminOrigin)
	registerV3Routes(r, cfg, tok, v3RouteLookup{}, "admin", admin)

	origin := cfg.AdminOrigin
	newRequest := func(method, path, body string) *http.Request {
		req := httptest.NewRequest(method, path, strings.NewReader(body))
		req.RemoteAddr = "192.0.2.40:1234"
		req.Header.Set("Origin", origin)
		return req
	}

	preflightReq := newRequest(http.MethodOptions, "/api/v3/admin/session/bootstrap", "")
	preflightReq.Header.Set("Access-Control-Request-Method", http.MethodPost)
	preflightReq.Header.Set("Access-Control-Request-Headers", "X-CSRF-Token")
	preflight := httptest.NewRecorder()
	r.ServeHTTP(preflight, preflightReq)
	if preflight.Code != http.StatusNoContent || preflight.Header().Get("Access-Control-Allow-Origin") != origin || preflight.Header().Get("Access-Control-Allow-Credentials") != "true" {
		t.Fatalf("admin preflight status/headers = %d %#v", preflight.Code, preflight.Header())
	}
	if strings.Contains(preflight.Header().Get("Access-Control-Allow-Origin"), "*") {
		t.Fatalf("admin preflight emitted wildcard origin: %#v", preflight.Header())
	}
	deniedPreflightReq := newRequest(http.MethodOptions, "/api/v3/admin/session/bootstrap", "")
	deniedPreflightReq.Header.Set("Origin", "https://evil.example")
	deniedPreflightReq.Header.Set("Access-Control-Request-Method", http.MethodPost)
	deniedPreflight := httptest.NewRecorder()
	r.ServeHTTP(deniedPreflight, deniedPreflightReq)
	if deniedPreflight.Code != http.StatusForbidden || deniedPreflight.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatalf("denied admin preflight = %d %#v", deniedPreflight.Code, deniedPreflight.Header())
	}

	bootstrap := httptest.NewRecorder()
	r.ServeHTTP(bootstrap, newRequest(http.MethodPost, "/api/v3/admin/session/bootstrap", ""))
	if bootstrap.Code != http.StatusOK {
		t.Fatalf("bootstrap status = %d, body = %s", bootstrap.Code, bootstrap.Body.String())
	}
	var boot struct {
		CSRFToken string `json:"csrfToken"`
	}
	if err := json.Unmarshal(bootstrap.Body.Bytes(), &boot); err != nil || boot.CSRFToken == "" {
		t.Fatalf("bootstrap response = %s", bootstrap.Body.String())
	}
	bootCookies := bootstrap.Result().Cookies()
	if len(bootCookies) != 1 || !bootCookies[0].Secure || !bootCookies[0].HttpOnly || bootCookies[0].SameSite != http.SameSiteStrictMode {
		t.Fatalf("bootstrap cookie flags = %#v", bootCookies)
	}
	preAuthCookie := bootCookies[0]

	loginReq := newRequest(http.MethodPost, "/api/v3/admin/session/login", `{"username":"router-operator","password":"password123"}`)
	loginReq.AddCookie(preAuthCookie)
	loginReq.Header.Set("X-CSRF-Token", boot.CSRFToken)
	login := httptest.NewRecorder()
	r.ServeHTTP(login, loginReq)
	if login.Code != http.StatusAccepted {
		t.Fatalf("login status = %d, body = %s", login.Code, login.Body.String())
	}
	var challenge struct {
		ChallengeID string `json:"challengeId"`
	}
	if err := json.Unmarshal(login.Body.Bytes(), &challenge); err != nil || challenge.ChallengeID == "" {
		t.Fatalf("login response = %s", login.Body.String())
	}

	code, _ := service.GenerateTOTP(secret, time.Now().UTC())
	mfaReq := newRequest(http.MethodPost, "/api/v3/admin/session/mfa", `{"challengeId":"`+challenge.ChallengeID+`","code":"`+code+`"}`)
	mfaReq.AddCookie(preAuthCookie)
	mfaReq.Header.Set("X-CSRF-Token", boot.CSRFToken)
	mfa := httptest.NewRecorder()
	r.ServeHTTP(mfa, mfaReq)
	if mfa.Code != http.StatusOK {
		t.Fatalf("mfa status = %d, body = %s", mfa.Code, mfa.Body.String())
	}
	authCookies := mfa.Result().Cookies()
	if len(authCookies) != 1 || !strings.HasPrefix(authCookies[0].Value, "s.") {
		t.Fatalf("authenticated cookie = %#v", authCookies)
	}
	authCookie := authCookies[0]
	var session struct {
		CSRFToken string `json:"csrfToken"`
	}
	if err := json.Unmarshal(mfa.Body.Bytes(), &session); err != nil || session.CSRFToken == "" {
		t.Fatalf("mfa response = %s", mfa.Body.String())
	}

	// A consumer bearer cannot satisfy the browser gate, while an authenticated
	// browser request reaches the protected service boundary.
	bearerReq := httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil)
	bearerReq.Header.Set("Authorization", "Bearer consumer-token")
	bearer := httptest.NewRecorder()
	r.ServeHTTP(bearer, bearerReq)
	assertV3RuntimeError(t, bearer, http.StatusUnauthorized, "unauthorized")

	usersReq := httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil)
	usersReq.AddCookie(authCookie)
	users := httptest.NewRecorder()
	r.ServeHTTP(users, usersReq)
	if users.Code != http.StatusServiceUnavailable {
		t.Fatalf("authenticated users status = %d, body = %s", users.Code, users.Body.String())
	}

	// Membership is reloaded for every request: removing users.read changes a
	// previously authenticated session into a capability failure immediately.
	membership, err := q.GetAdminMembership(ctx, enrollment.UserID)
	if err != nil || membership == nil {
		t.Fatalf("membership reload: %v %#v", err, membership)
	}
	if err := q.UpsertAdminMembership(ctx, db.AdminMembershipParams{
		ID: membership.ID, UserID: membership.UserID, Permissions: []string{"campaign.email"}, Active: membership.Active,
		TotpSecretCiphertext: membership.TotpSecretCiphertext, TotpKeyID: membership.TotpKeyID, TotpEnrolledAt: membership.TotpEnrolledAt,
		RevokedAt: membership.RevokedAt,
	}); err != nil {
		t.Fatalf("demote capability: %v", err)
	}
	forbiddenReq := httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil)
	forbiddenReq.AddCookie(authCookie)
	forbidden := httptest.NewRecorder()
	r.ServeHTTP(forbidden, forbiddenReq)
	assertV3RuntimeError(t, forbidden, http.StatusForbidden, "forbidden")

	csrfReq := newRequest(http.MethodPost, "/api/v2/admin/mail", `{"mails":["person@example.com"],"subject":"subject","message":"message"}`)
	csrfReq.AddCookie(authCookie)
	csrfMissing := httptest.NewRecorder()
	r.ServeHTTP(csrfMissing, csrfReq)
	assertV3RuntimeError(t, csrfMissing, http.StatusForbidden, "invalid_csrf")

	// The old v2 payload is still parsed and reaches its service result after
	// the browser gate; only the legacy JWT/username authentication is retired.
	v2Req := newRequest(http.MethodPost, "/api/v2/admin/mail", `{"mails":["person@example.com"],"subject":"subject","message":"message"}`)
	v2Req.AddCookie(authCookie)
	v2Req.Header.Set("X-CSRF-Token", session.CSRFToken)
	v2 := httptest.NewRecorder()
	r.ServeHTTP(v2, v2Req)
	if v2.Code != http.StatusServiceUnavailable {
		t.Fatalf("v2 admin result = %d, body = %s", v2.Code, v2.Body.String())
	}
}
