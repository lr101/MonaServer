package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/password"
	"github.com/lrprojects/monaserver/internal/token"
)

var (
	// ErrStaleGeneration is intentionally generic. Callers must not disclose
	// whether an account was contained, deleted, or merely had an old token.
	ErrStaleGeneration   = apperrors.New(http.StatusUnauthorized, "invalid token")
	ErrAccountRestricted = apperrors.New(http.StatusUnauthorized, "invalid token")
	ErrInvalidAction     = apperrors.New(http.StatusBadRequest, "invalid action token")
)

// These limits are the security service boundary for incident/audit input.
// Callers may impose stricter limits, but untrusted callers cannot bypass the
// storage contract by invoking this service directly.
const (
	maxContainmentReasonBytes   = 1024
	maxContainmentMetadataBytes = 16 * 1024
)

// ContainmentRequest is the security decision made by an administrative
// caller. Metadata is bounded/sanitized by the caller and never contains
// credentials; the security service stores it only in the audit records.
type ContainmentRequest struct {
	AccountID uuid.UUID
	ActorID   *uuid.UUID
	Reason    string
	Metadata  []byte
	Now       time.Time
}

// ContainmentResult reports the committed generation and recovery routing.
// The recovery status is informational; containment remains committed when a
// delivery adapter is unavailable.
type ContainmentResult struct {
	AccountID     uuid.UUID
	PreviousState string
	NewState      string
	Generation    int64
	Recovery      RecoveryEnqueueResult
}

// ActionToken is returned only at the issuance boundary. The raw value must
// be delivered immediately and is never persisted; the database stores its
// SHA-256 hash in account_action_tokens.
type ActionToken struct {
	ID             uuid.UUID
	Token          string
	Purpose        string
	AccountID      uuid.UUID
	AuthGeneration int64
	ExpiresAt      time.Time
}

// AccountSecurity owns the account lock order and all consumer credential
// invalidation. Its query object is always the caller's facade; transaction
// callbacks never use Pool or start an independent transaction.
type AccountSecurity struct {
	q        *db.Queries
	enqueuer RecoveryEnqueuer
	now      func() time.Time
}

func NewAccountSecurity(q *db.Queries, enqueuer ...RecoveryEnqueuer) *AccountSecurity {
	var e RecoveryEnqueuer = noOpRecoveryEnqueuer{}
	if len(enqueuer) > 0 && enqueuer[0] != nil {
		e = enqueuer[0]
	}
	return &AccountSecurity{q: q, enqueuer: e, now: time.Now}
}

// SetRecoveryEnqueuer wires the durable adapter at composition time. The
// default implementation records a deterministic status and performs no
// provider I/O, which keeps containment useful before T04 is integrated.
func (s *AccountSecurity) SetRecoveryEnqueuer(enqueuer RecoveryEnqueuer) {
	if enqueuer == nil {
		s.enqueuer = noOpRecoveryEnqueuer{}
		return
	}
	s.enqueuer = enqueuer
}

// SetClock is intended for deterministic service tests and local harnesses.
func (s *AccountSecurity) SetClock(now func() time.Time) {
	if now != nil {
		s.now = now
	}
}

func (s *AccountSecurity) GetSecurityState(ctx context.Context, id uuid.UUID) (*db.UserSecurityState, error) {
	if s == nil || s.q == nil || id == uuid.Nil {
		return nil, nil
	}
	return s.q.GetUserSecurityState(ctx, id)
}

// ValidateGeneration checks a parsed access-token claim against current state.
// A token with no claim is accepted only for generation-zero accounts.
func (s *AccountSecurity) ValidateGeneration(ctx context.Context, id uuid.UUID, generation int64, generationPresent bool) error {
	state, err := s.GetSecurityState(ctx, id)
	if err != nil {
		return err
	}
	return ValidateGenerationAgainstState(state, generation, generationPresent)
}

