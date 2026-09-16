package service

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"html/template"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/jobs"
	"github.com/lrprojects/monaserver/internal/token"
)

const (
	loginLinkTokenTTL       = 15 * time.Minute
	recoveryTokenTTL        = 10 * time.Minute
	loginDeliveryPayloadTTL = 15 * time.Minute

	addressBurstScope = "public_email_login.address.burst"
	addressDailyScope = "public_email_login.address.daily"
	ipBurstScope      = "public_email_login.ip.burst"
	globalScope       = "public_email_login.global"
)

var (
	// Public errors intentionally do not distinguish an absent account, an
	// unverified/duplicate address, or a restricted account.
	ErrEmailRateLimited         = apperrors.New(http.StatusTooManyRequests, "too many requests")
	ErrEmailDeliveryUnavailable = apperrors.New(http.StatusServiceUnavailable, "email delivery is unavailable")
	ErrInvalidEmailLink         = apperrors.New(http.StatusBadRequest, "invalid email link")
)

// EmailLoginConfig controls the shared public-email admission limits. HMAC
// keys are rotated by retaining previous entries; all retained identifiers
// count toward the same logical quota window.
type EmailLoginConfig struct {
	HMACKeyID        string
	HMACKey          []byte
	PreviousHMACKeys map[string][]byte

	AddressWindow      time.Duration
	AddressLimit       int64
	AddressDailyWindow time.Duration
	AddressDailyLimit  int64
	IPWindow           time.Duration
	IPLimit            int64
	GlobalWindow       time.Duration
	GlobalLimit        int64

	LoginTokenTTL      time.Duration
	RecoveryTokenTTL   time.Duration
	DeliveryPayloadTTL time.Duration
	CallbackURL        string
	DeliveryKeyRing    *DeliveryKeyRing
}

// EmailLoginRequest is the service boundary for a public request. ClientIP
// is supplied by trusted route middleware; an empty value is intentionally
// bucketed as one opaque unknown source rather than trusting a header here.
type EmailLoginRequest struct {
	Email    string
	ClientIP string
}

// LoginLinkDeliveryRequest is passed to the durable delivery adapter. Token
// is ephemeral and must only be encrypted by an adapter or delivered to a
// provider; it must never be logged or stored in plaintext.
type LoginLinkDeliveryRequest struct {
	AccountID      uuid.UUID
	Username       string
	To             string
	Token          string
	ActionTokenID  uuid.UUID
	AuthGeneration int64
	ExpiresAt      time.Time
}

// LoginLinkDeliveryEnqueuer is deliberately transaction-aware. The adapter
// must use the supplied transaction facade and must not call a provider.
type LoginLinkDeliveryEnqueuer interface {
	EnqueueLoginLink(context.Context, *db.Queries, LoginLinkDeliveryRequest) (*uuid.UUID, error)
}

// LoginLinkIssueRequest is the typed port for administrative callers. It
// accepts an account ID only, so an admin cannot override the trusted email
// destination with a raw address.
type LoginLinkIssueRequest struct {
	AccountID uuid.UUID
	ActorID   *uuid.UUID
}

// EmailLinkRequestResult is rich at the service/typed-port boundary but the
// public handler exposes only Accepted. Action is never rendered by a public
// response; it exists for the delivery adapter and deterministic tests.
type EmailLinkRequestResult struct {
	Accepted       bool
	Issued         bool
	AccountID      uuid.UUID
	Username       string
	CanonicalEmail string
	Action         *ActionToken
	DeliveryID     *uuid.UUID
}

// EmailLogin owns public email-link admission and atomic redemption.
type EmailLogin struct {
	q         *db.Queries
	security  *AccountSecurity
	tok       *token.Helper
	cfg       EmailLoginConfig
	enqueuer  LoginLinkDeliveryEnqueuer
	now       func() time.Time
	issuePair func(context.Context, *db.Queries, uuid.UUID) (*TokenPair, error)
	mu        sync.RWMutex
}

