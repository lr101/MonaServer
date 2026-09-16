package service

import (
	"context"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/password"
	"github.com/lrprojects/monaserver/internal/token"
)

func TestAdminBootstrapMFAReplayAndDemotion(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	userID := createTestUser(t, auth, "operator")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("quota-key"),
		SessionIdleTTL: time.Hour, SessionAbsoluteTTL: 8 * time.Hour,
	})
	enrollment, err := admin.EnrollAdminOperator(ctx, "operator", []string{"security.revoke", "users.read"})
	if err != nil {
		t.Fatalf("enroll operator: %v", err)
	}
	secret, err := normalizedTOTPSecret(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode enrollment secret: %v", err)
	}

	recorder := httptest.NewRecorder()
	bootstrapCtx := middleware.WithAdminResponseWriter(ctx, recorder)
	bootstrapCtx = middleware.WithAdminClientIP(bootstrapCtx, "127.0.0.1")
	boot, err := admin.BootstrapAdminSession(bootstrapCtx)
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	if boot.SessionState != "pre_authentication" || boot.CSRFToken == "" {
		t.Fatalf("bootstrap result = %#v", boot)
	}
	cookie := recorder.Result().Cookies()[0].Value
	loginCtx := middleware.WithAdminSessionCookie(bootstrapCtx, cookie)
	login, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "operator", "password123")
	if err != nil {
		t.Fatalf("password challenge: %v", err)
	}
	if login.SessionState != "mfa_required" || login.ChallengeID == "" {
		t.Fatalf("login result = %#v", login)
	}

	now := admin.currentTime()
	code, _ := GenerateTOTP(secret, now)
	mfaCtx := middleware.WithAdminSessionCookie(loginCtx, cookie)
	result, err := admin.CompleteAdminSessionMFA(mfaCtx, login.CSRFToken, login.ChallengeID, code)
	if err != nil {
		t.Fatalf("complete mfa: %v", err)
	}
	if result.Principal == nil || result.Principal.State != adminSessionStateAuthenticated || result.CSRFToken == login.CSRFToken {
		t.Fatalf("authenticated result = %#v", result)
	}
	if _, err := admin.CompleteAdminSessionMFA(mfaCtx, login.CSRFToken, login.ChallengeID, code); err == nil {
		t.Fatal("replayed MFA challenge was accepted")
	}

	authenticatedCtx := middleware.WithAdminSessionCookie(ctx, result.Cookie)
	principal, err := admin.ValidateAdminSession(authenticatedCtx, result.Cookie)
	if err != nil {
		t.Fatalf("validate authenticated session: %v", err)
	}
	if principal.UserID != userID.String() || !containsString(principal.Capabilities, "security.revoke") {
		t.Fatalf("principal = %#v", principal)
	}
	if err := q.RevokeAdminMembership(ctx, userID); err != nil {
		t.Fatalf("revoke membership: %v", err)
	}
	if _, err := admin.ValidateAdminSession(authenticatedCtx, result.Cookie); err == nil {
		t.Fatal("demoted operator retained an authenticated session")
	}
}

func TestAdminChallengeFailuresAreSharedAndNonLocking(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	_ = createTestUser(t, auth, "throttle-operator")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("quota-key"),
		LoginFailureLimit: 5, LoginIPLimit: 100, LoginGlobalLimit: 1000,
	})
	if _, err := admin.EnrollAdminOperator(ctx, "throttle-operator", []string{"users.read"}); err != nil {
		t.Fatalf("enroll: %v", err)
	}
	recorder := httptest.NewRecorder()
	base := middleware.WithAdminResponseWriter(ctx, recorder)
	base = middleware.WithAdminClientIP(base, "192.0.2.10")
	boot, err := admin.BootstrapAdminSession(base)
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	cookie := recorder.Result().Cookies()[0].Value
	loginCtx := middleware.WithAdminSessionCookie(base, cookie)
	for i := 0; i < 5; i++ {
		if _, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "throttle-operator", "wrong-password"); err == nil {
			t.Fatal("wrong password unexpectedly succeeded")
		}
	}
	if _, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "throttle-operator", "wrong-password"); err == nil || err != ErrAdminRateLimited {
		t.Fatalf("sixth failure = %v, want shared rate limit", err)
	}
	u, err := q.GetUserByUsername(ctx, "throttle-operator")
	if err != nil {
		t.Fatalf("load throttled user: %v", err)
	}
	if u.FailedLoginAttempts != 0 {
		t.Fatalf("admin failures changed consumer lock counter to %d", u.FailedLoginAttempts)
	}
}

