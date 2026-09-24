package service

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/base32"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/password"
)

const (
	adminSessionCookieName          = "admin_session"
	adminSessionCookiePath          = "/"
	adminSessionStatePreAuth        = "pre_auth"
	adminSessionStateAuthenticated  = "authenticated"
	adminSessionStateRevoked        = "revoked"
	adminChallengeWindow            = 15 * time.Minute
	adminDefaultChallengeTTL        = 5 * time.Minute
	adminDefaultIdleTTL             = 30 * time.Minute
	adminDefaultAbsoluteTTL         = 8 * time.Hour
	adminDefaultRecentMFATTL        = 5 * time.Minute
	adminDefaultPreAuthTTL          = 10 * time.Minute
	adminDefaultQuotaLimit          = 5
	adminDefaultIPQuotaLimit        = 100
	adminDefaultGlobalQuotaLimit    = 1000
	adminDefaultMaxPermissionCount  = 100
	adminDefaultMaxPermissionLength = 128
)

// AdminSessionCookieName is the browser cookie shared by the admin transport.
const AdminSessionCookieName = adminSessionCookieName

var (
	ErrAdminUnauthorized        = apperrors.New(http.StatusUnauthorized, "admin authentication is required")
	ErrAdminForbidden           = apperrors.New(http.StatusForbidden, "admin capability is required")
	ErrAdminRateLimited         = apperrors.New(http.StatusTooManyRequests, "too many admin authentication attempts")
	ErrAdminUnavailable         = apperrors.New(http.StatusServiceUnavailable, "admin authentication is unavailable")
	ErrAdminInvalidCSRF         = apperrors.New(http.StatusForbidden, "invalid csrf token")
	ErrAdminInvalidChallenge    = apperrors.New(http.StatusUnauthorized, "invalid admin challenge")
	ErrAdminInvalidAction       = apperrors.New(http.StatusBadRequest, "invalid admin action")
	ErrAdminInvalidSetupRequest = apperrors.New(http.StatusBadRequest, "invalid initial admin setup request")
	ErrAdminEnrollmentKey       = errors.New("admin enrollment encryption key is unavailable")
)

// AdminAuthConfig contains deploy-time bounds and key material. EncryptionKey
// is required for TOTP enrollment; HMACKey is required for shared failure
// quotas. No key is ever included in a response or audit event.
type AdminAuthConfig struct {
	EncryptionKey      []byte
	EncryptionKeyID    string
	HMACKey            []byte
	HMACKeyID          string
	FirstRunToken      string
	SessionIdleTTL     time.Duration
	SessionAbsoluteTTL time.Duration
	ChallengeTTL       time.Duration
	RecentMFATTL       time.Duration
	PreAuthTTL         time.Duration
	LoginFailureLimit  int64
	LoginIPLimit       int64
	LoginGlobalLimit   int64
	AdminOrigin        string
}

func (c AdminAuthConfig) withDefaults() AdminAuthConfig {
	if c.SessionIdleTTL <= 0 {
		c.SessionIdleTTL = adminDefaultIdleTTL
	}
	if c.SessionAbsoluteTTL <= 0 {
		c.SessionAbsoluteTTL = adminDefaultAbsoluteTTL
	}
	if c.ChallengeTTL <= 0 {
		c.ChallengeTTL = adminDefaultChallengeTTL
	}
	if c.RecentMFATTL <= 0 {
		c.RecentMFATTL = adminDefaultRecentMFATTL
	}
	if c.PreAuthTTL <= 0 {
		c.PreAuthTTL = adminDefaultPreAuthTTL
	}
	if c.LoginFailureLimit <= 0 {
		c.LoginFailureLimit = adminDefaultQuotaLimit
	}
	if c.LoginIPLimit <= 0 {
		c.LoginIPLimit = adminDefaultIPQuotaLimit
	}
	if c.LoginGlobalLimit <= 0 {
		c.LoginGlobalLimit = adminDefaultGlobalQuotaLimit
	}
	if c.EncryptionKeyID == "" {
		c.EncryptionKeyID = "admin-totp-v1"
	}
	if c.HMACKeyID == "" {
		c.HMACKeyID = "admin-quota-v1"
	}
	return c
}

// AdminAuth owns the browser-admin authentication boundary. It deliberately
// accepts the concrete DB facade so transaction callbacks can use the caller's
// transaction rather than opening a pool escape.
type AdminAuth struct {
	q      *db.Queries
	cfg    AdminAuthConfig
	now    func() time.Time
	random func([]byte) error
	mu     sync.RWMutex
}

func NewAdminAuth(q *db.Queries, cfg AdminAuthConfig) *AdminAuth {
	cfg = cfg.withDefaults()
	return &AdminAuth{q: q, cfg: cfg, now: time.Now, random: func(b []byte) error { _, err := rand.Read(b); return err }}
}

// RecentMFATTL matches the authenticated session's absolute lifetime. The
// login MFA proof remains valid while that session is valid.
func (a *AdminAuth) RecentMFATTL() time.Duration {
	if a == nil {
		return 0
	}
	return a.cfg.SessionAbsoluteTTL
}

// ReloadAdminActor refreshes the account security state and admin membership
// used by a durable bulk worker. Session-bound MFA proof is intentionally not
// reconstructed here; the bulk service carries that proof from the
// authenticated request while taking the membership, generation, and
// capability fields from this fresh lookup.
//
// Invalid or revoked state is returned as an invalid actor so the caller can
// pause its durable job with an authorization outcome. Storage failures are
// returned as an unavailable error and never produce a usable actor.
func (a *AdminAuth) ReloadAdminActor(ctx context.Context, userID uuid.UUID) (AdminActor, error) {
	if a == nil || a.q == nil {
		return AdminActor{}, ErrAdminUnavailable
	}
	if userID == uuid.Nil {
		return AdminActor{}, ErrAdminUnauthorized
	}
	state, err := a.q.GetUserSecurityState(ctx, userID)
	if err != nil {
		return AdminActor{}, ErrAdminUnavailable
	}
	membership, err := a.q.GetAdminMembership(ctx, userID)
	if err != nil {
		return AdminActor{}, ErrAdminUnavailable
	}
	actor := AdminActor{ID: userID, State: adminSessionStateRevoked}
	if state != nil {
		actor.AuthGeneration = state.AuthGeneration
	}
	if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired ||
		membership == nil || !membership.Active || membership.RevokedAt != nil || len(membership.TotpSecretCiphertext) == 0 || membership.TotpKeyID == nil {
		return actor, nil
	}
	permissions := append([]string(nil), membership.Permissions...)
	actor.State = adminSessionStateAuthenticated
	actor.Permissions = permissions
	actor.Capabilities = CapabilitiesForPermissions(permissions)
	return actor, nil
}

var _ AdminActorReloader = (*AdminAuth)(nil)

func (a *AdminAuth) SetClock(now func() time.Time) {
	if now == nil {
		now = time.Now
	}
	a.mu.Lock()
	a.now = now
	a.mu.Unlock()
}

func (a *AdminAuth) currentTime() time.Time {
	a.mu.RLock()
	now := a.now
	a.mu.RUnlock()
	return now().UTC()
}

func (a *AdminAuth) SetRandomReader(fn func([]byte) error) {
	if fn == nil {
		fn = func(b []byte) error { _, err := rand.Read(b); return err }
	}
	a.mu.Lock()
	a.random = fn
	a.mu.Unlock()
}

func (a *AdminAuth) randomBytes(n int) ([]byte, error) {
	if n <= 0 {
		return nil, errors.New("invalid random length")
	}
	b := make([]byte, n)
	a.mu.RLock()
	fn := a.random
	a.mu.RUnlock()
	if err := fn(b); err != nil {
		return nil, err
	}
	return b, nil
}

