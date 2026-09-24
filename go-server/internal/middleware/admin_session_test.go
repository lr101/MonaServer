package middleware

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

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

func TestAdminCORSAllowsCredentialedCampaignDeletePreflight(t *testing.T) {
	preflight := httptest.NewRequest(http.MethodOptions, "/api/v3/admin/campaigns/campaign-id", nil)
	preflight.Header.Set("Origin", "https://admin.example")
	preflight.Header.Set("Access-Control-Request-Method", http.MethodDelete)
	preflight.Header.Set("Access-Control-Request-Headers", "Content-Type, X-CSRF-Token")
	recorder := httptest.NewRecorder()
	AdminCORS("https://admin.example")(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("preflight reached the protected handler")
	})).ServeHTTP(recorder, preflight)
	if recorder.Code != http.StatusNoContent {
		t.Fatalf("preflight status = %d, want 204", recorder.Code)
	}
	if !strings.Contains(recorder.Header().Get("Access-Control-Allow-Methods"), http.MethodDelete) {
		t.Fatalf("allow methods = %q, want DELETE", recorder.Header().Get("Access-Control-Allow-Methods"))
	}
}

func TestTrustedRealIPRejectsSpoofedForwardedHeaders(t *testing.T) {
	var got string
	next := http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		got = AdminClientIP(r.Context())
	})
	h := TrustedRealIP("10.0.0.0/8")(CaptureAdminRequest(next))

	untrusted := httptest.NewRequest(http.MethodGet, "/", nil)
	untrusted.RemoteAddr = "192.0.2.40:1234"
	untrusted.Header.Set("X-Forwarded-For", "198.51.100.7")
	h.ServeHTTP(httptest.NewRecorder(), untrusted)
	if got != "192.0.2.40" {
		t.Fatalf("untrusted forwarded client = %q, want direct peer", got)
	}

	trusted := httptest.NewRequest(http.MethodGet, "/", nil)
	trusted.RemoteAddr = "10.0.0.8:1234"
	trusted.Header.Set("X-Forwarded-For", "198.51.100.7, 10.0.0.8")
	h.ServeHTTP(httptest.NewRecorder(), trusted)
	if got != "198.51.100.7" {
		t.Fatalf("trusted forwarded client = %q, want client address", got)
	}

	trustedRealIP := httptest.NewRequest(http.MethodGet, "/", nil)
	trustedRealIP.RemoteAddr = "10.0.0.8:1234"
	trustedRealIP.Header.Set("X-Real-IP", "198.51.100.8")
	h.ServeHTTP(httptest.NewRecorder(), trustedRealIP)
	if got != "198.51.100.8" {
		t.Fatalf("trusted X-Real-IP client = %q, want client address", got)
	}

	directRealIPSpoof := httptest.NewRequest(http.MethodGet, "/", nil)
	directRealIPSpoof.RemoteAddr = "192.0.2.41:1234"
	directRealIPSpoof.Header.Set("X-Real-IP", "198.51.100.9")
	h.ServeHTTP(httptest.NewRecorder(), directRealIPSpoof)
	if got != "192.0.2.41" {
		t.Fatalf("direct X-Real-IP client = %q, want direct peer", got)
	}

	malformed := httptest.NewRequest(http.MethodGet, "/", nil)
	malformed.RemoteAddr = "10.0.0.8:1234"
	malformed.Header.Set("X-Forwarded-For", "not-an-ip")
	h.ServeHTTP(httptest.NewRecorder(), malformed)
	if got != "10.0.0.8" {
		t.Fatalf("malformed forwarded client = %q, want direct peer", got)
	}
}

func TestLoginMFASatisfiesMutationsDuringSession(t *testing.T) {
	if !RecentMFAActionMatches("session", "mark_compromised") || !RecentMFAActionMatches("session", "campaigns.write") {
		t.Fatal("login MFA should authorize subsequent mutations")
	}
}

