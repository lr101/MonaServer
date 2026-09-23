package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/handler"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

func TestNewV3AdminServicersUsesDatabaseBackedImplementations(t *testing.T) {
	queries := db.New(nil)
	auth := service.NewAdminAuth(queries, service.AdminAuthConfig{})
	servicers := newV3AdminServicers(queries, auth)

	if _, ok := servicers.users.(*handler.AdminUsersServicer); !ok {
		t.Fatalf("users servicer = %T, want concrete admin users servicer", servicers.users)
	}
	if _, ok := servicers.campaigns.(*handler.AdminCampaignsServicer); !ok {
		t.Fatalf("campaigns servicer = %T, want concrete admin campaigns servicer", servicers.campaigns)
	}
	if _, ok := servicers.audiences.(*handler.AdminAudienceServicer); !ok {
		t.Fatalf("audiences servicer = %T, want concrete admin audience servicer", servicers.audiences)
	}
	if _, ok := servicers.jobs.(*handler.AdminJobsServicer); !ok {
		t.Fatalf("jobs servicer = %T, want concrete admin jobs servicer", servicers.jobs)
	}
	if _, ok := servicers.messages.(*handler.AdminMessagesServicer); !ok {
		t.Fatalf("messages servicer = %T, want concrete admin messages servicer", servicers.messages)
	}
	if _, ok := servicers.reports.(*handler.AdminReportsServicer); !ok {
		t.Fatalf("reports servicer = %T, want concrete admin reports servicer", servicers.reports)
	}
	if _, ok := servicers.audit.(*handler.AdminAuditServicer); !ok {
		t.Fatalf("audit servicer = %T, want concrete admin audit servicer", servicers.audit)
	}
}

type v3RouteLookup struct {
	usernames map[uuid.UUID]string
}

func (l v3RouteLookup) GetUsername(_ context.Context, id uuid.UUID) (string, error) {
	username, ok := l.usernames[id]
	if !ok {
		return "", http.ErrNoCookie
	}
	return username, nil
}

func newV3RuntimeRouter(t *testing.T, cfg *config.Config) (http.Handler, string, string) {
	t.Helper()
	consumerID := uuid.New()
	adminID := uuid.New()
	tok := token.NewHelper("runtime-test-secret", time.Minute)
	consumerToken, err := tok.GenerateAccessToken(consumerID)
	if err != nil {
		t.Fatalf("generate consumer token: %v", err)
	}
	adminToken, err := tok.GenerateAccessToken(adminID)
	if err != nil {
		t.Fatalf("generate admin token: %v", err)
	}
	lookup := v3RouteLookup{usernames: map[uuid.UUID]string{
		consumerID: "consumer",
		adminID:    "admin",
	}}
	r := chi.NewRouter()
	registerV3Routes(r, cfg, tok, lookup, "admin")
	return r, consumerToken, adminToken
}

func TestV3AdminRoutesRequireAdminBrowserSession(t *testing.T) {
	r, consumerToken, adminToken := newV3RuntimeRouter(t, &config.Config{WebAdminAPI: true})

	tests := []struct {
		name       string
		authorize  string
		cookie     bool
		wantStatus int
		wantCode   string
	}{
		{name: "missing authentication", wantStatus: http.StatusUnauthorized, wantCode: "unauthorized"},
		{name: "ordinary consumer bearer", authorize: consumerToken, wantStatus: http.StatusForbidden, wantCode: "forbidden"},
		{name: "consumer bearer cannot fall back to legacy admin username", authorize: adminToken, wantStatus: http.StatusForbidden, wantCode: "forbidden"},
		{name: "browser session reaches unavailable scaffold", cookie: true, wantStatus: http.StatusServiceUnavailable, wantCode: "feature_unavailable"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil)
			if tt.authorize != "" {
				req.Header.Set("Authorization", "Bearer "+tt.authorize)
			}
			if tt.cookie {
				req.AddCookie(&http.Cookie{Name: "admin_session", Value: "opaque-session"})
			}
			recorder := httptest.NewRecorder()
			r.ServeHTTP(recorder, req)
			assertV3RuntimeError(t, recorder, tt.wantStatus, tt.wantCode)
		})
	}
}

func TestV3CampaignRoutesRequireAdminBrowserSession(t *testing.T) {
	r, consumerToken, adminToken := newV3RuntimeRouter(t, &config.Config{WebAdminAPI: true})

	tests := []struct {
		name       string
		authorize  string
		cookie     bool
		wantStatus int
		wantCode   string
	}{
		{name: "missing authentication", wantStatus: http.StatusUnauthorized, wantCode: "unauthorized"},
		{name: "ordinary consumer bearer", authorize: consumerToken, wantStatus: http.StatusForbidden, wantCode: "forbidden"},
		{name: "legacy admin bearer cannot access campaign", authorize: adminToken, wantStatus: http.StatusForbidden, wantCode: "forbidden"},
		{name: "browser session reaches campaign scaffold", cookie: true, wantStatus: http.StatusServiceUnavailable, wantCode: "feature_unavailable"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v3/admin/campaigns", nil)
			if tt.authorize != "" {
				req.Header.Set("Authorization", "Bearer "+tt.authorize)
			}
			if tt.cookie {
				req.AddCookie(&http.Cookie{Name: adminSessionCookieName, Value: "opaque-session"})
			}
			recorder := httptest.NewRecorder()
			r.ServeHTTP(recorder, req)
			assertV3RuntimeError(t, recorder, tt.wantStatus, tt.wantCode)
		})
	}
}

