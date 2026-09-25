package service

import (
	"context"
	"encoding/base32"
	"net/http/httptest"
	"reflect"
	"strings"
	"sync"
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
	if principal.RecentMFAAction != "session" || !middleware.RecentMFAActionMatches(principal.RecentMFAAction, "revoke_sessions") {
		t.Fatalf("login MFA proof did not survive session restore: %#v", principal)
	}
	if err := q.RevokeAdminMembership(ctx, userID); err != nil {
		t.Fatalf("revoke membership: %v", err)
	}
	if _, err := admin.ValidateAdminSession(authenticatedCtx, result.Cookie); err == nil {
		t.Fatal("demoted operator retained an authenticated session")
	}
}

func TestBootstrapInitialAdminFromConfigCreatesLoginWithoutResetOnRestart(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"),
		HMACKey:       []byte("bootstrap-quota-key-32-bytes-long!!"),
	})
	seed := bootstrapTestSeed()
	created, err := admin.BootstrapInitialAdmin(ctx, AdminBootstrapCredentials{
		Username: "env-operator", Password: "initial-password-123", TOTPSecret: seed,
	})
	if err != nil || !created {
		t.Fatalf("bootstrap created = %v, err = %v", created, err)
	}
	user, err := q.GetUserByUsername(ctx, "env-operator")
	if err != nil || user == nil || !password.Verify(user.Password, "initial-password-123") {
		t.Fatalf("bootstrapped account = %#v, err = %v", user, err)
	}
	membership, err := q.GetAdminMembership(ctx, user.ID)
	if err != nil || membership == nil || !membership.Active || !containsString(membership.Permissions, "campaigns.write") {
		t.Fatalf("bootstrapped membership = %#v, err = %v", membership, err)
	}
	recorder := httptest.NewRecorder()
	bootstrapCtx := middleware.WithAdminClientIP(middleware.WithAdminResponseWriter(ctx, recorder), "192.0.2.10")
	boot, err := admin.BootstrapAdminSession(bootstrapCtx)
	if err != nil {
		t.Fatalf("browser bootstrap: %v", err)
	}
	loginCtx := middleware.WithAdminSessionCookie(bootstrapCtx, recorder.Result().Cookies()[0].Value)
	login, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "env-operator", "initial-password-123")
	if err != nil {
		t.Fatalf("bootstrapped admin login: %v", err)
	}
	secretBytes, _ := normalizedTOTPSecret(seed)
	code, _ := GenerateTOTP(secretBytes, admin.currentTime())
	session, err := admin.CompleteAdminSessionMFA(loginCtx, login.CSRFToken, login.ChallengeID, code)
	if err != nil || session.Principal == nil || session.Principal.UserID != user.ID.String() {
		t.Fatalf("bootstrapped admin MFA session = %#v, err = %v", session, err)
	}
	created, err = admin.BootstrapInitialAdmin(ctx, AdminBootstrapCredentials{
		Username: "replacement-operator", Password: "different-password-123", TOTPSecret: seed,
	})
	if err != nil || created {
		t.Fatalf("restart created = %v, err = %v", created, err)
	}
	if replacement, err := q.GetUserByUsername(ctx, "replacement-operator"); err != nil || replacement != nil {
		t.Fatalf("replacement account = %#v, err = %v", replacement, err)
	}
	user, err = q.GetUserByUsername(ctx, "env-operator")
	if err != nil || !password.Verify(user.Password, "initial-password-123") || password.Verify(user.Password, "different-password-123") {
		t.Fatal("restart changed the original administrator password")
	}
}

func TestBootstrapInitialAdminFromConfigRejectsUsernameTakeover(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	consumer := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	userID := createTestUser(t, consumer, "existing-user")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"),
		HMACKey:       []byte("bootstrap-quota-key-32-bytes-long!!"),
	})
	_, err := admin.BootstrapInitialAdmin(ctx, AdminBootstrapCredentials{
		Username: "existing-user", Password: "attacker-password-123", TOTPSecret: bootstrapTestSeed(),
	})
	if err == nil {
		t.Fatal("existing consumer username was enrolled as administrator")
	}
	if membership, err := q.GetAdminMembership(ctx, userID); err != nil || membership != nil {
		t.Fatalf("existing account membership = %#v, err = %v", membership, err)
	}
	user, err := q.GetUserByUsername(ctx, "existing-user")
	if err != nil || !password.Verify(user.Password, "password123") {
		t.Fatal("existing account password changed")
	}
}

