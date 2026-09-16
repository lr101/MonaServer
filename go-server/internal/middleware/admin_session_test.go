package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

func TestAdminOriginGuardRejectsCrossSiteMutations(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	r := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", nil)
	r.Header.Set("Origin", "https://evil.example")
	recorder := httptest.NewRecorder()
	AdminOriginGuard("https://admin.example")(next).ServeHTTP(recorder, r)
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusForbidden)
	}
}

func TestAdminOriginGuardAllowsConfiguredOriginAndSafeRead(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	read := httptest.NewRequest(http.MethodGet, "/api/v3/admin/session", nil)
	read.Header.Set("Origin", "https://evil.example")
	readRecorder := httptest.NewRecorder()
	AdminOriginGuard("https://admin.example")(next).ServeHTTP(readRecorder, read)
	if readRecorder.Code != http.StatusNoContent {
		t.Fatalf("read status = %d, want %d", readRecorder.Code, http.StatusNoContent)
	}
	write := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", nil)
	write.Header.Set("Origin", "https://admin.example")
	writeRecorder := httptest.NewRecorder()
	AdminOriginGuard("https://admin.example")(next).ServeHTTP(writeRecorder, write)
	if writeRecorder.Code != http.StatusNoContent {
		t.Fatalf("write status = %d, want %d", writeRecorder.Code, http.StatusNoContent)
	}
}

func TestAdminOriginGuardFailsClosedWithoutConfiguredOrigin(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	r := httptest.NewRequest(http.MethodPost, "/api/v3/admin/session/logout", nil)
	r.Header.Set("Origin", "https://admin.example")
	recorder := httptest.NewRecorder()
	AdminOriginGuard("")(next).ServeHTTP(recorder, r)
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusForbidden)
	}
}

func TestAdminCapabilityGuardReturnsForbiddenForMissingCapability(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	r := httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil)
	ctx := WithAdminPrincipal(r.Context(), AdminPrincipal{Capabilities: []string{"reports.read"}})
	recorder := httptest.NewRecorder()
	AdminCapabilityGuard(next).ServeHTTP(recorder, r.WithContext(ctx))
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusForbidden)
	}
}

type adminValidatorFunc func(context.Context, string) (*AdminPrincipal, error)

func (f adminValidatorFunc) ValidateAdminSession(ctx context.Context, cookie string) (*AdminPrincipal, error) {
	return f(ctx, cookie)
}

func TestAdminSessionGuardNeverUsesConsumerBearerFallback(t *testing.T) {
	called := false
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		w.WriteHeader(http.StatusNoContent)
	})
	r := httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil)
	r.Header.Set("Authorization", "Bearer consumer-token")
	recorder := httptest.NewRecorder()
	AdminSessionGuard(adminValidatorFunc(func(context.Context, string) (*AdminPrincipal, error) {
		t.Fatal("validator called without an admin cookie")
		return nil, nil
	}))(next).ServeHTTP(recorder, r)
	if recorder.Code != http.StatusUnauthorized || called {
		t.Fatalf("status = %d, next called = %v; want 401 and no next", recorder.Code, called)
	}
}

func TestAdminSessionGuardPreservesUnavailableStatus(t *testing.T) {
	r := httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil)
	r.AddCookie(&http.Cookie{Name: "admin_session", Value: "opaque"})
	recorder := httptest.NewRecorder()
	AdminSessionGuard(adminValidatorFunc(func(context.Context, string) (*AdminPrincipal, error) {
		return nil, apperrors.New(http.StatusServiceUnavailable, "database unavailable")
	}))(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})).ServeHTTP(recorder, r)
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503", recorder.Code)
	}
}

func TestAdminCORSAllowsCredentialsOnlyForConfiguredOrigin(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	allowed := httptest.NewRequest(http.MethodGet, "/api/v3/admin/session", nil)
	allowed.Header.Set("Origin", "https://admin.example")
	allowedRecorder := httptest.NewRecorder()
	AdminCORS("https://admin.example")(next).ServeHTTP(allowedRecorder, allowed)
	if allowedRecorder.Header().Get("Access-Control-Allow-Origin") != "https://admin.example" || allowedRecorder.Header().Get("Access-Control-Allow-Credentials") != "true" {
		t.Fatalf("allowed CORS headers = %#v", allowedRecorder.Header())
	}
	denied := httptest.NewRequest(http.MethodGet, "/api/v3/admin/session", nil)
	denied.Header.Set("Origin", "https://evil.example")
	deniedRecorder := httptest.NewRecorder()
	AdminCORS("https://admin.example")(next).ServeHTTP(deniedRecorder, denied)
	if deniedRecorder.Header().Get("Access-Control-Allow-Origin") != "" || deniedRecorder.Header().Get("Access-Control-Allow-Credentials") != "" {
		t.Fatalf("denied CORS headers = %#v", deniedRecorder.Header())
	}
}
