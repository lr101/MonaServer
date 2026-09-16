package service

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/jobs"
)

var (
	ErrInvalidRecoveryToken    = apperrors.New(http.StatusBadRequest, "invalid recovery token")
	ErrInvalidRecoveryPassword = apperrors.New(http.StatusBadRequest, "invalid recovery password")
)

// RecoveryCompletionRequest is the restricted POST-only recovery input.
// Completing recovery never returns a consumer credential.
type RecoveryCompletionRequest struct {
	Token    string
	Password string
}

// AccountRecovery consumes restricted recovery capabilities and clears the
// containment state only after a valid replacement password is available.
type AccountRecovery struct {
	q        *db.Queries
	security *AccountSecurity
	now      func() time.Time
}

func NewAccountRecovery(q *db.Queries, security *AccountSecurity) *AccountRecovery {
	if security == nil {
		security = NewAccountSecurity(q)
	}
	return &AccountRecovery{q: q, security: security, now: time.Now}
}

// NewRecoveryService is a descriptive constructor alias.
func NewRecoveryService(q *db.Queries, security *AccountSecurity) *AccountRecovery {
	return NewAccountRecovery(q, security)
}

func (s *AccountRecovery) SetClock(now func() time.Time) {
	if s == nil || now == nil {
		return
	}
	s.now = now
	if s.security != nil {
		s.security.SetClock(now)
	}
}

// CompleteRecovery validates password policy before consuming the one-use
// action. The account and current owned email claim are then rechecked under
// lock, old credentials and sibling capabilities are invalidated, and the
// restriction is cleared. A delivery outage cannot affect this completion.
func (s *AccountRecovery) CompleteRecovery(ctx context.Context, request RecoveryCompletionRequest) error {
	if s == nil || s.q == nil || s.security == nil || strings.TrimSpace(request.Token) == "" {
		return ErrInvalidRecoveryToken
	}
	if err := ValidateRecoveryPassword(request.Password); err != nil {
		return err
	}
	// T03 owns the account lock order, bound-token consumption, generation
	// advance, credential invalidation, and restriction transition. T06 only
	// adds the consumer password policy and maps its generic invalid-action
	// result to the public recovery error.
	err := s.security.CompleteRecovery(ctx, request.Token, request.Password)
	if errors.Is(err, ErrInvalidAction) {
		return ErrInvalidRecoveryToken
	}
	return err
}

// CompleteRecoveryToken is an alias for callers that already use token
// terminology.
func (s *AccountRecovery) CompleteRecoveryToken(ctx context.Context, rawToken, newPassword string) error {
	return s.CompleteRecovery(ctx, RecoveryCompletionRequest{Token: rawToken, Password: newPassword})
}

// ValidateRecoveryPassword mirrors the frozen v3 recovery schema: a valid
// UTF-8 string with 8 through 256 Unicode code points. The schema does not
// impose an ASCII allowlist or a narrower legacy-login length.
func ValidateRecoveryPassword(value string) error {
	if !utf8.ValidString(value) {
		return ErrInvalidRecoveryPassword
	}
	length := utf8.RuneCountInString(value)
	if length < 8 || length > 256 {
		return ErrInvalidRecoveryPassword
	}
	return nil
}

// DurableRecoveryEnqueuer creates the restricted action and encrypted
// delivery attempt inside T03's containment transaction. It never invokes a
// provider and reports manual recovery when no current owned destination is
// available.
type DurableRecoveryEnqueuer struct {
	security   *AccountSecurity
	keys       *DeliveryKeyRing
	callback   string
	clock      func() time.Time
	payloadTTL time.Duration
}

func NewDurableRecoveryEnqueuer(security *AccountSecurity, keys *DeliveryKeyRing, callback string, clock func() time.Time, payloadTTL ...time.Duration) *DurableRecoveryEnqueuer {
	if clock == nil {
		clock = time.Now
	}
	ttl := recoveryTokenTTL
	if len(payloadTTL) > 0 && payloadTTL[0] > 0 {
		ttl = payloadTTL[0]
	}
	return &DurableRecoveryEnqueuer{security: security, keys: keys, callback: callback, clock: clock, payloadTTL: ttl}
}