func NewOpaqueSecret() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return ""
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func opaqueSecret(randomFn func([]byte) error) (string, error) {
	b := make([]byte, 32)
	if err := randomFn(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func hashOpaque(raw string) []byte {
	sum := sha256.Sum256([]byte(raw))
	return sum[:]
}

func hmacDigest(key []byte, parts ...string) []byte {
	h := hmac.New(sha256.New, key)
	for _, part := range parts {
		_, _ = h.Write([]byte(strconv.Itoa(len(part))))
		_, _ = h.Write([]byte(":"))
		_, _ = h.Write([]byte(part))
	}
	return h.Sum(nil)
}

func csrfForPreAuth(cookie string, key []byte) string {
	digest := hmacDigest(key, "admin-preauth-csrf", cookie)
	return base64.RawURLEncoding.EncodeToString(digest)
}

func challengeBinding(challengeID uuid.UUID, cookie string, key []byte) []byte {
	return hmacDigest(key, "admin-challenge", challengeID.String(), cookie)
}

func constantTimeBytesEqual(a, b []byte) bool {
	return len(a) == len(b) && hmac.Equal(a, b)
}

func CapabilitiesForPermissions(permissions []string) []string {
	seen := make(map[string]struct{}, len(permissions))
	result := make([]string, 0, len(permissions))
	for _, permission := range permissions {
		permission = strings.TrimSpace(permission)
		if permission == "" || len(permission) > adminDefaultMaxPermissionLength {
			continue
		}
		if _, ok := seen[permission]; ok {
			continue
		}
		seen[permission] = struct{}{}
		result = append(result, permission)
	}
	sort.Strings(result)
	if len(result) > adminDefaultMaxPermissionCount {
		result = result[:adminDefaultMaxPermissionCount]
	}
	return result
}

func RecentMFAValid(at *time.Time, now time.Time, ttl time.Duration) bool {
	return at != nil && ttl > 0 && !at.After(now) && now.Sub(*at) < ttl
}

func NewAdminSessionCookie(value string, now time.Time, ttl time.Duration) *http.Cookie {
	maxAge := 0
	if ttl > 0 {
		maxAge = int(ttl / time.Second)
	}
	return &http.Cookie{
		Name: adminSessionCookieName, Value: value, Path: adminSessionCookiePath,
		Expires: now.Add(ttl), MaxAge: maxAge, Secure: true, HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
	}
}

func clearAdminSessionCookie(now time.Time) *http.Cookie {
	cookie := NewAdminSessionCookie("", now, -time.Hour)
	cookie.Expires = time.Unix(1, 0).UTC()
	cookie.MaxAge = -1
	return cookie
}

func writeAdminCookie(ctx context.Context, cookie *http.Cookie) {
	if writer, ok := middleware.AdminResponseWriter(ctx); ok && writer != nil {
		http.SetCookie(writer, cookie)
	}
}

func adminCookie(ctx context.Context) string { return middleware.AdminSessionCookie(ctx) }
func adminClientIP(ctx context.Context) string {
	ip := strings.TrimSpace(middleware.AdminClientIP(ctx))
	if ip == "" {
		return "unknown"
	}
	return ip
}

func validPreAuthCookie(cookie string) bool {
	_, _, ok := preAuthCookieParts(cookie)
	return ok
}

func preAuthCookieParts(cookie string) ([]byte, time.Time, bool) {
	parts := strings.Split(cookie, ".")
	if len(parts) != 3 || parts[0] != "p" || len(cookie) > 256 {
		return nil, time.Time{}, false
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil || len(raw) != 32 {
		return nil, time.Time{}, false
	}
	nanos, err := strconv.ParseInt(parts[2], 10, 64)
	if err != nil {
		return nil, time.Time{}, false
	}
	return raw, time.Unix(0, nanos).UTC(), true
}

func preAuthCookieValue(raw []byte, issuedAt time.Time) string {
	return "p." + base64.RawURLEncoding.EncodeToString(raw) + "." + strconv.FormatInt(issuedAt.UnixNano(), 10)
}

func (a *AdminAuth) validPreAuthEnvelope(cookie string) bool {
	_, issuedAt, ok := preAuthCookieParts(cookie)
	if !ok {
		return false
	}
	now := a.currentTime()
	return !issuedAt.After(now) && now.Sub(issuedAt) < a.cfg.PreAuthTTL
}

func authenticatedCookieParts(cookie string) (sessionSecret, csrf string, ok bool) {
	parts := strings.Split(cookie, ".")
	if len(parts) != 3 || parts[0] != "s" || len(parts[1]) < 32 || len(parts[2]) < 16 || len(cookie) > 512 {
		return "", "", false
	}
	if _, err := base64.RawURLEncoding.DecodeString(parts[1]); err != nil {
		return "", "", false
	}
	if _, err := base64.RawURLEncoding.DecodeString(parts[2]); err != nil {
		return "", "", false
	}
	return parts[1], parts[2], true
}

func (a *AdminAuth) preAuthCSRF(cookie string) (string, bool) {
	if !validPreAuthCookie(cookie) {
		return "", false
	}
	return csrfForPreAuth(cookie, a.enrollmentKey()), true
}

func (a *AdminAuth) enrollmentKey() []byte {
	if len(a.cfg.EncryptionKey) > 0 {
		return a.cfg.EncryptionKey
	}
	if len(a.cfg.HMACKey) > 0 {
		sum := sha256.Sum256(a.cfg.HMACKey)
		return sum[:]
	}
	return nil
}

func (a *AdminAuth) encryptionCipher() (cipher.AEAD, error) {
	key := a.cfg.EncryptionKey
	if len(key) == 0 {
		return nil, ErrAdminEnrollmentKey
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("admin enrollment cipher: %w", err)
	}
	return cipher.NewGCM(block)
}

func (a *AdminAuth) encryptTOTP(secret []byte) ([]byte, error) {
	aead, err := a.encryptionCipher()
	if err != nil {
		return nil, err
	}
	nonce, err := a.randomBytes(aead.NonceSize())
	if err != nil {
		return nil, err
	}
	return aead.Seal(nonce, nonce, secret, []byte(a.cfg.EncryptionKeyID)), nil
}

func (a *AdminAuth) decryptTOTP(ciphertext []byte, keyID *string) ([]byte, error) {
	if len(ciphertext) == 0 || keyID == nil || *keyID == "" || *keyID != a.cfg.EncryptionKeyID {
		return nil, ErrAdminEnrollmentKey
	}
	aead, err := a.encryptionCipher()
	if err != nil {
		return nil, err
	}
	if len(ciphertext) < aead.NonceSize() {
		return nil, ErrAdminEnrollmentKey
	}
	nonce, payload := ciphertext[:aead.NonceSize()], ciphertext[aead.NonceSize():]
	return aead.Open(nil, nonce, payload, []byte(*keyID))
}

// TOTP follows RFC 6238's default SHA-1/30-second/6-digit profile, which is
// the profile supported by common authenticator applications. The returned
// counter is persisted after successful verification to prevent replay.
func GenerateTOTP(secret []byte, now time.Time) (string, int64) {
	counter := now.Unix() / 30
	return totpAtCounter(secret, counter), counter
}

func totpAtCounter(secret []byte, counter int64) string {
	if counter < 0 {
		return ""
	}
	var message [8]byte
	binary.BigEndian.PutUint64(message[:], uint64(counter))
	h := hmac.New(sha1.New, secret)
	_, _ = h.Write(message[:])
	digest := h.Sum(nil)
	offset := digest[len(digest)-1] & 0x0f
	value := (uint32(digest[offset])&0x7f)<<24 |
		(uint32(digest[offset+1])&0xff)<<16 |
		(uint32(digest[offset+2])&0xff)<<8 |
		(uint32(digest[offset+3]) & 0xff)
	return fmt.Sprintf("%06d", value%1_000_000)
}

// ValidTOTPCounter returns the accepted counter, allowing a small clock skew.
// It is separate from VerifyTOTP so replay checks can persist the exact
// moving factor that was accepted.
func ValidTOTPCounter(secret []byte, code string, now time.Time, skew int) (int64, bool) {
	code = strings.TrimSpace(code)
	if len(secret) == 0 || len(code) != 6 || skew < 0 {
		return 0, false
	}
	base := now.Unix() / 30
	for delta := -skew; delta <= skew; delta++ {
		counter := base + int64(delta)
		if counter < 0 {
			continue
		}
		candidate := totpAtCounter(secret, counter)
		if hmac.Equal([]byte(candidate), []byte(code)) {
			return counter, true
		}
	}
	return 0, false
}

func VerifyTOTP(secret []byte, code string, now time.Time, skew int) bool {
	_, ok := ValidTOTPCounter(secret, code, now, skew)
	return ok
}

func normalizedTOTPSecret(raw string) ([]byte, error) {
	raw = strings.ToUpper(strings.TrimSpace(raw))
	raw = strings.TrimRight(raw, "=")
	if raw == "" {
		return nil, errors.New("empty totp secret")
	}
	secret, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(raw)
	if err != nil || len(secret) < 10 {
		return nil, errors.New("invalid totp secret")
	}
	return secret, nil
}

func generateTOTPSecret(randomFn func([]byte) error) (string, []byte, error) {
	raw := make([]byte, 20)
	if err := randomFn(raw); err != nil {
		return "", nil, err
	}
	secret := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(raw)
	return secret, raw, nil
}

// GenerateEnrollmentSecret returns a base32 secret suitable for an operator
// enrollment QR/URI. It is intentionally not called from browser endpoints.
func (a *AdminAuth) GenerateEnrollmentSecret() (string, []byte, error) {
	if a == nil {
		return "", nil, ErrAdminEnrollmentKey
	}
	return generateTOTPSecret(func(b []byte) error {
		a.mu.RLock()
		fn := a.random
		a.mu.RUnlock()
		return fn(b)
	})
}

func hashKeyID(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:8])
}

type AdminBootstrapResult struct {
	CSRFToken    string
	SessionState string
	ExpiresAt    time.Time
}

type AdminLoginResult struct {
	ChallengeID  string
	CSRFToken    string
	SessionState string
	ExpiresAt    time.Time
}

// AdminBootstrapCredentials are supplied by deployment configuration and
// consumed only while enrolling the first administrator at startup.
type AdminBootstrapCredentials struct {
	Username   string
	Password   string
	TOTPSecret string
}

// BootstrapInitialAdmin creates a fresh account and admin membership exactly
// once. The durable claim is shared with browser setup, so restarts cannot
// reset credentials or revive bootstrap after the first admin is removed.
func (a *AdminAuth) BootstrapInitialAdmin(ctx context.Context, credentials AdminBootstrapCredentials) (bool, error) {
	if credentials.Username == "" && credentials.Password == "" && credentials.TOTPSecret == "" {
		return false, nil
	}
	if a == nil || a.q == nil {
		return false, ErrAdminUnavailable
	}
	if credentials.Username == "" || credentials.Password == "" || credentials.TOTPSecret == "" {
		return false, errors.New("admin bootstrap requires username, password, and TOTP secret together")
	}
	var created bool
	err := a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		created = false
		claimed, err := tx.ClaimInitialAdminSetup(ctx)
		if err != nil || !claimed {
			return err
		}
		if credentials.Username != strings.TrimSpace(credentials.Username) || len(credentials.Username) > 256 ||
			len(credentials.Password) < 8 || len(credentials.Password) > 256 {
			return errors.New("invalid admin bootstrap username or password length")
		}
		secret, err := normalizedTOTPSecret(credentials.TOTPSecret)
		if err != nil || len(secret) < 20 || len(secret) > 64 {
			return errors.New("invalid admin bootstrap TOTP secret")
		}
		if len(a.cfg.HMACKey) == 0 {
			return errors.New("admin bootstrap HMAC key is required")
		}
		ciphertext, err := a.encryptTOTP(secret)
		if err != nil {
			return fmt.Errorf("admin bootstrap encryption key: %w", err)
		}
		existing, err := tx.GetUserByUsername(ctx, credentials.Username)
		if err != nil {
			return err
		}
		if existing != nil {
			return errors.New("admin bootstrap username already exists")
		}
		hash, err := password.Hash(credentials.Password)
		if err != nil {
			return err
		}
		userID, err := tx.CreateUser(ctx, credentials.Username, hash, nil, nil)
		if err != nil {
			return err
		}
		keyID := a.cfg.EncryptionKeyID
		enrolledAt := a.currentTime()
		if err := tx.UpsertAdminMembership(ctx, db.AdminMembershipParams{
			ID: uuid.New(), UserID: userID, Permissions: firstRunAdminPermissions(), Active: true,
			TotpSecretCiphertext: ciphertext, TotpKeyID: &keyID, TotpEnrolledAt: &enrolledAt,
		}); err != nil {
			return err
		}
		if err := createAdminAudit(ctx, tx, userID, "admin_env_bootstrap", nil, strPtr("enrolled"), nil); err != nil {
			return err
		}
		created = true
		return nil
	})
	return created && err == nil, err
}