func TestV3DisabledFeaturesCannotExecutePlaceholderMutations(t *testing.T) {
	r, _, _ := newV3RuntimeRouter(t, &config.Config{})
	tests := []struct {
		name   string
		method string
		path   string
		body   string
	}{
		{
			name:   "public email link request",
			method: http.MethodPost,
			path:   "/api/v3/public/auth/email-link/request",
			body:   `{"email":"person@example.com"}`,
		},
		{
			name:   "own session revoke",
			method: http.MethodPost,
			path:   "/api/v3/auth/session/revoke",
			body:   `{"refreshToken":"opaque-refresh-token"}`,
		},
		{
			name:   "admin bootstrap",
			method: http.MethodPost,
			path:   "/api/v3/admin/session/bootstrap",
		},
		{
			name:   "admin job mutation",
			method: http.MethodPost,
			path:   "/api/v3/admin/jobs",
			body:   `{}`,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, tt.path, strings.NewReader(tt.body))
			recorder := httptest.NewRecorder()
			r.ServeHTTP(recorder, req)
			assertV3RuntimeError(t, recorder, http.StatusServiceUnavailable, "feature_unavailable")
			if recorder.Code >= http.StatusOK && recorder.Code < http.StatusMultipleChoices {
				t.Fatalf("disabled route returned successful status %d", recorder.Code)
			}
		})
	}
}

func TestV3EnabledAdminMutationCannotReturnPlaceholderSuccess(t *testing.T) {
	r, _, _ := newV3RuntimeRouter(t, &config.Config{WebAdminAPI: true})
	req := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", strings.NewReader(`{"action":{"action":"email","body":"Security update","subject":"Stick-It"},"payloadHash":"payload-hash","snapshotId":"snapshot-id"}`))
	req.AddCookie(&http.Cookie{Name: adminSessionCookieName, Value: "opaque-session"})
	recorder := httptest.NewRecorder()
	r.ServeHTTP(recorder, req)
	assertV3RuntimeError(t, recorder, http.StatusServiceUnavailable, "feature_unavailable")
	if recorder.Code >= http.StatusOK && recorder.Code < http.StatusMultipleChoices {
		t.Fatalf("unimplemented admin mutation returned successful status %d", recorder.Code)
	}
}

