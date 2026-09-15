package service

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/jobs"
)

const (
	KindEmailDelivery    = "delivery.email"
	KindPushDelivery     = "delivery.push"
	KindRecoveryDelivery = "delivery.recovery"

	DeliveryStatusPending  = "pending"
	DeliveryStatusAccepted = "accepted"
	DeliveryStatusFailed   = "failed"
	DeliveryStatusUnknown  = "unknown_delivery"
)

// DeliveryJobPayload is intentionally only an attempt reference. Recipient
// addresses, push tokens, and login/recovery action tokens remain inside the
// encrypted delivery-attempt payload and never appear in durable job details.
type DeliveryJobPayload struct {
	AttemptID uuid.UUID `json:"attemptId"`
}

// DeliveryPayload is encrypted before persistence. Exactly one channel field
// must be populated by the dispatcher.
type DeliveryPayload struct {
	Email *EmailContent `json:"email,omitempty"`
	Push  *PushMessage  `json:"push,omitempty"`
}

type DeliveryAttemptStore interface {
	GetDeliveryAttempt(context.Context, uuid.UUID) (*db.DeliveryAttempt, error)
	UpdateDeliveryAttemptOutcome(context.Context, uuid.UUID, string, *string, *string, *string, *time.Time) error
	DisableDeviceRegistration(context.Context, uuid.UUID, uuid.UUID) error
}

// DeliveryDispatcher decrypts one attempt, invokes the channel adapter, and
// records a structured provider outcome. It does not own a transaction around
// provider I/O; the durable worker lease supplies crash/retry fencing.
type DeliveryDispatcher struct {
	attempts DeliveryAttemptStore
	keys     *DeliveryKeyRing
	email    *EmailDelivery
	push     *PushDelivery
	clock    func() time.Time
}

func NewDeliveryDispatcher(attempts DeliveryAttemptStore, keys *DeliveryKeyRing, email *EmailDelivery, push *PushDelivery, clock func() time.Time) *DeliveryDispatcher {
	if clock == nil {
		clock = time.Now
	}
	return &DeliveryDispatcher{attempts: attempts, keys: keys, email: email, push: push, clock: clock}
}

func RegisterDeliveryHandlers(worker *jobs.Worker, dispatcher *DeliveryDispatcher) error {
	if worker == nil || dispatcher == nil {
		return errors.New("worker and dispatcher are required")
	}
	if err := jobs.RegisterTyped(worker, KindEmailDelivery, dispatcher.handleEmail); err != nil {
		return err
	}
	if err := jobs.RegisterTyped(worker, KindRecoveryDelivery, dispatcher.handleEmail); err != nil {
		return err
	}
	return jobs.RegisterTyped(worker, KindPushDelivery, dispatcher.handlePush)
}

func (d *DeliveryDispatcher) handleEmail(ctx context.Context, job jobs.Job, payload DeliveryJobPayload) jobs.Result {
	return d.handle(ctx, job, payload, false)
}

func (d *DeliveryDispatcher) handlePush(ctx context.Context, job jobs.Job, payload DeliveryJobPayload) jobs.Result {
	return d.handle(ctx, job, payload, true)
}