func bootstrapTestSeed() string {
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString([]byte("12345678901234567890"))
}

func TestReloadAdminActorUsesFreshMembershipAndGeneration(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	userID := createTestUser(t, auth, "bulk-reload-operator")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("bulk-reload-quota-key"),
	})
	if _, err := admin.EnrollAdminOperator(ctx, "bulk-reload-operator", []string{"campaign.email", "jobs.execute_all"}); err != nil {
		t.Fatalf("enroll operator: %v", err)
	}
	state, err := q.GetUserSecurityState(ctx, userID)
	if err != nil || state == nil {
		t.Fatalf("security state: %v %#v", err, state)
	}
	actor, err := admin.ReloadAdminActor(ctx, userID)
	if err != nil {
		t.Fatalf("reload actor: %v", err)
	}
	if !actor.Valid() || actor.AuthGeneration != state.AuthGeneration || !actor.Can("campaign.email") || !actor.Can("jobs.execute_all") {
		t.Fatalf("reloaded actor = %#v, want active membership and current generation", actor)
	}

	if _, err := q.AdvanceUserAuthGeneration(ctx, userID); err != nil {
		t.Fatalf("advance auth generation: %v", err)
	}
	advanced, err := admin.ReloadAdminActor(ctx, userID)
	if err != nil {
		t.Fatalf("reload advanced actor: %v", err)
	}
	if !advanced.Valid() || advanced.AuthGeneration <= actor.AuthGeneration {
		t.Fatalf("advanced actor = %#v, want fresh generation", advanced)
	}

	if err := q.RevokeAdminMembership(ctx, userID); err != nil {
		t.Fatalf("revoke membership: %v", err)
	}
	revoked, err := admin.ReloadAdminActor(ctx, userID)
	if err != nil {
		t.Fatalf("reload revoked actor: %v", err)
	}
	if revoked.Valid() || revoked.ID != userID {
		t.Fatalf("revoked actor = %#v, want invalid actor with stable ID", revoked)
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

func TestAdminThrottleAdmissionPrecedesPasswordAndMFAVerification(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	hash, err := password.Hash("password123")
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	userID, err := q.CreateUser(ctx, "preverify-throttle-admin", hash, nil, nil)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("preverify-throttle-key"),
		ChallengeTTL: time.Hour, PreAuthTTL: time.Hour, LoginFailureLimit: 1, LoginIPLimit: 100, LoginGlobalLimit: 1000,
	})
	admin.SetClock(func() time.Time { return now })
	enrollment, err := admin.EnrollAdminOperator(ctx, "preverify-throttle-admin", []string{"users.read", "jobs.create"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	secret, err := normalizedTOTPSecret(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode secret: %v", err)
	}
	recorder := httptest.NewRecorder()
	base := middleware.WithAdminResponseWriter(ctx, recorder)
	base = middleware.WithAdminClientIP(base, "192.0.2.41")
	boot, err := admin.BootstrapAdminSession(base)
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	preAuth := recorder.Result().Cookies()[0].Value
	loginCtx := middleware.WithAdminSessionCookie(base, preAuth)
	if _, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "preverify-throttle-admin", "wrong-password"); err != ErrAdminUnauthorized {
		t.Fatalf("first bad password err=%v, want unauthorized", err)
	}
	if _, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "preverify-throttle-admin", "password123"); err != ErrAdminRateLimited {
		t.Fatalf("correct password in exhausted window err=%v, want rate limited", err)
	}

	now = now.Add(16 * time.Minute)
	login, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "preverify-throttle-admin", "password123")
	if err != nil {
		t.Fatalf("correct password after window: %v", err)
	}
	wrongCode := "000000"
	if _, err := admin.CompleteAdminSessionMFA(loginCtx, boot.CSRFToken, login.ChallengeID, wrongCode); err != ErrAdminUnauthorized {
		t.Fatalf("first bad mfa err=%v, want unauthorized", err)
	}
	code, _ := GenerateTOTP(secret, now)
	if _, err := admin.CompleteAdminSessionMFA(loginCtx, boot.CSRFToken, login.ChallengeID, code); err != ErrAdminRateLimited {
		t.Fatalf("correct mfa in exhausted window err=%v, want rate limited", err)
	}

	now = now.Add(16 * time.Minute)
	code, _ = GenerateTOTP(secret, now)
	session, err := admin.CompleteAdminSessionMFA(loginCtx, boot.CSRFToken, login.ChallengeID, code)
	if err != nil {
		t.Fatalf("correct mfa after window: %v", err)
	}

	// Step-up uses the same pre-verification gate as password and initial MFA:
	// once a failed proof consumes the account bucket, a correct proof remains
	// rejected until the shared window rolls over.
	authCtx := middleware.WithAdminSessionCookie(base, session.Cookie)
	if _, err := admin.ReauthenticateAdminSession(authCtx, session.CSRFToken, "jobs.create", "000000"); err != ErrAdminUnauthorized {
		t.Fatalf("first bad step-up err=%v, want unauthorized", err)
	}
	code, _ = GenerateTOTP(secret, now)
	if _, err := admin.ReauthenticateAdminSession(authCtx, session.CSRFToken, "jobs.create", code); err != ErrAdminRateLimited {
		t.Fatalf("correct step-up in exhausted window err=%v, want rate limited", err)
	}
	now = now.Add(16 * time.Minute)
	code, _ = GenerateTOTP(secret, now)
	if _, err := admin.ReauthenticateAdminSession(authCtx, session.CSRFToken, "jobs.create", code); err != nil {
		t.Fatalf("correct step-up after window: %v", err)
	}
	_ = userID
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
	if _, err := admin.EnrollAdminOperator(ctx, "breakglass-actor", []string{"security.recovery_resend"}); err != nil {
		t.Fatalf("enroll break-glass actor: %v", err)
	}
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