func TestAdminEnrollmentIsIdempotentAndEncrypted(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	hash, err := password.Hash("password123")
	if err != nil {
		t.Fatalf("hash: %v", err)
	}
	id, err := q.CreateUser(ctx, "enrollment-operator", hash, nil, nil)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	admin := NewAdminAuth(q, AdminAuthConfig{EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("quota-key")})
	first, err := admin.EnrollAdminOperator(ctx, "enrollment-operator", []string{"users.read"})
	if err != nil {
		t.Fatalf("first enrollment: %v", err)
	}
	second, err := admin.EnrollAdminOperator(ctx, "enrollment-operator", []string{"users.read"})
	if err != nil {
		t.Fatalf("second enrollment: %v", err)
	}
	if first.Secret == "" || second.Secret != "" {
		t.Fatalf("idempotent secret presence = first:%v second:%v", first.Secret != "", second.Secret != "")
	}
	membership, err := q.GetAdminMembership(ctx, id)
	if err != nil {
		t.Fatalf("membership: %v", err)
	}
	if membership == nil || len(membership.TotpSecretCiphertext) == 0 || string(membership.TotpSecretCiphertext) == first.Secret {
		t.Fatalf("unencrypted or missing enrollment = %#v", membership)
	}
	if membership.UserID != id {
		t.Fatalf("membership user = %s, want %s", membership.UserID, id)
	}
}