func (d *DeliveryDispatcher) handle(ctx context.Context, _ jobs.Job, payload DeliveryJobPayload, push bool) jobs.Result {
	if d == nil || d.attempts == nil || payload.AttemptID == uuid.Nil {
		return jobs.Failed(errors.New("invalid delivery attempt"))
	}
	attempt, err := d.attempts.GetDeliveryAttempt(ctx, payload.AttemptID)
	if err != nil {
		return jobs.Retry(err)
	}
	if attempt == nil {
		return jobs.Failed(errors.New("delivery attempt not found"))
	}
	if attempt.Status == DeliveryStatusAccepted {
		return jobs.Success()
	}
	if d.keys == nil || attempt.DeliveryKeyID == nil || attempt.PayloadExpiresAt == nil {
		return d.recordFailure(ctx, attempt.ID, "delivery_key_unavailable", nil)
	}
	envelope := EncryptedDeliveryPayload{Ciphertext: append([]byte(nil), attempt.EncryptedPayload...), KeyID: *attempt.DeliveryKeyID, ExpiresAt: *attempt.PayloadExpiresAt}
	plaintext, err := d.keys.DecryptPayload(envelope, d.clock())
	if err != nil {
		code := "delivery_payload_invalid"
		if errors.Is(err, ErrDeliveryKeyUnavailable) {
			code = "delivery_key_unavailable"
		} else if errors.Is(err, ErrDeliveryPayloadExpired) {
			code = "delivery_payload_expired"
		}
		return d.recordFailure(ctx, attempt.ID, code, nil)
	}
	var message DeliveryPayload
	if err := json.Unmarshal(plaintext, &message); err != nil {
		return d.recordFailure(ctx, attempt.ID, "delivery_payload_invalid", nil)
	}
	var providerResult ProviderResult
	if push {
		if attempt.Channel != "push" || message.Push == nil {
			return d.recordFailure(ctx, attempt.ID, "delivery_channel_mismatch", nil)
		}
		if d.push == nil {
			providerResult = ProviderResult{Outcome: ProviderDisabled, ErrorCode: "provider_disabled"}
		} else {
			providerResult = d.push.Send(ctx, *message.Push)
		}
	} else {
		if attempt.Channel == "push" || message.Email == nil {
			return d.recordFailure(ctx, attempt.ID, "delivery_channel_mismatch", nil)
		}
		if d.email == nil {
			providerResult = ProviderResult{Outcome: ProviderDisabled, ErrorCode: "provider_disabled"}
		} else {
			providerResult = d.email.Send(ctx, *message.Email)
		}
	}
	return d.recordProviderResult(ctx, attempt, providerResult)
}

func (d *DeliveryDispatcher) recordProviderResult(ctx context.Context, attempt *db.DeliveryAttempt, result ProviderResult) jobs.Result {
	status := DeliveryStatusFailed
	if result.Outcome == ProviderAccepted {
		status = DeliveryStatusAccepted
	} else if result.Outcome == ProviderTransientFailure || result.Outcome == ProviderUnknownDelivery {
		status = DeliveryStatusUnknown
	}
	providerReference := optionalString(result.Reference)
	providerOutcome := optionalString(string(result.Outcome))
	errorCode := optionalString(result.SafeErrorCode())
	var acceptedAt *time.Time
	if result.Outcome == ProviderAccepted {
		now := d.clock()
		acceptedAt = &now
	}
	if err := d.attempts.UpdateDeliveryAttemptOutcome(ctx, attempt.ID, status, providerReference, providerOutcome, errorCode, acceptedAt); err != nil {
		return jobs.Retry(err)
	}
	if IsInvalidDeviceToken(result) && attempt.DeviceID != nil && attempt.AccountID != nil {
		if err := d.attempts.DisableDeviceRegistration(ctx, *attempt.DeviceID, *attempt.AccountID); err != nil {
			return jobs.Retry(err)
		}
	}
	jobResult := result.JobResult()
	if result.Outcome == ProviderTransientFailure || result.Outcome == ProviderUnknownDelivery {
		jobResult.Retry = true
	}
	return jobResult
}

func (d *DeliveryDispatcher) recordFailure(ctx context.Context, attemptID uuid.UUID, code string, err error) jobs.Result {
	if d == nil || d.attempts == nil {
		return jobs.Failed(err)
	}
	code = safeProviderCode(code)
	if code == "" {
		code = "delivery_failed"
	}
	if updateErr := d.attempts.UpdateDeliveryAttemptOutcome(ctx, attemptID, DeliveryStatusFailed, nil, optionalString("failed"), optionalString(code), nil); updateErr != nil {
		return jobs.Retry(updateErr)
	}
	return jobs.Result{Status: jobs.StatusFailed, Outcome: jobs.OutcomeFailed, ErrorCode: code, Err: err}
}

func optionalString(value string) *string {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return &value
}