func TestAdminMFAReplayScopeIsSharedAcrossSessions(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	userID := createTestUser(t, auth, "replay-scope-admin")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("replay-scope-quota-key"),
	})
	if _, err := admin.EnrollAdminOperator(ctx, "replay-scope-admin", []string{"users.read"}); err != nil {
		t.Fatalf("enroll: %v", err)
	}
	membership, err := q.GetAdminMembership(ctx, userID)
	if err != nil || membership == nil {
		t.Fatalf("membership: %v %#v", err, membership)
	}
	counter := time.Now().Unix() / 30
	if _, accepted, err := q.AdvanceAdminMFAReplayScope(ctx, membership.ID, userID, counter); err != nil || !accepted {
		t.Fatalf("first counter accepted=%v err=%v", accepted, err)
	}
	if _, accepted, err := q.AdvanceAdminMFAReplayScope(ctx, membership.ID, userID, counter); err != nil || accepted {
		t.Fatalf("replayed counter accepted=%v err=%v", accepted, err)
	}
	if _, accepted, err := q.AdvanceAdminMFAReplayScope(ctx, membership.ID, userID, counter+1); err != nil || !accepted {
		t.Fatalf("next counter accepted=%v err=%v", accepted, err)
	}
}

func TestAdminMFAReplayScopeAllowsCounterOnceConcurrently(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	userID := createTestUser(t, auth, "concurrent-replay-admin")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("concurrent-replay-quota-key"),
	})
	if _, err := admin.EnrollAdminOperator(ctx, "concurrent-replay-admin", []string{"users.read"}); err != nil {
		t.Fatalf("enroll: %v", err)
	}
	membership, err := q.GetAdminMembership(ctx, userID)
	if err != nil || membership == nil {
		t.Fatalf("membership: %v %#v", err, membership)
	}

	const attempts = 8
	start := make(chan struct{})
	accepted := make(chan bool, attempts)
	errs := make(chan error, attempts)
	var wg sync.WaitGroup
	for i := 0; i < attempts; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, ok, err := q.AdvanceAdminMFAReplayScope(ctx, membership.ID, userID, 7_000_000)
			accepted <- ok
			errs <- err
		}()
	}
	close(start)
	wg.Wait()
	close(accepted)
	close(errs)
	acceptedCount := 0
	for ok := range accepted {
		if ok {
			acceptedCount++
		}
	}
	for err := range errs {
		if err != nil {
			t.Fatalf("concurrent replay update: %v", err)
		}
	}
	if acceptedCount != 1 {
		t.Fatalf("concurrent replay accepted=%d, want 1", acceptedCount)
	}

	// A second wave with the same moving factor models independent browser
	// sessions replaying one TOTP code at the same instant. Exactly one update
	// can win the conditional ON CONFLICT update.
	start = make(chan struct{})
	accepted = make(chan bool, attempts)
	errs = make(chan error, attempts)
	for i := 0; i < attempts; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, ok, err := q.AdvanceAdminMFAReplayScope(ctx, membership.ID, userID, 7_000_000)
			accepted <- ok
			errs <- err
		}()
	}
	close(start)
	wg.Wait()
	close(accepted)
	close(errs)
	acceptedCount = 0
	for ok := range accepted {
		if ok {
			acceptedCount++
		}
	}
	for err := range errs {
		if err != nil {
			t.Fatalf("concurrent replay rejection: %v", err)
		}
	}
	if acceptedCount != 0 {
		t.Fatalf("concurrent replay accepted=%d, want 0", acceptedCount)
	}
}

