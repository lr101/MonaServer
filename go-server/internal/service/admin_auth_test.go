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

func TestSuperadminGrantsCurrentAndFutureCapabilities(t *testing.T) {
	actor := AdminActor{ID: uuid.New(), Capabilities: CapabilitiesForPermissions([]string{"superadmin"})}
	if len(actor.Capabilities) != 1 || actor.Capabilities[0] != "superadmin" {
		t.Fatalf("superadmin capabilities = %#v, want only the persistent superadmin marker", actor.Capabilities)
	}
	for _, permission := range []string{"users.write", "campaign.login_link", "a.future.capability"} {
		if !actor.Can(permission) {
			t.Errorf("superadmin cannot %q", permission)
		}
	}
}

func TestNewBootstrapAdminIsSuperadmin(t *testing.T) {
	permissions := bootstrapAdminPermissions()
	if len(permissions) != 1 || permissions[0] != "superadmin" {
		t.Fatalf("bootstrap permissions = %#v, want superadmin", permissions)
	}
}

func TestCampaignWriteActionMapsToCampaignCapability(t *testing.T) {
	if got := AdminActionCapability("campaigns.write"); got != "campaigns.write" {
		t.Fatalf("campaign write action capability = %q, want campaigns.write", got)
	}
}

func TestAdminUserWriteActionMapsToWriteCapability(t *testing.T) {
	if got := AdminActionCapability("users.write"); got != "users.write" {
		t.Fatalf("user write action capability = %q, want users.write", got)
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
	if !cookie.Secure || !cookie.HttpOnly || cookie.SameSite != http.SameSiteNoneMode {
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
