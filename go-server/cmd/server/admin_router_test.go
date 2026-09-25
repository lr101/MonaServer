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
	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/handler"
	"github.com/lrprojects/monaserver/internal/password"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

type routerLoginLinkEnqueuer struct {
	requests []service.LoginLinkDeliveryRequest
}

func (e *routerLoginLinkEnqueuer) EnqueueLoginLink(_ context.Context, _ *db.Queries, request service.LoginLinkDeliveryRequest) (*uuid.UUID, error) {
	e.requests = append(e.requests, request)
	id := uuid.New()
	return &id, nil
}

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
	if _, err := q.Pool().Exec(ctx, `UPDATE users SET email = $1 WHERE username = $2`, "router@example.com", "router-operator"); err != nil {
		t.Fatalf("set operator email: %v", err)
	}
	admin := service.NewAdminAuth(q, service.AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"),
		HMACKey:       []byte("router-admin-quota-key"),
	})
	// Keep two successive TOTP windows behind wall time so middleware also
	// considers each action-bound step-up recent during this route test.
	currentNow := time.Now().UTC().Add(-90 * time.Second).Truncate(time.Second)
	admin.SetClock(func() time.Time { return currentNow })
	enrollment, err := admin.EnrollAdminOperator(ctx, "router-operator", []string{"users.read", "users.verify", "reports.read", "campaigns.read", "campaigns.write", "campaign.email", "campaign.login_link"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	secret, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode enrollment: %v", err)
	}

	cfg := &config.Config{WebAdminAPI: true}
	tok := token.NewHelper("consumer-router-secret", time.Minute)
	enqueuer := &routerLoginLinkEnqueuer{}
	emailLogin := service.NewEmailLogin(q, service.NewAccountSecurity(q), tok, service.EmailLoginConfig{}, enqueuer)
	r := chi.NewRouter()
	r.Use(globalCORS())
	registerAdminV2Routes(r, genserver.NewAdminAPIController(handler.NewAdminServicer(q, nil, nil)), admin)
	registerV3Routes(r, cfg, tok, v3RouteLookup{}, "admin", admin, q, emailLogin)

	origin := "https://admin.example"
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
	otherOriginPreflightReq := newRequest(http.MethodOptions, "/api/v3/admin/session/bootstrap", "")
	otherOriginPreflightReq.Header.Set("Origin", "https://evil.example")
	otherOriginPreflightReq.Header.Set("Access-Control-Request-Method", http.MethodPost)
	otherOriginPreflight := httptest.NewRecorder()
	r.ServeHTTP(otherOriginPreflight, otherOriginPreflightReq)
	if otherOriginPreflight.Code != http.StatusNoContent || otherOriginPreflight.Header().Get("Access-Control-Allow-Origin") != "https://evil.example" || otherOriginPreflight.Header().Get("Access-Control-Allow-Credentials") != "true" {
		t.Fatalf("other-origin admin preflight = %d %#v", otherOriginPreflight.Code, otherOriginPreflight.Header())
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
	if len(bootCookies) != 1 || !bootCookies[0].Secure || !bootCookies[0].HttpOnly || bootCookies[0].SameSite != http.SameSiteNoneMode {
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
	verifyPath := "/api/v3/admin/users/" + enrollment.UserID.String() + "/verify-email"
	verifyUnauthenticated := httptest.NewRecorder()
	r.ServeHTTP(verifyUnauthenticated, newRequest(http.MethodPost, verifyPath, ""))
	assertV3RuntimeError(t, verifyUnauthenticated, http.StatusUnauthorized, "unauthorized")
	verifyReq := newRequest(http.MethodPost, verifyPath, "")
	verifyReq.AddCookie(authCookie)
	verifyReq.Header.Set("X-CSRF-Token", session.CSRFToken)
	verified := httptest.NewRecorder()
	r.ServeHTTP(verified, verifyReq)
	if verified.Code != http.StatusOK || !strings.Contains(verified.Body.String(), `"emailVerified":true`) {
		t.Fatalf("verify email status = %d, body = %s", verified.Code, verified.Body.String())
	}
	linkPath := "/api/v3/admin/users/" + enrollment.UserID.String() + "/login-link"
	linkUnauthenticated := httptest.NewRecorder()
	r.ServeHTTP(linkUnauthenticated, newRequest(http.MethodPost, linkPath, ""))
	assertV3RuntimeError(t, linkUnauthenticated, http.StatusUnauthorized, "unauthorized")
	linkReq := newRequest(http.MethodPost, linkPath, "")
	linkReq.AddCookie(authCookie)
	linkReq.Header.Set("X-CSRF-Token", session.CSRFToken)
	linkQueued := httptest.NewRecorder()
	r.ServeHTTP(linkQueued, linkReq)
	if linkQueued.Code != http.StatusAccepted {
		t.Fatalf("login link status = %d, body = %s", linkQueued.Code, linkQueued.Body.String())
	}
	if len(enqueuer.requests) != 1 || enqueuer.requests[0].AccountID != enrollment.UserID || enqueuer.requests[0].To != "router@example.com" {
		t.Fatalf("login link delivery requests = %d; expected one to the verified account", len(enqueuer.requests))
	}

	campaignListReq := newRequest(http.MethodGet, "/api/v3/admin/campaigns", "")
	campaignListReq.AddCookie(authCookie)
	campaignList := httptest.NewRecorder()
	r.ServeHTTP(campaignList, campaignListReq)
	if campaignList.Code != http.StatusOK {
		t.Fatalf("campaign list status = %d, body = %s", campaignList.Code, campaignList.Body.String())
	}
	campaignBody := `{"name":"Router campaign","channel":"email","subject":"Hello","body":"Message","status":"draft"}`
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
	verifyWithoutCapability := newRequest(http.MethodPost, verifyPath, "")
	verifyWithoutCapability.AddCookie(authCookie)
	verifyWithoutCapability.Header.Set("X-CSRF-Token", session.CSRFToken)
	verifyForbidden := httptest.NewRecorder()
	r.ServeHTTP(verifyForbidden, verifyWithoutCapability)
	assertV3RuntimeError(t, verifyForbidden, http.StatusForbidden, "forbidden")
	linkWithoutCapability := newRequest(http.MethodPost, linkPath, "")
	linkWithoutCapability.AddCookie(authCookie)
	linkWithoutCapability.Header.Set("X-CSRF-Token", session.CSRFToken)
	linkForbidden := httptest.NewRecorder()
	r.ServeHTTP(linkForbidden, linkWithoutCapability)
	assertV3RuntimeError(t, linkForbidden, http.StatusForbidden, "forbidden")

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

func TestWebAdminAPIDisablesMigratedV2AdminSurface(t *testing.T) {
	r := chi.NewRouter()
	cfg := &config.Config{WebAdminAPI: false}
	registerAdminV2Routes(r, genserver.NewAdminAPIController(handler.NewAdminServicer(nil, nil, nil)), nil, cfg.WebAdminAPI)

	req := httptest.NewRequest(http.MethodPost, "/api/v2/admin/mail", strings.NewReader(`{}`))
	recorder := httptest.NewRecorder()
	r.ServeHTTP(recorder, req)
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("disabled v2 admin status = %d, body = %s; want 503", recorder.Code, recorder.Body.String())
	}
}