func TestAdminStepUpReplayIsRejectedAtServiceBoundaryConcurrently(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	now := time.Unix(1_700_000_000, 0).UTC()
	consumer := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	createTestUser(t, consumer, "concurrent-step-up-admin")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("concurrent-step-up-quota-key"),
	})
	admin.SetClock(func() time.Time { return now })
	enrollment, err := admin.EnrollAdminOperator(ctx, "concurrent-step-up-admin", []string{"jobs.create"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	secret, err := normalizedTOTPSecret(enrollment.Secret)
	if err != nil {
		t.Fatalf("decode secret: %v", err)
	}

	bootstrapRecorder := httptest.NewRecorder()
	bootstrapCtx := middleware.WithAdminResponseWriter(ctx, bootstrapRecorder)
	bootstrapCtx = middleware.WithAdminClientIP(bootstrapCtx, "192.0.2.60")
	boot, err := admin.BootstrapAdminSession(bootstrapCtx)
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	preAuthCookie := bootstrapRecorder.Result().Cookies()[0].Value
	loginCtx := middleware.WithAdminSessionCookie(bootstrapCtx, preAuthCookie)
	login, err := admin.AdminSessionLogin(loginCtx, boot.CSRFToken, "concurrent-step-up-admin", "password123")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	code, _ := GenerateTOTP(secret, now)
	initial, err := admin.CompleteAdminSessionMFA(loginCtx, boot.CSRFToken, login.ChallengeID, code)
	if err != nil {
		t.Fatalf("complete mfa: %v", err)
	}
	secretPart, _, ok := authenticatedCookieParts(initial.Cookie)
	if !ok {
		t.Fatalf("authenticated cookie was malformed: %q", initial.Cookie)
	}
	stored, err := q.GetAdminSessionByHash(ctx, hashOpaque(secretPart))
	if err != nil {
		t.Fatalf("load initial session: %v", err)
	}
	if stored == nil {
		t.Fatal("initial MFA session was not persisted")
	}
	if stored.RecentMFAAction == nil || strings.TrimSpace(*stored.RecentMFAAction) != "session" {
		t.Fatalf("initial MFA persisted action = %v, want session", stored.RecentMFAAction)
	}

	now = now.Add(31 * time.Second)
	stepUpCode, _ := GenerateTOTP(secret, now)
	stepUpCtx := middleware.WithAdminClientIP(ctx, "192.0.2.60")
	stepUpCtx = middleware.WithAdminSessionCookie(stepUpCtx, initial.Cookie)
	const attempts = 2
	start := make(chan struct{})
	results := make(chan error, attempts)
	var wg sync.WaitGroup
	for i := 0; i < attempts; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, err := admin.ReauthenticateAdminSession(stepUpCtx, initial.CSRFToken, "jobs.create", stepUpCode)
			results <- err
		}()
	}
	close(start)
	wg.Wait()
	close(results)

	var accepted, rejected int
	for err := range results {
		switch {
		case err == nil:
			accepted++
		case err == ErrAdminUnauthorized:
			rejected++
		default:
			t.Fatalf("concurrent step-up err = %v, want one success and one unauthorized replay", err)
		}
	}
	if accepted != 1 || rejected != 1 {
		t.Fatalf("concurrent step-up accepted=%d rejected=%d, want 1/1", accepted, rejected)
	}
}