// NewEmailLogin constructs the service. A nil enqueuer installs the durable
// adapter when a delivery key ring is configured; otherwise requests fail
// closed before an action token can commit.
func NewEmailLogin(q *db.Queries, security *AccountSecurity, tok *token.Helper, cfg EmailLoginConfig, enqueuer LoginLinkDeliveryEnqueuer) *EmailLogin {
	if security == nil {
		security = NewAccountSecurity(q)
	}
	cfg = cfg.withDefaults()
	if enqueuer == nil && cfg.DeliveryKeyRing != nil {
		enqueuer = NewDurableLoginLinkEnqueuer(cfg.DeliveryKeyRing, cfg.CallbackURL, nil)
	}
	s := &EmailLogin{
		q: q, security: security, tok: tok, cfg: cfg, enqueuer: enqueuer,
		now: time.Now,
	}
	s.issuePair = func(ctx context.Context, tx *db.Queries, accountID uuid.UUID) (*TokenPair, error) {
		return security.IssueTokens(ctx, tx, tok, accountID)
	}
	return s
}

// NewEmailLoginService is a descriptive constructor alias for composition
// code that names services explicitly.
func NewEmailLoginService(q *db.Queries, security *AccountSecurity, tok *token.Helper, cfg EmailLoginConfig, enqueuer LoginLinkDeliveryEnqueuer) *EmailLogin {
	return NewEmailLogin(q, security, tok, cfg, enqueuer)
}

func (c EmailLoginConfig) withDefaults() EmailLoginConfig {
	if c.HMACKeyID == "" {
		c.HMACKeyID = "default-v1"
	}
	if len(c.HMACKey) == 0 {
		// Composition code should replace this with a deployment secret. The
		// stable fallback prevents a process restart from silently resetting
		// quotas in local/test deployments.
		c.HMACKey = []byte("monaserver-public-email-login-quota-key")
	}
	if c.AddressWindow <= 0 {
		c.AddressWindow = 15 * time.Minute
	}
	if c.AddressLimit <= 0 {
		c.AddressLimit = 3
	}
	if c.AddressDailyWindow <= 0 {
		c.AddressDailyWindow = 24 * time.Hour
	}
	if c.AddressDailyLimit <= 0 {
		c.AddressDailyLimit = 10
	}
	if c.IPWindow <= 0 {
		c.IPWindow = 15 * time.Minute
	}
	if c.IPLimit <= 0 {
		c.IPLimit = 20
	}
	if c.GlobalWindow <= 0 {
		c.GlobalWindow = time.Minute
	}
	if c.GlobalLimit <= 0 {
		c.GlobalLimit = 100
	}
	if c.LoginTokenTTL <= 0 {
		c.LoginTokenTTL = loginLinkTokenTTL
	}
	if c.RecoveryTokenTTL <= 0 {
		c.RecoveryTokenTTL = recoveryTokenTTL
	}
	if c.DeliveryPayloadTTL <= 0 {
		c.DeliveryPayloadTTL = loginDeliveryPayloadTTL
	}
	if c.CallbackURL == "" {
		c.CallbackURL = "https://consumer.example/#/email-login/callback?token="
	}
	return c
}

// SetClock makes expiry/quota tests deterministic and keeps the shared
// security coordinator on the same clock.
func (s *EmailLogin) SetClock(now func() time.Time) {
	if s == nil || now == nil {
		return
	}
	s.mu.Lock()
	s.now = now
	s.mu.Unlock()
	if s.security != nil {
		s.security.SetClock(now)
	}
}

func (s *EmailLogin) SetDeliveryEnqueuer(enqueuer LoginLinkDeliveryEnqueuer) {
	if s == nil {
		return
	}
	s.mu.Lock()
	s.enqueuer = enqueuer
	s.mu.Unlock()
}

// SetTokenIssuer is a test/composition seam. The default issuer is the T03
// transaction-preserving AccountSecurity implementation.
func (s *EmailLogin) SetTokenIssuer(issuer func(context.Context, *db.Queries, uuid.UUID) (*TokenPair, error)) {
	if s == nil || issuer == nil {
		return
	}
	s.mu.Lock()
	s.issuePair = issuer
	s.mu.Unlock()
}

func (s *EmailLogin) clock() func() time.Time {
	s.mu.RLock()
	now := s.now
	s.mu.RUnlock()
	if now == nil {
		return time.Now
	}
	return now
}