// InitialAdminSetup enrolls one existing password account. The deployment
// token and account password are both required; a durable database claim
// prevents any later browser enrollment, even if the account is deleted.
func (a *AdminAuth) InitialAdminSetup(ctx context.Context, csrf, username, plainPassword, setupToken string) (*AdminEnrollmentResult, error) {
	if a == nil || a.q == nil || len(strings.TrimSpace(a.cfg.FirstRunToken)) < 32 || len(a.cfg.EncryptionKey) == 0 || len(a.cfg.HMACKey) == 0 {
		return nil, ErrAdminUnavailable
	}
	cookie := adminCookie(ctx)
	if !a.validPreAuthEnvelope(cookie) {
		return nil, ErrAdminUnauthorized
	}
	if !a.validatePreAuthCSRF(cookie, csrf) {
		return nil, ErrAdminInvalidCSRF
	}
	if len(username) > 256 || len(plainPassword) < 8 || len(plainPassword) > 256 || len(setupToken) < 32 || len(setupToken) > 256 {
		return nil, ErrAdminInvalidSetupRequest
	}
	username = strings.TrimSpace(username)
	if username == "" {
		return nil, ErrAdminInvalidSetupRequest
	}
	candidate, err := a.q.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	clientIP := adminClientIP(ctx)
	if err := a.checkFailedChallengeQuota(ctx, candidateID(candidate), clientIP); err != nil {
		return nil, err
	}
	expected := sha256.Sum256([]byte(a.cfg.FirstRunToken))
	actual := sha256.Sum256([]byte(setupToken))
	if !hmac.Equal(expected[:], actual[:]) || candidate == nil {
		if err := a.admitFailedChallenge(ctx, candidateID(candidate), clientIP); err != nil {
			return nil, err
		}
		return nil, ErrAdminUnauthorized
	}
	var result *AdminEnrollmentResult
	err = a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, candidate.ID)
		if err != nil {
			return err
		}
		user, err := tx.GetUserByID(ctx, candidate.ID)
		if err != nil {
			return err
		}
		if state == nil || user == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired || !password.Verify(user.Password, plainPassword) {
			return ErrAdminUnauthorized
		}
		claimed, err := tx.ClaimInitialAdminSetup(ctx)
		if err != nil {
			return err
		}
		if !claimed {
			return ErrAdminUnauthorized
		}
		secretText, secret, err := a.GenerateEnrollmentSecret()
		if err != nil {
			return err
		}
		ciphertext, err := a.encryptTOTP(secret)
		if err != nil {
			return err
		}
		keyID := a.cfg.EncryptionKeyID
		enrolledAt := a.currentTime()
		if err := tx.UpsertAdminMembership(ctx, db.AdminMembershipParams{
			ID: uuid.New(), UserID: candidate.ID, Permissions: firstRunAdminPermissions(), Active: true,
			TotpSecretCiphertext: ciphertext, TotpKeyID: &keyID, TotpEnrolledAt: &enrolledAt,
		}); err != nil {
			return err
		}
		if err := createAdminAudit(ctx, tx, candidate.ID, "admin_initial_setup", nil, strPtr("enrolled"), nil); err != nil {
			return err
		}
		result = &AdminEnrollmentResult{UserID: candidate.ID, Secret: secretText}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrAdminUnauthorized) {
			if quotaErr := a.admitFailedChallenge(ctx, candidate.ID, clientIP); quotaErr != nil {
				return nil, quotaErr
			}
			return nil, ErrAdminUnauthorized
		}
		return nil, ErrAdminUnavailable
	}
	return result, nil
}

