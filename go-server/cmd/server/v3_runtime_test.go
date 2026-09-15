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
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/token"
)

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
	req := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", strings.NewReader(`{"action":{"action":"email"},"payloadHash":"payload-hash","snapshotId":"snapshot-id"}`))
	req.AddCookie(&http.Cookie{Name: adminSessionCookieName, Value: "opaque-session"})
	recorder := httptest.NewRecorder()
	r.ServeHTTP(recorder, req)
	assertV3RuntimeError(t, recorder, http.StatusServiceUnavailable, "feature_unavailable")
	if recorder.Code >= http.StatusOK && recorder.Code < http.StatusMultipleChoices {
		t.Fatalf("unimplemented admin mutation returned successful status %d", recorder.Code)
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