// AdvanceGenerationForMutation is used by an already account-locked
// password/email mutation. It fences every credential that was issued before
// the mutation while leaving the account in its current normal state. The
// caller must pass the transaction facade that owns the lock.
func (s *AccountSecurity) AdvanceGenerationForMutation(ctx context.Context, q *db.Queries, id uuid.UUID) (int64, error) {
	if s == nil || q == nil || id == uuid.Nil {
		return 0, apperrors.ErrBadRequest
	}
	state, err := q.GetUserSecurityState(ctx, id)
	if err != nil {
		return 0, err
	}
	if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired {
		return 0, ErrAccountRestricted
	}
	verifiedEmail, err := canonicalVerifiedEmail(ctx, q, state)
	if err != nil {
		return 0, err
	}
	if err := invalidateLegacyActionValues(ctx, q, id, state.Email, verifiedEmail != nil, s.now()); err != nil {
		return 0, err
	}
	generation, err := q.AdvanceUserAuthGeneration(ctx, id)
	if err != nil {
		return 0, err
	}
	if err := q.InvalidateUserTokens(ctx, id); err != nil {
		return 0, err
	}
	if err := q.RevokeAccountActionTokens(ctx, id, ""); err != nil {
		return 0, err
	}
	if err := q.RevokeAdminSessionsForUser(ctx, id); err != nil {
		return 0, err
	}
	if err := q.RevokeAdminLoginChallengesForUser(ctx, id); err != nil {
		return 0, err
	}
	return generation, nil
}

func (s *AccountSecurity) AdvanceGeneration(ctx context.Context, q *db.Queries, id uuid.UUID) (int64, error) {
	return s.AdvanceGenerationForMutation(ctx, q, id)
}

// ValidateGenerationAgainstState is the pure state/claim rule shared by
// middleware tests and non-HTTP callers.
func ValidateGenerationAgainstState(state *db.UserSecurityState, generation int64, generationPresent bool) error {
	if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired {
		return ErrAccountRestricted
	}
	if generation < 0 {
		return ErrStaleGeneration
	}
	if generationPresent {
		if generation != state.AuthGeneration {
			return ErrStaleGeneration
		}
		return nil
	}
	if state.AuthGeneration != 0 {
		return ErrStaleGeneration
	}
	return nil
}