func firstRunAdminPermissions() []string {
	return []string{"audit.read", "campaign.login_link", "campaigns.read", "campaigns.write", "reports.read", "reports.review", "security.recovery_resend", "users.read", "users.verify"}
}

// BootstrapAdminSession creates a cryptographically bound pre-auth cookie.
// Persisted admin sessions require a user foreign key, so the pre-auth state
// remains a short-lived authenticated-cookie-less envelope until a password
// challenge identifies the account. The envelope is HMAC-bound to its CSRF
// value and is replaced by a persisted opaque session after MFA.
func (a *AdminAuth) BootstrapAdminSession(ctx context.Context) (*AdminBootstrapResult, error) {
	if a == nil || a.q == nil || len(a.enrollmentKey()) == 0 {
		return nil, ErrAdminUnavailable
	}
	now := a.currentTime()
	cookie := adminCookie(ctx)
	if a.validPreAuthEnvelope(cookie) {
		_, issuedAt, _ := preAuthCookieParts(cookie)
		csrf, _ := a.preAuthCSRF(cookie)
		expiresAt := issuedAt.Add(a.cfg.PreAuthTTL)
		result := &AdminBootstrapResult{CSRFToken: csrf, SessionState: "pre_authentication", ExpiresAt: expiresAt}
		writeAdminCookie(ctx, NewAdminSessionCookie(cookie, now, expiresAt.Sub(now)))
		return result, nil
	}
	// A valid authenticated cookie is restored rather than downgraded by a
	// second bootstrap call during a page reload. A database outage must also
	// remain visible as unavailable instead of issuing a new pre-auth cookie.
	if strings.HasPrefix(cookie, "s.") {
		principal, err := a.ValidateAdminSession(ctx, cookie)
		if err == nil && principal != nil {
			return &AdminBootstrapResult{CSRFToken: principal.CSRFToken, SessionState: "authenticated", ExpiresAt: principal.IdleExpiresAt}, nil
		}
		if apperrors.HTTPStatus(err) == http.StatusServiceUnavailable {
			return nil, ErrAdminUnavailable
		}
	}
	raw, err := a.randomBytes(32)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	value := preAuthCookieValue(raw, now)
	csrf := csrfForPreAuth(value, a.enrollmentKey())
	writeAdminCookie(ctx, NewAdminSessionCookie(value, now, a.cfg.PreAuthTTL))
	return &AdminBootstrapResult{CSRFToken: csrf, SessionState: "pre_authentication", ExpiresAt: now.Add(a.cfg.PreAuthTTL)}, nil
}

// csrfTokenFromHash is used only for restoration. A database session stores a
// hash, so GET restoration rotates to a fresh random token rather than trying
// to recover the original value.
func (a *AdminAuth) validatePreAuthCSRF(cookie, csrf string) bool {
	if !a.validPreAuthEnvelope(cookie) {
		return false
	}
	expected, ok := a.preAuthCSRF(cookie)
	return ok && hmac.Equal([]byte(expected), []byte(csrf))
}

func (a *AdminAuth) validateCSRF(ctx context.Context, csrf string) (*middleware.AdminPrincipal, error) {
	cookie := adminCookie(ctx)
	if validPreAuthCookie(cookie) {
		if !a.validPreAuthEnvelope(cookie) {
			return nil, ErrAdminUnauthorized
		}
		if !a.validatePreAuthCSRF(cookie, csrf) {
			return nil, ErrAdminInvalidCSRF
		}
		return nil, nil
	}
	principal, err := a.ValidateAdminSession(ctx, cookie)
	if err != nil {
		return nil, err
	}
	if !middleware.CSRFMatches(principal.CSRFHash, csrf) {
		return nil, ErrAdminInvalidCSRF
	}
	return principal, nil
}

// AdminSessionLogin verifies the password while holding the account lock and
// creates a one-use, generation-bound MFA challenge. It never issues a JWT or
// refresh credential.
func (a *AdminAuth) AdminSessionLogin(ctx context.Context, csrf, username, plainPassword string) (*AdminLoginResult, error) {
	if a == nil || a.q == nil {
		return nil, ErrAdminUnavailable
	}
	cookie := adminCookie(ctx)
	if !a.validPreAuthEnvelope(cookie) {
		return nil, ErrAdminUnauthorized
	}
	if !a.validatePreAuthCSRF(cookie, csrf) {
		return nil, ErrAdminInvalidCSRF
	}
	if strings.TrimSpace(username) == "" || plainPassword == "" {
		return nil, apperrors.New(http.StatusBadRequest, "invalid admin credentials")
	}
	var candidate *db.User
	var err error
	// This lookup is deliberately only used to obtain a stable ID. The full
	// password/security row is re-read after locking inside the transaction.
	candidate, err = a.q.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	// Admission is deliberately performed before password verification. This
	// keeps an exhausted account/IP/global window effective for correct
	// credentials as well as failures, without changing the consumer lockout
	// counter or creating a permanent account lock.
	if err := a.checkFailedChallengeQuota(ctx, candidateID(candidate), adminClientIP(ctx)); err != nil {
		return nil, err
	}
	var failed bool
	var login *AdminLoginResult
	err = a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		if candidate == nil {
			failed = true
			return nil
		}
		state, err := tx.LockUserSecurity(ctx, candidate.ID)
		if err != nil {
			return err
		}
		u, err := tx.GetUserByID(ctx, candidate.ID)
		if err != nil {
			return err
		}
		membership, err := tx.GetAdminMembership(ctx, candidate.ID)
		if err != nil {
			return err
		}
		if state == nil || u == nil || membership == nil || !membership.Active || membership.RevokedAt != nil ||
			state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired ||
			len(membership.TotpSecretCiphertext) == 0 || membership.TotpKeyID == nil {
			failed = true
			return nil
		}
		if !password.Verify(u.Password, plainPassword) {
			failed = true
			return nil
		}
		challengeID := uuid.New()
		challengeHash := challengeBinding(challengeID, cookie, a.enrollmentKey())
		expires := a.currentTime().Add(a.cfg.ChallengeTTL)
		if err := tx.RevokeAdminLoginChallengesForUser(ctx, candidate.ID); err != nil {
			return err
		}
		if err := tx.CreateAdminLoginChallenge(ctx, db.AdminLoginChallengeParams{
			ID: challengeID, ChallengeHash: challengeHash, UserID: &candidate.ID,
			IPHMAC: a.ipHMAC(adminClientIP(ctx)), AuthGeneration: state.AuthGeneration, ExpiresAt: expires,
		}); err != nil {
			return err
		}
		login = &AdminLoginResult{ChallengeID: challengeID.String(), CSRFToken: csrf, SessionState: "mfa_required", ExpiresAt: expires}
		return nil
	})
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	if failed || login == nil {
		if err := a.admitFailedChallenge(ctx, candidateID(candidate), adminClientIP(ctx)); err != nil {
			return nil, err
		}
		return nil, ErrAdminUnauthorized
	}
	return login, nil
}