func TestAdminSessionExpirySelfTargetAndBreakGlassAudit(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	consumer := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	targetID := createTestUser(t, consumer, "breakglass-target")
	actorID := createTestUser(t, consumer, "breakglass-actor")
	now := time.Now().UTC().Truncate(time.Second)
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("breakglass-quota-key"),
		SessionIdleTTL: time.Minute, SessionAbsoluteTTL: 2 * time.Minute,
	})
	admin.SetClock(func() time.Time { return now })
	enrollment, err := admin.EnrollAdminOperator(ctx, "breakglass-target", []string{"security.revoke"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	secret, err := normalizedTOTPSecret(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode enrollment secret: %v", err)
	}
	recorder := httptest.NewRecorder()
	bootstrapCtx := middleware.WithAdminResponseWriter(ctx, recorder)
	bootstrapCtx = middleware.WithAdminClientIP(bootstrapCtx, "192.0.2.30")
	boot, err := admin.BootstrapAdminSession(bootstrapCtx)
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	preAuth := recorder.Result().Cookies()[0].Value
	loginCtx := middleware.WithAdminSessionCookie(bootstrapCtx, preAuth)
	login, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "breakglass-target", "password123")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	code, _ := GenerateTOTP(secret, now)
	result, err := admin.CompleteAdminSessionMFA(middleware.WithAdminSessionCookie(loginCtx, preAuth), boot.CSRFToken, login.ChallengeID, code)
	if err != nil {
		t.Fatalf("mfa: %v", err)
	}
	if result.Principal == nil {
		t.Fatal("mfa did not create a principal")
	}

	admin.SetClock(func() time.Time { return now.Add(3 * time.Minute) })
	if _, err := admin.ValidateAdminSession(ctx, result.Cookie); err == nil {
		t.Fatal("expired admin session was accepted")
	}
	admin.SetClock(func() time.Time { return now })

	paused, err := admin.InvalidateSessionForSelfTarget(ctx, targetID, targetID, uuid.MustParse(result.Principal.SessionID))
	if err != nil || !paused {
		t.Fatalf("self-target result paused=%v err=%v, want paused=true", paused, err)
	}
	if _, err := admin.ValidateAdminSession(ctx, result.Cookie); err == nil {
		t.Fatal("self-target session remained valid")
	}

	recovered, err := admin.BreakGlassRecoverAdminMFA(ctx, "breakglass-target", &actorID)
	if err != nil {
		t.Fatalf("break-glass recovery: %v", err)
	}
	if recovered.Secret == "" || recovered.UserID != targetID {
		t.Fatalf("break-glass result user=%s secret-present=%v", recovered.UserID, recovered.Secret != "")
	}
	if recovered.Secret == enrollment.Secret {
		t.Fatal("break-glass recovery reused the old TOTP secret")
	}
	audits, err := q.ListAuditEvents(ctx, nil, 100)
	if err != nil {
		t.Fatalf("list audit events: %v", err)
	}
	var foundRecovery, foundSelf bool
	for _, audit := range audits {
		if audit.Action == "admin_break_glass_mfa_recovery" {
			foundRecovery = true
			if audit.ActorID == nil || *audit.ActorID != actorID || audit.TargetAccountID == nil || *audit.TargetAccountID != targetID {
				t.Fatalf("break-glass audit attribution = %#v", audit)
			}
		}
		if audit.Action == "admin_self_target" {
			foundSelf = true
			if audit.ActorID == nil || *audit.ActorID != targetID || audit.TargetAccountID == nil || *audit.TargetAccountID != targetID {
				t.Fatalf("self-target audit attribution = %#v", audit)
			}
		}
	}
	if !foundRecovery || !foundSelf {
		t.Fatalf("audit actions recovery=%v self_target=%v, events=%d", foundRecovery, foundSelf, len(audits))
	}
}

func TestAdminSessionRejectsCompromisedSecurityState(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	consumer := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	userID := createTestUser(t, consumer, "compromised-admin")
	now := time.Now().UTC().Truncate(time.Second)
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("compromise-quota-key"),
	})
	admin.SetClock(func() time.Time { return now })
	enrollment, err := admin.EnrollAdminOperator(ctx, "compromised-admin", []string{"users.read"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	secret, err := normalizedTOTPSecret(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode enrollment secret: %v", err)
	}
	recorder := httptest.NewRecorder()
	bootstrapCtx := middleware.WithAdminResponseWriter(ctx, recorder)
	bootstrapCtx = middleware.WithAdminClientIP(bootstrapCtx, "192.0.2.31")
	boot, err := admin.BootstrapAdminSession(bootstrapCtx)
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	preAuth := recorder.Result().Cookies()[0].Value
	loginCtx := middleware.WithAdminSessionCookie(bootstrapCtx, preAuth)
	login, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "compromised-admin", "password123")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	code, _ := GenerateTOTP(secret, now)
	result, err := admin.CompleteAdminSessionMFA(middleware.WithAdminSessionCookie(loginCtx, preAuth), boot.CSRFToken, login.ChallengeID, code)
	if err != nil {
		t.Fatalf("mfa: %v", err)
	}
	if result.Principal == nil || result.Principal.UserID != userID.String() {
		t.Fatalf("authenticated result = %#v", result)
	}
	if err := q.SetUserSecurityState(ctx, userID, db.SecurityStateCompromised, true, true, ptrTime(time.Now().UTC())); err != nil {
		t.Fatalf("mark compromised: %v", err)
	}
	if _, err := admin.ValidateAdminSession(ctx, result.Cookie); err == nil {
		t.Fatal("compromised account retained an authenticated admin session")
	}
}

func ptrTime(value time.Time) *time.Time { return &value }