// ContainAccount atomically fences all consumer and admin credentials. The
// user row is locked before every account-scoped token/session mutation. A
// failed recovery enqueue is represented as manual recovery and never rolls
// back the committed containment decision.
func (s *AccountSecurity) ContainAccount(ctx context.Context, req ContainmentRequest) (*ContainmentResult, error) {
	if s == nil || s.q == nil || req.AccountID == uuid.Nil {
		return nil, apperrors.ErrBadRequest
	}
	if req.Reason == "" {
		req.Reason = "account security containment"
	}
	if len(req.Reason) > maxContainmentReasonBytes || len(req.Metadata) > maxContainmentMetadataBytes {
		return nil, apperrors.ErrBadRequest
	}
	now := req.Now
	if now.IsZero() {
		now = s.now()
	}
	if now.IsZero() {
		now = time.Now()
	}
	if !json.Valid(req.Metadata) {
		req.Metadata = nil
	}
	var result *ContainmentResult
	err := s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, req.AccountID)
		if err != nil {
			return err
		}
		if state == nil {
			return apperrors.ErrNotFound
		}
		result = &ContainmentResult{AccountID: req.AccountID, PreviousState: state.SecurityState}

		// Repeated administrative delivery/retry commands must not keep
		// advancing the generation or append duplicate incidents.
		if state.IsDeleted || (state.PasswordDisabled && state.PasswordResetRequired &&
			(state.SecurityState == db.SecurityStateCompromised || state.SecurityState == db.SecurityStateSecuredManualRecovery)) {
			result.NewState = state.SecurityState
			result.Generation = state.AuthGeneration
			if state.IsDeleted {
				result.Recovery.Status = RecoveryEnqueueManualRecoveryRequired
				return nil
			}
			verifiedEmail, err := canonicalVerifiedEmail(ctx, tx, state)
			if err != nil {
				return err
			}
			if verifiedEmail == nil {
				result.Recovery.Status = RecoveryEnqueueManualRecoveryRequired
				return nil
			}
			queued, enqueueErr := s.enqueuer.EnqueueRecovery(ctx, tx, RecoveryEnqueueRequest{
				AccountID: req.AccountID, ActorID: req.ActorID, AuthGeneration: state.AuthGeneration,
				Reason: RecoveryReasonCompromise, VerifiedEmail: verifiedEmail,
			})
			queued = normalizeRecoveryEnqueueResult(queued, enqueueErr, verifiedEmail)
			result.Recovery = queued
			return nil
		}

		verifiedEmail, err := canonicalVerifiedEmail(ctx, tx, state)
		if err != nil {
			return err
		}
		newState := db.SecurityStateCompromised
		if verifiedEmail == nil {
			newState = db.SecurityStateSecuredManualRecovery
		}
		if err := invalidateLegacyActionValues(ctx, tx, req.AccountID, state.Email, verifiedEmail != nil, now); err != nil {
			return err
		}
		generation, err := tx.AdvanceUserAuthGeneration(ctx, req.AccountID)
		if err != nil {
			return err
		}
		if err := tx.SetUserSecurityState(ctx, req.AccountID, newState, true, true, &now); err != nil {
			return err
		}
		if err := tx.InvalidateUserTokens(ctx, req.AccountID); err != nil {
			return err
		}
		if err := tx.RevokeAccountActionTokens(ctx, req.AccountID, ""); err != nil {
			return err
		}
		if err := tx.RevokeAdminSessionsForUser(ctx, req.AccountID); err != nil {
			return err
		}
		if err := tx.RevokeAdminLoginChallengesForUser(ctx, req.AccountID); err != nil {
			return err
		}

		previous := state.SecurityState
		if previous == "" {
			previous = db.SecurityStateNormal
		}
		if err := tx.CreateSecurityIncident(ctx, db.SecurityIncidentParams{
			ID: uuid.New(), AccountID: req.AccountID, ActorID: req.ActorID,
			Reason: req.Reason, PreviousState: stringPtr(previous), NewState: newState,
			AuthGeneration: generation, Metadata: req.Metadata,
		}); err != nil {
			return err
		}

		queued, enqueueErr := s.enqueuer.EnqueueRecovery(ctx, tx, RecoveryEnqueueRequest{
			AccountID: req.AccountID, ActorID: req.ActorID, AuthGeneration: generation,
			Reason: RecoveryReasonCompromise, VerifiedEmail: verifiedEmail,
		})
		queued = normalizeRecoveryEnqueueResult(queued, enqueueErr, verifiedEmail)
		result.NewState = newState
		result.Generation = generation
		result.Recovery = queued

		reason := req.Reason
		outcome := string(queued.Status)
		return tx.CreateAuditEvent(ctx, db.AuditEventParams{
			ID: uuid.New(), ActorID: req.ActorID, TargetAccountID: &req.AccountID,
			Action: "account_containment", Reason: &reason, Outcome: &outcome, Metadata: req.Metadata,
		})
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// Contains is a compact compatibility alias used by callers that already
// represent containment as an account operation.
func (s *AccountSecurity) Contains(ctx context.Context, accountID uuid.UUID, actorID *uuid.UUID, reason string) (*ContainmentResult, error) {
	return s.ContainAccount(ctx, ContainmentRequest{AccountID: accountID, ActorID: actorID, Reason: reason})
}

// MarkCompromised is the explicit security-action alias used by admin flows.
func (s *AccountSecurity) MarkCompromised(ctx context.Context, accountID uuid.UUID, actorID *uuid.UUID, reason string) (*ContainmentResult, error) {
	return s.Contains(ctx, accountID, actorID, reason)
}

// RevokeOwnSession revokes only the submitted refresh credential after
// verifying that it belongs to callerID. Account-wide generation revocation
// is deliberately a separate containment operation.
func (s *AccountSecurity) RevokeOwnSession(ctx context.Context, callerID, refreshID uuid.UUID) error {
	if s == nil || s.q == nil || callerID == uuid.Nil || refreshID == uuid.Nil {
		return apperrors.ErrBadRequest
	}
	return s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, callerID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted {
			return apperrors.ErrBadRequest
		}
		stored, err := tx.FindRefreshToken(ctx, refreshID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil
			}
			return err
		}
		if stored == nil || stored.UserID != callerID {
			return apperrors.ErrBadRequest
		}
		return tx.DeleteRefreshToken(ctx, refreshID)
	})
}