func candidateID(candidate *db.User) uuid.UUID {
	if candidate == nil {
		return uuid.Nil
	}
	return candidate.ID
}

func (a *AdminAuth) ipHMAC(ip string) []byte {
	key := a.cfg.HMACKey
	if len(key) == 0 {
		key = a.enrollmentKey()
	}
	return hmacDigest(key, "admin-client-ip", ip)
}

func (a *AdminAuth) quotaWindow(now time.Time) (time.Time, time.Time) {
	start := now.UTC().Truncate(adminChallengeWindow)
	return start, start.Add(adminChallengeWindow)
}

func (a *AdminAuth) acquireQuota(ctx context.Context, scope, identifier string, limit int64) (bool, error) {
	if a.q == nil || len(a.cfg.HMACKey) == 0 {
		return false, ErrAdminUnavailable
	}
	now := a.currentTime()
	start, end := a.quotaWindow(now)
	key := db.SharedQuotaKey{Scope: scope, IdentifierHMAC: hmacDigest(a.cfg.HMACKey, scope, identifier), KeyID: a.cfg.HMACKeyID, WindowStart: start, WindowEnd: end, Limit: limit}
	decision, err := a.q.AcquireSharedQuota(ctx, []db.SharedQuotaKey{key}, 1)
	if err != nil {
		return false, err
	}
	return decision.Allowed, nil
}

func (a *AdminAuth) checkFailedChallengeQuota(ctx context.Context, accountID uuid.UUID, ip string) error {
	if a.q == nil || len(a.cfg.HMACKey) == 0 {
		return ErrAdminUnavailable
	}
	err := a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		return a.checkFailedChallengeQuotaTx(ctx, tx, accountID, ip)
	})
	if err != nil {
		if errors.Is(err, ErrAdminRateLimited) || errors.Is(err, ErrAdminUnavailable) {
			return err
		}
		return ErrAdminUnavailable
	}
	return nil
}

// checkFailedChallengeQuotaTx checks all three dimensions while one
// transaction owns their advisory locks. No bucket is incremented here; the
// failure path consumes a hit only after credentials have been rejected.
func (a *AdminAuth) checkFailedChallengeQuotaTx(ctx context.Context, tx *db.Queries, accountID uuid.UUID, ip string) error {
	if tx == nil || len(a.cfg.HMACKey) == 0 {
		return ErrAdminUnavailable
	}
	accountKey := accountID.String()
	if accountID == uuid.Nil {
		accountKey = "unknown"
	}
	checks := []struct {
		scope, id string
		limit     int64
	}{
		{"admin-login-account-ip", accountKey + "|" + ip, a.cfg.LoginFailureLimit},
		{"admin-login-ip", ip, a.cfg.LoginIPLimit},
		{"admin-login-global", "global", a.cfg.LoginGlobalLimit},
	}
	for _, check := range checks {
		now := a.currentTime()
		start, end := a.quotaWindow(now)
		key := db.SharedQuotaKey{Scope: check.scope, IdentifierHMAC: hmacDigest(a.cfg.HMACKey, check.scope, check.id), KeyID: a.cfg.HMACKeyID, WindowStart: start, WindowEnd: end, Limit: check.limit}
		decision, err := tx.CheckSharedQuota(ctx, []db.SharedQuotaKey{key}, 1)
		if err != nil {
			return ErrAdminUnavailable
		}
		if !decision.Allowed {
			return ErrAdminRateLimited
		}
	}
	return nil
}

func (a *AdminAuth) admitFailedChallenge(ctx context.Context, accountID uuid.UUID, ip string) error {
	accountKey := accountID.String()
	if accountID == uuid.Nil {
		accountKey = "unknown"
	}
	checks := []struct {
		scope, id string
		limit     int64
	}{
		{"admin-login-account-ip", accountKey + "|" + ip, a.cfg.LoginFailureLimit},
		{"admin-login-ip", ip, a.cfg.LoginIPLimit},
		{"admin-login-global", "global", a.cfg.LoginGlobalLimit},
	}
	for _, check := range checks {
		allowed, err := a.acquireQuota(ctx, check.scope, check.id, check.limit)
		if err != nil {
			return ErrAdminUnavailable
		}
		if !allowed {
			return ErrAdminRateLimited
		}
	}
	return nil
}

type AdminSessionResult struct {
	Principal *middleware.AdminPrincipal
	CSRFToken string
	Cookie    string
}

func (a *AdminAuth) sessionCookieParts(cookie string) (string, string, error) {
	secret, csrf, ok := authenticatedCookieParts(cookie)
	if !ok {
		return "", "", ErrAdminUnauthorized
	}
	return secret, csrf, nil
}

// ValidateAdminSession reloads the session, account security state and stable
// membership for every request. It rejects a demotion, generation advance,
// compromise, expiry, or revocation immediately.
func (a *AdminAuth) ValidateAdminSession(ctx context.Context, cookie string) (*middleware.AdminPrincipal, error) {
	if a == nil || a.q == nil {
		return nil, ErrAdminUnavailable
	}
	secret, csrf, err := a.sessionCookieParts(cookie)
	if err != nil {
		return nil, err
	}
	session, err := a.q.GetAdminSessionByHash(ctx, hashOpaque(secret))
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	if session == nil || session.State != adminSessionStateAuthenticated || session.RevokedAt != nil {
		return nil, ErrAdminUnauthorized
	}
	now := a.currentTime()
	if !session.IdleExpiresAt.After(now) || !session.AbsoluteExpiresAt.After(now) {
		_ = a.q.RevokeAdminSession(ctx, session.ID)
		return nil, ErrAdminUnauthorized
	}
	state, err := a.q.GetUserSecurityState(ctx, session.UserID)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	membership, err := a.q.GetAdminMembership(ctx, session.UserID)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	username, err := a.q.GetUsernameByID(ctx, session.UserID)
	if err != nil {
		return nil, ErrAdminUnauthorized
	}
	if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired || state.AuthGeneration != session.AuthGeneration ||
		membership == nil || !membership.Active || membership.RevokedAt != nil || len(membership.TotpSecretCiphertext) == 0 || membership.TotpKeyID == nil || !middleware.CSRFMatches(session.CSRFHash, csrf) {
		return nil, ErrAdminUnauthorized
	}
	if err := a.q.TouchAdminSession(ctx, hashOpaque(secret), minTime(now.Add(a.cfg.SessionIdleTTL), session.AbsoluteExpiresAt)); err != nil {
		return nil, ErrAdminUnavailable
	}
	capabilities := CapabilitiesForPermissions(membership.Permissions)
	principal := &middleware.AdminPrincipal{
		SessionID: session.ID.String(), UserID: session.UserID.String(), Username: username, AuthGeneration: session.AuthGeneration,
		State: session.State, CSRFHash: append([]byte(nil), session.CSRFHash...), CSRFToken: csrf,
		Permissions: append([]string(nil), membership.Permissions...), Capabilities: capabilities,
		RecentMFAAt: cloneTime(session.RecentMFAAt), RecentMFAAction: stringValue(session.RecentMFAAction), AuthenticatedAt: session.IssuedAt,
		LastActivityAt: now, IdleExpiresAt: minTime(now.Add(a.cfg.SessionIdleTTL), session.AbsoluteExpiresAt),
	}
	_ = username // username is loaded here to ensure a deleted/hidden user cannot retain a session.
	return principal, nil
}

