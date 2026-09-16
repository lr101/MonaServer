package db

// This file is the application-facing repository for the additive admin and
// email-link storage.  SQL remains in queries/admin_foundation.sql and the
// generated package; this layer only owns transaction boundaries, validation,
// and conversion from pgtype values to the types used by services.

import (
	"bytes"
	"context"
	"errors"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

// ---- common conversion helpers -------------------------------------------

func uuidPtrFromPG(v pgtype.UUID) *uuid.UUID {
	if !v.Valid {
		return nil
	}
	u := goUUID(v)
	return &u
}

func timeFromPG(v pgtype.Timestamptz) time.Time {
	if !v.Valid {
		return time.Time{}
	}
	return v.Time
}

func timePtrFromPG(v pgtype.Timestamptz) *time.Time {
	if !v.Valid {
		return nil
	}
	t := v.Time
	return &t
}

func textFromPG(v pgtype.Text) string {
	if !v.Valid {
		return ""
	}
	return v.String
}

func textPtrFromPG(v pgtype.Text) *string {
	if !v.Valid {
		return nil
	}
	s := v.String
	return &s
}

func cloneBytes(v []byte) []byte {
	if v == nil {
		return nil
	}
	return append([]byte(nil), v...)
}

func cloneJSON(v []byte) []byte {
	if len(v) == 0 {
		return []byte(`{}`)
	}
	return cloneBytes(v)
}

// ---- action tokens --------------------------------------------------------

type AccountActionToken struct {
	ID                uuid.UUID
	TokenHash         []byte
	Purpose           string
	AccountID         uuid.UUID
	EmailBinding      *string
	AuthGeneration    int64
	ExpiresAt         time.Time
	ConsumedAt        *time.Time
	RevokedAt         *time.Time
	DeliveryAttemptID *uuid.UUID
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

type AccountActionTokenParams struct {
	ID                uuid.UUID
	TokenHash         []byte
	Purpose           string
	AccountID         uuid.UUID
	EmailBinding      *string
	AuthGeneration    int64
	ExpiresAt         time.Time
	DeliveryAttemptID *uuid.UUID
}

func accountActionTokenFromRow(r dbgen.AccountActionToken) AccountActionToken {
	return AccountActionToken{
		ID:                goUUID(r.ID),
		TokenHash:         cloneBytes(r.TokenHash),
		Purpose:           r.Purpose,
		AccountID:         goUUID(r.AccountID),
		EmailBinding:      textPtrFromPG(r.EmailBinding),
		AuthGeneration:    r.AuthGeneration,
		ExpiresAt:         timeFromPG(r.ExpiresAt),
		ConsumedAt:        timePtrFromPG(r.ConsumedAt),
		RevokedAt:         timePtrFromPG(r.RevokedAt),
		DeliveryAttemptID: uuidPtrFromPG(r.DeliveryAttemptID),
		CreatedAt:         timeFromPG(r.CreatedAt),
		UpdatedAt:         timeFromPG(r.UpdatedAt),
	}
}

func (q *Queries) CreateAccountActionToken(ctx context.Context, p AccountActionTokenParams) error {
	if p.ID == uuid.Nil || p.AccountID == uuid.Nil || len(p.TokenHash) == 0 || p.Purpose == "" || p.ExpiresAt.IsZero() || p.AuthGeneration < 0 {
		return ErrInvalidActionToken
	}
	if p.EmailBinding != nil {
		canonical := CanonicalEmail(*p.EmailBinding)
		if canonical == "" {
			return ErrInvalidActionToken
		}
		p.EmailBinding = &canonical
	}
	return q.g.CreateAccountActionToken(ctx, dbgen.CreateAccountActionTokenParams{
		ID:                pgUUID(p.ID),
		TokenHash:         cloneBytes(p.TokenHash),
		Purpose:           p.Purpose,
		AccountID:         pgUUID(p.AccountID),
		EmailBinding:      pgText(p.EmailBinding),
		AuthGeneration:    p.AuthGeneration,
		ExpiresAt:         pgTZ(&p.ExpiresAt),
		DeliveryAttemptID: pgUUIDPtr(p.DeliveryAttemptID),
	})
}

func (q *Queries) GetAccountActionTokenByHash(ctx context.Context, tokenHash []byte) (*AccountActionToken, error) {
	if len(tokenHash) == 0 {
		return nil, nil
	}
	r, err := q.g.GetAccountActionTokenByHash(ctx, cloneBytes(tokenHash))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := accountActionTokenFromRow(r)
	return &v, nil
}

// LockAccountActionTokenByHash is a low-level primitive.  Callers must lock
// the account first (using LockUserSecurity) so every account/token mutation
// follows the shared lock order documented in admin_foundation.go.
func (q *Queries) LockAccountActionTokenByHash(ctx context.Context, tokenHash []byte) (*AccountActionToken, error) {
	if len(tokenHash) == 0 {
		return nil, nil
	}
	r, err := q.g.LockAccountActionTokenByHash(ctx, cloneBytes(tokenHash))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := accountActionTokenFromRow(r)
	return &v, nil
}

// ConsumeAccountActionToken performs the token-only single-use update.  It
// intentionally validates account generation, current email binding, and
// security state while holding the account lock.  Invalid or already-used
// credentials return (nil, false, nil), allowing public handlers to retain a
// generic response.
func (q *Queries) ConsumeAccountActionToken(ctx context.Context, tokenHash []byte, purpose string, now time.Time) (*AccountActionToken, bool, error) {
	if len(tokenHash) == 0 || purpose == "" || now.IsZero() {
		return nil, false, nil
	}
	if !q.inTx {
		var token *AccountActionToken
		var consumed bool
		err := q.InTxRetry(ctx, func(tx *Queries) error {
			var err error
			token, consumed, err = tx.consumeAccountActionToken(ctx, tokenHash, purpose, now)
			return err
		})
		return token, consumed, err
	}
	return q.consumeAccountActionToken(ctx, tokenHash, purpose, now)
}

func (q *Queries) consumeAccountActionToken(ctx context.Context, tokenHash []byte, purpose string, now time.Time) (*AccountActionToken, bool, error) {
	// Read the account ID without locking first.  The account is then locked
	// before the token row, which prevents a token redemption racing a security
	// generation advance from observing a stale account state.
	initial, err := q.g.GetAccountActionTokenByHash(ctx, cloneBytes(tokenHash))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	// Purpose is checked before the account restriction so a recovery token
	// can be considered for the explicitly recoverable restricted states.
	// The locked token is checked again below before consumption.
	if initial.Purpose != purpose {
		return nil, false, nil
	}
	account, err := q.LockUserSecurity(ctx, goUUID(initial.AccountID))
	if err != nil {
		return nil, false, err
	}
	if account == nil || account.IsDeleted {
		return nil, false, nil
	}
	if account.SecurityState != SecurityStateNormal || account.PasswordResetRequired {
		recoverable := purpose == ActionTokenPurposeRecovery && account.PasswordResetRequired &&
			(account.SecurityState == SecurityStateNormal ||
				account.SecurityState == SecurityStatePasswordDisabled ||
				account.SecurityState == SecurityStateCompromised)
		if !recoverable {
			return nil, false, nil
		}
	}
	locked, err := q.LockAccountActionTokenByHash(ctx, tokenHash)
	if err != nil {
		return nil, false, err
	}
	if locked == nil || locked.Purpose != purpose || locked.ConsumedAt != nil || locked.RevokedAt != nil || !locked.ExpiresAt.After(now) {
		return nil, false, nil
	}
	if locked.AuthGeneration != account.AuthGeneration {
		return nil, false, nil
	}
	if locked.EmailBinding != nil {
		if !account.EmailConfirmed || account.Email == nil || CanonicalEmail(*account.Email) != CanonicalEmail(*locked.EmailBinding) {
			return nil, false, nil
		}
	}
	consumed, err := q.g.ConsumeAccountActionToken(ctx, dbgen.ConsumeAccountActionTokenParams{
		TokenHash: cloneBytes(tokenHash), Purpose: purpose, ExpiresAt: pgTZ(&now),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	if purpose == ActionTokenPurposeLoginLink {
		if err := q.g.RevokeAccountActionTokens(ctx, dbgen.RevokeAccountActionTokensParams{AccountID: pgUUID(locked.AccountID), Column2: purpose}); err != nil {
			return nil, false, err
		}
	}
	v := accountActionTokenFromRow(consumed)
	return &v, true, nil
}

func (q *Queries) RevokeAccountActionTokens(ctx context.Context, accountID uuid.UUID, purpose string) error {
	if accountID == uuid.Nil {
		return nil
	}
	return q.g.RevokeAccountActionTokens(ctx, dbgen.RevokeAccountActionTokensParams{
		AccountID: pgUUID(accountID), Column2: purpose,
	})
}

func (q *Queries) RevokeAccountActionTokensExcept(ctx context.Context, accountID, exceptID uuid.UUID) error {
	if accountID == uuid.Nil {
		return nil
	}
	var id pgtype.UUID
	if exceptID != uuid.Nil {
		id = pgUUID(exceptID)
	}
	return q.g.RevokeAccountActionTokensExcept(ctx, dbgen.RevokeAccountActionTokensExceptParams{
		AccountID: pgUUID(accountID), Column2: id,
	})
}

func (q *Queries) DeleteExpiredAccountActionTokens(ctx context.Context, expiredBefore, retainedBefore time.Time) error {
	if expiredBefore.IsZero() || retainedBefore.IsZero() {
		return ErrInvalidRetentionWindow
	}
	return q.g.DeleteExpiredAccountActionTokens(ctx, dbgen.DeleteExpiredAccountActionTokensParams{
		ExpiresAt: pgTZ(&expiredBefore), ConsumedAt: pgTZ(&retainedBefore),
	})
}

// ---- durable jobs and outbox ---------------------------------------------

type DurableJob struct {
	ID             uuid.UUID
	Kind           string
	IdempotencyKey string
	Payload        []byte
	Priority       int32
	Status         string
	AvailableAt    time.Time
	AttemptCount   int32
	MaxAttempts    int32
	LeaseOwner     *string
	LeaseToken     uuid.UUID
	LeaseUntil     *time.Time
	LastError      *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
	StartedAt      *time.Time
	CompletedAt    *time.Time
}

type DurableJobParams struct {
	ID             uuid.UUID
	Kind           string
	IdempotencyKey string
	Payload        []byte
	Priority       int32
	AvailableAt    time.Time
	MaxAttempts    int32
}

func durableJobFromRow(r dbgen.DurableJob) DurableJob {
	return DurableJob{
		ID:             goUUID(r.ID),
		Kind:           r.Kind,
		IdempotencyKey: r.IdempotencyKey,
		Payload:        cloneBytes(r.Payload),
		Priority:       r.Priority,
		Status:         r.Status,
		AvailableAt:    timeFromPG(r.AvailableAt),
		AttemptCount:   r.AttemptCount,
		MaxAttempts:    r.MaxAttempts,
		LeaseOwner:     textPtrFromPG(r.LeaseOwner),
		LeaseToken:     goUUID(r.LeaseToken),
		LeaseUntil:     timePtrFromPG(r.LeaseUntil),
		LastError:      textPtrFromPG(r.LastError),
		CreatedAt:      timeFromPG(r.CreatedAt),
		UpdatedAt:      timeFromPG(r.UpdatedAt),
		StartedAt:      timePtrFromPG(r.StartedAt),
		CompletedAt:    timePtrFromPG(r.CompletedAt),
	}
}

func (q *Queries) CreateDurableJob(ctx context.Context, p DurableJobParams) error {
	if p.ID == uuid.Nil || p.Kind == "" || p.IdempotencyKey == "" || p.AvailableAt.IsZero() || p.MaxAttempts <= 0 {
		return ErrInvalidJob
	}
	return q.g.CreateDurableJob(ctx, dbgen.CreateDurableJobParams{
		ID: pgUUID(p.ID), Kind: p.Kind, IdempotencyKey: p.IdempotencyKey,
		Payload: cloneJSON(p.Payload), Priority: p.Priority,
		AvailableAt: pgTZ(&p.AvailableAt), MaxAttempts: p.MaxAttempts,
	})
}

func (q *Queries) GetDurableJob(ctx context.Context, id uuid.UUID) (*DurableJob, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetDurableJob(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := durableJobFromRow(r)
	return &v, nil
}

func (q *Queries) ClaimDurableJobs(ctx context.Context, worker string, limit int, lease time.Duration) ([]DurableJob, error) {
	if worker == "" || limit <= 0 || lease <= 0 {
		return nil, ErrInvalidLease
	}
	// The SQL statement assigns one fresh token to each row.  Passing a token
	// from the caller would make all jobs in a batch share an acknowledgement
	// capability.
	rs, err := q.g.ClaimDurableJobs(ctx, dbgen.ClaimDurableJobsParams{
		Limit: int32(limit), LeaseOwner: pgTextS(worker), Column3: lease.Seconds(),
	})
	if err != nil {
		return nil, err
	}
	out := make([]DurableJob, 0, len(rs))
	for _, r := range rs {
		out = append(out, durableJobFromClaimRow(r))
	}
	return out, nil
}

// ClaimDurableJobsByKinds applies the queue-family allowlist inside the
// database claim statement.  The row lock and lease transition therefore
// cover only kinds this worker is responsible for; callers never need to
// claim another family's row and release it afterward.
func (q *Queries) ClaimDurableJobsByKinds(ctx context.Context, worker string, kinds []string, limit int, lease time.Duration) ([]DurableJob, error) {
	if worker == "" || limit <= 0 || lease <= 0 {
		return nil, ErrInvalidLease
	}
	normalizedKinds, err := normalizeDurableJobKinds(kinds)
	if err != nil {
		return nil, err
	}
	rs, err := q.g.ClaimDurableJobsByKinds(ctx, dbgen.ClaimDurableJobsByKindsParams{
		Limit: int32(limit), Column2: normalizedKinds, LeaseOwner: pgTextS(worker), Column4: lease.Seconds(),
	})
	if err != nil {
		return nil, err
	}
	out := make([]DurableJob, 0, len(rs))
	for _, r := range rs {
		out = append(out, durableJobFromKindClaimRow(r))
	}
	return out, nil
}

func normalizeDurableJobKinds(kinds []string) ([]string, error) {
	// An empty, non-nil slice is significant to PostgreSQL: it means all
	// kinds in the SQL predicate, while a NULL array would match none.
	normalized := make([]string, 0, len(kinds))
	seen := make(map[string]struct{}, len(kinds))
	for _, kind := range kinds {
		kind = strings.TrimSpace(kind)
		if kind == "" {
			return nil, ErrInvalidJob
		}
		if _, ok := seen[kind]; ok {
			continue
		}
		seen[kind] = struct{}{}
		normalized = append(normalized, kind)
	}
	return normalized, nil
}

func durableJobFromKindClaimRow(r dbgen.ClaimDurableJobsByKindsRow) DurableJob {
	return DurableJob{
		ID:             goUUID(r.ID),
		Kind:           r.Kind,
		IdempotencyKey: r.IdempotencyKey,
		Payload:        cloneBytes(r.Payload),
		Priority:       r.Priority,
		Status:         r.Status,
		AvailableAt:    timeFromPG(r.AvailableAt),
		AttemptCount:   r.AttemptCount,
		MaxAttempts:    r.MaxAttempts,
		LeaseOwner:     textPtrFromPG(r.LeaseOwner),
		LeaseToken:     goUUID(r.LeaseToken),
		LeaseUntil:     timePtrFromPG(r.LeaseUntil),
		LastError:      textPtrFromPG(r.LastError),
		CreatedAt:      timeFromPG(r.CreatedAt),
		UpdatedAt:      timeFromPG(r.UpdatedAt),
		StartedAt:      timePtrFromPG(r.StartedAt),
		CompletedAt:    timePtrFromPG(r.CompletedAt),
	}
}

func durableJobFromClaimRow(r dbgen.ClaimDurableJobsRow) DurableJob {
	return DurableJob{
		ID:             goUUID(r.ID),
		Kind:           r.Kind,
		IdempotencyKey: r.IdempotencyKey,
		Payload:        cloneBytes(r.Payload),
		Priority:       r.Priority,
		Status:         r.Status,
		AvailableAt:    timeFromPG(r.AvailableAt),
		AttemptCount:   r.AttemptCount,
		MaxAttempts:    r.MaxAttempts,
		LeaseOwner:     textPtrFromPG(r.LeaseOwner),
		LeaseToken:     goUUID(r.LeaseToken),
		LeaseUntil:     timePtrFromPG(r.LeaseUntil),
		LastError:      textPtrFromPG(r.LastError),
		CreatedAt:      timeFromPG(r.CreatedAt),
		UpdatedAt:      timeFromPG(r.UpdatedAt),
		StartedAt:      timePtrFromPG(r.StartedAt),
		CompletedAt:    timePtrFromPG(r.CompletedAt),
	}
}

func (q *Queries) ExtendDurableJobLease(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, lease time.Duration) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || lease <= 0 {
		return false, ErrInvalidLease
	}
	_, err := q.g.ExtendDurableJobLease(ctx, dbgen.ExtendDurableJobLeaseParams{
		ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token), Column4: lease.Seconds(),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) FinishDurableJob(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, status string) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || status == "" {
		return false, ErrInvalidLease
	}
	_, err := q.g.FinishDurableJob(ctx, dbgen.FinishDurableJobParams{
		ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token), Status: status,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) ReleaseDurableJobLease(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, availableAt time.Time) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || availableAt.IsZero() {
		return false, ErrInvalidLease
	}
	_, err := q.g.ReleaseDurableJobLease(ctx, dbgen.ReleaseDurableJobLeaseParams{
		ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token), AvailableAt: pgTZ(&availableAt),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

type OutboxEvent struct {
	ID             uuid.UUID
	Topic          string
	AggregateID    *uuid.UUID
	IdempotencyKey string
	Payload        []byte
	Status         string
	AvailableAt    time.Time
	AttemptCount   int32
	LeaseOwner     *string
	LeaseToken     uuid.UUID
	LeaseUntil     *time.Time
	AcceptedAt     *time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type OutboxEventParams struct {
	ID             uuid.UUID
	Topic          string
	AggregateID    *uuid.UUID
	IdempotencyKey string
	Payload        []byte
	AvailableAt    time.Time
}

func outboxEventFromRow(r dbgen.OutboxEvent) OutboxEvent {
	return OutboxEvent{
		ID: goUUID(r.ID), Topic: r.Topic, AggregateID: uuidPtrFromPG(r.AggregateID),
		IdempotencyKey: r.IdempotencyKey, Payload: cloneBytes(r.Payload), Status: r.Status,
		AvailableAt: timeFromPG(r.AvailableAt), AttemptCount: r.AttemptCount,
		LeaseOwner: textPtrFromPG(r.LeaseOwner), LeaseToken: goUUID(r.LeaseToken),
		LeaseUntil: timePtrFromPG(r.LeaseUntil), AcceptedAt: timePtrFromPG(r.AcceptedAt),
		CreatedAt: timeFromPG(r.CreatedAt), UpdatedAt: timeFromPG(r.UpdatedAt),
	}
}

func (q *Queries) CreateOutboxEvent(ctx context.Context, p OutboxEventParams) error {
	if p.ID == uuid.Nil || p.Topic == "" || p.IdempotencyKey == "" || p.AvailableAt.IsZero() {
		return ErrInvalidJob
	}
	return q.g.CreateOutboxEvent(ctx, dbgen.CreateOutboxEventParams{
		ID: pgUUID(p.ID), Topic: p.Topic, AggregateID: pgUUIDPtr(p.AggregateID),
		IdempotencyKey: p.IdempotencyKey, Payload: cloneJSON(p.Payload), AvailableAt: pgTZ(&p.AvailableAt),
	})
}

func (q *Queries) ClaimOutboxEvents(ctx context.Context, worker string, limit int, lease time.Duration) ([]OutboxEvent, error) {
	if worker == "" || limit <= 0 || lease <= 0 {
		return nil, ErrInvalidLease
	}
	rs, err := q.g.ClaimOutboxEvents(ctx, dbgen.ClaimOutboxEventsParams{
		Limit: int32(limit), LeaseOwner: pgTextS(worker), Column3: lease.Seconds(),
	})
	if err != nil {
		return nil, err
	}
	out := make([]OutboxEvent, 0, len(rs))
	for _, r := range rs {
		out = append(out, outboxEventFromClaimRow(r))
	}
	return out, nil
}

func outboxEventFromClaimRow(r dbgen.ClaimOutboxEventsRow) OutboxEvent {
	return OutboxEvent{
		ID: goUUID(r.ID), Topic: r.Topic, AggregateID: uuidPtrFromPG(r.AggregateID),
		IdempotencyKey: r.IdempotencyKey, Payload: cloneBytes(r.Payload), Status: r.Status,
		AvailableAt: timeFromPG(r.AvailableAt), AttemptCount: r.AttemptCount,
		LeaseOwner: textPtrFromPG(r.LeaseOwner), LeaseToken: goUUID(r.LeaseToken),
		LeaseUntil: timePtrFromPG(r.LeaseUntil), AcceptedAt: timePtrFromPG(r.AcceptedAt),
		CreatedAt: timeFromPG(r.CreatedAt), UpdatedAt: timeFromPG(r.UpdatedAt),
	}
}

func (q *Queries) FinishOutboxEvent(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, status string) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || status == "" {
		return false, ErrInvalidLease
	}
	_, err := q.g.FinishOutboxEvent(ctx, dbgen.FinishOutboxEventParams{
		ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token), Column4: status,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) GetOutboxEvent(ctx context.Context, id uuid.UUID) (*OutboxEvent, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetOutboxEvent(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := outboxEventFromRow(r)
	return &v, nil
}

func (q *Queries) ExtendOutboxEventLease(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, lease time.Duration) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || lease <= 0 {
		return false, ErrInvalidLease
	}
	_, err := q.g.ExtendOutboxEventLease(ctx, dbgen.ExtendOutboxEventLeaseParams{ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token), Column4: lease.Seconds()})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) ReleaseOutboxEventLease(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, availableAt time.Time) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || availableAt.IsZero() {
		return false, ErrInvalidLease
	}
	_, err := q.g.ReleaseOutboxEventLease(ctx, dbgen.ReleaseOutboxEventLeaseParams{ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token), AvailableAt: pgTZ(&availableAt)})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

// ---- shared HMAC-keyed quota ---------------------------------------------

type SharedQuotaKey struct {
	Scope          string
	IdentifierHMAC []byte
	KeyID          string
	WindowStart    time.Time
	WindowEnd      time.Time
	Limit          int64
}

type QuotaDecision struct {
	Allowed   bool
	Current   int64
	Limit     int64
	Requested int64
	Remaining int64
	RetryAt   time.Time
}

// CheckSharedQuota takes the same advisory lock and reads the aggregate quota
// without consuming it. Authentication callers use this as an atomic
// pre-verification admission gate so an already exhausted account/IP/global
// window rejects even correct credentials.
func (q *Queries) CheckSharedQuota(ctx context.Context, keys []SharedQuotaKey, amount int64) (QuotaDecision, error) {
	if amount <= 0 || len(keys) == 0 {
		return QuotaDecision{}, ErrInvalidQuota
	}
	if !q.inTx {
		var decision QuotaDecision
		err := q.InTxRetry(ctx, func(tx *Queries) error {
			var err error
			decision, err = tx.CheckSharedQuota(ctx, keys, amount)
			return err
		})
		return decision, err
	}
	return q.sharedQuotaDecision(ctx, keys, amount, false)
}

func (q *Queries) AcquireSharedQuota(ctx context.Context, keys []SharedQuotaKey, amount int64) (QuotaDecision, error) {
	if amount <= 0 || len(keys) == 0 {
		return QuotaDecision{}, ErrInvalidQuota
	}
	if !q.inTx {
		var decision QuotaDecision
		err := q.InTxRetry(ctx, func(tx *Queries) error {
			var err error
			decision, err = tx.AcquireSharedQuota(ctx, keys, amount)
			return err
		})
		return decision, err
	}
	return q.sharedQuotaDecision(ctx, keys, amount, true)
}

func (q *Queries) sharedQuotaDecision(ctx context.Context, keys []SharedQuotaKey, amount int64, consume bool) (QuotaDecision, error) {
	// Rotation keys represent aliases for one logical scope/window.  Require
	// one window and limit so callers cannot accidentally combine unrelated
	// quotas under one advisory lock.
	first := keys[0]
	if first.Scope == "" || len(first.IdentifierHMAC) == 0 || first.KeyID == "" || first.WindowStart.IsZero() || first.WindowEnd.IsZero() || !first.WindowEnd.After(first.WindowStart) || first.Limit <= 0 {
		return QuotaDecision{}, ErrInvalidQuota
	}
	limit := first.Limit
	identifiers := make([][]byte, 0, len(keys))
	seen := make(map[string]struct{}, len(keys))
	for _, key := range keys {
		if key.Scope != first.Scope || !key.WindowStart.Equal(first.WindowStart) || !key.WindowEnd.Equal(first.WindowEnd) || key.Limit != first.Limit || key.KeyID == "" || len(key.IdentifierHMAC) == 0 {
			return QuotaDecision{}, ErrInvalidQuota
		}
		id := string(key.IdentifierHMAC)
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		identifiers = append(identifiers, cloneBytes(key.IdentifierHMAC))
	}
	sort.Slice(identifiers, func(i, j int) bool { return string(identifiers[i]) < string(identifiers[j]) })
	windowKey := first.WindowStart.UTC().Format(time.RFC3339Nano)
	if err := q.g.LockRateLimitWindow(ctx, dbgen.LockRateLimitWindowParams{Column1: pgTextS(first.Scope), Column2: windowKey}); err != nil {
		return QuotaDecision{}, err
	}
	current, err := q.g.SumRateLimitBuckets(ctx, dbgen.SumRateLimitBucketsParams{
		Scope: first.Scope, WindowStart: pgTZ(&first.WindowStart), Column3: identifiers,
	})
	if err != nil {
		return QuotaDecision{}, err
	}
	decision := QuotaDecision{Current: current, Limit: limit, Requested: amount, RetryAt: first.WindowEnd}
	if current > limit || amount > limit-current {
		decision.Remaining = maxInt64(0, limit-current)
		return decision, nil
	}
	if !consume {
		decision.Allowed = true
		return decision, nil
	}
	// Only the first (current) key is incremented.  The sum includes all
	// previous key IDs, so rotating the active key cannot reset the quota.
	if _, err := q.g.UpsertRateLimitBucket(ctx, dbgen.UpsertRateLimitBucketParams{
		Scope: first.Scope, IdentifierHmac: cloneBytes(first.IdentifierHMAC), KeyID: first.KeyID,
		WindowStart: pgTZ(&first.WindowStart), WindowEnd: pgTZ(&first.WindowEnd), HitCount: amount,
	}); err != nil {
		return QuotaDecision{}, err
	}
	decision.Current += amount
	decision.Remaining = limit - decision.Current
	decision.Allowed = true
	return decision, nil
}

func maxInt64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}

func (q *Queries) PurgeRateLimitBuckets(ctx context.Context, before time.Time) error {
	if before.IsZero() {
		return ErrInvalidRetentionWindow
	}
	return q.g.PurgeRateLimitBuckets(ctx, pgTZ(&before))
}

// ---- audience snapshots --------------------------------------------------

type AudienceSnapshot struct {
	ID             uuid.UUID
	ActorID        *uuid.UUID
	Resource       string
	Action         string
	PayloadHash    []byte
	Filter         []byte
	Status         string
	AccountCount   int64
	EligibleCount  int64
	DeviceCount    int64
	ExclusionCount int64
	ExpiresAt      time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type AudienceSnapshotParams struct {
	ID          uuid.UUID
	ActorID     uuid.UUID
	Resource    string
	Action      string
	PayloadHash []byte
	Filter      []byte
	Status      string
	ExpiresAt   time.Time
}

type AudienceSnapshotMember struct {
	SnapshotID    uuid.UUID
	Ordinal       int64
	ResourceID    uuid.UUID
	Eligible      bool
	ExclusionCode *string
	CreatedAt     time.Time
}

func audienceSnapshotFromRow(r dbgen.AudienceSnapshot) AudienceSnapshot {
	return AudienceSnapshot{
		ID: goUUID(r.ID), ActorID: uuidPtrFromPG(r.ActorID), Resource: r.Resource, Action: r.Action,
		PayloadHash: cloneBytes(r.PayloadHash), Filter: cloneBytes(r.Filter), Status: r.Status,
		AccountCount: r.AccountCount, EligibleCount: r.EligibleCount, DeviceCount: r.DeviceCount,
		ExclusionCount: r.ExclusionCount, ExpiresAt: timeFromPG(r.ExpiresAt), CreatedAt: timeFromPG(r.CreatedAt), UpdatedAt: timeFromPG(r.UpdatedAt),
	}
}

func audienceSnapshotMemberFromRow(r dbgen.AudienceSnapshotMember) AudienceSnapshotMember {
	return AudienceSnapshotMember{
		SnapshotID: goUUID(r.SnapshotID), Ordinal: r.Ordinal, ResourceID: goUUID(r.ResourceID),
		Eligible: r.Eligible, ExclusionCode: textPtrFromPG(r.ExclusionCode), CreatedAt: timeFromPG(r.CreatedAt),
	}
}

func (q *Queries) CreateAudienceSnapshot(ctx context.Context, p AudienceSnapshotParams) error {
	if p.ID == uuid.Nil || p.Resource == "" || p.Action == "" || p.ExpiresAt.IsZero() {
		return ErrInvalidSnapshot
	}
	var actorID pgtype.UUID
	if p.ActorID != uuid.Nil {
		actorID = pgUUID(p.ActorID)
	}
	if p.Status == "" {
		p.Status = "ready"
	}
	payloadHash := cloneBytes(p.PayloadHash)
	if payloadHash == nil {
		payloadHash = []byte{}
	}
	return q.g.CreateAudienceSnapshot(ctx, dbgen.CreateAudienceSnapshotParams{
		ID: pgUUID(p.ID), ActorID: actorID, Resource: p.Resource, Action: p.Action,
		PayloadHash: payloadHash, Filter: cloneBytes(p.Filter), Status: p.Status, ExpiresAt: pgTZ(&p.ExpiresAt),
	})
}

func (q *Queries) GetAudienceSnapshot(ctx context.Context, id uuid.UUID) (*AudienceSnapshot, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetAudienceSnapshot(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := audienceSnapshotFromRow(r)
	return &v, nil
}

func (q *Queries) UpdateAudienceSnapshotCounts(ctx context.Context, id uuid.UUID, status string, accountCount, eligibleCount, deviceCount, exclusionCount int64) error {
	if id == uuid.Nil || status == "" || accountCount < 0 || eligibleCount < 0 || deviceCount < 0 || exclusionCount < 0 {
		return ErrInvalidSnapshot
	}
	return q.g.UpdateAudienceSnapshotCounts(ctx, dbgen.UpdateAudienceSnapshotCountsParams{
		ID: pgUUID(id), Status: status, AccountCount: accountCount, EligibleCount: eligibleCount,
		DeviceCount: deviceCount, ExclusionCount: exclusionCount,
	})
}

// AddAudienceSnapshotMembers appends in caller order under the snapshot row
// lock.  This gives concurrent materializers a single stable ordinal stream.
func (q *Queries) AddAudienceSnapshotMembers(ctx context.Context, snapshotID uuid.UUID, resourceIDs []uuid.UUID) error {
	if snapshotID == uuid.Nil {
		return ErrInvalidSnapshot
	}
	if len(resourceIDs) == 0 {
		return nil
	}
	pgIDs := make([]pgtype.UUID, 0, len(resourceIDs))
	for _, id := range resourceIDs {
		if id == uuid.Nil {
			return ErrInvalidSnapshot
		}
		pgIDs = append(pgIDs, pgUUID(id))
	}
	if !q.inTx {
		return q.InTxRetry(ctx, func(tx *Queries) error {
			return tx.AddAudienceSnapshotMembers(ctx, snapshotID, resourceIDs)
		})
	}
	if _, err := q.g.LockAudienceSnapshot(ctx, pgUUID(snapshotID)); errors.Is(err, pgx.ErrNoRows) {
		return ErrInvalidSnapshot
	} else if err != nil {
		return err
	}
	return q.g.AppendAudienceSnapshotMembers(ctx, dbgen.AppendAudienceSnapshotMembersParams{SnapshotID: pgUUID(snapshotID), Column2: pgIDs})
}

func (q *Queries) AddAudienceSnapshotMember(ctx context.Context, snapshotID uuid.UUID, ordinal int64, resourceID uuid.UUID, eligible bool, exclusionCode *string) error {
	if snapshotID == uuid.Nil || resourceID == uuid.Nil || ordinal < 0 {
		return ErrInvalidSnapshot
	}
	if !q.inTx {
		return q.InTxRetry(ctx, func(tx *Queries) error {
			return tx.AddAudienceSnapshotMember(ctx, snapshotID, ordinal, resourceID, eligible, exclusionCode)
		})
	}
	if _, err := q.g.LockAudienceSnapshot(ctx, pgUUID(snapshotID)); errors.Is(err, pgx.ErrNoRows) {
		return ErrInvalidSnapshot
	} else if err != nil {
		return err
	}
	return q.g.AddAudienceSnapshotMember(ctx, dbgen.AddAudienceSnapshotMemberParams{
		SnapshotID: pgUUID(snapshotID), Ordinal: ordinal, ResourceID: pgUUID(resourceID), Eligible: eligible, ExclusionCode: pgText(exclusionCode),
	})
}

func (q *Queries) ListAudienceSnapshotMembers(ctx context.Context, snapshotID uuid.UUID, limit int, afterOrdinal int64) ([]AudienceSnapshotMember, error) {
	if snapshotID == uuid.Nil || limit <= 0 || afterOrdinal < InitialAudienceSnapshotOrdinal {
		return nil, ErrInvalidSnapshot
	}
	// Pass the explicit initial sentinel through unchanged.  In particular,
	// ordinal zero is a real exclusive cursor and must not be rewritten.
	rs, err := q.g.ListAudienceSnapshotMembers(ctx, dbgen.ListAudienceSnapshotMembersParams{
		SnapshotID: pgUUID(snapshotID), Column2: afterOrdinal, Limit: int32(limit),
	})
	if err != nil {
		return nil, err
	}
	out := make([]AudienceSnapshotMember, 0, len(rs))
	for _, r := range rs {
		out = append(out, audienceSnapshotMemberFromRow(r))
	}
	return out, nil
}

func (q *Queries) CountAudienceSnapshotMembers(ctx context.Context, snapshotID uuid.UUID) (total, eligible, excluded int64, err error) {
	if snapshotID == uuid.Nil {
		return 0, 0, 0, ErrInvalidSnapshot
	}
	r, err := q.g.CountAudienceSnapshotMembers(ctx, pgUUID(snapshotID))
	return r.Total, r.Eligible, r.Excluded, err
}

func (q *Queries) DeleteExpiredAudienceSnapshots(ctx context.Context, before time.Time) error {
	if before.IsZero() {
		return ErrInvalidRetentionWindow
	}
	return q.g.DeleteExpiredAudienceSnapshots(ctx, pgTZ(&before))
}

// ---- delivery attempts ---------------------------------------------------

type DeliveryAttempt struct {
	ID                uuid.UUID
	Channel           string
	AccountID         *uuid.UUID
	DeviceID          *uuid.UUID
	JobID             *uuid.UUID
	ItemID            *uuid.UUID
	Status            string
	AttemptNumber     int32
	ProviderReference *string
	ProviderOutcome   *string
	ErrorCode         *string
	EncryptedPayload  []byte
	DeliveryKeyID     *string
	PayloadExpiresAt  *time.Time
	AcceptedAt        *time.Time
	CreatedAt         time.Time
	UpdatedAt         time.Time
	LeaseOwner        *string
	LeaseToken        uuid.UUID
	LeaseUntil        *time.Time
}

type DeliveryAttemptParams struct {
	ID               uuid.UUID
	Channel          string
	AccountID        *uuid.UUID
	DeviceID         *uuid.UUID
	JobID            *uuid.UUID
	ItemID           *uuid.UUID
	Status           string
	AttemptNumber    int32
	EncryptedPayload []byte
	DeliveryKeyID    *string
	PayloadExpiresAt *time.Time
}

func deliveryAttemptFromRow(r dbgen.DeliveryAttempt) DeliveryAttempt {
	return DeliveryAttempt{
		ID: goUUID(r.ID), Channel: r.Channel, AccountID: uuidPtrFromPG(r.AccountID), DeviceID: uuidPtrFromPG(r.DeviceID),
		JobID: uuidPtrFromPG(r.JobID), ItemID: uuidPtrFromPG(r.ItemID), Status: r.Status, AttemptNumber: r.AttemptNumber,
		ProviderReference: textPtrFromPG(r.ProviderReference), ProviderOutcome: textPtrFromPG(r.ProviderOutcome), ErrorCode: textPtrFromPG(r.ErrorCode),
		EncryptedPayload: cloneBytes(r.EncryptedPayload), DeliveryKeyID: textPtrFromPG(r.DeliveryKeyID), PayloadExpiresAt: timePtrFromPG(r.PayloadExpiresAt),
		AcceptedAt: timePtrFromPG(r.AcceptedAt), CreatedAt: timeFromPG(r.CreatedAt), UpdatedAt: timeFromPG(r.UpdatedAt),
		LeaseOwner: textPtrFromPG(r.LeaseOwner), LeaseToken: goUUID(r.LeaseToken), LeaseUntil: timePtrFromPG(r.LeaseUntil),
	}
}

func (q *Queries) CreateDeliveryAttempt(ctx context.Context, p DeliveryAttemptParams) error {
	if p.ID == uuid.Nil || p.Channel == "" || p.Status == "" || p.AttemptNumber < 0 {
		return ErrInvalidDeliveryAttempt
	}
	return q.g.CreateDeliveryAttempt(ctx, dbgen.CreateDeliveryAttemptParams{
		ID: pgUUID(p.ID), Channel: p.Channel, AccountID: pgUUIDPtr(p.AccountID), DeviceID: pgUUIDPtr(p.DeviceID),
		JobID: pgUUIDPtr(p.JobID), ItemID: pgUUIDPtr(p.ItemID), Status: p.Status, AttemptNumber: p.AttemptNumber,
		EncryptedPayload: cloneBytes(p.EncryptedPayload), DeliveryKeyID: pgText(p.DeliveryKeyID), PayloadExpiresAt: pgTZ(p.PayloadExpiresAt),
	})
}

func (q *Queries) GetDeliveryAttempt(ctx context.Context, id uuid.UUID) (*DeliveryAttempt, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetDeliveryAttempt(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := deliveryAttemptFromRow(r)
	return &v, nil
}

func (q *Queries) UpdateDeliveryAttemptOutcome(ctx context.Context, id uuid.UUID, status string, providerReference, providerOutcome, errorCode *string, acceptedAt *time.Time) error {
	if id == uuid.Nil || status == "" {
		return ErrInvalidDeliveryAttempt
	}
	return q.g.UpdateDeliveryAttemptOutcome(ctx, dbgen.UpdateDeliveryAttemptOutcomeParams{
		ID: pgUUID(id), Status: status, ProviderReference: pgText(providerReference), ProviderOutcome: pgText(providerOutcome),
		ErrorCode: pgText(errorCode), AcceptedAt: pgTZ(acceptedAt),
	})
}

// ClearDeliveryAttemptPayload atomically removes the encrypted delivery
// secret and its key identifier once the attempt is terminal or its payload
// has expired.  Retryable statuses do not satisfy the predicate, so a
// cleanup racing an outcome update cannot erase a payload needed for retry.
func (q *Queries) ClearDeliveryAttemptPayload(ctx context.Context, id uuid.UUID, now time.Time) (bool, error) {
	if id == uuid.Nil {
		return false, ErrInvalidDeliveryAttempt
	}
	if now.IsZero() {
		return false, ErrInvalidRetentionWindow
	}
	clearedID, err := q.g.ClearDeliveryAttemptPayload(ctx, dbgen.ClearDeliveryAttemptPayloadParams{
		ID: pgUUID(id), PayloadExpiresAt: pgTZ(&now),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return clearedID.Valid, nil
}

func (q *Queries) ClearExpiredDeliveryPayloads(ctx context.Context, payloadBefore, acceptedBefore time.Time) error {
	if payloadBefore.IsZero() || acceptedBefore.IsZero() {
		return ErrInvalidRetentionWindow
	}
	return q.g.ClearExpiredDeliveryPayloads(ctx, dbgen.ClearExpiredDeliveryPayloadsParams{
		PayloadExpiresAt: pgTZ(&payloadBefore), AcceptedAt: pgTZ(&acceptedBefore),
	})
}

// ---- admin memberships, sessions, and challenges ------------------------

type AdminMembership struct {
	ID                   uuid.UUID
	UserID               uuid.UUID
	Permissions          []string
	Active               bool
	TotpSecretCiphertext []byte
	TotpKeyID            *string
	TotpEnrolledAt       *time.Time
	CreatedAt            time.Time
	UpdatedAt            time.Time
	RevokedAt            *time.Time
}

type AdminMembershipParams struct {
	ID                   uuid.UUID
	UserID               uuid.UUID
	Permissions          []string
	Active               bool
	TotpSecretCiphertext []byte
	TotpKeyID            *string
	TotpEnrolledAt       *time.Time
	RevokedAt            *time.Time
}

func adminMembershipFromRow(r dbgen.AdminMembership) AdminMembership {
	return AdminMembership{
		ID: goUUID(r.ID), UserID: goUUID(r.UserID), Permissions: append([]string(nil), r.Permissions...), Active: r.Active,
		TotpSecretCiphertext: cloneBytes(r.TotpSecretCiphertext), TotpKeyID: textPtrFromPG(r.TotpKeyID), TotpEnrolledAt: timePtrFromPG(r.TotpEnrolledAt),
		CreatedAt: timeFromPG(r.CreatedAt), UpdatedAt: timeFromPG(r.UpdatedAt), RevokedAt: timePtrFromPG(r.RevokedAt),
	}
}

func (q *Queries) GetAdminMembership(ctx context.Context, userID uuid.UUID) (*AdminMembership, error) {
	if userID == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetAdminMembership(ctx, pgUUID(userID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := adminMembershipFromRow(r)
	return &v, nil
}

func (q *Queries) UpsertAdminMembership(ctx context.Context, p AdminMembershipParams) error {
	if p.ID == uuid.Nil || p.UserID == uuid.Nil {
		return ErrInvalidMembership
	}
	permissions := append([]string(nil), p.Permissions...)
	if permissions == nil {
		permissions = []string{}
	}
	return q.g.UpsertAdminMembership(ctx, dbgen.UpsertAdminMembershipParams{
		ID: pgUUID(p.ID), UserID: pgUUID(p.UserID), Permissions: permissions, Active: p.Active,
		TotpSecretCiphertext: cloneBytes(p.TotpSecretCiphertext), TotpKeyID: pgText(p.TotpKeyID), TotpEnrolledAt: pgTZ(p.TotpEnrolledAt), RevokedAt: pgTZ(p.RevokedAt),
	})
}

func (q *Queries) RevokeAdminMembership(ctx context.Context, userID uuid.UUID) error {
	if userID == uuid.Nil {
		return nil
	}
	return q.g.RevokeAdminMembership(ctx, pgUUID(userID))
}

type AdminSession struct {
	ID                uuid.UUID
	SessionHash       []byte
	UserID            uuid.UUID
	CSRFHash          []byte
	State             string
	AuthGeneration    int64
	IssuedAt          time.Time
	LastSeenAt        time.Time
	IdleExpiresAt     time.Time
	AbsoluteExpiresAt time.Time
	RecentMFAAt       *time.Time
	RecentMFAAction   *string
	RevokedAt         *time.Time
}

type AdminSessionParams struct {
	ID                uuid.UUID
	SessionHash       []byte
	UserID            uuid.UUID
	CSRFHash          []byte
	State             string
	AuthGeneration    int64
	IdleExpiresAt     time.Time
	AbsoluteExpiresAt time.Time
	RecentMFAAt       *time.Time
	RecentMFAAction   *string
}

func adminSessionFromRow(r dbgen.GetAdminSessionByHashRow) AdminSession {
	return AdminSession{
		ID: goUUID(r.ID), SessionHash: cloneBytes(r.SessionHash), UserID: goUUID(r.UserID), CSRFHash: cloneBytes(r.CsrfHash), State: r.State,
		AuthGeneration: r.AuthGeneration, IssuedAt: timeFromPG(r.IssuedAt), LastSeenAt: timeFromPG(r.LastSeenAt), IdleExpiresAt: timeFromPG(r.IdleExpiresAt),
		AbsoluteExpiresAt: timeFromPG(r.AbsoluteExpiresAt), RecentMFAAt: timePtrFromPG(r.RecentMfaAt), RecentMFAAction: textPtrFromPG(r.RecentMfaAction), RevokedAt: timePtrFromPG(r.RevokedAt),
	}
}

func (q *Queries) CreateAdminSession(ctx context.Context, p AdminSessionParams) error {
	if p.ID == uuid.Nil || p.UserID == uuid.Nil || len(p.SessionHash) == 0 || len(p.CSRFHash) == 0 || p.IdleExpiresAt.IsZero() || p.AbsoluteExpiresAt.IsZero() || !p.AbsoluteExpiresAt.After(p.IdleExpiresAt) {
		return ErrInvalidSession
	}
	if p.State == "" {
		p.State = "pre_auth"
	}
	return q.g.CreateAdminSession(ctx, dbgen.CreateAdminSessionParams{
		ID: pgUUID(p.ID), SessionHash: cloneBytes(p.SessionHash), UserID: pgUUID(p.UserID), CsrfHash: cloneBytes(p.CSRFHash), State: p.State,
		AuthGeneration: p.AuthGeneration, IdleExpiresAt: pgTZ(&p.IdleExpiresAt), AbsoluteExpiresAt: pgTZ(&p.AbsoluteExpiresAt), RecentMfaAt: pgTZ(p.RecentMFAAt), RecentMfaAction: pgText(p.RecentMFAAction),
	})
}

func (q *Queries) GetAdminSessionByHash(ctx context.Context, sessionHash []byte) (*AdminSession, error) {
	if len(sessionHash) == 0 {
		return nil, nil
	}
	r, err := q.g.GetAdminSessionByHash(ctx, cloneBytes(sessionHash))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := adminSessionFromRow(r)
	return &v, nil
}

func (q *Queries) TouchAdminSession(ctx context.Context, sessionHash []byte, idleExpiresAt time.Time) error {
	if len(sessionHash) == 0 || idleExpiresAt.IsZero() {
		return ErrInvalidSession
	}
	return q.g.TouchAdminSession(ctx, dbgen.TouchAdminSessionParams{SessionHash: cloneBytes(sessionHash), IdleExpiresAt: pgTZ(&idleExpiresAt)})
}

func (q *Queries) RotateAdminSessionCSRF(ctx context.Context, id uuid.UUID, csrfHash []byte, recentMFAAt *time.Time, recentMFAAction ...string) error {
	if id == uuid.Nil || len(csrfHash) == 0 {
		return ErrInvalidSession
	}
	var action *string
	if len(recentMFAAction) > 0 && strings.TrimSpace(recentMFAAction[0]) != "" {
		value := strings.TrimSpace(recentMFAAction[0])
		action = &value
	}
	return q.g.RotateAdminSessionCSRF(ctx, dbgen.RotateAdminSessionCSRFParams{ID: pgUUID(id), CsrfHash: cloneBytes(csrfHash), RecentMfaAt: pgTZ(recentMFAAt), RecentMfaAction: pgText(action)})
}

func (q *Queries) RevokeAdminSession(ctx context.Context, id uuid.UUID) error {
	if id == uuid.Nil {
		return nil
	}
	return q.g.RevokeAdminSession(ctx, pgUUID(id))
}

func (q *Queries) RevokeAdminSessionsForUser(ctx context.Context, userID uuid.UUID) error {
	if userID == uuid.Nil {
		return nil
	}
	return q.g.RevokeAdminSessionsForUser(ctx, pgUUID(userID))
}

func (q *Queries) RevokeExpiredAdminSessions(ctx context.Context, now time.Time) error {
	if now.IsZero() {
		return ErrInvalidRetentionWindow
	}
	return q.g.RevokeExpiredAdminSessions(ctx, pgTZ(&now))
}

type AdminLoginChallenge struct {
	ID             uuid.UUID
	ChallengeHash  []byte
	UserID         *uuid.UUID
	IPHMAC         []byte
	FailedAttempts int32
	AuthGeneration int64
	ExpiresAt      time.Time
	ConsumedAt     *time.Time
	RevokedAt      *time.Time
	CreatedAt      time.Time
}

type AdminLoginChallengeParams struct {
	ID             uuid.UUID
	ChallengeHash  []byte
	UserID         *uuid.UUID
	IPHMAC         []byte
	AuthGeneration int64
	ExpiresAt      time.Time
}

func adminLoginChallengeFromRow(r dbgen.AdminLoginChallenge) AdminLoginChallenge {
	return AdminLoginChallenge{
		ID: goUUID(r.ID), ChallengeHash: cloneBytes(r.ChallengeHash), UserID: uuidPtrFromPG(r.UserID), IPHMAC: cloneBytes(r.IpHmac), FailedAttempts: r.FailedAttempts,
		AuthGeneration: r.AuthGeneration, ExpiresAt: timeFromPG(r.ExpiresAt), ConsumedAt: timePtrFromPG(r.ConsumedAt), RevokedAt: timePtrFromPG(r.RevokedAt), CreatedAt: timeFromPG(r.CreatedAt),
	}
}

func (q *Queries) CreateAdminLoginChallenge(ctx context.Context, p AdminLoginChallengeParams) error {
	if p.ID == uuid.Nil || p.UserID == nil || *p.UserID == uuid.Nil || len(p.ChallengeHash) == 0 || p.ExpiresAt.IsZero() || p.AuthGeneration < 0 {
		return ErrInvalidChallenge
	}
	return q.g.CreateAdminLoginChallenge(ctx, dbgen.CreateAdminLoginChallengeParams{
		ID: pgUUID(p.ID), ChallengeHash: cloneBytes(p.ChallengeHash), UserID: pgUUIDPtr(p.UserID), IpHmac: cloneBytes(p.IPHMAC), AuthGeneration: p.AuthGeneration, ExpiresAt: pgTZ(&p.ExpiresAt),
	})
}

func (q *Queries) GetAdminLoginChallenge(ctx context.Context, id uuid.UUID) (*AdminLoginChallenge, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetAdminLoginChallenge(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := adminLoginChallengeFromRow(r)
	return &v, nil
}

func (q *Queries) ConsumeAdminLoginChallenge(ctx context.Context, id uuid.UUID, now time.Time) (*AdminLoginChallenge, bool, error) {
	if id == uuid.Nil || now.IsZero() {
		return nil, false, nil
	}
	if !q.inTx {
		var challenge *AdminLoginChallenge
		var consumed bool
		err := q.InTxRetry(ctx, func(tx *Queries) error {
			var err error
			challenge, consumed, err = tx.ConsumeAdminLoginChallenge(ctx, id, now)
			return err
		})
		return challenge, consumed, err
	}
	initial, err := q.g.GetAdminLoginChallenge(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	if !initial.UserID.Valid {
		return nil, false, nil
	}
	account, err := q.LockUserSecurity(ctx, goUUID(initial.UserID))
	if err != nil {
		return nil, false, err
	}
	if account == nil || account.IsDeleted || account.SecurityState != SecurityStateNormal || account.PasswordResetRequired || account.AuthGeneration != initial.AuthGeneration {
		return nil, false, nil
	}
	locked, err := q.g.LockAdminLoginChallenge(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	if locked.AuthGeneration != account.AuthGeneration || locked.ConsumedAt.Valid || locked.RevokedAt.Valid || !locked.ExpiresAt.Valid || !locked.ExpiresAt.Time.After(now) {
		return nil, false, nil
	}
	r, err := q.g.ConsumeAdminLoginChallenge(ctx, dbgen.ConsumeAdminLoginChallengeParams{ID: pgUUID(id), ExpiresAt: pgTZ(&now)})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	v := adminLoginChallengeFromRow(r)
	return &v, true, nil
}

func (q *Queries) IncrementAdminChallengeFailure(ctx context.Context, id uuid.UUID) (int32, bool, error) {
	if id == uuid.Nil {
		return 0, false, nil
	}
	n, err := q.g.IncrementAdminChallengeFailure(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, false, nil
	}
	return n, err == nil, err
}

func (q *Queries) RevokeAdminLoginChallengesForUser(ctx context.Context, userID uuid.UUID) error {
	if userID == uuid.Nil {
		return nil
	}
	return q.g.RevokeAdminLoginChallengesForUser(ctx, pgUUID(userID))
}

type AdminMFAReplayCounter struct {
	SessionID   uuid.UUID
	LastCounter int64
	UpdatedAt   time.Time
}

// AdminMFAReplayScope is shared by all browser sessions for one stable admin
// membership and user enrollment.
type AdminMFAReplayScope struct {
	MembershipID uuid.UUID
	UserID       uuid.UUID
	LastCounter  int64
	UpdatedAt    time.Time
}

func adminMFAReplayCounterFromRow(r dbgen.AdminMfaReplayCounter) AdminMFAReplayCounter {
	return AdminMFAReplayCounter{SessionID: goUUID(r.SessionID), LastCounter: r.LastCounter, UpdatedAt: timeFromPG(r.UpdatedAt)}
}

func (q *Queries) GetAdminMFAReplayCounter(ctx context.Context, sessionID uuid.UUID) (*AdminMFAReplayCounter, error) {
	if sessionID == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetAdminMFAReplayCounter(ctx, pgUUID(sessionID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := adminMFAReplayCounterFromRow(r)
	return &v, nil
}

func (q *Queries) AdvanceAdminMFAReplayCounter(ctx context.Context, sessionID uuid.UUID, counter int64) (*AdminMFAReplayCounter, bool, error) {
	if sessionID == uuid.Nil || counter < 0 {
		return nil, false, nil
	}
	r, err := q.g.AdvanceAdminMFAReplayCounter(ctx, dbgen.AdvanceAdminMFAReplayCounterParams{SessionID: pgUUID(sessionID), LastCounter: counter})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	v := adminMFAReplayCounterFromRow(r)
	return &v, true, nil
}

func adminMFAReplayScopeFromRow(r dbgen.AdminMfaReplayScope) AdminMFAReplayScope {
	return AdminMFAReplayScope{MembershipID: goUUID(r.MembershipID), UserID: goUUID(r.UserID), LastCounter: r.LastCounter, UpdatedAt: timeFromPG(r.UpdatedAt)}
}

func (q *Queries) GetAdminMFAReplayScope(ctx context.Context, membershipID, userID uuid.UUID) (*AdminMFAReplayScope, error) {
	if membershipID == uuid.Nil || userID == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetAdminMFAReplayScope(ctx, dbgen.GetAdminMFAReplayScopeParams{MembershipID: pgUUID(membershipID), UserID: pgUUID(userID)})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := adminMFAReplayScopeFromRow(r)
	return &v, nil
}

// AdvanceAdminMFAReplayScope is the atomic moving-factor boundary. A false
// result means this counter was already accepted for this membership/user,
// including from a different browser session.
func (q *Queries) AdvanceAdminMFAReplayScope(ctx context.Context, membershipID, userID uuid.UUID, counter int64) (*AdminMFAReplayScope, bool, error) {
	if membershipID == uuid.Nil || userID == uuid.Nil || counter < 0 {
		return nil, false, nil
	}
	r, err := q.g.AdvanceAdminMFAReplayScope(ctx, dbgen.AdvanceAdminMFAReplayScopeParams{MembershipID: pgUUID(membershipID), UserID: pgUUID(userID), LastCounter: counter})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	v := adminMFAReplayScopeFromRow(r)
	return &v, true, nil
}

func (q *Queries) ResetAdminMFAReplayScope(ctx context.Context, membershipID, userID uuid.UUID) error {
	if membershipID == uuid.Nil || userID == uuid.Nil {
		return nil
	}
	return q.g.ResetAdminMFAReplayScope(ctx, dbgen.ResetAdminMFAReplayScopeParams{MembershipID: pgUUID(membershipID), UserID: pgUUID(userID)})
}

// ---- administrative jobs and recipient items -----------------------------

var ErrIdempotencyConflict = errors.New("idempotency key belongs to a different operation")

type AdminJob struct {
	ID             uuid.UUID
	ActorID        *uuid.UUID
	SnapshotID     *uuid.UUID
	Action         string
	PayloadHash    []byte
	IdempotencyKey string
	Status         string
	AccountCount   int64
	EligibleCount  int64
	DeviceCount    int64
	CompletedCount int64
	FailedCount    int64
	Reason         *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
	StartedAt      *time.Time
	CompletedAt    *time.Time
}

type AdminJobParams struct {
	ID             uuid.UUID
	ActorID        *uuid.UUID
	SnapshotID     *uuid.UUID
	Action         string
	PayloadHash    []byte
	IdempotencyKey string
	AccountCount   int64
	EligibleCount  int64
	DeviceCount    int64
	Reason         *string
}

func adminJobFromRow(r dbgen.AdminJob) AdminJob {
	return AdminJob{
		ID:             goUUID(r.ID),
		ActorID:        uuidPtrFromPG(r.ActorID),
		SnapshotID:     uuidPtrFromPG(r.SnapshotID),
		Action:         r.Action,
		PayloadHash:    cloneBytes(r.PayloadHash),
		IdempotencyKey: r.IdempotencyKey,
		Status:         r.Status,
		AccountCount:   r.AccountCount,
		EligibleCount:  r.EligibleCount,
		DeviceCount:    r.DeviceCount,
		CompletedCount: r.CompletedCount,
		FailedCount:    r.FailedCount,
		Reason:         textPtrFromPG(r.Reason),
		CreatedAt:      timeFromPG(r.CreatedAt),
		UpdatedAt:      timeFromPG(r.UpdatedAt),
		StartedAt:      timePtrFromPG(r.StartedAt),
		CompletedAt:    timePtrFromPG(r.CompletedAt),
	}
}

func optionalUUIDEqual(a, b *uuid.UUID) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return *a == *b
}

func optionalStringEqual(a, b *string) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return *a == *b
}

func adminJobMatches(p AdminJobParams, existing AdminJob) bool {
	return optionalUUIDEqual(p.ActorID, existing.ActorID) &&
		optionalUUIDEqual(p.SnapshotID, existing.SnapshotID) &&
		p.Action == existing.Action && bytes.Equal(p.PayloadHash, existing.PayloadHash) &&
		p.AccountCount == existing.AccountCount && p.EligibleCount == existing.EligibleCount &&
		p.DeviceCount == existing.DeviceCount && optionalStringEqual(p.Reason, existing.Reason)
}

// CreateAdminJob is idempotent on the database key.  A replay with the same
// operation returns the original row; reusing that key for another payload is
// rejected before a caller can enqueue a different operation.
func (q *Queries) CreateAdminJob(ctx context.Context, p AdminJobParams) (*AdminJob, error) {
	if p.ID == uuid.Nil || p.Action == "" || p.IdempotencyKey == "" ||
		p.AccountCount < 0 || p.EligibleCount < 0 || p.DeviceCount < 0 {
		return nil, ErrInvalidJob
	}
	payloadHash := cloneBytes(p.PayloadHash)
	if payloadHash == nil {
		payloadHash = []byte{}
	}
	r, err := q.g.CreateAdminJob(ctx, dbgen.CreateAdminJobParams{
		ID:             pgUUID(p.ID),
		ActorID:        pgUUIDPtr(p.ActorID),
		SnapshotID:     pgUUIDPtr(p.SnapshotID),
		Action:         p.Action,
		PayloadHash:    payloadHash,
		IdempotencyKey: p.IdempotencyKey,
		AccountCount:   p.AccountCount,
		EligibleCount:  p.EligibleCount,
		DeviceCount:    p.DeviceCount,
		Reason:         pgText(p.Reason),
	})
	if err != nil {
		return nil, err
	}
	v := adminJobFromRow(r)
	if !adminJobMatches(p, v) {
		return nil, ErrIdempotencyConflict
	}
	return &v, nil
}

func (q *Queries) GetAdminJob(ctx context.Context, id uuid.UUID) (*AdminJob, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetAdminJob(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := adminJobFromRow(r)
	return &v, nil
}

func (q *Queries) ListAdminJobs(ctx context.Context, status string, before *time.Time, limit int) ([]AdminJob, error) {
	if limit <= 0 {
		return nil, ErrInvalidJob
	}
	rs, err := q.g.ListAdminJobs(ctx, dbgen.ListAdminJobsParams{
		Column1: status, Column2: pgTZ(before), Limit: int32(limit),
	})
	if err != nil {
		return nil, err
	}
	out := make([]AdminJob, 0, len(rs))
	for _, r := range rs {
		out = append(out, adminJobFromRow(r))
	}
	return out, nil
}

func (q *Queries) UpdateAdminJobProgress(ctx context.Context, id uuid.UUID, status string, completedCount, failedCount int64) error {
	if id == uuid.Nil || status == "" || completedCount < 0 || failedCount < 0 {
		return ErrInvalidJob
	}
	return q.g.UpdateAdminJobProgress(ctx, dbgen.UpdateAdminJobProgressParams{
		ID: pgUUID(id), Status: status, CompletedCount: completedCount, FailedCount: failedCount,
	})
}

type AdminJobItem struct {
	ID                uuid.UUID
	JobID             uuid.UUID
	TargetID          uuid.UUID
	DeviceID          *uuid.UUID
	Outcome           string
	ErrorCode         *string
	ProviderReference *string
	AttemptCount      int32
	LeaseOwner        *string
	LeaseToken        uuid.UUID
	LeaseUntil        *time.Time
	CompletedAt       *time.Time
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

type AdminJobItemParams struct {
	ID                uuid.UUID
	JobID             uuid.UUID
	TargetID          uuid.UUID
	DeviceID          *uuid.UUID
	Outcome           string
	ErrorCode         *string
	ProviderReference *string
}

func adminJobItemFromRow(r dbgen.AdminJobItem) AdminJobItem {
	return AdminJobItem{
		ID:                goUUID(r.ID),
		JobID:             goUUID(r.JobID),
		TargetID:          goUUID(r.TargetID),
		DeviceID:          uuidPtrFromPG(r.DeviceID),
		Outcome:           r.Outcome,
		ErrorCode:         textPtrFromPG(r.ErrorCode),
		ProviderReference: textPtrFromPG(r.ProviderReference),
		AttemptCount:      r.AttemptCount,
		LeaseOwner:        textPtrFromPG(r.LeaseOwner),
		LeaseToken:        goUUID(r.LeaseToken),
		LeaseUntil:        timePtrFromPG(r.LeaseUntil),
		CompletedAt:       timePtrFromPG(r.CompletedAt),
		CreatedAt:         timeFromPG(r.CreatedAt),
		UpdatedAt:         timeFromPG(r.UpdatedAt),
	}
}

func adminJobItemFromClaimRow(r dbgen.ClaimAdminJobItemsRow) AdminJobItem {
	return AdminJobItem{
		ID:                goUUID(r.ID),
		JobID:             goUUID(r.JobID),
		TargetID:          goUUID(r.TargetID),
		DeviceID:          uuidPtrFromPG(r.DeviceID),
		Outcome:           r.Outcome,
		ErrorCode:         textPtrFromPG(r.ErrorCode),
		ProviderReference: textPtrFromPG(r.ProviderReference),
		AttemptCount:      r.AttemptCount,
		LeaseOwner:        textPtrFromPG(r.LeaseOwner),
		LeaseToken:        goUUID(r.LeaseToken),
		LeaseUntil:        timePtrFromPG(r.LeaseUntil),
		CompletedAt:       timePtrFromPG(r.CompletedAt),
		CreatedAt:         timeFromPG(r.CreatedAt),
		UpdatedAt:         timeFromPG(r.UpdatedAt),
	}
}

func (q *Queries) AddAdminJobItem(ctx context.Context, p AdminJobItemParams) error {
	if p.ID == uuid.Nil || p.JobID == uuid.Nil || p.TargetID == uuid.Nil {
		return ErrInvalidJob
	}
	if p.Outcome == "" {
		p.Outcome = "queued"
	}
	return q.g.AddAdminJobItem(ctx, dbgen.AddAdminJobItemParams{
		ID:    pgUUID(p.ID),
		JobID: pgUUID(p.JobID), TargetID: pgUUID(p.TargetID), DeviceID: pgUUIDPtr(p.DeviceID),
		Outcome: p.Outcome, ErrorCode: pgText(p.ErrorCode), ProviderReference: pgText(p.ProviderReference),
	})
}

func (q *Queries) GetAdminJobItem(ctx context.Context, id uuid.UUID) (*AdminJobItem, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetAdminJobItem(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := adminJobItemFromRow(r)
	return &v, nil
}

func (q *Queries) ListAdminJobItems(ctx context.Context, jobID uuid.UUID, before *time.Time, limit int) ([]AdminJobItem, error) {
	if jobID == uuid.Nil || limit <= 0 {
		return nil, ErrInvalidJob
	}
	rs, err := q.g.ListAdminJobItems(ctx, dbgen.ListAdminJobItemsParams{JobID: pgUUID(jobID), Column2: pgTZ(before), Limit: int32(limit)})
	if err != nil {
		return nil, err
	}
	out := make([]AdminJobItem, 0, len(rs))
	for _, r := range rs {
		out = append(out, adminJobItemFromRow(r))
	}
	return out, nil
}

func (q *Queries) ClaimAdminJobItems(ctx context.Context, jobID uuid.UUID, worker string, limit int, lease time.Duration) ([]AdminJobItem, error) {
	if jobID == uuid.Nil || worker == "" || limit <= 0 || lease <= 0 {
		return nil, ErrInvalidLease
	}
	rs, err := q.g.ClaimAdminJobItems(ctx, dbgen.ClaimAdminJobItemsParams{
		JobID: pgUUID(jobID), Limit: int32(limit), LeaseOwner: pgTextS(worker), Column4: lease.Seconds(),
	})
	if err != nil {
		return nil, err
	}
	out := make([]AdminJobItem, 0, len(rs))
	for _, r := range rs {
		out = append(out, adminJobItemFromClaimRow(r))
	}
	return out, nil
}

func (q *Queries) FinishAdminJobItem(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, outcome string, errorCode, providerReference *string) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || outcome == "" {
		return false, ErrInvalidLease
	}
	_, err := q.g.FinishAdminJobItem(ctx, dbgen.FinishAdminJobItemParams{
		ID: pgUUID(id), Column2: outcome, ErrorCode: pgText(errorCode), ProviderReference: pgText(providerReference),
		LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) ExtendAdminJobItemLease(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, lease time.Duration) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil || lease <= 0 {
		return false, ErrInvalidLease
	}
	_, err := q.g.ExtendAdminJobItemLease(ctx, dbgen.ExtendAdminJobItemLeaseParams{
		ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token), Column4: lease.Seconds(),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) ReleaseAdminJobItemLease(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID) (bool, error) {
	if id == uuid.Nil || worker == "" || token == uuid.Nil {
		return false, ErrInvalidLease
	}
	_, err := q.g.ReleaseAdminJobItemLease(ctx, dbgen.ReleaseAdminJobItemLeaseParams{
		ID: pgUUID(id), LeaseOwner: pgTextS(worker), LeaseToken: pgUUID(token),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

// ---- reports and report notes ---------------------------------------------

type Report struct {
	ID             uuid.UUID
	ReporterUserID *uuid.UUID
	TargetID       *uuid.UUID
	TargetKind     *string
	TargetName     *string
	TargetDeleted  bool
	Body           string
	LegacyText     *string
	Status         string
	AssigneeUserID *uuid.UUID
	Revision       int64
	RequestID      *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
	ResolvedAt     *time.Time
}

type ReportParams struct {
	ID             uuid.UUID
	ReporterUserID *uuid.UUID
	TargetID       *uuid.UUID
	TargetKind     *string
	TargetName     *string
	TargetDeleted  bool
	Body           string
	LegacyText     *string
	RequestID      *string
}

func reportFromRow(r dbgen.Report) Report {
	return Report{
		ID:             goUUID(r.ID),
		ReporterUserID: uuidPtrFromPG(r.ReporterUserID),
		TargetID:       uuidPtrFromPG(r.TargetID),
		TargetKind:     textPtrFromPG(r.TargetKind),
		TargetName:     textPtrFromPG(r.TargetName),
		TargetDeleted:  r.TargetDeleted,
		Body:           r.Body,
		LegacyText:     textPtrFromPG(r.LegacyText),
		Status:         r.Status,
		AssigneeUserID: uuidPtrFromPG(r.AssigneeUserID),
		Revision:       r.Revision,
		RequestID:      textPtrFromPG(r.RequestID),
		CreatedAt:      timeFromPG(r.CreatedAt),
		UpdatedAt:      timeFromPG(r.UpdatedAt),
		ResolvedAt:     timePtrFromPG(r.ResolvedAt),
	}
}

func reportMatches(p ReportParams, existing Report) bool {
	return optionalUUIDEqual(p.ReporterUserID, existing.ReporterUserID) &&
		optionalUUIDEqual(p.TargetID, existing.TargetID) &&
		optionalStringEqual(p.TargetKind, existing.TargetKind) &&
		optionalStringEqual(p.TargetName, existing.TargetName) &&
		p.TargetDeleted == existing.TargetDeleted && p.Body == existing.Body &&
		optionalStringEqual(p.LegacyText, existing.LegacyText)
}

func (q *Queries) CreateReport(ctx context.Context, p ReportParams) (*Report, error) {
	if p.ID == uuid.Nil || p.Body == "" {
		return nil, ErrInvalidJob
	}
	r, err := q.g.CreateReport(ctx, dbgen.CreateReportParams{
		ID: pgUUID(p.ID), ReporterUserID: pgUUIDPtr(p.ReporterUserID), TargetID: pgUUIDPtr(p.TargetID),
		TargetKind: pgText(p.TargetKind), TargetName: pgText(p.TargetName), TargetDeleted: p.TargetDeleted,
		Body: p.Body, LegacyText: pgText(p.LegacyText), RequestID: pgText(p.RequestID),
	})
	if err != nil {
		return nil, err
	}
	v := reportFromRow(r)
	if p.RequestID != nil && !reportMatches(p, v) {
		return nil, ErrIdempotencyConflict
	}
	return &v, nil
}

func (q *Queries) GetReport(ctx context.Context, id uuid.UUID) (*Report, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetReport(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := reportFromRow(r)
	return &v, nil
}

func (q *Queries) ListReports(ctx context.Context, status string, before *time.Time, limit int) ([]Report, error) {
	if limit <= 0 {
		return nil, ErrInvalidJob
	}
	rs, err := q.g.ListReports(ctx, dbgen.ListReportsParams{Column1: status, Column2: pgTZ(before), Limit: int32(limit)})
	if err != nil {
		return nil, err
	}
	out := make([]Report, 0, len(rs))
	for _, r := range rs {
		out = append(out, reportFromRow(r))
	}
	return out, nil
}

func (q *Queries) UpdateReportIfRevision(ctx context.Context, id uuid.UUID, revision int64, status string, assigneeUserID *uuid.UUID) (*Report, bool, error) {
	if id == uuid.Nil || revision <= 0 {
		return nil, false, ErrInvalidJob
	}
	if status != "" && status != "open" && status != "resolved" && status != "dismissed" {
		return nil, false, ErrInvalidJob
	}
	r, err := q.g.UpdateReportIfRevision(ctx, dbgen.UpdateReportIfRevisionParams{
		ID: pgUUID(id), Column2: status, AssigneeUserID: pgUUIDPtr(assigneeUserID), Revision: revision,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	v := reportFromRow(r)
	return &v, true, nil
}

type ReportNote struct {
	ID           uuid.UUID
	ReportID     uuid.UUID
	AuthorUserID *uuid.UUID
	Body         string
	CreatedAt    time.Time
}

type ReportNoteParams struct {
	ID           uuid.UUID
	ReportID     uuid.UUID
	AuthorUserID *uuid.UUID
	Body         string
}

func reportNoteFromRow(r dbgen.ReportNote) ReportNote {
	return ReportNote{ID: goUUID(r.ID), ReportID: goUUID(r.ReportID), AuthorUserID: uuidPtrFromPG(r.AuthorUserID), Body: r.Body, CreatedAt: timeFromPG(r.CreatedAt)}
}

func (q *Queries) CreateReportNote(ctx context.Context, p ReportNoteParams) (*ReportNote, error) {
	if p.ID == uuid.Nil || p.ReportID == uuid.Nil || p.Body == "" {
		return nil, ErrInvalidJob
	}
	r, err := q.g.CreateReportNote(ctx, dbgen.CreateReportNoteParams{ID: pgUUID(p.ID), ReportID: pgUUID(p.ReportID), AuthorUserID: pgUUIDPtr(p.AuthorUserID), Body: p.Body})
	if err != nil {
		return nil, err
	}
	v := reportNoteFromRow(r)
	return &v, nil
}

func (q *Queries) ListReportNotes(ctx context.Context, reportID uuid.UUID, limit int) ([]ReportNote, error) {
	if reportID == uuid.Nil || limit <= 0 {
		return nil, ErrInvalidJob
	}
	rs, err := q.g.ListReportNotes(ctx, dbgen.ListReportNotesParams{ReportID: pgUUID(reportID), Limit: int32(limit)})
	if err != nil {
		return nil, err
	}
	out := make([]ReportNote, 0, len(rs))
	for _, r := range rs {
		out = append(out, reportNoteFromRow(r))
	}
	return out, nil
}

// ---- security incidents and audit events ---------------------------------

type SecurityIncident struct {
	ID             uuid.UUID
	AccountID      uuid.UUID
	ActorID        *uuid.UUID
	Reason         string
	PreviousState  *string
	NewState       string
	AuthGeneration int64
	Metadata       []byte
	CreatedAt      time.Time
}

type SecurityIncidentParams struct {
	ID             uuid.UUID
	AccountID      uuid.UUID
	ActorID        *uuid.UUID
	Reason         string
	PreviousState  *string
	NewState       string
	AuthGeneration int64
	Metadata       []byte
}

func securityIncidentFromRow(r dbgen.SecurityIncident) SecurityIncident {
	return SecurityIncident{ID: goUUID(r.ID), AccountID: goUUID(r.AccountID), ActorID: uuidPtrFromPG(r.ActorID), Reason: r.Reason, PreviousState: textPtrFromPG(r.PreviousState), NewState: r.NewState, AuthGeneration: r.AuthGeneration, Metadata: cloneBytes(r.Metadata), CreatedAt: timeFromPG(r.CreatedAt)}
}

func (q *Queries) CreateSecurityIncident(ctx context.Context, p SecurityIncidentParams) error {
	if p.ID == uuid.Nil || p.AccountID == uuid.Nil || p.Reason == "" || p.NewState == "" || p.AuthGeneration < 0 {
		return ErrInvalidJob
	}
	return q.g.CreateSecurityIncident(ctx, dbgen.CreateSecurityIncidentParams{ID: pgUUID(p.ID), AccountID: pgUUID(p.AccountID), ActorID: pgUUIDPtr(p.ActorID), Reason: p.Reason, PreviousState: pgText(p.PreviousState), NewState: p.NewState, AuthGeneration: p.AuthGeneration, Metadata: cloneJSON(p.Metadata)})
}

func (q *Queries) ListSecurityIncidentsForAccount(ctx context.Context, accountID uuid.UUID, limit int) ([]SecurityIncident, error) {
	if accountID == uuid.Nil || limit <= 0 {
		return nil, ErrInvalidJob
	}
	rs, err := q.g.ListSecurityIncidentsForAccount(ctx, dbgen.ListSecurityIncidentsForAccountParams{AccountID: pgUUID(accountID), Limit: int32(limit)})
	if err != nil {
		return nil, err
	}
	out := make([]SecurityIncident, 0, len(rs))
	for _, r := range rs {
		out = append(out, securityIncidentFromRow(r))
	}
	return out, nil
}

type AuditEvent struct {
	ID              uuid.UUID
	ActorID         *uuid.UUID
	TargetAccountID *uuid.UUID
	Action          string
	Reason          *string
	Outcome         *string
	Metadata        []byte
	CreatedAt       time.Time
}

type AuditEventParams struct {
	ID              uuid.UUID
	ActorID         *uuid.UUID
	TargetAccountID *uuid.UUID
	Action          string
	Reason          *string
	Outcome         *string
	Metadata        []byte
}

func auditEventFromRow(r dbgen.AuditEvent) AuditEvent {
	return AuditEvent{ID: goUUID(r.ID), ActorID: uuidPtrFromPG(r.ActorID), TargetAccountID: uuidPtrFromPG(r.TargetAccountID), Action: r.Action, Reason: textPtrFromPG(r.Reason), Outcome: textPtrFromPG(r.Outcome), Metadata: cloneBytes(r.Metadata), CreatedAt: timeFromPG(r.CreatedAt)}
}

func (q *Queries) CreateAuditEvent(ctx context.Context, p AuditEventParams) error {
	if p.ID == uuid.Nil || p.Action == "" {
		return ErrInvalidJob
	}
	return q.g.CreateAuditEvent(ctx, dbgen.CreateAuditEventParams{ID: pgUUID(p.ID), ActorID: pgUUIDPtr(p.ActorID), TargetAccountID: pgUUIDPtr(p.TargetAccountID), Action: p.Action, Reason: pgText(p.Reason), Outcome: pgText(p.Outcome), Metadata: cloneJSON(p.Metadata)})
}

func (q *Queries) ListAuditEvents(ctx context.Context, before *time.Time, limit int) ([]AuditEvent, error) {
	if limit <= 0 {
		return nil, ErrInvalidJob
	}
	rs, err := q.g.ListAuditEvents(ctx, dbgen.ListAuditEventsParams{Column1: pgTZ(before), Limit: int32(limit)})
	if err != nil {
		return nil, err
	}
	out := make([]AuditEvent, 0, len(rs))
	for _, r := range rs {
		out = append(out, auditEventFromRow(r))
	}
	return out, nil
}

// ---- device registrations and communication preferences ------------------

type DeviceRegistration struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	Provider    string
	DeviceToken string
	TokenHash   []byte
	Enabled     bool
	LastSeenAt  *time.Time
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type DeviceRegistrationParams struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	Provider    string
	DeviceToken string
	TokenHash   []byte
	Enabled     bool
}

func deviceRegistrationFromRow(r dbgen.DeviceRegistration) DeviceRegistration {
	return DeviceRegistration{ID: goUUID(r.ID), UserID: goUUID(r.UserID), Provider: r.Provider, DeviceToken: r.DeviceToken, TokenHash: cloneBytes(r.TokenHash), Enabled: r.Enabled, LastSeenAt: timePtrFromPG(r.LastSeenAt), CreatedAt: timeFromPG(r.CreatedAt), UpdatedAt: timeFromPG(r.UpdatedAt)}
}

func (q *Queries) UpsertDeviceRegistration(ctx context.Context, p DeviceRegistrationParams) (*DeviceRegistration, error) {
	if p.ID == uuid.Nil || p.UserID == uuid.Nil || p.Provider == "" || p.DeviceToken == "" {
		return nil, ErrInvalidJob
	}
	r, err := q.g.UpsertDeviceRegistration(ctx, dbgen.UpsertDeviceRegistrationParams{ID: pgUUID(p.ID), UserID: pgUUID(p.UserID), Provider: p.Provider, DeviceToken: p.DeviceToken, TokenHash: cloneBytes(p.TokenHash), Enabled: p.Enabled})
	if err != nil {
		return nil, err
	}
	v := deviceRegistrationFromRow(r)
	return &v, nil
}

func (q *Queries) ListDeviceRegistrations(ctx context.Context, userID uuid.UUID) ([]DeviceRegistration, error) {
	if userID == uuid.Nil {
		return nil, ErrInvalidJob
	}
	rs, err := q.g.ListDeviceRegistrations(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	out := make([]DeviceRegistration, 0, len(rs))
	for _, r := range rs {
		out = append(out, deviceRegistrationFromRow(r))
	}
	return out, nil
}

func (q *Queries) DisableDeviceRegistration(ctx context.Context, id, userID uuid.UUID) error {
	if id == uuid.Nil || userID == uuid.Nil {
		return ErrInvalidJob
	}
	return q.g.DisableDeviceRegistration(ctx, dbgen.DisableDeviceRegistrationParams{ID: pgUUID(id), UserID: pgUUID(userID)})
}

type CommunicationPreferences struct {
	UserID               uuid.UUID
	SecurityEmailEnabled bool
	GeneralEmailEnabled  bool
	PushEnabled          bool
	UpdatedAt            time.Time
}

func communicationPreferencesFromRow(r dbgen.CommunicationPreference) CommunicationPreferences {
	return CommunicationPreferences{UserID: goUUID(r.UserID), SecurityEmailEnabled: r.SecurityEmailEnabled, GeneralEmailEnabled: r.GeneralEmailEnabled, PushEnabled: r.PushEnabled, UpdatedAt: timeFromPG(r.UpdatedAt)}
}

func (q *Queries) GetCommunicationPreferences(ctx context.Context, userID uuid.UUID) (*CommunicationPreferences, error) {
	if userID == uuid.Nil {
		return nil, nil
	}
	r, err := q.g.GetCommunicationPreferences(ctx, pgUUID(userID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	v := communicationPreferencesFromRow(r)
	return &v, nil
}

func (q *Queries) UpsertCommunicationPreferences(ctx context.Context, userID uuid.UUID, securityEmailEnabled, generalEmailEnabled, pushEnabled bool) (*CommunicationPreferences, error) {
	if userID == uuid.Nil {
		return nil, ErrInvalidJob
	}
	r, err := q.g.UpsertCommunicationPreferences(ctx, dbgen.UpsertCommunicationPreferencesParams{UserID: pgUUID(userID), SecurityEmailEnabled: securityEmailEnabled, GeneralEmailEnabled: generalEmailEnabled, PushEnabled: pushEnabled})
	if err != nil {
		return nil, err
	}
	v := communicationPreferencesFromRow(r)
	return &v, nil
}