func (s *AccountSecurity) RevokeOwnRefreshToken(ctx context.Context, callerID, refreshID uuid.UUID) error {
	return s.RevokeOwnSession(ctx, callerID, refreshID)
}

// IssueTokens issues an access/refresh pair through the supplied query facade.
// A transaction facade is accepted and preserved; callers that need an atomic
// mutation must pass the *db.Queries received from InTx.
func (s *AccountSecurity) IssueTokens(ctx context.Context, q *db.Queries, tok *token.Helper, uid uuid.UUID) (*TokenPair, error) {
	if q == nil {
		q = s.q
	}
	if q == nil || tok == nil || uid == uuid.Nil {
		return nil, apperrors.ErrBadRequest
	}
	state, err := q.GetUserSecurityState(ctx, uid)
	if err != nil {
		return nil, err
	}
	if state == nil {
		return nil, apperrors.ErrNotFound
	}
	if state.IsDeleted || state.PasswordDisabled || state.PasswordResetRequired || state.SecurityState != db.SecurityStateNormal {
		return nil, ErrAccountRestricted
	}
	access, err := tok.GenerateAccessTokenWithGeneration(uid, state.AuthGeneration)
	if err != nil {
		return nil, err
	}
	refresh, err := q.CreateRefreshToken(ctx, uid)
	if err != nil {
		return nil, err
	}
	return &TokenPair{AccessToken: access, RefreshToken: refresh, UserID: uid}, nil
}

// IssueActionToken creates a purpose-bound opaque capability and persists only
// its hash. If q is a root facade, the method owns a transaction; if q is a
// caller transaction, it stays inside that transaction.
func (s *AccountSecurity) IssueActionToken(ctx context.Context, q *db.Queries, uid uuid.UUID, purpose string, emailBinding *string, ttl time.Duration) (*ActionToken, error) {
	if s == nil || s.q == nil || uid == uuid.Nil || ttl <= 0 || !validActionPurpose(purpose) {
		return nil, ErrInvalidAction
	}
	if q == nil {
		q = s.q
	}
	var issued *ActionToken
	issue := func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, uid)
		if err != nil {
			return err
		}
		issued, err = s.issueActionTokenLocked(ctx, tx, state, purpose, emailBinding, ttl)
		return err
	}
	var err error
	if q.Pool() == nil {
		err = issue(q)
	} else {
		err = q.InTxRetry(ctx, issue)
	}
	if err != nil {
		return nil, err
	}
	return issued, nil
}