func minTime(a, b time.Time) time.Time {
	if a.Before(b) {
		return a
	}
	return b
}

func cloneTime(value *time.Time) *time.Time {
	if value == nil {
		return nil
	}
	copy := *value
	return &copy
}

func stringValue(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func actionCapability(action string) string {
	switch action {
	case "revoke_sessions":
		return "security.revoke"
	case "mark_compromised":
		return "security.compromise"
	case "recovery_resend":
		return "security.recovery_resend"
	case "report_resolve":
		return "reports.resolve"
	case "report_dismiss":
		return "reports.dismiss"
	case "email":
		return "campaign.email"
	case "login_link":
		return "campaign.login_link"
	case "push":
		return "campaign.push"
	case "audience.preview":
		return "audience.preview"
	case "jobs.create", "jobs.control", "messages.test", "reports.review", "campaigns.write":
		// These route-family actions are intentionally capability-shaped. The
		// generated request type is a string alias at runtime, so a step-up can
		// bind to an operation that has no action-union payload (for example a
		// retry, report note, or test message).
		return action
	default:
		return ""
	}
}

func AdminActionCapability(action string) string { return actionCapability(action) }

func isKnownAdminAction(action string) bool {
	return actionCapability(action) != "" || action == "audience.preview"
}

// CompleteAdminSessionMFA consumes the challenge and creates a persisted
// authenticated session in one transaction. Challenge consumption and replay
// counter advancement roll back together if session creation fails.
func (a *AdminAuth) CompleteAdminSessionMFA(ctx context.Context, csrf, challengeIDText, code string) (*AdminSessionResult, error) {
	if a == nil || a.q == nil {
		return nil, ErrAdminUnavailable
	}
	cookie := adminCookie(ctx)
	if !a.validPreAuthEnvelope(cookie) {
		return nil, ErrAdminUnauthorized
	}
	if !a.validatePreAuthCSRF(cookie, csrf) {
		return nil, ErrAdminInvalidCSRF
	}
	challengeID, err := uuid.Parse(strings.TrimSpace(challengeIDText))
	if err != nil {
		return nil, ErrAdminInvalidChallenge
	}
	challenge, err := a.q.GetAdminLoginChallenge(ctx, challengeID)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	if challenge == nil || challenge.UserID == nil || challenge.ConsumedAt != nil || challenge.RevokedAt != nil || !challenge.ExpiresAt.After(a.currentTime()) ||
		!constantTimeBytesEqual(challenge.ChallengeHash, challengeBinding(challengeID, cookie, a.enrollmentKey())) ||
		!constantTimeBytesEqual(challenge.IPHMAC, a.ipHMAC(adminClientIP(ctx))) {
		return nil, ErrAdminInvalidChallenge
	}
	if err := a.checkFailedChallengeQuota(ctx, *challenge.UserID, adminClientIP(ctx)); err != nil {
		return nil, err
	}
	membership, err := a.q.GetAdminMembership(ctx, *challenge.UserID)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	secret, err := a.decryptTOTP(membershipSecret(membership), membershipKeyID(membership))
	if err != nil {
		return nil, ErrAdminUnauthorized
	}
	counter, valid := ValidTOTPCounter(secret, code, a.currentTime(), 1)
	if !valid {
		if err := a.admitFailedChallenge(ctx, *challenge.UserID, adminClientIP(ctx)); err != nil {
			return nil, err
		}
		if _, _, err := a.q.IncrementAdminChallengeFailure(ctx, challengeID); err != nil {
			return nil, ErrAdminUnavailable
		}
		return nil, ErrAdminUnauthorized
	}
	var result *AdminSessionResult
	err = a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		consumed, ok, err := tx.ConsumeAdminLoginChallenge(ctx, challengeID, a.currentTime())
		if err != nil {
			return err
		}
		if !ok || consumed == nil || consumed.UserID == nil {
			return ErrAdminInvalidChallenge
		}
		state, err := tx.LockUserSecurity(ctx, *consumed.UserID)
		if err != nil {
			return err
		}
		membership, err := tx.GetAdminMembership(ctx, *consumed.UserID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired ||
			membership == nil || !membership.Active || membership.RevokedAt != nil || state.AuthGeneration != consumed.AuthGeneration {
			return ErrAdminUnauthorized
		}
		if !constantTimeBytesEqual(consumed.IPHMAC, a.ipHMAC(adminClientIP(ctx))) {
			return ErrAdminInvalidChallenge
		}
		secret, err := a.decryptTOTP(membershipSecret(membership), membershipKeyID(membership))
		if err != nil {
			return err
		}
		counter, valid = ValidTOTPCounter(secret, code, a.currentTime(), 1)
		if !valid {
			return ErrAdminUnauthorized
		}
		sessionSecret, err := a.randomBytes(32)
		if err != nil {
			return err
		}
		csrfBytes, err := a.randomBytes(32)
		if err != nil {
			return err
		}
		sessionSecretEncoded := base64.RawURLEncoding.EncodeToString(sessionSecret)
		csrfToken := base64.RawURLEncoding.EncodeToString(csrfBytes)
		sessionCookie := "s." + sessionSecretEncoded + "." + csrfToken
		now := a.currentTime()
		// Login MFA authorizes mutations throughout this authenticated session.
		loginMFAAction := "session"
		session := db.AdminSessionParams{ID: uuid.New(), SessionHash: hashOpaque(sessionSecretEncoded), UserID: *consumed.UserID,
			CSRFHash: middleware.CSRFHash(csrfToken), State: adminSessionStateAuthenticated, AuthGeneration: state.AuthGeneration,
			IdleExpiresAt: now.Add(a.cfg.SessionIdleTTL), AbsoluteExpiresAt: now.Add(a.cfg.SessionAbsoluteTTL), RecentMFAAt: &now, RecentMFAAction: &loginMFAAction}
		if err := tx.CreateAdminSession(ctx, session); err != nil {
			return err
		}
		if _, ok, err := tx.AdvanceAdminMFAReplayScope(ctx, membership.ID, *consumed.UserID, counter); err != nil {
			return err
		} else if !ok {
			return ErrAdminUnauthorized
		}
		if err := createAdminAuditWithActor(ctx, tx, consumed.UserID, *consumed.UserID, "admin_mfa_completed", nil, strPtr("success"), nil); err != nil {
			return err
		}
		username, err := tx.GetUsernameByID(ctx, *consumed.UserID)
		if err != nil {
			return err
		}
		result = &AdminSessionResult{Cookie: sessionCookie, CSRFToken: csrfToken, Principal: &middleware.AdminPrincipal{
			SessionID: session.ID.String(), UserID: consumed.UserID.String(), Username: username, AuthGeneration: state.AuthGeneration,
			State: adminSessionStateAuthenticated, CSRFHash: middleware.CSRFHash(csrfToken), CSRFToken: csrfToken,
			Permissions: append([]string(nil), membership.Permissions...), Capabilities: CapabilitiesForPermissions(membership.Permissions),
			RecentMFAAt: &now, RecentMFAAction: loginMFAAction, AuthenticatedAt: now, LastActivityAt: now,
			IdleExpiresAt: session.IdleExpiresAt,
		}}
		_ = username
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrAdminUnauthorized) || errors.Is(err, ErrAdminInvalidChallenge) {
			return nil, err
		}
		return nil, ErrAdminUnavailable
	}
	writeAdminCookie(ctx, NewAdminSessionCookie(result.Cookie, a.currentTime(), a.cfg.SessionAbsoluteTTL))
	return result, nil
}