func TestV3ValidationErrorsUseBadRequestEnvelope(t *testing.T) {
	t.Run("public malformed JSON", func(t *testing.T) {
		r, _, _ := newV3RuntimeRouter(t, &config.Config{PublicEmailLogin: true})
		request := httptest.NewRequest(http.MethodPost, "/api/v3/public/auth/email-link/request", strings.NewReader(`{"email":"person@example.com","secret":"raw-token"}`))
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, request)
		raw := recorder.Body.String()
		assertV3RuntimeError(t, recorder, http.StatusBadRequest, "invalid_request")
		assertNoSecretEcho(t, raw, "raw-token")
	})

	t.Run("public missing required field", func(t *testing.T) {
		r, _, _ := newV3RuntimeRouter(t, &config.Config{PublicEmailLogin: true})
		request := httptest.NewRequest(http.MethodPost, "/api/v3/public/auth/email-link/request", strings.NewReader(`{}`))
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, request)
		assertV3RuntimeError(t, recorder, http.StatusBadRequest, "invalid_request")
	})

	t.Run("own session malformed JSON", func(t *testing.T) {
		r, consumerToken, _ := newV3RuntimeRouter(t, &config.Config{PublicEmailLogin: true})
		request := httptest.NewRequest(http.MethodPost, "/api/v3/auth/session/revoke", strings.NewReader(`{"refreshToken":"raw-refresh-token"`))
		request.Header.Set("Authorization", "Bearer "+consumerToken)
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, request)
		raw := recorder.Body.String()
		assertV3RuntimeError(t, recorder, http.StatusBadRequest, "invalid_request")
		assertNoSecretEcho(t, raw, "raw-refresh-token")
	})

	t.Run("admin missing required fields", func(t *testing.T) {
		r, _, _ := newV3RuntimeRouter(t, &config.Config{WebAdminAPI: true})
		request := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", strings.NewReader(`{}`))
		request.AddCookie(&http.Cookie{Name: adminSessionCookieName, Value: "opaque-session"})
		recorder := httptest.NewRecorder()
		r.ServeHTTP(recorder, request)
		assertV3RuntimeError(t, recorder, http.StatusBadRequest, "invalid_request")
	})

	nestedInvalidRequests := []struct {
		name string
		path string
		body string
	}{
		{
			name: "unknown action field",
			path: "/api/v3/admin/jobs",
			body: `{"action":{"action":"email","body":"Body","subject":"Subject","unexpected":null},"payloadHash":"payload-hash","snapshotId":"snapshot-id"}`,
		},
		{
			name: "inactive action field",
			path: "/api/v3/admin/jobs",
			body: `{"action":{"action":"email","body":"Body","subject":"Subject","title":""},"payloadHash":"payload-hash","snapshotId":"snapshot-id"}`,
		},
		{
			name: "unknown audience field",
			path: "/api/v3/admin/audiences/preview",
			body: `{"action":{"action":"login_link"},"audience":{"kind":"selected","resource":"accounts","ids":["046b6c7f-0b8a-43b9-b35d-6489e6daee91"],"unexpected":null}}`,
		},
		{
			name: "inactive audience ids",
			path: "/api/v3/admin/audiences/preview",
			body: `{"action":{"action":"login_link"},"audience":{"kind":"filter","resource":"accounts","ids":[],"filter":{"resource":"accounts"}}}`,
		},
		{
			name: "report account field false",
			path: "/api/v3/admin/audiences/preview",
			body: `{"action":{"action":"login_link"},"audience":{"kind":"filter","resource":"reports","filter":{"resource":"reports","includeAdmins":false}}}`,
		},
		{
			name: "report account field null",
			path: "/api/v3/admin/audiences/preview",
			body: `{"action":{"action":"login_link"},"audience":{"kind":"filter","resource":"reports","filter":{"resource":"reports","includeAdmins":null}}}`,
		},
	}
	for _, tt := range nestedInvalidRequests {
		t.Run(tt.name, func(t *testing.T) {
			r, _, _ := newV3RuntimeRouter(t, &config.Config{WebAdminAPI: true})
			request := httptest.NewRequest(http.MethodPost, tt.path, strings.NewReader(tt.body))
			request.AddCookie(&http.Cookie{Name: adminSessionCookieName, Value: "opaque-session"})
			recorder := httptest.NewRecorder()
			r.ServeHTTP(recorder, request)
			assertV3RuntimeError(t, recorder, http.StatusBadRequest, "invalid_request")
		})
	}
}

func TestV3OwnSessionRequiresBearerAuthentication(t *testing.T) {
	r, consumerToken, _ := newV3RuntimeRouter(t, &config.Config{PublicEmailLogin: true})

	req := httptest.NewRequest(http.MethodPost, "/api/v3/auth/session/revoke", strings.NewReader(`{"refreshToken":"opaque-refresh-token"}`))
	recorder := httptest.NewRecorder()
	r.ServeHTTP(recorder, req)
	assertLegacyRuntimeError(t, recorder, http.StatusUnauthorized, "missing bearer token")

	req = httptest.NewRequest(http.MethodPost, "/api/v3/auth/session/revoke", strings.NewReader(`{"refreshToken":"opaque-refresh-token"}`))
	req.Header.Set("Authorization", "Bearer "+consumerToken)
	recorder = httptest.NewRecorder()
	r.ServeHTTP(recorder, req)
	assertV3RuntimeError(t, recorder, http.StatusServiceUnavailable, "feature_unavailable")
}

func assertV3RuntimeError(t *testing.T, recorder *httptest.ResponseRecorder, wantStatus int, wantCode string) {
	t.Helper()
	if recorder.Code != wantStatus {
		t.Fatalf("status = %d, want %d; body = %s", recorder.Code, wantStatus, recorder.Body.String())
	}
	var body genserver.ApiErrorDto
	if err := json.NewDecoder(recorder.Body).Decode(&body); err != nil {
		t.Fatalf("decode v3 error: %v", err)
	}
	if body.Code != wantCode {
		t.Fatalf("error code = %q, want %q", body.Code, wantCode)
	}
}

func assertLegacyRuntimeError(t *testing.T, recorder *httptest.ResponseRecorder, wantStatus int, wantMessage string) {
	t.Helper()
	if recorder.Code != wantStatus {
		t.Fatalf("status = %d, want %d; body = %s", recorder.Code, wantStatus, recorder.Body.String())
	}
	var body map[string]string
	if err := json.NewDecoder(recorder.Body).Decode(&body); err != nil {
		t.Fatalf("decode legacy error: %v", err)
	}
	if body["error"] != wantMessage {
		t.Fatalf("legacy error = %q, want %q", body["error"], wantMessage)
	}
}

func assertNoSecretEcho(t *testing.T, response, secret string) {
	t.Helper()
	if strings.Contains(response, secret) {
		t.Fatalf("v3 validation error echoed secret %q: %s", secret, response)
	}
}