// IssueLegacyActionToken upgrades one still-current legacy URL to a
// purpose-bound opaque action while holding the account lock. The legacy URL
// is versioned in the same transaction, so a concurrent request cannot mint a
// second action from it or carry it across an email/generation mutation.
func (s *AccountSecurity) IssueLegacyActionToken(ctx context.Context, rawURL, purpose string, ttl time.Duration) (*ActionToken, error) {
	if s == nil || s.q == nil || rawURL == "" || ttl <= 0 ||
		(purpose != db.ActionTokenPurposeRecovery && purpose != db.ActionTokenPurposeDeleteAccount) {
		return nil, ErrInvalidAction
	}
	var issued *ActionToken
	now := s.now()
	if now.IsZero() {
		now = time.Now()
	}
	issue := func(tx *db.Queries) error {
		var lookup *db.UserURLLookup
		var err error
		switch purpose {
		case db.ActionTokenPurposeRecovery:
			lookup, err = tx.GetUserByResetPasswordUrl(ctx, rawURL)
		case db.ActionTokenPurposeDeleteAccount:
			lookup, err = tx.GetUserByDeletionUrl(ctx, rawURL)
		}
		if err != nil {
			return err
		}
		if lookup == nil {
			return ErrInvalidAction
		}
		state, err := tx.LockUserSecurity(ctx, lookup.ID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted {
			return ErrInvalidAction
		}
		// Re-read the full row after the lock. The URL lookup can have used a
		// snapshot from before a concurrent email, containment, or recovery
		// mutation committed.
		u, err := tx.GetUserByID(ctx, lookup.ID)
		if err != nil {
			return err
		}
		if u == nil {
			return ErrInvalidAction
		}
		var currentURL *string
		var expiresAt *time.Time
		switch purpose {
		case db.ActionTokenPurposeRecovery:
			currentURL, expiresAt = u.ResetPasswordUrl, u.ResetPasswordExpiration
		case db.ActionTokenPurposeDeleteAccount:
			currentURL, expiresAt = u.DeletionUrl, u.CodeExpiration
		}
		if currentURL == nil || *currentURL != rawURL || expiresAt == nil || !expiresAt.After(now) {
			return ErrInvalidAction
		}
		var emailBinding *string
		if purpose == db.ActionTokenPurposeRecovery {
			emailBinding, err = canonicalVerifiedEmail(ctx, tx, state)
			if err != nil {
				return err
			}
			if emailBinding == nil {
				return ErrInvalidAction
			}
		}
		issued, err = s.issueActionTokenLocked(ctx, tx, state, purpose, emailBinding, ttl)
		if err != nil {
			return err
		}
		return versionLegacyActionURL(ctx, tx, lookup.ID, purpose, now)
	}
	var err error
	if s.q.Pool() == nil {
		err = issue(s.q)
	} else {
		err = s.q.InTxRetry(ctx, issue)
	}
	if err != nil {
		return nil, err
	}
	return issued, nil
}

// ConfirmLegacyEmail checks the presented confirmation URL after taking the
// account lock. This closes the lookup-then-confirm race where an old link
// could confirm a newly changed address.
func (s *AccountSecurity) ConfirmLegacyEmail(ctx context.Context, rawURL string) (string, error) {
	if s == nil || s.q == nil || rawURL == "" {
		return "", ErrInvalidAction
	}
	var username string
	err := s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		lookup, err := tx.GetUserByEmailConfirmationUrl(ctx, rawURL)
		if err != nil {
			return err
		}
		if lookup == nil {
			return ErrInvalidAction
		}
		state, err := tx.LockUserSecurity(ctx, lookup.ID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordResetRequired {
			return ErrInvalidAction
		}
		u, err := tx.GetUserByID(ctx, lookup.ID)
		if err != nil {
			return err
		}
		if u == nil || u.EmailConfirmationUrl == nil || *u.EmailConfirmationUrl != rawURL {
			return ErrInvalidAction
		}
		confirmed, err := tx.ConfirmUserEmailWithClaim(ctx, lookup.ID)
		if err != nil {
			return err
		}
		if !confirmed {
			return ErrInvalidAction
		}
		username = u.Username
		return nil
	})
	return username, err
}

// issueActionTokenLocked is the common issuance boundary. Callers must hold
// the account row lock before entering it; email binding validation acquires
// the canonical claim lock in the documented account-then-claim order.
func (s *AccountSecurity) issueActionTokenLocked(ctx context.Context, q *db.Queries, state *db.UserSecurityState, purpose string, emailBinding *string, ttl time.Duration) (*ActionToken, error) {
	if s == nil || q == nil || state == nil || state.IsDeleted || ttl <= 0 || !validActionPurpose(purpose) {
		return nil, ErrInvalidAction
	}
	if purpose == db.ActionTokenPurposeRecovery {
		if !state.PasswordResetRequired || (state.SecurityState != db.SecurityStateNormal &&
			state.SecurityState != db.SecurityStatePasswordDisabled && state.SecurityState != db.SecurityStateCompromised) {
			return nil, ErrInvalidAction
		}
	} else if state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired {
		return nil, ErrInvalidAction
	}
	if emailBinding != nil {
		trusted, err := canonicalVerifiedEmail(ctx, q, state)
		if err != nil {
			return nil, err
		}
		canonical := db.CanonicalEmail(*emailBinding)
		if trusted == nil || canonical == "" || canonical != *trusted {
			return nil, ErrInvalidAction
		}
		emailBinding = trusted
	} else if purpose == db.ActionTokenPurposeRecovery {
		return nil, ErrInvalidAction
	}
	raw, err := randomOpaqueToken()
	if err != nil {
		return nil, err
	}
	hash := sha256.Sum256([]byte(raw))
	now := s.now()
	if now.IsZero() {
		now = time.Now()
	}
	expires := now.Add(ttl)
	id := uuid.New()
	if err := q.CreateAccountActionToken(ctx, db.AccountActionTokenParams{
		ID: id, TokenHash: hash[:], Purpose: purpose, AccountID: state.ID,
		EmailBinding: emailBinding, AuthGeneration: state.AuthGeneration, ExpiresAt: expires,
	}); err != nil {
		return nil, err
	}
	return &ActionToken{ID: id, Token: raw, Purpose: purpose, AccountID: state.ID, AuthGeneration: state.AuthGeneration, ExpiresAt: expires}, nil
}