func membershipSecret(membership *db.AdminMembership) []byte {
	if membership == nil {
		return nil
	}
	return membership.TotpSecretCiphertext
}

func membershipKeyID(membership *db.AdminMembership) *string {
	if membership == nil {
		return nil
	}
	return membership.TotpKeyID
}

func createAdminAudit(ctx context.Context, q *db.Queries, target uuid.UUID, action string, reason, outcome *string, metadata []byte) error {
	return createAdminAuditWithActor(ctx, q, nil, target, action, reason, outcome, metadata)
}

func createAdminAuditWithActor(ctx context.Context, q *db.Queries, actor *uuid.UUID, target uuid.UUID, action string, reason, outcome *string, metadata []byte) error {
	if q == nil {
		return ErrAdminUnavailable
	}
	return q.CreateAuditEvent(ctx, db.AuditEventParams{ID: uuid.New(), ActorID: actor, TargetAccountID: &target, Action: action, Reason: reason, Outcome: outcome, Metadata: metadata})
}

func (a *AdminAuth) sessionResult(ctx context.Context, principal *middleware.AdminPrincipal) (*AdminSessionResult, error) {
	if principal == nil {
		return nil, ErrAdminUnauthorized
	}
	return &AdminSessionResult{Principal: principal, CSRFToken: principal.CSRFToken, Cookie: adminCookie(ctx)}, nil
}

// GetAdminSession restores the current browser session. The CSRF token is
// recovered from the opaque HttpOnly cookie envelope and checked against the
// stored hash, allowing a full-page reload without storing credentials in
// local/session storage.
func (a *AdminAuth) GetAdminSession(ctx context.Context) (*AdminSessionResult, error) {
	principal, err := a.ValidateAdminSession(ctx, adminCookie(ctx))
	if err != nil {
		return nil, err
	}
	return a.sessionResult(ctx, principal)
}

// LogoutAdminSession revokes the persisted session (or simply clears a
// pre-auth envelope) after a valid double-submit CSRF proof.
func (a *AdminAuth) LogoutAdminSession(ctx context.Context, csrf string) error {
	if a == nil || a.q == nil {
		return ErrAdminUnavailable
	}
	cookie := adminCookie(ctx)
	if validPreAuthCookie(cookie) {
		if !a.validPreAuthEnvelope(cookie) {
			return ErrAdminUnauthorized
		}
		if !a.validatePreAuthCSRF(cookie, csrf) {
			return ErrAdminInvalidCSRF
		}
		writeAdminCookie(ctx, clearAdminSessionCookie(a.currentTime()))
		return nil
	}
	principal, err := a.validateCSRF(ctx, csrf)
	if err != nil {
		return err
	}
	if principal == nil {
		return ErrAdminUnauthorized
	}
	if err := a.q.RevokeAdminSession(ctx, uuidFromPrincipal(principal)); err != nil {
		return ErrAdminUnavailable
	}
	writeAdminCookie(ctx, clearAdminSessionCookie(a.currentTime()))
	return nil
}

func uuidFromPrincipal(principal *middleware.AdminPrincipal) uuid.UUID {
	if principal == nil {
		return uuid.Nil
	}
	id, _ := uuid.Parse(principal.SessionID)
	return id
}

// ReauthenticateAdminSession verifies a fresh TOTP for one capability-bound
// action, rotates CSRF, and records the recent-MFA timestamp. A replayed TOTP
// moving factor cannot pass the persisted counter update.
func (a *AdminAuth) ReauthenticateAdminSession(ctx context.Context, csrf, action, code string) (*AdminSessionResult, error) {
	if a == nil || a.q == nil {
		return nil, ErrAdminUnavailable
	}
	principal, err := a.validateCSRF(ctx, csrf)
	if err != nil {
		return nil, err
	}
	if principal == nil {
		return nil, ErrAdminUnauthorized
	}
	required := actionCapability(action)
	if !isKnownAdminAction(action) || required == "" {
		return nil, ErrAdminInvalidAction
	}
	if !containsString(principal.Capabilities, required) {
		return nil, ErrAdminForbidden
	}
	if err := a.checkFailedChallengeQuota(ctx, mustUUID(principal.UserID), adminClientIP(ctx)); err != nil {
		return nil, err
	}
	membership, err := a.q.GetAdminMembership(ctx, mustUUID(principal.UserID))
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	secret, err := a.decryptTOTP(membershipSecret(membership), membershipKeyID(membership))
	if err != nil {
		return nil, ErrAdminUnauthorized
	}
	counter, valid := ValidTOTPCounter(secret, code, a.currentTime(), 1)
	if !valid {
		if err := a.admitFailedChallenge(ctx, mustUUID(principal.UserID), adminClientIP(ctx)); err != nil {
			return nil, err
		}
		return nil, ErrAdminUnauthorized
	}
	now := a.currentTime()
	newCSRFBytes, err := a.randomBytes(32)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	newCSRF := base64.RawURLEncoding.EncodeToString(newCSRFBytes)
	secretPart, _, ok := authenticatedCookieParts(adminCookie(ctx))
	if !ok {
		return nil, ErrAdminUnauthorized
	}
	sessionID := mustUUID(principal.SessionID)
	err = a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, mustUUID(principal.UserID))
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired || state.AuthGeneration != principal.AuthGeneration {
			return ErrAdminUnauthorized
		}
		currentMembership, err := tx.GetAdminMembership(ctx, mustUUID(principal.UserID))
		if err != nil {
			return err
		}
		if currentMembership == nil || !currentMembership.Active || currentMembership.RevokedAt != nil || !containsString(CapabilitiesForPermissions(currentMembership.Permissions), required) {
			return ErrAdminForbidden
		}
		secret, err := a.decryptTOTP(membershipSecret(currentMembership), membershipKeyID(currentMembership))
		if err != nil {
			return err
		}
		counter, valid = ValidTOTPCounter(secret, code, now, 1)
		if !valid {
			return ErrAdminUnauthorized
		}
		if _, ok, err := tx.AdvanceAdminMFAReplayScope(ctx, currentMembership.ID, mustUUID(principal.UserID), counter); err != nil {
			return err
		} else if !ok {
			return ErrAdminUnauthorized
		}
		if err := tx.RotateAdminSessionCSRF(ctx, sessionID, middleware.CSRFHash(newCSRF), &now, action); err != nil {
			return err
		}
		actorID := mustUUID(principal.UserID)
		return createAdminAuditWithActor(ctx, tx, &actorID, actorID, "admin_step_up", &action, strPtr("success"), nil)
	})
	if err != nil {
		if errors.Is(err, ErrAdminUnauthorized) || errors.Is(err, ErrAdminForbidden) {
			return nil, err
		}
		return nil, ErrAdminUnavailable
	}
	newCookie := "s." + secretPart + "." + newCSRF
	writeAdminCookie(ctx, NewAdminSessionCookie(newCookie, now, a.cfg.SessionAbsoluteTTL))
	updated, err := a.ValidateAdminSession(ctx, newCookie)
	if err != nil {
		return nil, err
	}
	updated.CSRFToken = newCSRF
	return &AdminSessionResult{Principal: updated, CSRFToken: newCSRF, Cookie: newCookie}, nil
}

func mustUUID(raw string) uuid.UUID {
	id, _ := uuid.Parse(raw)
	return id
}

func containsString(values []string, value string) bool {
	for _, item := range values {
		if item == value {
			return true
		}
	}
	return false
}