// RequestEmailLink applies quotas to every syntactically valid request, then
// silently suppresses all ineligible accounts. It commits quotas and returns
// a generic accepted result for absent, unverified, duplicate, deleted, and
// restricted addresses.
func (s *EmailLogin) RequestEmailLink(ctx context.Context, request EmailLoginRequest) (*EmailLinkRequestResult, error) {
	if s == nil || s.q == nil || s.security == nil {
		return nil, ErrEmailDeliveryUnavailable
	}
	canonical := db.CanonicalEmail(request.Email)
	if canonical == "" {
		return nil, apperrors.ErrBadRequest
	}
	now := s.clock()()
	if now.IsZero() {
		now = time.Now()
	}
	result := &EmailLinkRequestResult{Accepted: true, CanonicalEmail: canonical}
	addressAllowed, rateLimited, err := s.acquireRequestQuotas(ctx, canonical, request.ClientIP, now)
	if err != nil {
		return nil, err
	}
	if rateLimited {
		return nil, ErrEmailRateLimited
	}
	if !addressAllowed {
		return result, nil
	}
	err = s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		// The quota transaction has already committed. This second transaction
		// owns the account, claim, action-token, and delivery writes so a
		// delivery failure cannot roll back abuse accounting.
		// The initial claim read finds the account without locking a claim first.
		// The account is then locked before the claim, matching all account/email
		// mutation lock order and preventing stale ownership decisions.
		claim, err := tx.GetEmailLoginClaim(ctx, canonical)
		if err != nil || claim == nil || claim.OwnerUserID == nil || claim.State != db.EmailClaimOwned {
			return err
		}
		state, err := tx.LockUserSecurity(ctx, *claim.OwnerUserID)
		if err != nil || state == nil {
			return err
		}
		lockedClaim, err := tx.LockEmailLoginClaim(ctx, canonical)
		if err != nil {
			return err
		}
		user, err := tx.GetUserByID(ctx, *claim.OwnerUserID)
		if err != nil || !ownedEmailMatches(state, lockedClaim, canonical, *claim.OwnerUserID) || user == nil {
			return err
		}
		issued, err := s.issueLoginLinkLocked(ctx, tx, state, user, canonical)
		if err != nil {
			return err
		}
		if issued == nil {
			return ErrEmailDeliveryUnavailable
		}
		*result = *issued
		result.Accepted = true
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// acquireRequestQuotas commits public abuse accounting independently from the
// account/action transaction. A provider or database failure while issuing a
// link must not give an attacker a fresh quota window on every retry.
func (s *EmailLogin) acquireRequestQuotas(ctx context.Context, canonical, clientIP string, now time.Time) (addressAllowed, rateLimited bool, err error) {
	err = s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		addressAllowed, err = s.acquireAddressQuotas(ctx, tx, canonical, now)
		if err != nil {
			return err
		}
		ipAllowed, err := s.acquireQuota(ctx, tx, ipBurstScope, clientIP, now, s.cfg.IPWindow, s.cfg.IPLimit)
		if err != nil {
			return err
		}
		globalAllowed, err := s.acquireQuota(ctx, tx, globalScope, "global", now, s.cfg.GlobalWindow, s.cfg.GlobalLimit)
		if err != nil {
			return err
		}
		rateLimited = !ipAllowed || !globalAllowed
		return nil
	})
	return addressAllowed, rateLimited, err
}

// Request is a compact alias used by non-HTTP callers.
func (s *EmailLogin) Request(ctx context.Context, request EmailLoginRequest) (*EmailLinkRequestResult, error) {
	return s.RequestEmailLink(ctx, request)
}

func (s *EmailLogin) acquireAddressQuotas(ctx context.Context, tx *db.Queries, canonical string, now time.Time) (bool, error) {
	allowed, err := s.acquireQuota(ctx, tx, addressBurstScope, canonical, now, s.cfg.AddressWindow, s.cfg.AddressLimit)
	if err != nil || !allowed {
		// Still acquire the daily bucket so every address request participates
		// in both shared limits, even after the short bucket is full.
		dailyAllowed, dailyErr := s.acquireQuota(ctx, tx, addressDailyScope, canonical, now, s.cfg.AddressDailyWindow, s.cfg.AddressDailyLimit)
		if dailyErr != nil {
			return false, dailyErr
		}
		return allowed && dailyAllowed, err
	}
	dailyAllowed, err := s.acquireQuota(ctx, tx, addressDailyScope, canonical, now, s.cfg.AddressDailyWindow, s.cfg.AddressDailyLimit)
	return dailyAllowed, err
}