// versionLegacyActionURL leaves a unique, already-expired replacement in the
// legacy column because the old schema exposes setters but no nullable clear
// primitive. The presented value is therefore unusable even to old adapters.
func versionLegacyActionURL(ctx context.Context, q *db.Queries, id uuid.UUID, purpose string, now time.Time) error {
	url := uuid.NewString()
	switch purpose {
	case db.ActionTokenPurposeRecovery:
		return q.SetUserResetPasswordUrl(ctx, id, url, now)
	case db.ActionTokenPurposeDeleteAccount:
		return q.SetUserDeletionUrl(ctx, id, url, now)
	default:
		return ErrInvalidAction
	}
}

// CompleteRecovery consumes a restricted recovery token, updates the
// password, advances generation again, clears the restriction, revokes all
// sibling capabilities, and intentionally returns no consumer credentials.
func (s *AccountSecurity) CompleteRecovery(ctx context.Context, rawToken, newPassword string) error {
	if s == nil || s.q == nil || rawToken == "" || newPassword == "" {
		return ErrInvalidAction
	}
	hash := sha256.Sum256([]byte(rawToken))
	now := s.now()
	return s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		consumed, ok, err := consumeBoundRecoveryToken(ctx, tx, hash[:], now)
		if err != nil {
			return err
		}
		if !ok || consumed == nil {
			return ErrInvalidAction
		}
		passwordHash, err := password.Hash(newPassword)
		if err != nil {
			return err
		}
		if err := tx.UpdateUserPassword(ctx, consumed.AccountID, passwordHash); err != nil {
			return err
		}
		if _, err := tx.AdvanceUserAuthGeneration(ctx, consumed.AccountID); err != nil {
			return err
		}
		if err := tx.ClearUserRecoveryRestriction(ctx, consumed.AccountID); err != nil {
			return err
		}
		if err := invalidateLegacyActionValues(ctx, tx, consumed.AccountID, consumed.EmailBinding, true, now); err != nil {
			return err
		}
		if err := tx.InvalidateUserTokens(ctx, consumed.AccountID); err != nil {
			return err
		}
		if err := tx.RevokeAccountActionTokens(ctx, consumed.AccountID, ""); err != nil {
			return err
		}
		reason := "recovery completed"
		outcome := "completed"
		return tx.CreateAuditEvent(ctx, db.AuditEventParams{
			ID: uuid.New(), TargetAccountID: &consumed.AccountID,
			Action: "account_recovery_completed", Reason: &reason, Outcome: &outcome,
		})
	})
}

func (s *AccountSecurity) CompleteRecoveryToken(ctx context.Context, rawToken, newPassword string) error {
	return s.CompleteRecovery(ctx, rawToken, newPassword)
}

func canonicalVerifiedEmail(ctx context.Context, q *db.Queries, state *db.UserSecurityState) (*string, error) {
	if state == nil || q == nil || !state.EmailConfirmed || state.Email == nil {
		return nil, nil
	}
	canonical := db.CanonicalEmail(*state.Email)
	if canonical == "" {
		return nil, nil
	}
	claim, err := q.LockEmailLoginClaim(ctx, canonical)
	if err != nil {
		return nil, err
	}
	if claim == nil || claim.State != db.EmailClaimOwned || claim.OwnerUserID == nil || *claim.OwnerUserID != state.ID {
		return nil, nil
	}
	return &canonical, nil
}