// InvalidateSessionForSelfTarget is called by security job handlers when an
// actor targets their own account. Revocation is immediate and the caller can
// use the returned false value to pause remaining work for another operator.
func (a *AdminAuth) InvalidateSessionForSelfTarget(ctx context.Context, actorID, targetID uuid.UUID, sessionID uuid.UUID) (bool, error) {
	if a == nil || a.q == nil {
		return false, ErrAdminUnavailable
	}
	if actorID == uuid.Nil || targetID == uuid.Nil || actorID != targetID {
		return false, nil
	}
	if sessionID != uuid.Nil {
		if err := a.q.RevokeAdminSession(ctx, sessionID); err != nil {
			return true, err
		}
	}
	if err := createAdminAuditWithActor(ctx, a.q, &actorID, targetID, "admin_self_target", nil, strPtr("session_revoked_job_paused"), nil); err != nil {
		return true, err
	}
	return true, nil
}

type AdminEnrollmentResult struct {
	UserID          uuid.UUID
	Secret          string
	AlreadyEnrolled bool
}

// EnrollAdminOperator is an explicit local-operator operation. It resolves a
// username once for the command, then persists membership by stable user ID.
// Re-running it updates permissions without replacing an existing TOTP secret.
func (a *AdminAuth) EnrollAdminOperator(ctx context.Context, username string, permissions []string) (*AdminEnrollmentResult, error) {
	if a == nil || a.q == nil {
		return nil, ErrAdminUnavailable
	}
	username = strings.TrimSpace(username)
	if username == "" {
		return nil, apperrors.New(http.StatusBadRequest, "username is required")
	}
	permissions = CapabilitiesForPermissions(permissions)
	user, err := a.q.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	if user == nil {
		return nil, apperrors.New(http.StatusNotFound, "operator account not found")
	}
	var result *AdminEnrollmentResult
	err = a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, user.ID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired {
			return ErrAdminForbidden
		}
		if err := tx.MarkInitialAdminSetupClaimed(ctx); err != nil {
			return err
		}
		membership, err := tx.GetAdminMembership(ctx, user.ID)
		if err != nil {
			return err
		}
		if membership != nil && membership.Active && membership.RevokedAt == nil && len(membership.TotpSecretCiphertext) > 0 && membership.TotpKeyID != nil {
			if err := tx.UpsertAdminMembership(ctx, db.AdminMembershipParams{ID: membership.ID, UserID: user.ID, Permissions: permissions, Active: true,
				TotpSecretCiphertext: membership.TotpSecretCiphertext, TotpKeyID: membership.TotpKeyID, TotpEnrolledAt: membership.TotpEnrolledAt}); err != nil {
				return err
			}
			if err := createAdminAudit(ctx, tx, user.ID, "admin_membership_enrollment", nil, strPtr("already_enrolled"), nil); err != nil {
				return err
			}
			result = &AdminEnrollmentResult{UserID: user.ID, AlreadyEnrolled: true}
			return nil
		}
		secretText, secret, err := a.GenerateEnrollmentSecret()
		if err != nil {
			return err
		}
		ciphertext, err := a.encryptTOTP(secret)
		if err != nil {
			return err
		}
		enrolledAt := a.currentTime()
		membershipID := uuid.New()
		if membership != nil {
			membershipID = membership.ID
		}
		keyID := a.cfg.EncryptionKeyID
		if err := tx.ResetAdminMFAReplayScope(ctx, membershipID, user.ID); err != nil {
			return err
		}
		if err := tx.UpsertAdminMembership(ctx, db.AdminMembershipParams{ID: membershipID, UserID: user.ID, Permissions: permissions, Active: true,
			TotpSecretCiphertext: ciphertext, TotpKeyID: &keyID, TotpEnrolledAt: &enrolledAt}); err != nil {
			return err
		}
		if err := createAdminAudit(ctx, tx, user.ID, "admin_membership_enrollment", nil, strPtr("enrolled"), nil); err != nil {
			return err
		}
		result = &AdminEnrollmentResult{UserID: user.ID, Secret: secretText}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrAdminForbidden) {
			return nil, err
		}
		if apperrors.HTTPStatus(err) >= 400 && apperrors.HTTPStatus(err) < 500 {
			return nil, err
		}
		return nil, ErrAdminUnavailable
	}
	return result, nil
}

// BreakGlassRecoverAdminMFA is intentionally a service operation for a local
// operator command. It requires a stable active admin actor with the
// security.recovery_resend capability, then rotates the encrypted secret,
// preserves stable membership permissions, revokes active browser sessions,
// and appends audit metadata. No public endpoint invokes this method.
func (a *AdminAuth) BreakGlassRecoverAdminMFA(ctx context.Context, username string, actorID *uuid.UUID) (*AdminEnrollmentResult, error) {
	if a == nil || a.q == nil {
		return nil, ErrAdminUnavailable
	}
	if actorID == nil || *actorID == uuid.Nil {
		return nil, ErrAdminForbidden
	}
	actor := *actorID
	user, err := a.q.GetUserByUsername(ctx, strings.TrimSpace(username))
	if err != nil {
		return nil, ErrAdminUnavailable
	}
	if user == nil {
		return nil, apperrors.New(http.StatusNotFound, "operator account not found")
	}
	var result *AdminEnrollmentResult
	err = a.q.InTxRetry(ctx, func(tx *db.Queries) error {
		actorState, err := tx.LockUserSecurity(ctx, actor)
		if err != nil {
			return err
		}
		if actorState == nil || actorState.IsDeleted || actorState.SecurityState != db.SecurityStateNormal || actorState.PasswordDisabled || actorState.PasswordResetRequired {
			return ErrAdminForbidden
		}
		actorMembership, err := tx.GetAdminMembership(ctx, actor)
		if err != nil {
			return err
		}
		if actorMembership == nil || !actorMembership.Active || actorMembership.RevokedAt != nil ||
			!containsString(CapabilitiesForPermissions(actorMembership.Permissions), "security.recovery_resend") {
			return ErrAdminForbidden
		}
		state, err := tx.LockUserSecurity(ctx, user.ID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted {
			return ErrAdminForbidden
		}
		membership, err := tx.GetAdminMembership(ctx, user.ID)
		if err != nil {
			return err
		}
		if membership == nil || !membership.Active || membership.RevokedAt != nil {
			return ErrAdminForbidden
		}
		secretText, secret, err := a.GenerateEnrollmentSecret()
		if err != nil {
			return err
		}
		ciphertext, err := a.encryptTOTP(secret)
		if err != nil {
			return err
		}
		enrolledAt := a.currentTime()
		keyID := a.cfg.EncryptionKeyID
		if err := tx.ResetAdminMFAReplayScope(ctx, membership.ID, user.ID); err != nil {
			return err
		}
		if err := tx.UpsertAdminMembership(ctx, db.AdminMembershipParams{ID: membership.ID, UserID: user.ID, Permissions: membership.Permissions, Active: membership.Active,
			TotpSecretCiphertext: ciphertext, TotpKeyID: &keyID, TotpEnrolledAt: &enrolledAt, RevokedAt: membership.RevokedAt}); err != nil {
			return err
		}
		if err := tx.RevokeAdminSessionsForUser(ctx, user.ID); err != nil {
			return err
		}
		if err := createAdminAuditWithActor(ctx, tx, &actor, user.ID, "admin_break_glass_mfa_recovery", nil, strPtr("secret_rotated"), nil); err != nil {
			return err
		}
		result = &AdminEnrollmentResult{UserID: user.ID, Secret: secretText}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrAdminForbidden) {
			return nil, err
		}
		return nil, ErrAdminUnavailable
	}
	return result, nil
}