func (e *DurableRecoveryEnqueuer) EnqueueRecovery(ctx context.Context, tx *db.Queries, request RecoveryEnqueueRequest) (RecoveryEnqueueResult, error) {
	if e == nil || e.security == nil || e.keys == nil || tx == nil || request.AccountID == uuid.Nil || request.VerifiedEmail == nil {
		if request.VerifiedEmail == nil {
			return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, nil
		}
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, ErrEmailDeliveryUnavailable
	}
	canonical := db.CanonicalEmail(*request.VerifiedEmail)
	if canonical == "" {
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, nil
	}
	state, err := tx.LockUserSecurity(ctx, request.AccountID)
	if err != nil {
		return RecoveryEnqueueResult{}, err
	}
	if state == nil || state.IsDeleted || state.AuthGeneration != request.AuthGeneration || state.Email == nil ||
		!state.EmailConfirmed || db.CanonicalEmail(*state.Email) != canonical {
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, nil
	}
	claim, err := tx.LockEmailLoginClaim(ctx, canonical)
	if err != nil {
		return RecoveryEnqueueResult{}, err
	}
	if !recoveryEmailMatches(state, claim, canonical, request.AccountID) {
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, nil
	}
	if err := e.ensureKeyAvailable(); err != nil {
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, err
	}
	// Issue the token only after key/destination validation. If a later
	// durable write fails, revoke the just-created recovery capability before
	// returning so containment remains fenced and retries mint no stale token.
	action, err := e.security.issueActionTokenLocked(ctx, tx, state, db.ActionTokenPurposeRecovery, &canonical, recoveryTokenTTL)
	if err != nil {
		return RecoveryEnqueueResult{}, err
	}
	user, err := tx.GetUserByID(ctx, request.AccountID)
	if err != nil || user == nil {
		_ = tx.RevokeAccountActionTokens(ctx, request.AccountID, db.ActionTokenPurposeRecovery)
		return RecoveryEnqueueResult{}, err
	}
	content := recoveryEmailContent(user.Username, canonical, action.Token, e.callback)
	when := e.clock()
	if when.IsZero() {
		when = time.Now()
	}
	metadata := authenticatedDeliveryMetadata{
		ActionTokenID:  action.ID,
		TokenHash:      sha256Bytes(action.Token),
		Purpose:        db.ActionTokenPurposeRecovery,
		AccountID:      request.AccountID,
		AuthGeneration: request.AuthGeneration,
		CanonicalEmail: canonical,
	}
	plaintext, err := marshalAuthenticatedEmailPayload(content, metadata)
	if err != nil {
		_ = tx.RevokeAccountActionTokens(ctx, request.AccountID, db.ActionTokenPurposeRecovery)
		return RecoveryEnqueueResult{}, err
	}
	ttl, ok := boundedDeliveryTTL(e.payloadTTL, action.ExpiresAt, when)
	if !ok {
		_ = tx.RevokeAccountActionTokens(ctx, request.AccountID, db.ActionTokenPurposeRecovery)
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, ErrEmailDeliveryUnavailable
	}
	envelope, err := e.keys.EncryptPayload(plaintext, when, ttl)
	if err != nil {
		_ = tx.RevokeAccountActionTokens(ctx, request.AccountID, db.ActionTokenPurposeRecovery)
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, ErrEmailDeliveryUnavailable
	}
	attemptID, err := enqueueEncryptedEmail(ctx, tx, request.AccountID, "recovery:"+action.ID.String(), KindRecoveryDelivery, content, envelope, when)
	if err != nil {
		_ = tx.RevokeAccountActionTokens(ctx, request.AccountID, db.ActionTokenPurposeRecovery)
		return RecoveryEnqueueResult{}, err
	}
	return RecoveryEnqueueResult{AttemptID: attemptID, Status: RecoveryEnqueueQueued}, nil
}