func TestAdminPreAuthEnvelopeExpiresAtOriginalDeadline(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	now := time.Now().UTC().Truncate(time.Second)
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("preauth-expiry-quota-key"),
		PreAuthTTL: 5 * time.Minute,
	})
	admin.SetClock(func() time.Time { return now })

	firstRecorder := httptest.NewRecorder()
	base := middleware.WithAdminClientIP(ctx, "192.0.2.50")
	firstCtx := middleware.WithAdminResponseWriter(base, firstRecorder)
	first, err := admin.BootstrapAdminSession(firstCtx)
	if err != nil {
		t.Fatalf("first bootstrap: %v", err)
	}
	firstCookies := firstRecorder.Result().Cookies()
	if len(firstCookies) != 1 {
		t.Fatalf("first cookie count = %d", len(firstCookies))
	}
	preAuth := firstCookies[0].Value
	expiresAt := first.ExpiresAt

	now = now.Add(2 * time.Minute)
	secondRecorder := httptest.NewRecorder()
	secondCtx := middleware.WithAdminResponseWriter(middleware.WithAdminSessionCookie(base, preAuth), secondRecorder)
	second, err := admin.BootstrapAdminSession(secondCtx)
	if err != nil {
		t.Fatalf("renewal bootstrap: %v", err)
	}
	if second.ExpiresAt != expiresAt {
		t.Fatalf("renewal moved pre-auth deadline from %v to %v", expiresAt, second.ExpiresAt)
	}
	secondCookies := secondRecorder.Result().Cookies()
	if len(secondCookies) != 1 || secondCookies[0].Value != preAuth || !secondCookies[0].Expires.Equal(expiresAt) {
		t.Fatalf("renewed pre-auth cookie = %#v, want original value/deadline", secondCookies)
	}

	now = expiresAt.Add(time.Second)
	thirdRecorder := httptest.NewRecorder()
	thirdCtx := middleware.WithAdminResponseWriter(middleware.WithAdminSessionCookie(base, preAuth), thirdRecorder)
	third, err := admin.BootstrapAdminSession(thirdCtx)
	if err != nil {
		t.Fatalf("expired bootstrap: %v", err)
	}
	thirdCookies := thirdRecorder.Result().Cookies()
	if len(thirdCookies) != 1 || thirdCookies[0].Value == preAuth || !third.ExpiresAt.After(now) {
		t.Fatalf("expired pre-auth was reused: result=%#v cookies=%#v", third, thirdCookies)
	}
	if _, err := admin.AdminSessionLogin(middleware.WithAdminSessionCookie(base, preAuth), second.CSRFToken, "nobody", "password"); err != ErrAdminUnauthorized {
		t.Fatalf("expired pre-auth login err=%v, want %v", err, ErrAdminUnauthorized)
	}
}

func TestBreakGlassRecoveryRequiresActiveMembership(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	userID := createTestUser(t, auth, "inactive-breakglass-admin")
	actorID := createTestUser(t, auth, "active-breakglass-actor")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("inactive-breakglass-quota-key"),
	})
	if _, err := admin.EnrollAdminOperator(ctx, "active-breakglass-actor", []string{"security.recovery_resend"}); err != nil {
		t.Fatalf("enroll actor: %v", err)
	}
	enrollment, err := admin.EnrollAdminOperator(ctx, "inactive-breakglass-admin", []string{"users.read"})
	if err != nil {
		t.Fatalf("enroll: %v", err)
	}
	membership, err := q.GetAdminMembership(ctx, userID)
	if err != nil || membership == nil {
		t.Fatalf("membership: %v %#v", err, membership)
	}
	if err := q.UpsertAdminMembership(ctx, db.AdminMembershipParams{
		ID: membership.ID, UserID: membership.UserID, Permissions: membership.Permissions, Active: false,
		TotpSecretCiphertext: membership.TotpSecretCiphertext, TotpKeyID: membership.TotpKeyID, TotpEnrolledAt: membership.TotpEnrolledAt,
		RevokedAt: membership.RevokedAt,
	}); err != nil {
		t.Fatalf("disable membership: %v", err)
	}
	if _, err := admin.BreakGlassRecoverAdminMFA(ctx, "inactive-breakglass-admin", &actorID); err != ErrAdminForbidden {
		t.Fatalf("inactive recovery err=%v, want %v", err, ErrAdminForbidden)
	}
	after, err := q.GetAdminMembership(ctx, userID)
	if err != nil || after == nil {
		t.Fatalf("membership after rejection: %v %#v", err, after)
	}
	if after.Active || string(after.TotpSecretCiphertext) != string(membership.TotpSecretCiphertext) || enrollment.Secret == "" {
		t.Fatalf("inactive membership changed: before=%#v after=%#v", membership, after)
	}
	revokedAt := time.Now().UTC()
	if err := q.UpsertAdminMembership(ctx, db.AdminMembershipParams{
		ID: after.ID, UserID: after.UserID, Permissions: after.Permissions, Active: true,
		TotpSecretCiphertext: after.TotpSecretCiphertext, TotpKeyID: after.TotpKeyID, TotpEnrolledAt: after.TotpEnrolledAt,
		RevokedAt: &revokedAt,
	}); err != nil {
		t.Fatalf("revoke membership: %v", err)
	}
	revokedBefore, err := q.GetAdminMembership(ctx, userID)
	if err != nil || revokedBefore == nil {
		t.Fatalf("revoked membership before recovery: %v %#v", err, revokedBefore)
	}
	if _, err := admin.BreakGlassRecoverAdminMFA(ctx, "inactive-breakglass-admin", &actorID); err != ErrAdminForbidden {
		t.Fatalf("revoked recovery err=%v, want %v", err, ErrAdminForbidden)
	}
	revoked, err := q.GetAdminMembership(ctx, userID)
	if err != nil || revoked == nil || !reflect.DeepEqual(*revokedBefore, *revoked) {
		t.Fatalf("revoked membership changed: %v %#v", err, revoked)
	}
}

