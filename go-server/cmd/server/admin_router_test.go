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
	// Keep two successive TOTP windows behind wall time so middleware also
	// considers each action-bound step-up recent during this route test.
	currentNow := time.Now().UTC().Add(-90 * time.Second).Truncate(time.Second)
	admin.SetClock(func() time.Time { return currentNow })
	enrollment, err := admin.EnrollAdminOperator(ctx, "router-operator", []string{"users.read", "reports.read", "campaigns.read", "campaigns.write", "campaign.email"})
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
	registerV3Routes(r, cfg, tok, v3RouteLookup{}, "admin", admin, q)

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

	code, _ := service.GenerateTOTP(secret, currentNow)
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
	if users.Code != http.StatusOK {
		t.Fatalf("authenticated users status = %d, body = %s", users.Code, users.Body.String())
	}
	var userPage genserver.AdminUserPageDto
	if err := json.Unmarshal(users.Body.Bytes(), &userPage); err != nil || len(userPage.Items) != 1 || userPage.Items[0].Username != "router-operator" {
		t.Fatalf("authenticated users response = %s err=%v", users.Body.String(), err)
	}

	campaignListReq := newRequest(http.MethodGet, "/api/v3/admin/campaigns", "")
	campaignListReq.AddCookie(authCookie)
	campaignList := httptest.NewRecorder()
	r.ServeHTTP(campaignList, campaignListReq)
	if campaignList.Code != http.StatusOK {
		t.Fatalf("campaign list status = %d, body = %s", campaignList.Code, campaignList.Body.String())
	}
	campaignBody := `{"name":"Router campaign","channel":"email","subject":"Hello","body":"Message","status":"draft"}`
	campaignBeforeMFAReq := newRequest(http.MethodPost, "/api/v3/admin/campaigns", campaignBody)
	campaignBeforeMFAReq.AddCookie(authCookie)
	campaignBeforeMFAReq.Header.Set("X-CSRF-Token", session.CSRFToken)
	campaignBeforeMFA := httptest.NewRecorder()
	r.ServeHTTP(campaignBeforeMFA, campaignBeforeMFAReq)
	assertV3RuntimeError(t, campaignBeforeMFA, http.StatusForbidden, "recent_mfa_required")

	campaignCodeAt := currentNow.Truncate(30 * time.Second).Add(30 * time.Second)
	campaignCode, _ := service.GenerateTOTP(secret, campaignCodeAt)
	campaignStepReq := newRequest(http.MethodPost, "/api/v3/admin/session/reauthenticate", `{"action":"campaigns.write","code":"`+campaignCode+`"}`)
	campaignStepReq.AddCookie(authCookie)
	campaignStepReq.Header.Set("X-CSRF-Token", session.CSRFToken)
	campaignStep := httptest.NewRecorder()
	r.ServeHTTP(campaignStep, campaignStepReq)
	if campaignStep.Code != http.StatusOK {
		t.Fatalf("campaign step-up status = %d, body = %s", campaignStep.Code, campaignStep.Body.String())
	}
	if err := json.Unmarshal(campaignStep.Body.Bytes(), &session); err != nil || session.CSRFToken == "" {
		t.Fatalf("campaign step-up response = %s err=%v", campaignStep.Body.String(), err)
	}
	campaignCookies := campaignStep.Result().Cookies()
	if len(campaignCookies) != 1 {
		t.Fatalf("campaign step-up cookies = %#v", campaignCookies)
	}
	authCookie = campaignCookies[0]
	campaignCreateReq := newRequest(http.MethodPost, "/api/v3/admin/campaigns", campaignBody)
	campaignCreateReq.AddCookie(authCookie)
	campaignCreateReq.Header.Set("X-CSRF-Token", session.CSRFToken)
	campaignCreate := httptest.NewRecorder()
	r.ServeHTTP(campaignCreate, campaignCreateReq)
	if campaignCreate.Code != http.StatusCreated {
		t.Fatalf("campaign create status = %d, body = %s", campaignCreate.Code, campaignCreate.Body.String())
	}
	var createdCampaign genserver.AdminCampaignDto
	if err := json.Unmarshal(campaignCreate.Body.Bytes(), &createdCampaign); err != nil || createdCampaign.Revision != 1 || createdCampaign.Name != "Router campaign" {
		t.Fatalf("campaign create response = %s err=%v", campaignCreate.Body.String(), err)
	}
	campaignDeletePreflightReq := newRequest(http.MethodOptions, "/api/v3/admin/campaigns/"+createdCampaign.Id, "")
	campaignDeletePreflightReq.Header.Set("Access-Control-Request-Method", http.MethodDelete)
	campaignDeletePreflight := httptest.NewRecorder()
	r.ServeHTTP(campaignDeletePreflight, campaignDeletePreflightReq)
	if campaignDeletePreflight.Code != http.StatusNoContent || !strings.Contains(campaignDeletePreflight.Header().Get("Access-Control-Allow-Methods"), http.MethodDelete) {
		t.Fatalf("campaign DELETE preflight = %d %#v", campaignDeletePreflight.Code, campaignDeletePreflight.Header())
	}
	campaignDeleteReq := newRequest(http.MethodDelete, "/api/v3/admin/campaigns/"+createdCampaign.Id, `{"expectedRevision":1}`)
	campaignDeleteReq.AddCookie(authCookie)
	campaignDeleteReq.Header.Set("X-CSRF-Token", session.CSRFToken)
	campaignDelete := httptest.NewRecorder()
	r.ServeHTTP(campaignDelete, campaignDeleteReq)
	if campaignDelete.Code != http.StatusNoContent {
		t.Fatalf("campaign delete status = %d, body = %s", campaignDelete.Code, campaignDelete.Body.String())
	}

	if _, err := service.NewReportService(q).Submit(ctx, service.ReportSubmission{
		ReporterID: enrollment.UserID,
		Body:       "router report",
	}); err != nil {
		t.Fatalf("create router report: %v", err)
	}
	reportsReq := newRequest(http.MethodGet, "/api/v3/admin/reports?limit=1", "")
	reportsReq.AddCookie(authCookie)
	reports := httptest.NewRecorder()
	r.ServeHTTP(reports, reportsReq)
	if reports.Code != http.StatusOK {
		t.Fatalf("authenticated reports status = %d, body = %s", reports.Code, reports.Body.String())
	}
	var reportPage genserver.AdminReportPageDto
	if err := json.Unmarshal(reports.Body.Bytes(), &reportPage); err != nil || len(reportPage.Items) != 1 || reportPage.Items[0].Text != "router report" {
		t.Fatalf("authenticated reports response = %s err=%v", reports.Body.String(), err)
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

	// Initial MFA authenticates the browser but carries no mutation action.
	// A capability-bound step-up is required before the migrated v2 mutation
	// surface can be used.
	currentNow = currentNow.Add(30 * time.Second)
	stepUpCodeAt := currentNow.Truncate(30 * time.Second).Add(30 * time.Second)
	stepUpCode, _ := service.GenerateTOTP(secret, stepUpCodeAt)
	stepUpReq := newRequest(http.MethodPost, "/api/v3/admin/session/reauthenticate", `{"action":"email","code":"`+stepUpCode+`"}`)
	stepUpReq.AddCookie(authCookie)
	stepUpReq.Header.Set("X-CSRF-Token", session.CSRFToken)
	stepUp := httptest.NewRecorder()
	r.ServeHTTP(stepUp, stepUpReq)
	if stepUp.Code != http.StatusOK {
		t.Fatalf("step-up status = %d, body = %s", stepUp.Code, stepUp.Body.String())
	}
	var steppedUpSession struct {
		CSRFToken string `json:"csrfToken"`
	}
	if err := json.Unmarshal(stepUp.Body.Bytes(), &steppedUpSession); err != nil || steppedUpSession.CSRFToken == "" {
		t.Fatalf("step-up response = %s", stepUp.Body.String())
	}
	stepUpCookies := stepUp.Result().Cookies()
	if len(stepUpCookies) != 1 || !strings.HasPrefix(stepUpCookies[0].Value, "s.") {
		t.Fatalf("step-up cookie = %#v", stepUpCookies)
	}
	authCookie = stepUpCookies[0]
	session.CSRFToken = steppedUpSession.CSRFToken

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

func TestInitialAdminSetupRouteRequiresPreAuthCSRF(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatal(err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE admin_initial_setup_claims, users CASCADE`); err != nil {
		t.Fatal(err)
	}
	q := db.New(pool)
	hash, err := password.Hash("password123")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := q.CreateUser(context.Background(), "first-admin", hash, nil, nil); err != nil {
		t.Fatal(err)
	}
	origin := "https://admin.example"
	auth := service.NewAdminAuth(q, service.AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"),
		HMACKey: []byte("initial-route-quota-key"),
		FirstRunToken: "a-unique-deployment-secret-with-at-least-32-chars",
		AdminOrigin: origin,
	})
	r := chi.NewRouter()
	r.Use(globalCORS(origin))
	registerV3Routes(r, &config.Config{WebAdminAPI: true, AdminOrigin: origin}, token.NewHelper("consumer-secret", time.Minute), v3RouteLookup{}, "admin", auth, q)
	request := func(path, body string) *http.Request {
		req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
		req.RemoteAddr = "192.0.2.40:1234"
		req.Header.Set("Origin", origin)
		return req
	}
	bootstrap := httptest.NewRecorder()
	r.ServeHTTP(bootstrap, request("/api/v3/admin/session/bootstrap", ""))
	if bootstrap.Code != http.StatusOK || len(bootstrap.Result().Cookies()) != 1 {
		t.Fatalf("bootstrap status/cookies = %d %#v", bootstrap.Code, bootstrap.Result().Cookies())
	}
	var boot struct{ CSRFToken string `json:"csrfToken"` }
	if err := json.Unmarshal(bootstrap.Body.Bytes(), &boot); err != nil || boot.CSRFToken == "" {
		t.Fatalf("bootstrap body = %s", bootstrap.Body.String())
	}
	path := "/api/v3/admin/session/initial-setup"
	body := `{"username":"first-admin","password":"password123","setupToken":"a-unique-deployment-secret-with-at-least-32-chars"}`
	withoutCSRF := request(path, body)
	withoutCSRF.AddCookie(bootstrap.Result().Cookies()[0])
	denied := httptest.NewRecorder()
	r.ServeHTTP(denied, withoutCSRF)
	if denied.Code != http.StatusForbidden {
		t.Fatalf("missing CSRF status = %d, body = %s", denied.Code, denied.Body.String())
	}
	valid := request(path, body)
	valid.AddCookie(bootstrap.Result().Cookies()[0])
	valid.Header.Set("X-CSRF-Token", boot.CSRFToken)
	created := httptest.NewRecorder()
	r.ServeHTTP(created, valid)
	if created.Code != http.StatusCreated || !strings.Contains(created.Body.String(), `"totpSecret"`) || created.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("initial setup status/body/headers = %d %s %#v", created.Code, created.Body.String(), created.Header())
	}
}

func TestWebAdminAPIDisablesMigratedV2AdminSurface(t *testing.T) {
	r := chi.NewRouter()
	cfg := &config.Config{WebAdminAPI: false, AdminOrigin: "https://admin.example"}
	registerAdminV2Routes(r, genserver.NewAdminAPIController(handler.NewAdminServicer(nil, nil, nil)), nil, cfg.AdminOrigin, cfg.WebAdminAPI)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/admin/mail", strings.NewReader(`{}`))
	recorder := httptest.NewRecorder()
	r.ServeHTTP(recorder, req)
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("disabled v2 admin status = %d, body = %s; want 503", recorder.Code, recorder.Body.String())
	}
}