func (s *EmailLogin) acquireQuota(ctx context.Context, tx *db.Queries, scope, identifier string, now time.Time, window time.Duration, limit int64) (bool, error) {
	if tx == nil || window <= 0 || limit <= 0 {
		return false, db.ErrInvalidQuota
	}
	start := now.UTC().Truncate(window)
	end := start.Add(window)
	keys := s.quotaKeys(scope, identifier)
	decision, err := tx.AcquireSharedQuota(ctx, keysForQuota(keys, scope, start, end, limit), 1)
	if err != nil {
		return false, err
	}
	return decision.Allowed, nil
}

type quotaHMACKey struct {
	ID     string
	Secret []byte
}

func (s *EmailLogin) quotaKeys(scope, identifier string) []quotaHMACKey {
	keys := []quotaHMACKey{{ID: s.cfg.HMACKeyID, Secret: s.cfg.HMACKey}}
	for id, secret := range s.cfg.PreviousHMACKeys {
		if id == "" || len(secret) == 0 || id == s.cfg.HMACKeyID {
			continue
		}
		keys = append(keys, quotaHMACKey{ID: id, Secret: secret})
	}
	for i := range keys {
		mac := hmac.New(sha256.New, keys[i].Secret)
		_, _ = mac.Write([]byte(scope))
		_, _ = mac.Write([]byte{0})
		_, _ = mac.Write([]byte(identifier))
		keys[i].Secret = mac.Sum(nil)
	}
	return keys
}

func keysForQuota(keys []quotaHMACKey, scope string, start, end time.Time, limit int64) []db.SharedQuotaKey {
	out := make([]db.SharedQuotaKey, 0, len(keys))
	for _, key := range keys {
		out = append(out, db.SharedQuotaKey{
			Scope: scope, IdentifierHMAC: append([]byte(nil), key.Secret...), KeyID: key.ID,
			WindowStart: start, WindowEnd: end, Limit: limit,
		})
	}
	return out
}

func ownedEmailMatches(state *db.UserSecurityState, claim *db.EmailLoginClaim, canonical string, owner uuid.UUID) bool {
	return state != nil && claim != nil && claim.State == db.EmailClaimOwned && !claim.IsAmbiguous && claim.OwnerUserID != nil &&
		*claim.OwnerUserID == owner && owner == state.ID && !state.IsDeleted &&
		state.SecurityState == db.SecurityStateNormal && !state.PasswordDisabled &&
		!state.PasswordResetRequired && state.EmailConfirmed && state.Email != nil &&
		db.CanonicalEmail(*state.Email) == canonical
}

func (s *EmailLogin) issueLoginLinkLocked(ctx context.Context, tx *db.Queries, state *db.UserSecurityState, user *db.User, canonical string) (*EmailLinkRequestResult, error) {
	if tx == nil || state == nil || user == nil || !ownedEmailMatches(state, &db.EmailLoginClaim{CanonicalEmail: canonical, OwnerUserID: &state.ID, State: db.EmailClaimOwned}, canonical, state.ID) {
		return nil, nil
	}
	// issueActionTokenLocked is called after the account and claim locks are
	// held. It persists only the hash and binds the current generation/email.
	action, err := s.security.issueActionTokenLocked(ctx, tx, state, db.ActionTokenPurposeLoginLink, &canonical, s.cfg.LoginTokenTTL)
	if err != nil {
		return nil, err
	}
	s.mu.RLock()
	enqueuer := s.enqueuer
	s.mu.RUnlock()
	if enqueuer == nil {
		return nil, ErrEmailDeliveryUnavailable
	}
	deliveryID, err := enqueuer.EnqueueLoginLink(ctx, tx, LoginLinkDeliveryRequest{
		AccountID: state.ID, Username: user.Username, To: canonical, Token: action.Token,
		ActionTokenID: action.ID, AuthGeneration: state.AuthGeneration, ExpiresAt: action.ExpiresAt,
	})
	if err != nil || deliveryID == nil {
		return nil, ErrEmailDeliveryUnavailable
	}
	return &EmailLinkRequestResult{
		Accepted: true, Issued: true, AccountID: state.ID, Username: user.Username,
		CanonicalEmail: canonical, Action: action, DeliveryID: deliveryID,
	}, nil
}