// recoveryEmailMatches applies the trusted-address binding required to leave
// containment. Recovery is deliberately allowed to run while the account is
// compromised/password-disabled; the normal login predicate would reject the
// very state that requires recovery. Deleted/manual-recovery accounts remain
// ineligible through the explicit state checks below and the claim owner.
func recoveryEmailMatches(state *db.UserSecurityState, claim *db.EmailLoginClaim, canonical string, owner uuid.UUID) bool {
	if state == nil || claim == nil || canonical == "" || claim.State != db.EmailClaimOwned || claim.IsAmbiguous ||
		claim.OwnerUserID == nil || *claim.OwnerUserID != owner || owner != state.ID ||
		state.IsDeleted || !state.EmailConfirmed || state.Email == nil ||
		db.CanonicalEmail(*state.Email) != canonical {
		return false
	}
	switch state.SecurityState {
	case db.SecurityStateNormal, db.SecurityStatePasswordDisabled, db.SecurityStateCompromised:
		return state.PasswordResetRequired
	default:
		return false
	}
}

func (e *DurableRecoveryEnqueuer) ensureKeyAvailable() error {
	if e == nil || e.keys == nil {
		return ErrEmailDeliveryUnavailable
	}
	return nil
}

func recoveryEmailContent(username, to, rawToken, callback string) EmailContent {
	callback = strings.TrimRight(callback, "&?")
	if strings.Contains(callback, "token=") {
		callback += rawToken
	} else if strings.HasSuffix(callback, "=") {
		callback += rawToken
	} else if strings.Contains(callback, "?") {
		callback += "&token=" + rawToken
	} else {
		callback += "?token=" + rawToken
	}
	return EmailContent{
		To: to, Subject: "Recover your Stick-It account",
		Body: "Use this restricted recovery link to choose a new Stick-It password: " + callback,
		HTML: "<p>Hi " + escapeHTML(username) + ",</p><p>Use this restricted recovery link to choose a new password:</p><p><a href=\"" + escapeHTML(callback) + "\">Recover your account</a></p>",
	}
}

func escapeHTML(value string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", "\"", "&#34;", "'", "&#39;").Replace(value)
}

func enqueueEncryptedEmail(ctx context.Context, tx *db.Queries, accountID uuid.UUID, idempotencyKey, kind string, _ EmailContent, envelope EncryptedDeliveryPayload, now time.Time) (*uuid.UUID, error) {
	if tx == nil || accountID == uuid.Nil || idempotencyKey == "" || kind == "" || now.IsZero() {
		return nil, ErrEmailDeliveryUnavailable
	}
	attemptID := uuid.New()
	if err := tx.CreateDeliveryAttempt(ctx, db.DeliveryAttemptParams{
		ID: attemptID, Channel: "email", AccountID: &accountID, Status: DeliveryStatusPending,
		AttemptNumber: 0, EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &envelope.KeyID,
		PayloadExpiresAt: &envelope.ExpiresAt,
	}); err != nil {
		return nil, err
	}
	payload, err := json.Marshal(DeliveryJobPayload{AttemptID: attemptID})
	if err != nil {
		return nil, err
	}
	// Keep the job JSON in PostgreSQL's jsonb output form. The shared durable
	// enqueue adapter compares its read-back bytes when checking idempotency.
	payload = []byte(strings.Replace(string(payload), `":`, `": `, 1))
	if _, err := jobs.EnqueueDurableJob(ctx, tx, jobs.EnqueueRequest{
		Kind: kind, IdempotencyKey: idempotencyKey, Payload: payload,
		Priority: 100, AvailableAt: now, MaxAttempts: 5,
	}); err != nil {
		return nil, err
	}
	return &attemptID, nil
}
