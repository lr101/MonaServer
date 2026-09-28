package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

// RecoveryReason identifies the security event that caused a recovery message
// to be queued. The value is persisted as structured job metadata and is never
// taken from a public email request.
type RecoveryReason string

const (
	RecoveryReasonCompromise     RecoveryReason = "compromise"
	RecoveryReasonManualRecovery RecoveryReason = "manual_recovery"
	RecoveryReasonRecoveryResend RecoveryReason = "recovery_resend"
)

// RecoveryEnqueueRequest is the complete input for one recovery delivery
// attempt. VerifiedEmail is the canonical, already-verified account address;
// callers cannot use this port to supply an arbitrary destination.
type RecoveryEnqueueRequest struct {
	AccountID      uuid.UUID
	ActorID        *uuid.UUID
	AuthGeneration int64
	Reason         RecoveryReason
	VerifiedEmail  *string
}

// RecoveryEnqueueStatus describes whether the account has a trusted address
// that can receive a recovery attempt. A missing address is a successful
// containment result with manual recovery required, rather than a fake queued
// delivery.
type RecoveryEnqueueStatus string

const (
	RecoveryEnqueueQueued                 RecoveryEnqueueStatus = "queued"
	RecoveryEnqueueManualRecoveryRequired RecoveryEnqueueStatus = "manual_recovery_required"
)

// RecoveryEnqueueResult is returned after the recovery attempt row has been
// recorded in the caller's transaction.
type RecoveryEnqueueResult struct {
	AttemptID *uuid.UUID
	Status    RecoveryEnqueueStatus
}

// RecoveryEnqueuer appends a recovery delivery attempt to an existing caller
// transaction. The tx argument must be the *db.Queries value supplied by
// db.Queries.InTx; implementations must use it directly and must not begin a
// second transaction or use the underlying pool. This keeps containment,
// generation changes, audit records, and the enqueue atomic.
type RecoveryEnqueuer interface {
	EnqueueRecovery(context.Context, *db.Queries, RecoveryEnqueueRequest) (RecoveryEnqueueResult, error)
}