func TestAdminCSRFAndRecentMFAGuardsProtectMutations(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	now := time.Now().UTC()
	principal := AdminPrincipal{CSRFHash: CSRFHash("csrf"), RecentMFAAt: &now, RecentMFAAction: "email"}

	missing := httptest.NewRequest(http.MethodPost, "/api/v2/admin/mail", nil)
	missing = missing.WithContext(WithAdminPrincipal(missing.Context(), principal))
	recorder := httptest.NewRecorder()
	AdminCSRFGuard(next).ServeHTTP(recorder, missing)
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("missing csrf status = %d, want 403", recorder.Code)
	}

	wrongAction := httptest.NewRequest(http.MethodPost, "/api/v2/admin/notification", nil)
	wrongAction.Header.Set("X-CSRF-Token", "csrf")
	wrongAction = wrongAction.WithContext(WithAdminPrincipal(wrongAction.Context(), principal))
	recorder = httptest.NewRecorder()
	AdminCSRFGuard(AdminRecentMFAGuard(time.Minute)(next)).ServeHTTP(recorder, wrongAction)
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("wrong recent mfa action status = %d, want 403", recorder.Code)
	}

	valid := httptest.NewRequest(http.MethodPost, "/api/v2/admin/mail", nil)
	valid.Header.Set("X-CSRF-Token", "csrf")
	valid = valid.WithContext(WithAdminPrincipal(valid.Context(), principal))
	recorder = httptest.NewRecorder()
	AdminCSRFGuard(AdminRecentMFAGuard(time.Minute)(next)).ServeHTTP(recorder, valid)
	if recorder.Code != http.StatusNoContent {
		t.Fatalf("valid mutation status = %d, want 204", recorder.Code)
	}
}

func TestAdminJobCommandRouteBindsRecentMFAProofToJobsControl(t *testing.T) {
	now := time.Now().UTC()
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	serve := func(action string) int {
		r := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs/123/retry", nil)
		r.Header.Set("X-CSRF-Token", "csrf")
		r = r.WithContext(WithAdminPrincipal(r.Context(), AdminPrincipal{
			State: "authenticated", Capabilities: []string{"jobs.control"}, CSRFHash: CSRFHash("csrf"),
			RecentMFAAt: &now, RecentMFAAction: action,
		}))
		recorder := httptest.NewRecorder()
		AdminCSRFGuard(AdminRecentMFAGuard(time.Minute)(AdminCapabilityGuard(next))).ServeHTTP(recorder, r)
		return recorder.Code
	}
	if got := serve("jobs.control"); got != http.StatusNoContent {
		t.Fatalf("jobs.control command proof status = %d, want 204", got)
	}
	if got := serve("email"); got != http.StatusForbidden {
		t.Fatalf("email command proof status = %d, want 403", got)
	}
}