// IssueLoginLink is the admin typed issuance port. It rechecks the current
// canonical claim and account state inside the transaction.
func (s *EmailLogin) IssueLoginLink(ctx context.Context, request LoginLinkIssueRequest) (*EmailLinkRequestResult, error) {
	if s == nil || s.q == nil || request.AccountID == uuid.Nil {
		return nil, apperrors.ErrBadRequest
	}
	var result *EmailLinkRequestResult
	err := s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, request.AccountID)
		if err != nil || state == nil {
			return err
		}
		if state.Email == nil || !state.EmailConfirmed {
			return ErrInvalidEmailLink
		}
		canonical := db.CanonicalEmail(*state.Email)
		claim, err := tx.LockEmailLoginClaim(ctx, canonical)
		if err != nil {
			return err
		}
		user, err := tx.GetUserByID(ctx, request.AccountID)
		if err != nil || user == nil || !ownedEmailMatches(state, claim, canonical, request.AccountID) {
			return ErrInvalidEmailLink
		}
		result, err = s.issueLoginLinkLocked(ctx, tx, state, user, canonical)
		return err
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// ExchangeEmailLink consumes exactly one login token and creates its refresh
// credential in the same transaction. A failed credential insert rolls back
// consumption and sibling revocation.
func (s *EmailLogin) ExchangeEmailLink(ctx context.Context, rawToken string) (*EmailLinkExchangeResult, error) {
	if s == nil || s.q == nil || s.security == nil || s.tok == nil || strings.TrimSpace(rawToken) == "" {
		return nil, ErrInvalidEmailLink
	}
	now := s.clock()()
	if now.IsZero() {
		now = time.Now()
	}
	hash := sha256.Sum256([]byte(rawToken))
	var result *EmailLinkExchangeResult
	err := s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		initial, err := tx.GetAccountActionTokenByHash(ctx, hash[:])
		if err != nil || initial == nil || initial.Purpose != db.ActionTokenPurposeLoginLink || initial.EmailBinding == nil {
			return ErrInvalidEmailLink
		}
		state, err := tx.LockUserSecurity(ctx, initial.AccountID)
		if err != nil || state == nil {
			return err
		}
		claim, err := tx.LockEmailLoginClaim(ctx, *initial.EmailBinding)
		if err != nil {
			return err
		}
		if !ownedEmailMatches(state, claim, db.CanonicalEmail(*initial.EmailBinding), initial.AccountID) {
			return ErrInvalidEmailLink
		}
		consumed, ok, err := tx.ConsumeAccountActionToken(ctx, hash[:], db.ActionTokenPurposeLoginLink, now)
		if err != nil {
			return err
		}
		if !ok || consumed == nil {
			return ErrInvalidEmailLink
		}
		user, err := tx.GetUserByID(ctx, consumed.AccountID)
		if err != nil || user == nil {
			return ErrInvalidEmailLink
		}
		s.mu.RLock()
		issuer := s.issuePair
		s.mu.RUnlock()
		if issuer == nil {
			return ErrEmailDeliveryUnavailable
		}
		pair, err := issuer(ctx, tx, consumed.AccountID)
		if err != nil {
			return err
		}
		result = &EmailLinkExchangeResult{Pair: pair, Username: user.Username, AccountID: consumed.AccountID, AuthGeneration: state.AuthGeneration}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrInvalidEmailLink) {
			return nil, ErrInvalidEmailLink
		}
		return nil, err
	}
	return result, nil
}

// Exchange is a compact alias used by non-HTTP callers.
func (s *EmailLogin) Exchange(ctx context.Context, rawToken string) (*EmailLinkExchangeResult, error) {
	return s.ExchangeEmailLink(ctx, rawToken)
}

type EmailLinkExchangeResult struct {
	Pair           *TokenPair
	Username       string
	AccountID      uuid.UUID
	AuthGeneration int64
}

// DurableLoginLinkEnqueuer encrypts the ephemeral token, writes one delivery
// attempt, and enqueues one durable delivery job in the caller transaction.
type DurableLoginLinkEnqueuer struct {
	keys     *DeliveryKeyRing
	callback string
	clock    func() time.Time
}

func NewDurableLoginLinkEnqueuer(keys *DeliveryKeyRing, callback string, clock func() time.Time) *DurableLoginLinkEnqueuer {
	if clock == nil {
		clock = time.Now
	}
	return &DurableLoginLinkEnqueuer{keys: keys, callback: callback, clock: clock}
}

