package handler

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

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

type adminHandlerFixture struct {
	controller *genserver.AdminSessionAPIController
	auth       *service.AdminAuth
	secret     []byte
	now        time.Time
}

func setupAdminHandler(t *testing.T) adminHandlerFixture {
	t.Helper()
	dsn := testDatabaseURL(t)
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
	consumer := service.NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	if _, err := consumer.Signup(context.Background(), "handler-operator", "password123", nil); err != nil {
		t.Fatalf("signup: %v", err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	auth := service.NewAdminAuth(q, service.AdminAuthConfig{
		EncryptionKey:      []byte("0123456789abcdef0123456789abcdef"),
		HMACKey:            []byte("handler-quota-key"),
		SessionIdleTTL:     time.Hour,
		SessionAbsoluteTTL: 8 * time.Hour,
	})
	auth.SetClock(func() time.Time { return now })
	enrollment, err := auth.EnrollAdminOperator(context.Background(), "handler-operator", []string{"security.revoke", "users.read"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	secret, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode enrollment secret: %v", err)
	}
	return adminHandlerFixture{
		controller: genserver.NewAdminSessionAPIController(NewAdminSessionServicer(auth)),
		auth:       auth,
		secret:     secret,
		now:        now,
	}
}

func testDatabaseURL(t *testing.T) string {
	t.Helper()
	dsn := strings.TrimSpace(os.Getenv("TEST_DATABASE_URL"))
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	return dsn
}

func serveAdminHandler(t *testing.T, invoke func(http.ResponseWriter, *http.Request), method, cookie, csrf, body string) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(method, "https://admin.example.com/api/v3/admin/session", strings.NewReader(body))
	request.RemoteAddr = "192.0.2.40:443"
	if cookie != "" {
		request.AddCookie(&http.Cookie{Name: service.AdminSessionCookieName, Value: cookie})
	}
	if csrf != "" {
		request.Header.Set("X-CSRF-Token", csrf)
	}
	request.Header.Set("Origin", "https://admin.example.com")
	middleware.CaptureAdminRequest(http.HandlerFunc(invoke)).ServeHTTP(recorder, request)
	return recorder
}

func responseCookie(t *testing.T, recorder *httptest.ResponseRecorder) *http.Cookie {
	t.Helper()
	cookies := recorder.Result().Cookies()
	if len(cookies) != 1 {
		t.Fatalf("set-cookie count = %d, want 1", len(cookies))
	}
	return cookies[0]
}

func TestAdminSessionHandlerFlowEnforcesCSRFAndRotatesSession(t *testing.T) {
	fixture := setupAdminHandler(t)
	controller := fixture.controller

	bootstrap := serveAdminHandler(t, controller.BootstrapAdminSession, http.MethodPost, "", "", "")
	if bootstrap.Code != http.StatusOK {
		t.Fatalf("bootstrap status = %d, want 200", bootstrap.Code)
	}
	var bootstrapBody genserver.AdminSessionBootstrapDto
	if err := json.NewDecoder(bootstrap.Body).Decode(&bootstrapBody); err != nil {
		t.Fatalf("decode bootstrap: %v", err)
	}
	preAuthCookie := responseCookie(t, bootstrap)
	if preAuthCookie.Name != service.AdminSessionCookieName || !preAuthCookie.HttpOnly || !preAuthCookie.Secure || preAuthCookie.SameSite != http.SameSiteNoneMode {
		t.Fatalf("bootstrap cookie flags = %#v", preAuthCookie)
	}

	loginBody := `{"username":"handler-operator","password":"password123"}`
	wrongCSRF := serveAdminHandler(t, controller.AdminSessionLogin, http.MethodPost, preAuthCookie.Value, "wrong", loginBody)
	if wrongCSRF.Code != http.StatusForbidden {
		t.Fatalf("wrong csrf status = %d, want 403", wrongCSRF.Code)
	}
	login := serveAdminHandler(t, controller.AdminSessionLogin, http.MethodPost, preAuthCookie.Value, bootstrapBody.CsrfToken, loginBody)
	if login.Code != http.StatusAccepted {
		t.Fatalf("login status = %d, want 202", login.Code)
	}
	var loginBodyDto genserver.AdminSessionLoginResponseDto
	if err := json.NewDecoder(login.Body).Decode(&loginBodyDto); err != nil {
		t.Fatalf("decode login: %v", err)
	}
	if loginBodyDto.SessionState != "mfa_required" || loginBodyDto.CsrfToken != bootstrapBody.CsrfToken {
		t.Fatalf("login body = %#v", loginBodyDto)
	}

	code, _ := service.GenerateTOTP(fixture.secret, fixture.now)
	mfaBody := `{"challengeId":"` + loginBodyDto.ChallengeId + `","code":"` + code + `"}`
	mfa := serveAdminHandler(t, controller.CompleteAdminSessionMfa, http.MethodPost, preAuthCookie.Value, bootstrapBody.CsrfToken, mfaBody)
	if mfa.Code != http.StatusOK {
		t.Fatalf("mfa status = %d, want 200", mfa.Code)
	}
	var sessionBody genserver.AdminSessionDto
	if err := json.NewDecoder(mfa.Body).Decode(&sessionBody); err != nil {
		t.Fatalf("decode mfa: %v", err)
	}
	authCookie := responseCookie(t, mfa)
	if sessionBody.SessionState != "authenticated" || sessionBody.CsrfToken == bootstrapBody.CsrfToken || sessionBody.SessionId == "" {
		t.Fatalf("mfa body = %#v", sessionBody)
	}
	if authCookie.Value == preAuthCookie.Value || !authCookie.HttpOnly || !authCookie.Secure || authCookie.SameSite != http.SameSiteNoneMode {
		t.Fatalf("authenticated cookie = %#v", authCookie)
	}

	restored := serveAdminHandler(t, controller.GetAdminSession, http.MethodGet, authCookie.Value, "", "")
	if restored.Code != http.StatusOK {
		t.Fatalf("restore status = %d, want 200", restored.Code)
	}
	var restoredBody genserver.AdminSessionDto
	if err := json.NewDecoder(restored.Body).Decode(&restoredBody); err != nil {
		t.Fatalf("decode restore: %v", err)
	}
	if restoredBody.SessionId != sessionBody.SessionId || restoredBody.CsrfToken != sessionBody.CsrfToken {
		t.Fatalf("restored body = %#v, initial = %#v", restoredBody, sessionBody)
	}

	fixture.auth.SetClock(func() time.Time { return fixture.now.Add(31 * time.Second) })
	reauthCode, _ := service.GenerateTOTP(fixture.secret, fixture.now.Add(31*time.Second))
	reauthBody := `{"action":"revoke_sessions","code":"` + reauthCode + `"}`
	reauth := serveAdminHandler(t, controller.ReauthenticateAdminSession, http.MethodPost, authCookie.Value, sessionBody.CsrfToken, reauthBody)
	if reauth.Code != http.StatusOK {
		t.Fatalf("reauth status = %d, want 200", reauth.Code)
	}
	var reauthSession genserver.AdminSessionDto
	if err := json.NewDecoder(reauth.Body).Decode(&reauthSession); err != nil {
		t.Fatalf("decode reauth: %v", err)
	}
	rotatedCookie := responseCookie(t, reauth)
	if reauthSession.CsrfToken == sessionBody.CsrfToken || rotatedCookie.Value == authCookie.Value {
		t.Fatalf("reauth did not rotate csrf/session envelope: csrf-changed=%v cookie-changed=%v", reauthSession.CsrfToken != sessionBody.CsrfToken, rotatedCookie.Value != authCookie.Value)
	}
	oldCSRFLogout := serveAdminHandler(t, controller.LogoutAdminSession, http.MethodPost, rotatedCookie.Value, sessionBody.CsrfToken, "")
	if oldCSRFLogout.Code != http.StatusForbidden {
		t.Fatalf("stale csrf logout status = %d, want 403", oldCSRFLogout.Code)
	}
	logout := serveAdminHandler(t, controller.LogoutAdminSession, http.MethodPost, rotatedCookie.Value, reauthSession.CsrfToken, "")
	if logout.Code != http.StatusNoContent {
		t.Fatalf("logout status = %d, want 204", logout.Code)
	}
	cleared := responseCookie(t, logout)
	if cleared.Value != "" || cleared.MaxAge >= 0 || !cleared.HttpOnly || !cleared.Secure || cleared.SameSite != http.SameSiteNoneMode {
		t.Fatalf("logout cookie = %#v", cleared)
	}
}