func TestAdminMutationActionsAreExplicitAndBodyBound(t *testing.T) {
	paths := []struct {
		method string
		path   string
		want   string
	}{
		{http.MethodPost, "/api/v3/admin/audiences/preview", "audience.preview"},
		{http.MethodPost, "/api/v3/admin/jobs", "jobs.create"},
		{http.MethodPost, "/api/v3/admin/jobs/123/retry", "jobs.control"},
		{http.MethodPost, "/api/v3/admin/jobs/123/cancel", "jobs.control"},
		{http.MethodPost, "/api/v3/admin/messages/test", "messages.test"},
		{http.MethodPatch, "/api/v3/admin/reports/123", "reports.review"},
		{http.MethodPost, "/api/v3/admin/reports/123/notes", "reports.review"},
		{http.MethodPost, "/api/v3/admin/campaigns", "campaigns.write"},
		{http.MethodPatch, "/api/v3/admin/campaigns/123", "campaigns.write"},
		{http.MethodPost, "/api/v3/admin/campaigns/123/archive", "campaigns.write"},
		{http.MethodDelete, "/api/v3/admin/campaigns/123", "campaigns.write"},
		{http.MethodPost, "/api/v2/admin/mail", "email"},
		{http.MethodPost, "/api/v2/admin/notification", "push"},
	}
	for _, test := range paths {
		if got := AdminMutationAction(test.method, test.path); got != test.want {
			t.Fatalf("AdminMutationAction(%s, %s) = %q, want %q", test.method, test.path, got, test.want)
		}
	}
	if RecentMFAActionMatches("email", "") {
		t.Fatal("stored action was allowed to match an unmapped mutation")
	}
	if RecentMFAActionMatches("", "jobs.control") {
		t.Fatal("empty stored action was allowed to match a mapped mutation")
	}

	job := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", strings.NewReader(`{"action":{"action":"mark_compromised","reason":"incident"}}`))
	if got := AdminMutationActionForRequest(job); got != "mark_compromised" {
		t.Fatalf("body action = %q, want mark_compromised", got)
	}
	decoded, err := io.ReadAll(job.Body)
	if err != nil || string(decoded) == "" {
		t.Fatalf("body was not restored: %q (%v)", decoded, err)
	}
	bulkReport := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", strings.NewReader(`{"action":{"action":"report_resolve","reason":"reviewed"}}`))
	if got := AdminMutationActionForRequest(bulkReport); got != "report_resolve" {
		t.Fatalf("bulk report body action = %q, want report_resolve", got)
	}

	report := httptest.NewRequest(http.MethodPatch, "/api/v3/admin/reports/123", strings.NewReader(`{"status":"dismissed","expectedRevision":1}`))
	if got := AdminMutationActionForRequest(report); got != "reports.review" {
		t.Fatalf("individual report body action = %q, want reports.review", got)
	}
	if got := RequiredAdminCapability(http.MethodPatch, "/api/v3/admin/reports/123"); got != "reports.review" {
		t.Fatalf("individual report capability = %q, want reports.review", got)
	}
	if got := RequiredAdminCapability(http.MethodGet, "/api/v3/admin/campaigns"); got != "campaigns.read" {
		t.Fatalf("campaign list capability = %q, want campaigns.read", got)
	}
	if got := RequiredAdminCapability(http.MethodPost, "/api/v3/admin/campaigns"); got != "campaigns.write" {
		t.Fatalf("campaign mutation capability = %q, want campaigns.write", got)
	}

	now := time.Now().UTC()
	for _, test := range []struct {
		status     string
		bulkAction string
	}{
		{status: "resolved", bulkAction: "report_resolve"},
		{status: "dismissed", bulkAction: "report_dismiss"},
	} {
		request := httptest.NewRequest(http.MethodPatch, "/api/v3/admin/reports/123", strings.NewReader(`{"status":"`+test.status+`","expectedRevision":1}`))
		if got := AdminMutationActionForRequest(request); got != "reports.review" {
			t.Fatalf("%s report body action = %q, want reports.review", test.status, got)
		}
		principal := AdminPrincipal{
			Capabilities:    []string{"reports.review"},
			RecentMFAAt:     &now,
			RecentMFAAction: "reports.review",
		}
		request = request.WithContext(WithAdminPrincipal(request.Context(), principal))
		recorder := httptest.NewRecorder()
		AdminRecentMFAGuard(time.Minute)(AdminCapabilityGuard(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusNoContent)
		}))).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusNoContent {
			t.Fatalf("%s report transition status = %d, want 204", test.status, recorder.Code)
		}

		request = httptest.NewRequest(http.MethodPatch, "/api/v3/admin/reports/123", strings.NewReader(`{"status":"`+test.status+`","expectedRevision":1}`))
		request = request.WithContext(WithAdminPrincipal(request.Context(), AdminPrincipal{
			Capabilities:    []string{"reports.review"},
			RecentMFAAt:     &now,
			RecentMFAAction: test.bulkAction,
		}))
		recorder = httptest.NewRecorder()
		AdminRecentMFAGuard(time.Minute)(AdminCapabilityGuard(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusNoContent)
		}))).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusForbidden {
			t.Fatalf("%s bulk action proof status = %d, want 403", test.status, recorder.Code)
		}
	}

	principal := AdminPrincipal{RecentMFAAt: &now, RecentMFAAction: "mark_compromised"}
	matched := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", strings.NewReader(`{"action":{"action":"mark_compromised","reason":"incident"}}`))
	matched = matched.WithContext(WithAdminPrincipal(matched.Context(), principal))
	matchedRecorder := httptest.NewRecorder()
	AdminRecentMFAGuard(time.Minute)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})).ServeHTTP(matchedRecorder, matched)
	if matchedRecorder.Code != http.StatusNoContent {
		t.Fatalf("body-bound matching action status = %d, want 204", matchedRecorder.Code)
	}

	wrong := httptest.NewRequest(http.MethodPost, "/api/v3/admin/jobs", strings.NewReader(`{"action":{"action":"email","body":"hello","subject":"notice"}}`))
	wrong = wrong.WithContext(WithAdminPrincipal(wrong.Context(), principal))
	wrongRecorder := httptest.NewRecorder()
	AdminRecentMFAGuard(time.Minute)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})).ServeHTTP(wrongRecorder, wrong)
	if wrongRecorder.Code != http.StatusForbidden {
		t.Fatalf("body-bound mismatching action status = %d, want 403", wrongRecorder.Code)
	}
}