func TestBreakGlassRecoveryRejectsInvalidActorStateBeforeMutation(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	targetID := createTestUser(t, auth, "breakglass-actor-state-target")
	actorID := createTestUser(t, auth, "breakglass-actor-state-actor")
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("actor-state-quota-key"),
	})
	if _, err := admin.EnrollAdminOperator(ctx, "breakglass-actor-state-target", []string{"users.read"}); err != nil {
		t.Fatalf("enroll target: %v", err)
	}
	if _, err := admin.EnrollAdminOperator(ctx, "breakglass-actor-state-actor", []string{"security.recovery_resend"}); err != nil {
		t.Fatalf("enroll actor: %v", err)
	}
	targetMembership, err := q.GetAdminMembership(ctx, targetID)
	if err != nil || targetMembership == nil {
		t.Fatalf("target membership: %v %#v", err, targetMembership)
	}
	originalCiphertext := string(targetMembership.TotpSecretCiphertext)
	assertRejectedWithoutMutation := func(name string) {
		t.Helper()
		if _, err := admin.BreakGlassRecoverAdminMFA(ctx, "breakglass-actor-state-target", &actorID); err != ErrAdminForbidden {
			t.Fatalf("%s actor err=%v, want %v", name, err, ErrAdminForbidden)
		}
		current, err := q.GetAdminMembership(ctx, targetID)
		if err != nil || current == nil || string(current.TotpSecretCiphertext) != originalCiphertext {
			t.Fatalf("%s actor mutated target membership: %v %#v", name, err, current)
		}
	}
	setActorMembership := func(active bool, revokedAt *time.Time) {
		t.Helper()
		membership, err := q.GetAdminMembership(ctx, actorID)
		if err != nil || membership == nil {
			t.Fatalf("actor membership: %v %#v", err, membership)
		}
		if err := q.UpsertAdminMembership(ctx, db.AdminMembershipParams{
			ID: membership.ID, UserID: membership.UserID, Permissions: membership.Permissions, Active: active,
			TotpSecretCiphertext: membership.TotpSecretCiphertext, TotpKeyID: membership.TotpKeyID,
			TotpEnrolledAt: membership.TotpEnrolledAt, RevokedAt: revokedAt,
		}); err != nil {
			t.Fatalf("set actor membership: %v", err)
		}
	}

	setActorMembership(false, nil)
	assertRejectedWithoutMutation("inactive")
	setActorMembership(true, nil)

	revokedAt := time.Now().UTC()
	setActorMembership(true, &revokedAt)
	assertRejectedWithoutMutation("revoked")
	setActorMembership(true, nil)

	if err := q.SetUserSecurityState(ctx, actorID, db.SecurityStateNormal, true, false, nil); err != nil {
		t.Fatalf("disable actor password: %v", err)
	}
	assertRejectedWithoutMutation("password-disabled")
	if err := q.SetUserSecurityState(ctx, actorID, db.SecurityStateNormal, false, false, nil); err != nil {
		t.Fatalf("restore actor password: %v", err)
	}

	compromisedAt := time.Now().UTC()
	if err := q.SetUserSecurityState(ctx, actorID, db.SecurityStateCompromised, false, false, &compromisedAt); err != nil {
		t.Fatalf("compromise actor: %v", err)
	}
	compromisedState, err := q.GetUserSecurityState(ctx, actorID)
	if err != nil || compromisedState == nil || compromisedState.SecurityState != db.SecurityStateCompromised || compromisedState.PasswordDisabled || compromisedState.PasswordResetRequired || compromisedState.CompromisedAt == nil {
		t.Fatalf("compromised actor state = %v %#v", err, compromisedState)
	}
	assertRejectedWithoutMutation("compromised")
}

