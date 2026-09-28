package db

import (
	"context"
	"errors"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"

	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

// SecurityState values are persisted on users and deliberately do not share
// the API DTO package.  Keeping these values in the DB layer lets security
// services make generation checks without importing handlers.
const (
	SecurityStateNormal                 = "normal"
	SecurityStatePasswordDisabled       = "password_disabled"
	SecurityStateCompromised            = "compromised"
	SecurityStateSecuredManualRecovery  = "secured_manual_recovery_required"
	SecurityStateDeleted                = "deleted"
	EmailClaimAvailable                 = "available"
	EmailClaimOwned                     = "owned"
	EmailClaimBlocked                   = "blocked"
	ActionTokenPurposeLoginLink         = "login_link"
	ActionTokenPurposeRecovery          = "recovery"
	ActionTokenPurposeEmailConfirmation = "email_confirmation"
	ActionTokenPurposeDeleteAccount     = "delete_account"
	// InitialAudienceSnapshotOrdinal is the only value that requests the
	// first snapshot page.  Ordinal zero is a real exclusive cursor.
	InitialAudienceSnapshotOrdinal int64 = -1
	AudienceResourceAccounts             = "accounts"
	AudienceResourceReports              = "reports"
	DurableJobPending                    = "pending"
	DurableJobRunning                    = "running"
	DurableJobCompleted                  = "completed"
	DurableJobFailed                     = "failed"
	DurableJobCancelled                  = "cancelled"
	ReportStatusOpen                     = "open"
	ReportStatusResolved                 = "resolved"
	ReportStatusDismissed                = "dismissed"
)

var (
	// ErrEmailClaimUnavailable is returned when a confirmation would make an
	// ambiguous address eligible.  Callers should map it to a generic result.
	ErrEmailClaimUnavailable  = errors.New("email address is not claimable")
	ErrInvalidEmail           = errors.New("invalid email address")
	ErrInvalidQuota           = errors.New("invalid quota request")
	ErrInvalidActionToken     = errors.New("invalid action token")
	ErrInvalidDeliveryAttempt = errors.New("invalid delivery attempt")
	ErrInvalidJob             = errors.New("invalid job")
	ErrInvalidLease           = errors.New("invalid lease")
	ErrInvalidMembership      = errors.New("invalid admin membership")
	ErrInvalidSession         = errors.New("invalid admin session")
	ErrInvalidChallenge       = errors.New("invalid admin login challenge")
	ErrInvalidSnapshot        = errors.New("invalid audience snapshot")
	ErrInvalidRetentionWindow = errors.New("invalid retention window")
)

const maxTransactionRetries = 3

// InTxRetry retries only PostgreSQL serialization/deadlock failures.  A
// bounded retry is important for the lock order shared by account, claim, and
// token mutations, while application/validation failures remain immediate.
func (q *Queries) InTxRetry(ctx context.Context, fn func(*Queries) error) error {
	if q.inTx {
		return fn(q)
	}
	var err error
	for attempt := 0; attempt < maxTransactionRetries; attempt++ {
		err = q.InTx(ctx, fn)
		if !isRetryableTxError(err) || attempt == maxTransactionRetries-1 {
			return err
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(time.Duration(attempt+1) * 5 * time.Millisecond):
		}
	}
	return err
}

// WithRetry is the explicit alias used by callers that prefer an operation
// name over the transaction implementation detail.
func (q *Queries) WithRetry(ctx context.Context, fn func(*Queries) error) error {
	return q.InTxRetry(ctx, fn)
}

func isRetryableTxError(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && (pgErr.Code == "40001" || pgErr.Code == "40P01")
}

// CanonicalEmail trims surrounding whitespace and compares case-insensitively.
// It intentionally does not apply provider-specific dot or plus rewriting.
// An empty result means the address is not eligible for a claim.
func CanonicalEmail(raw string) string {
	canonical := strings.ToLower(strings.TrimSpace(raw))
	if canonical == "" || len(canonical) > 320 || strings.IndexByte(canonical, '@') <= 0 {
		return ""
	}
	return canonical
}

// NormalizeEmail is an explicit alias for callers that prefer a verb which
// describes the operation.  It has the same no-provider-rewriting semantics.
func NormalizeEmail(raw string) string { return CanonicalEmail(raw) }

type EmailLoginClaim struct {
	CanonicalEmail string
	OwnerUserID    *uuid.UUID
	State          string
	IsAmbiguous    bool
	BlockedReason  *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type UserSecurityState struct {
	ID                    uuid.UUID
	Email                 *string
	EmailConfirmed        bool
	IsDeleted             bool
	AuthGeneration        int64
	SecurityState         string
	PasswordDisabled      bool
	PasswordResetRequired bool
	CompromisedAt         *time.Time
}

func emailClaimFromRow(r dbgen.EmailLoginClaim) EmailLoginClaim {
	var owner *uuid.UUID
	if r.OwnerUserID.Valid {
		u := goUUID(r.OwnerUserID)
		owner = &u
	}
	return EmailLoginClaim{
		CanonicalEmail: r.CanonicalEmail,
		OwnerUserID:    owner,
		State:          r.State,
		IsAmbiguous:    r.IsAmbiguous,
		BlockedReason:  goText(r.BlockedReason),
		CreatedAt:      r.CreatedAt.Time,
		UpdatedAt:      r.UpdatedAt.Time,
	}
}

func securityStateFromRow(r dbgen.GetUserSecurityStateRow) UserSecurityState {
	return UserSecurityState{
		ID:                    goUUID(r.ID),
		Email:                 goText(r.Email),
		EmailConfirmed:        r.EmailConfirmed,
		IsDeleted:             r.IsDeleted,
		AuthGeneration:        r.AuthGeneration,
		SecurityState:         r.SecurityState,
		PasswordDisabled:      r.PasswordDisabled,
		PasswordResetRequired: r.PasswordResetRequired,
		CompromisedAt:         goTZ(r.CompromisedAt),
	}
}

func securityStateFromLockRow(r dbgen.LockUserSecurityStateRow) UserSecurityState {
	return UserSecurityState{
		ID:                    goUUID(r.ID),
		Email:                 goText(r.Email),
		EmailConfirmed:        r.EmailConfirmed,
		IsDeleted:             r.IsDeleted,
		AuthGeneration:        r.AuthGeneration,
		SecurityState:         r.SecurityState,
		PasswordDisabled:      r.PasswordDisabled,
		PasswordResetRequired: r.PasswordResetRequired,
		CompromisedAt:         goTZ(r.CompromisedAt),
	}
}

// ---- canonical email claims ----------------------------------------------

func (q *Queries) BackfillEmailLoginClaims(ctx context.Context) error {
	return q.g.BackfillEmailLoginClaims(ctx)
}

func (q *Queries) GetEmailLoginClaim(ctx context.Context, rawEmail string) (*EmailLoginClaim, error) {
	canonical := CanonicalEmail(rawEmail)
	if canonical == "" {
		return nil, nil
	}
	r, err := q.g.GetEmailLoginClaim(ctx, canonical)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	claim := emailClaimFromRow(r)
	return &claim, nil
}

func (q *Queries) LockEmailLoginClaim(ctx context.Context, rawEmail string) (*EmailLoginClaim, error) {
	canonical := CanonicalEmail(rawEmail)
	if canonical == "" {
		return nil, nil
	}
	r, err := q.g.LockEmailLoginClaim(ctx, canonical)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	claim := emailClaimFromRow(r)
	return &claim, nil
}

// LockEmailLoginClaims locks a sorted set of existing claims.  This is the
// shared primitive for an email change affecting multiple addresses.
func (q *Queries) LockEmailLoginClaims(ctx context.Context, rawEmails []string) ([]EmailLoginClaim, error) {
	canonicals := make([]string, 0, len(rawEmails))
	seen := make(map[string]struct{}, len(rawEmails))
	for _, raw := range rawEmails {
		canonical := CanonicalEmail(raw)
		if canonical == "" {
			continue
		}
		if _, ok := seen[canonical]; ok {
			continue
		}
		seen[canonical] = struct{}{}
		canonicals = append(canonicals, canonical)
	}
	sort.Strings(canonicals)
	claims := make([]EmailLoginClaim, 0, len(canonicals))
	for _, canonical := range canonicals {
		claim, err := q.LockEmailLoginClaim(ctx, canonical)
		if err != nil {
			return nil, err
		}
		if claim != nil {
			claims = append(claims, *claim)
		}
	}
	return claims, nil
}

func (q *Queries) claimEmailLoginClaim(ctx context.Context, canonical string, owner uuid.UUID) (bool, error) {
	_, err := q.g.ClaimEmailLoginClaim(ctx, dbgen.ClaimEmailLoginClaimParams{
		CanonicalEmail: canonical,
		OwnerUserID:    pgUUID(owner),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) reconcileEmailLoginClaim(ctx context.Context, canonical string) error {
	if canonical == "" {
		return nil
	}
	// The caller owns the user lock when this is part of a user mutation.  The
	// claim itself is then locked before the candidate list is evaluated.
	if _, err := q.LockEmailLoginClaim(ctx, canonical); err != nil {
		return err
	}
	ids, err := q.g.ListVerifiedUsersForEmailClaim(ctx, pgTextS(canonical))
	if err != nil {
		return err
	}
	owner := pgtype.UUID{}
	state := EmailClaimAvailable
	ambiguous := false
	var reason *string
	switch len(ids) {
	case 0:
		// Keep an existing row available so a future confirmation can claim it.
	case 1:
		owner = ids[0]
		state = EmailClaimOwned
	case 2:
		state = EmailClaimBlocked
		ambiguous = true
		v := "duplicate_verified_accounts"
		reason = &v
	default:
		state = EmailClaimBlocked
		ambiguous = true
		v := "duplicate_verified_accounts"
		reason = &v
	}
	claim, err := q.GetEmailLoginClaim(ctx, canonical)
	if err != nil {
		return err
	}
	if claim == nil {
		if len(ids) == 0 {
			return nil
		}
		// Claim the sole owner first to create the row; duplicate groups are
		// immediately changed to blocked in the same transaction.
		if _, err := q.g.ClaimEmailLoginClaim(ctx, dbgen.ClaimEmailLoginClaimParams{
			CanonicalEmail: canonical,
			OwnerUserID:    ids[0],
		}); err != nil {
			return err
		}
	}
	return q.g.SetEmailLoginClaim(ctx, dbgen.SetEmailLoginClaimParams{
		CanonicalEmail: canonical,
		OwnerUserID:    owner,
		State:          state,
		IsAmbiguous:    ambiguous,
		BlockedReason:  pgText(reason),
	})
}

// ConfirmUserEmailWithClaim acquires the account lock, then the canonical
// claim lock, and only then makes the address eligible.  Exactly one of two
// simultaneous confirmations can own a previously ambiguous address.
func (q *Queries) ConfirmUserEmailWithClaim(ctx context.Context, id uuid.UUID) (bool, error) {
	if !q.inTx {
		var confirmed bool
		err := q.InTxRetry(ctx, func(tx *Queries) error {
			var err error
			confirmed, err = tx.ConfirmUserEmailWithClaim(ctx, id)
			return err
		})
		return confirmed, err
	}
	user, err := q.g.LockUserSecurityState(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if user.IsDeleted || user.SecurityState != SecurityStateNormal || user.PasswordResetRequired || user.Email == (pgtype.Text{}) || !user.Email.Valid {
		return false, nil
	}
	canonical := CanonicalEmail(user.Email.String)
	if canonical == "" {
		return false, nil
	}
	claimed, err := q.claimEmailLoginClaim(ctx, canonical, id)
	if err != nil || !claimed {
		return false, err
	}
	if err := q.g.ConfirmUserEmail(ctx, pgUUID(id)); err != nil {
		return false, err
	}
	return true, nil
}

// ChangeUserEmail atomically stores a pending address and then reconciles the
// old verified claim.  The new address remains ineligible until confirmation.
func (q *Queries) ChangeUserEmail(ctx context.Context, id uuid.UUID, email, confirmationURL *string) error {
	if !q.inTx {
		return q.InTxRetry(ctx, func(tx *Queries) error {
			return tx.ChangeUserEmail(ctx, id, email, confirmationURL)
		})
	}
	user, err := q.g.LockUserSecurityState(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return pgx.ErrNoRows
	}
	if err != nil {
		return err
	}
	if user.IsDeleted || user.SecurityState != SecurityStateNormal || user.PasswordResetRequired {
		return ErrEmailClaimUnavailable
	}
	old := ""
	if user.Email.Valid {
		old = CanonicalEmail(user.Email.String)
	}
	newCanonical := ""
	if email != nil {
		newCanonical = CanonicalEmail(*email)
		if newCanonical == "" {
			return ErrInvalidEmail
		}
	}
	// Lock both keys in lexical order before changing either one.  This is
	// the only order used by multi-address mutations.
	if _, err := q.LockEmailLoginClaims(ctx, []string{old, newCanonical}); err != nil {
		return err
	}
	if err := q.g.UpdateUserEmail(ctx, dbgen.UpdateUserEmailParams{
		ID:                   pgUUID(id),
		Email:                pgText(email),
		EmailConfirmationUrl: pgText(confirmationURL),
	}); err != nil {
		return err
	}
	// Reconcile after the user is marked unconfirmed.  Reconciling before the
	// update would incorrectly leave the old address owned by this account.
	if user.EmailConfirmed && old != "" {
		if err := q.reconcileEmailLoginClaim(ctx, old); err != nil {
			return err
		}
	}
	// Email changes invalidate all pending capabilities bound to the old
	// address.  The caller may create the new confirmation token afterwards.
	return q.g.RevokeAccountActionTokens(ctx, dbgen.RevokeAccountActionTokensParams{AccountID: pgUUID(id), Column2: ""})
}

// ---- user security state --------------------------------------------------

func (q *Queries) GetUserSecurityState(ctx context.Context, id uuid.UUID) (*UserSecurityState, error) {
	r, err := q.g.GetUserSecurityState(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := securityStateFromRow(r)
	return &v, nil
}

func (q *Queries) LockUserSecurity(ctx context.Context, id uuid.UUID) (*UserSecurityState, error) {
	r, err := q.g.LockUserSecurityState(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := securityStateFromLockRow(r)
	return &v, nil
}

func (q *Queries) LockUsersForSecurity(ctx context.Context, ids []uuid.UUID) ([]UserSecurityState, error) {
	sorted := append([]uuid.UUID(nil), ids...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].String() < sorted[j].String() })
	out := make([]UserSecurityState, 0, len(sorted))
	for _, id := range sorted {
		v, err := q.LockUserSecurity(ctx, id)
		if err != nil {
			return nil, err
		}
		if v != nil {
			out = append(out, *v)
		}
	}
	return out, nil
}

func (q *Queries) AdvanceUserAuthGeneration(ctx context.Context, id uuid.UUID) (int64, error) {
	return q.g.AdvanceUserAuthGeneration(ctx, pgUUID(id))
}

func (q *Queries) SetUserSecurityState(ctx context.Context, id uuid.UUID, state string, passwordDisabled, resetRequired bool, compromisedAt *time.Time) error {
	return q.g.SetUserSecurityState(ctx, dbgen.SetUserSecurityStateParams{
		ID:                    pgUUID(id),
		SecurityState:         state,
		PasswordDisabled:      passwordDisabled,
		PasswordResetRequired: resetRequired,
		CompromisedAt:         pgTZ(compromisedAt),
	})
}

func (q *Queries) ClearUserRecoveryRestriction(ctx context.Context, id uuid.UUID) error {
	return q.g.ClearUserRecoveryRestriction(ctx, pgUUID(id))
}

// SoftDeleteUser also reconciles its verified email claim.  It preserves the
// legacy facade signature while making account deletion safe for email login.
func (q *Queries) SoftDeleteUser(ctx context.Context, id uuid.UUID) error {
	if !q.inTx {
		return q.InTxRetry(ctx, func(tx *Queries) error { return tx.SoftDeleteUser(ctx, id) })
	}
	if id == uuid.Nil {
		return nil
	}
	user, err := q.g.LockUserSecurityState(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := q.LockReportTarget(ctx, id); err != nil {
		return err
	}
	if user.IsDeleted {
		return nil
	}
	if _, err := q.g.ContainUser(ctx, pgUUID(id)); err != nil {
		return err
	}
	if user.EmailConfirmed && user.Email.Valid {
		if err := q.reconcileEmailLoginClaim(ctx, CanonicalEmail(user.Email.String)); err != nil {
			return err
		}
	}
	if err := q.g.InvalidateUserTokens(ctx, pgUUID(id)); err != nil {
		return err
	}
	if err := q.g.RevokeAccountActionTokens(ctx, dbgen.RevokeAccountActionTokensParams{AccountID: pgUUID(id), Column2: ""}); err != nil {
		return err
	}
	if err := q.g.RevokeAdminSessionsForUser(ctx, pgUUID(id)); err != nil {
		return err
	}
	if err := q.g.RevokeAdminLoginChallengesForUser(ctx, pgUUID(id)); err != nil {
		return err
	}
	return q.g.RevokeAdminMembership(ctx, pgUUID(id))
}

// HardDeleteUser marks the account deleted, reconciles its claim, removes
// credentials, then executes the legacy physical delete.  Dependent additive
// rows use cascading or SET NULL FKs as appropriate.
func (q *Queries) HardDeleteUser(ctx context.Context, id uuid.UUID) error {
	if !q.inTx {
		return q.InTxRetry(ctx, func(tx *Queries) error { return tx.HardDeleteUser(ctx, id) })
	}
	if id == uuid.Nil {
		return nil
	}
	user, err := q.g.LockUserSecurityState(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := q.LockReportTarget(ctx, id); err != nil {
		return err
	}
	if !user.IsDeleted {
		if _, err := q.g.ContainUser(ctx, pgUUID(id)); err != nil {
			return err
		}
		if user.EmailConfirmed && user.Email.Valid {
			if err := q.reconcileEmailLoginClaim(ctx, CanonicalEmail(user.Email.String)); err != nil {
				return err
			}
		}
		if err := q.g.InvalidateUserTokens(ctx, pgUUID(id)); err != nil {
			return err
		}
		if err := q.g.RevokeAccountActionTokens(ctx, dbgen.RevokeAccountActionTokensParams{AccountID: pgUUID(id), Column2: ""}); err != nil {
			return err
		}
		if err := q.g.RevokeAdminSessionsForUser(ctx, pgUUID(id)); err != nil {
			return err
		}
		if err := q.g.RevokeAdminLoginChallengesForUser(ctx, pgUUID(id)); err != nil {
			return err
		}
		if err := q.g.RevokeAdminMembership(ctx, pgUUID(id)); err != nil {
			return err
		}
	}
	if err := q.g.PurgeDeletedAccountData(ctx, pgUUID(id)); err != nil {
		return err
	}
	return q.g.HardDeleteUser(ctx, pgUUID(id))
}