// invalidateLegacyActionValues versions the legacy URL/code columns while the
// account row is locked. The random replacement keeps the existing unique
// indexes usable; expiry is set to now so the replacement cannot be redeemed.
// A verified address is restored after clearing a pending confirmation URL.
func invalidateLegacyActionValues(ctx context.Context, q *db.Queries, id uuid.UUID, email *string, restoreConfirmed bool, now time.Time) error {
	if now.IsZero() {
		now = time.Now()
	}
	if err := q.SetUserRecoveryCode(ctx, id, "", now); err != nil {
		return err
	}
	reset := uuid.NewString()
	if err := q.SetUserResetPasswordUrl(ctx, id, reset, now); err != nil {
		return err
	}
	deletion := uuid.NewString()
	if err := q.SetUserDeletionUrl(ctx, id, deletion, now); err != nil {
		return err
	}
	if err := q.ChangeUserEmail(ctx, id, email, nil); err != nil {
		return err
	}
	if restoreConfirmed {
		confirmed, err := q.ConfirmUserEmailWithClaim(ctx, id)
		if err != nil {
			return err
		}
		if !confirmed {
			return db.ErrEmailClaimUnavailable
		}
	}
	return nil
}

// consumeBoundRecoveryToken validates the current claim while holding the
// account and claim locks before invoking the DB single-use boundary. The DB
// operation rechecks purpose, generation, expiry, and account email while the
// locks remain held, so a claim becoming ambiguous cannot consume a token.
func consumeBoundRecoveryToken(ctx context.Context, q *db.Queries, tokenHash []byte, now time.Time) (*db.AccountActionToken, bool, error) {
	initial, err := q.GetAccountActionTokenByHash(ctx, tokenHash)
	if err != nil || initial == nil || initial.Purpose != db.ActionTokenPurposeRecovery || initial.EmailBinding == nil {
		return nil, false, err
	}
	state, err := q.LockUserSecurity(ctx, initial.AccountID)
	if err != nil || state == nil || state.IsDeleted {
		return nil, false, err
	}
	if !state.PasswordResetRequired || (state.SecurityState != db.SecurityStateNormal &&
		state.SecurityState != db.SecurityStatePasswordDisabled && state.SecurityState != db.SecurityStateCompromised) {
		return nil, false, nil
	}
	trusted, err := canonicalVerifiedEmail(ctx, q, state)
	if err != nil || trusted == nil || db.CanonicalEmail(*initial.EmailBinding) != *trusted {
		return nil, false, err
	}
	return q.ConsumeAccountActionToken(ctx, tokenHash, db.ActionTokenPurposeRecovery, now)
}

func validActionPurpose(purpose string) bool {
	switch purpose {
	case db.ActionTokenPurposeLoginLink, db.ActionTokenPurposeRecovery,
		db.ActionTokenPurposeEmailConfirmation, db.ActionTokenPurposeDeleteAccount:
		return true
	default:
		return false
	}
}

func randomOpaqueToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func stringPtr(s string) *string { return &s }

type noOpRecoveryEnqueuer struct{}

func (noOpRecoveryEnqueuer) EnqueueRecovery(_ context.Context, _ *db.Queries, _ RecoveryEnqueueRequest) (RecoveryEnqueueResult, error) {
	// T04's durable adapter is the only implementation allowed to report a
	// queued attempt. A composition-time no-op must remain honest even when a
	// trusted address exists.
	return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, nil
}

func normalizeRecoveryEnqueueResult(result RecoveryEnqueueResult, enqueueErr error, verifiedEmail *string) RecoveryEnqueueResult {
	if enqueueErr != nil || verifiedEmail == nil || result.Status != RecoveryEnqueueQueued {
		result.Status = RecoveryEnqueueManualRecoveryRequired
	}
	return result
}
