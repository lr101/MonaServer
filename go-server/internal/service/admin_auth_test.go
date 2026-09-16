package service

import (
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAdminCapabilitiesReflectStableMembershipPermissions(t *testing.T) {
	got := CapabilitiesForPermissions([]string{"jobs.create", "users.read", "jobs.create", "security.revoke"})
	want := []string{"jobs.create", "security.revoke", "users.read"}
	if len(got) != len(want) {
		t.Fatalf("capabilities = %#v, want %#v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("capabilities = %#v, want %#v", got, want)
		}
	}
}

func TestAdminTOTPAcceptsCurrentCodeAndRejectsMalformedCode(t *testing.T) {
	secret := []byte("12345678901234567890")
	now := time.Unix(1_700_000_000, 0).UTC()
	code, counter := GenerateTOTP(secret, now)
	if len(code) != 6 || counter <= 0 {
		t.Fatalf("generated TOTP = %q counter=%d", code, counter)
	}
	if !VerifyTOTP(secret, code, now, 1) {
		t.Fatalf("current TOTP %q was rejected", code)
	}
	if VerifyTOTP(secret, "000000", now, 1) {
		t.Fatal("malformed TOTP was accepted")
	}
}

func TestAdminActionRequiresRecentMFA(t *testing.T) {
	now := time.Unix(1_700_000_000, 0).UTC()
	if !RecentMFAValid(&now, now, 5*time.Minute) {
		t.Fatal("fresh MFA was rejected")
	}
	old := now.Add(-5*time.Minute - time.Second)
	if RecentMFAValid(&old, now, 5*time.Minute) {
		t.Fatal("stale MFA was accepted")
	}
}

func TestAdminCookieHasHostOnlySecureHttpOnlyStrictFlags(t *testing.T) {
	cookie := NewAdminSessionCookie("opaque", time.Unix(1_700_000_000, 0).UTC(), time.Hour)
	if cookie.Name != adminSessionCookieName {
		t.Fatalf("cookie name = %q", cookie.Name)
	}
	if !cookie.Secure || !cookie.HttpOnly || cookie.SameSite != http.SameSiteStrictMode {
		t.Fatalf("cookie flags = secure:%v httponly:%v samesite:%v", cookie.Secure, cookie.HttpOnly, cookie.SameSite)
	}
	if cookie.Domain != "" {
		t.Fatalf("cookie domain = %q, want host-only", cookie.Domain)
	}
	if cookie.Path != "/" || cookie.MaxAge != int(time.Hour/time.Second) {
		t.Fatalf("cookie scope/lifetime = path:%q max-age:%d", cookie.Path, cookie.MaxAge)
	}
}

func TestAdminSessionIDIsOpaqueAndNotUserID(t *testing.T) {
	userID := uuid.New()
	raw := NewOpaqueSecret()
	if len(raw) < 32 || raw == userID.String() {
		t.Fatalf("opaque secret length = %d, equals user ID = %v", len(raw), raw == userID.String())
	}
}