func TestBreakGlassRecoveryRequiresAuthorizedStableActor(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	auth := NewAuth(q, token.NewHelper("consumer-secret", time.Minute), &config.Config{MaxLoginAttempts: 10})
	targetID := createTestUser(t, auth, "breakglass-recovery-target")
	consumerID := createTestUser(t, auth, "breakglass-consumer-actor")
	unknownID := uuid.New()
	admin := NewAdminAuth(q, AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"), HMACKey: []byte("authorized-actor-quota-key"),
	})
	targetEnrollment, err := admin.EnrollAdminOperator(ctx, "breakglass-recovery-target", []string{"users.read"})
	if err != nil {
		t.Fatalf("enroll target: %v", err)
	}
	if targetEnrollment.Secret == "" {
		t.Fatal("target enrollment did not return a secret")
	}
	targetMembership, err := q.GetAdminMembership(ctx, targetID)
	if err != nil || targetMembership == nil {
		t.Fatalf("target membership: %v %#v", err, targetMembership)
	}
	originalCiphertext := string(targetMembership.TotpSecretCiphertext)

	for name, candidate := range map[string]*uuid.UUID{
		"missing":  nil,
		"unknown":  &unknownID,
		"consumer": &consumerID,
	} {
		if _, err := admin.BreakGlassRecoverAdminMFA(ctx, "breakglass-recovery-target", candidate); err != ErrAdminForbidden {
			t.Fatalf("%s actor err=%v, want %v", name, err, ErrAdminForbidden)
		}
		current, err := q.GetAdminMembership(ctx, targetID)
		if err != nil || current == nil || string(current.TotpSecretCiphertext) != originalCiphertext {
			t.Fatalf("%s actor mutated target membership: %v %#v", name, err, current)
		}
	}

	if _, err := admin.EnrollAdminOperator(ctx, "breakglass-consumer-actor", []string{"users.read"}); err != nil {
		t.Fatalf("enroll insufficient actor: %v", err)
	}
	if _, err := admin.BreakGlassRecoverAdminMFA(ctx, "breakglass-recovery-target", &consumerID); err != ErrAdminForbidden {
		t.Fatalf("insufficient actor err=%v, want %v", err, ErrAdminForbidden)
	}
	current, err := q.GetAdminMembership(ctx, targetID)
	if err != nil || current == nil || string(current.TotpSecretCiphertext) != originalCiphertext {
		t.Fatalf("insufficient actor mutated target membership: %v %#v", err, current)
	}

	if _, err := admin.EnrollAdminOperator(ctx, "breakglass-consumer-actor", []string{"security.recovery_resend"}); err != nil {
		t.Fatalf("upgrade actor permission: %v", err)
	}
	recovered, err := admin.BreakGlassRecoverAdminMFA(ctx, "breakglass-recovery-target", &consumerID)
	if err != nil {
		t.Fatalf("authorized recovery: %v", err)
	}
	if recovered == nil || recovered.Secret == "" {
		t.Fatal("authorized recovery did not return a secret")
	}
	audits, err := q.ListAuditEvents(ctx, nil, 100)
	if err != nil {
		t.Fatalf("list audit events: %v", err)
	}
	for _, audit := range audits {
		if audit.Action != "admin_break_glass_mfa_recovery" {
			continue
		}
		if audit.ActorID == nil || *audit.ActorID != consumerID || audit.TargetAccountID == nil || *audit.TargetAccountID != targetID {
			t.Fatalf("recovery audit attribution = %#v", audit)
		}
		return
	}
	t.Fatal("authorized recovery audit was not recorded")
}

func ptrTime(value time.Time) *time.Time { return &value }