func (e *DurableLoginLinkEnqueuer) EnqueueLoginLink(ctx context.Context, tx *db.Queries, request LoginLinkDeliveryRequest) (*uuid.UUID, error) {
	if e == nil || e.keys == nil || tx == nil || request.AccountID == uuid.Nil || request.ActionTokenID == uuid.Nil || request.Token == "" || request.To == "" {
		return nil, ErrEmailDeliveryUnavailable
	}
	now := e.clock()
	if now.IsZero() {
		now = time.Now()
	}
	content := loginLinkEmailContent(request.Username, request.To, request.Token, e.callback)
	plaintext, err := json.Marshal(DeliveryPayload{Email: &content})
	if err != nil {
		return nil, err
	}
	envelope, err := e.keys.EncryptPayload(plaintext, now, loginDeliveryPayloadTTL)
	if err != nil {
		return nil, ErrEmailDeliveryUnavailable
	}
	attemptID := uuid.New()
	if err := tx.CreateDeliveryAttempt(ctx, db.DeliveryAttemptParams{
		ID: attemptID, Channel: "email", AccountID: &request.AccountID, Status: DeliveryStatusPending,
		AttemptNumber: 0, EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &envelope.KeyID,
		PayloadExpiresAt: &envelope.ExpiresAt,
	}); err != nil {
		return nil, err
	}
	payload, err := json.Marshal(DeliveryJobPayload{AttemptID: attemptID})
	if err != nil {
		return nil, err
	}
	// PostgreSQL jsonb renders object separators with a space. Keep the
	// serialized form aligned with that representation because the existing
	// durable-job idempotency adapter compares the read-back bytes.
	payload = bytes.Replace(payload, []byte(`":`), []byte(`": `), 1)
	if _, err := jobs.EnqueueDurableJob(ctx, tx, jobs.EnqueueRequest{
		Kind: KindEmailDelivery, IdempotencyKey: "email-login:" + request.ActionTokenID.String(),
		Payload: payload, Priority: 100, AvailableAt: now, MaxAttempts: 5,
	}); err != nil {
		return nil, err
	}
	return &attemptID, nil
}

var loginLinkEmailTemplate = template.Must(template.New("email-login").Parse(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="color-scheme" content="light"><title>Sign in to Stick-It</title></head>
<body style="font-family:Arial,sans-serif;background:#f3f4f6;padding:24px"><main style="max-width:480px;margin:auto;background:#fff;padding:32px;border-radius:12px">
<h1>Sign in to Stick-It</h1><p>Hi {{.Username}},</p><p>Use the button below to sign in. This link expires in 15 minutes and can be used once.</p>
<p><a href="{{.URL}}" style="display:inline-block;padding:12px 20px;background:#4f46e5;color:#fff;text-decoration:none;border-radius:8px">Sign in</a></p>
<p>If you did not request this email, you can ignore it.</p></main></body></html>`))

type loginLinkEmailData struct {
	Username string
	URL      string
}

func loginLinkEmailContent(username, to, rawToken, callback string) EmailContent {
	callback = strings.TrimRight(callback, "&?")
	if !strings.Contains(callback, "token=") {
		if strings.HasSuffix(callback, "=") {
			callback += rawToken
		} else if strings.Contains(callback, "?") {
			callback += "&token=" + rawToken
		} else {
			callback += "?token=" + rawToken
		}
	} else {
		callback += rawToken
	}
	data := loginLinkEmailData{Username: username, URL: callback}
	var htmlBody bytes.Buffer
	if err := loginLinkEmailTemplate.Execute(&htmlBody, data); err != nil {
		htmlBody.WriteString(template.HTMLEscapeString(callback))
	}
	return EmailContent{
		To: to, Subject: "Sign in to Stick-It",
		Body: "Use this one-time link to sign in to Stick-It: " + callback,
		HTML: htmlBody.String(),
	}
}

// EmailLoginClientIPFromContext is the optional context bridge used by the
// handler. The key is private so a public header cannot spoof it.
type emailLoginClientIPContextKey struct{}

func WithEmailLoginClientIP(ctx context.Context, clientIP string) context.Context {
	return context.WithValue(ctx, emailLoginClientIPContextKey{}, strings.TrimSpace(clientIP))
}

func EmailLoginClientIPFromContext(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	value, _ := ctx.Value(emailLoginClientIPContextKey{}).(string)
	return value
}
