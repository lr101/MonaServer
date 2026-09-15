package jobs

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

var (
	ErrInvalidEnqueueRequest = errors.New("invalid enqueue request")
	ErrInvalidPayload        = errors.New("invalid durable job payload")
	ErrIdempotencyConflict   = errors.New("idempotency key belongs to a different operation")
)

// EnqueueRequest describes one durable business command.  If ID is omitted,
// EnqueueDurableJob derives a stable UUID from Kind and IdempotencyKey, which
// lets a retried command read back the same row without issuing a second job.
// The supplied store is used directly; callers that need atomic business
// state plus enqueue must pass their transaction-backed *db.Queries facade.
type EnqueueRequest struct {
	ID             uuid.UUID
	Kind           string
	IdempotencyKey string
	Payload        []byte
	Priority       int32
	AvailableAt    time.Time
	MaxAttempts    int32
}

// DurableJobEnqueuer is the transaction-safe portion of the DB facade used by
// EnqueueDurableJob.  It intentionally includes a read so a duplicate command
// can compare its payload instead of silently accepting a changed operation.
type DurableJobEnqueuer interface {
	CreateDurableJob(context.Context, db.DurableJobParams) error
	GetDurableJob(context.Context, uuid.UUID) (*db.DurableJob, error)
}

// OutboxRequest is the caller-owned transaction form of an outbox event.
type OutboxRequest struct {
	ID             uuid.UUID
	Topic          string
	AggregateID    *uuid.UUID
	IdempotencyKey string
	Payload        []byte
	AvailableAt    time.Time
}

// OutboxEnqueuer is implemented by *db.Queries and transaction facades.
type OutboxEnqueuer interface {
	CreateOutboxEvent(context.Context, db.OutboxEventParams) error
}

// DeterministicJobID returns the stable UUID used when a command omits ID.
// SHA-256 is only an idempotency namespace; it is not used as a secret or
// credential and the resulting UUID is never exposed as an action token.
func DeterministicJobID(kind, idempotencyKey string) uuid.UUID {
	sum := sha256.Sum256([]byte(kind + "\x00" + idempotencyKey))
	var id uuid.UUID
	copy(id[:], sum[:16])
	id[6] = (id[6] & 0x0f) | 0x50
	id[8] = (id[8] & 0x3f) | 0x80
	return id
}

// EnqueueDurableJob inserts one command into the caller-supplied store.  It
// opens no transaction and never calls a provider.  The unique database key
// remains the final duplicate fence; the read-back comparison additionally
// catches a reused key with a changed operation when the deterministic ID is
// available.
func EnqueueDurableJob(ctx context.Context, store DurableJobEnqueuer, request EnqueueRequest) (uuid.UUID, error) {
	if store == nil || strings.TrimSpace(request.Kind) == "" || strings.TrimSpace(request.IdempotencyKey) == "" {
		return uuid.Nil, ErrInvalidEnqueueRequest
	}
	request.Kind = strings.TrimSpace(request.Kind)
	request.IdempotencyKey = strings.TrimSpace(request.IdempotencyKey)
	if request.ID == uuid.Nil {
		request.ID = DeterministicJobID(request.Kind, request.IdempotencyKey)
	}
	if request.AvailableAt.IsZero() {
		request.AvailableAt = time.Now()
	}
	if request.MaxAttempts <= 0 {
		request.MaxAttempts = 5
	}
	payload, err := normalizedJSON(request.Payload)
	if err != nil {
		return uuid.Nil, err
	}

	err = store.CreateDurableJob(ctx, db.DurableJobParams{
		ID:             request.ID,
		Kind:           request.Kind,
		IdempotencyKey: request.IdempotencyKey,
		Payload:        payload,
		Priority:       request.Priority,
		AvailableAt:    request.AvailableAt,
		MaxAttempts:    request.MaxAttempts,
	})
	if err != nil {
		return uuid.Nil, err
	}
	existing, err := store.GetDurableJob(ctx, request.ID)
	if err != nil {
		return uuid.Nil, err
	}
	if existing == nil {
		// A store may intentionally make writes asynchronous. The database
		// facade is synchronous, and its deterministic row is read back here;
		// returning the stable ID still lets the caller safely retry.
		return request.ID, nil
	}
	if existing.Kind != request.Kind || existing.IdempotencyKey != request.IdempotencyKey ||
		!bytes.Equal(existing.Payload, payload) || existing.Priority != request.Priority ||
		existing.MaxAttempts != request.MaxAttempts {
		return uuid.Nil, ErrIdempotencyConflict
	}
	return existing.ID, nil
}

// EnqueueOutboxEvent appends an idempotent outbox event using the supplied
// transaction-backed store.  The database unique idempotency key suppresses a
// duplicate event; this function deliberately does not begin a second
// transaction or publish the event synchronously.
func EnqueueOutboxEvent(ctx context.Context, store OutboxEnqueuer, request OutboxRequest) error {
	if store == nil || request.ID == uuid.Nil || strings.TrimSpace(request.Topic) == "" || strings.TrimSpace(request.IdempotencyKey) == "" || request.AvailableAt.IsZero() {
		return ErrInvalidEnqueueRequest
	}
	payload, err := normalizedJSON(request.Payload)
	if err != nil {
		return err
	}
	return store.CreateOutboxEvent(ctx, db.OutboxEventParams{
		ID:             request.ID,
		Topic:          strings.TrimSpace(request.Topic),
		AggregateID:    request.AggregateID,
		IdempotencyKey: strings.TrimSpace(request.IdempotencyKey),
		Payload:        payload,
		AvailableAt:    request.AvailableAt,
	})
}

func normalizedJSON(payload []byte) ([]byte, error) {
	if len(bytes.TrimSpace(payload)) == 0 {
		return []byte(`{}`), nil
	}
	if !json.Valid(payload) {
		return nil, ErrInvalidPayload
	}
	return append([]byte(nil), payload...), nil
}
