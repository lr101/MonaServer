package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/jobs"
)

func testKeyRing(t *testing.T) *DeliveryKeyRing {
	t.Helper()
	ring, err := NewDeliveryKeyRing(map[string][]byte{
		"key-old": bytes.Repeat([]byte{0x11}, 32),
	}, "key-old", 15*time.Minute)
	if err != nil {
		t.Fatalf("new key ring: %v", err)
	}
	return ring
}

func TestDeliveryPayloadIsEncryptedAndSurvivesKeyRotation(t *testing.T) {
	now := time.Unix(100, 0)
	ring := testKeyRing(t)
	plaintext := []byte("opaque-login-token")
	envelope, err := ring.EncryptPayload(plaintext, now, time.Minute)
	if err != nil {
		t.Fatalf("encrypt payload: %v", err)
	}
	if envelope.KeyID != "key-old" || !envelope.ExpiresAt.Equal(now.Add(time.Minute)) {
		t.Fatalf("envelope metadata = %#v", envelope)
	}
	if bytes.Contains(envelope.Ciphertext, plaintext) {
		t.Fatal("ciphertext contains plaintext token")
	}
	decoded, err := ring.DecryptPayload(envelope, now.Add(30*time.Second))
	if err != nil || !bytes.Equal(decoded, plaintext) {
		t.Fatalf("decrypt = %q, err=%v", decoded, err)
	}
	if err := ring.AddKey("key-new", bytes.Repeat([]byte{0x22}, 32)); err != nil {
		t.Fatalf("add rotated key: %v", err)
	}
	if err := ring.SetActiveKey("key-new"); err != nil {
		t.Fatalf("set active key: %v", err)
	}
	rotated, err := ring.EncryptPayload([]byte("new-token"), now, time.Minute)
	if err != nil || rotated.KeyID != "key-new" {
		t.Fatalf("rotated envelope = %#v, err=%v", rotated, err)
	}
	if _, err := ring.DecryptPayload(envelope, now.Add(2*time.Minute)); !errors.Is(err, ErrDeliveryPayloadExpired) {
		t.Fatalf("expired payload error = %v, want expiry", err)
	}
	if err := ring.RemoveKey("key-old"); err != nil {
		t.Fatalf("remove old key: %v", err)
	}
	if _, err := ring.DecryptPayload(envelope, now.Add(30*time.Second)); !errors.Is(err, ErrDeliveryKeyUnavailable) {
		t.Fatalf("missing key error = %v, want unavailable", err)
	}
}

func TestDeliveryKeyRingFailsClosedForMissingOrInvalidKeys(t *testing.T) {
	if _, err := NewDeliveryKeyRing(map[string][]byte{}, "missing", time.Minute); !errors.Is(err, ErrDeliveryKeyUnavailable) {
		t.Fatalf("missing active key error = %v, want unavailable", err)
	}
	ring := testKeyRing(t)
	if _, err := ring.EncryptPayload(nil, time.Unix(100, 0), time.Minute); !errors.Is(err, ErrInvalidDeliveryPayload) {
		t.Fatalf("empty payload error = %v, want invalid payload", err)
	}
	if _, err := ring.EncryptPayload([]byte("x"), time.Unix(100, 0), 2*time.Hour); !errors.Is(err, ErrDeliveryTTLTooLong) {
		t.Fatalf("long TTL error = %v, want TTL error", err)
	}
	envelope := EncryptedDeliveryPayload{KeyID: "unknown", Ciphertext: []byte("cipher"), ExpiresAt: time.Unix(200, 0)}
	if _, err := ring.DecryptPayload(envelope, time.Unix(100, 0)); !errors.Is(err, ErrDeliveryKeyUnavailable) {
		t.Fatalf("unknown key error = %v, want unavailable", err)
	}
}

func TestProviderErrorRedactionNeverReturnsSecretText(t *testing.T) {
	secret := "opaque-token-value"
	redacted := RedactProviderError(errors.New("smtp failed token=" + secret + " password=hunter2"))
	if redacted == "" || strings.Contains(redacted, secret) || strings.Contains(redacted, "hunter2") {
		t.Fatalf("redacted provider error = %q, contains secret", redacted)
	}
}

func TestRenderEmailSanitizesHTMLAndEnforcesBounds(t *testing.T) {
	rendered, err := RenderEmail(EmailContent{
		To:      "person@example.test",
		Subject: "Notice",
		Body:    "Plain text body",
		HTML:    `<p onclick="steal()">Hello <a href="javascript:alert(1)">there</a></p><script>steal()</script><img src="https://tracker.example/pixel">`,
	})
	if err != nil {
		t.Fatalf("render email: %v", err)
	}
	for _, forbidden := range []string{"onclick", "javascript:", "<script", "tracker.example", "<img"} {
		if strings.Contains(strings.ToLower(rendered.HTML), forbidden) {
			t.Fatalf("rendered HTML contains %q: %s", forbidden, rendered.HTML)
		}
	}
	if !strings.Contains(rendered.HTML, "Hello") || rendered.Text != "Plain text body" {
		t.Fatalf("rendered email = %#v", rendered)
	}
	if _, err := RenderEmail(EmailContent{To: "person@example.test", Subject: "", Body: "body"}); !errors.Is(err, ErrInvalidEmailContent) {
		t.Fatalf("empty subject error = %v, want invalid content", err)
	}
	if _, err := RenderEmail(EmailContent{To: "person@example.test", Subject: "subject", Body: strings.Repeat("x", maxEmailTextBytes+1)}); !errors.Is(err, ErrEmailContentTooLarge) {
		t.Fatalf("large body error = %v, want too large", err)
	}
}

type fakeEmailProvider struct {
	mu       sync.Mutex
	result   ProviderResult
	received []RenderedEmail
}

func (f *fakeEmailProvider) SendEmail(_ context.Context, message RenderedEmail) ProviderResult {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.received = append(f.received, message)
	return f.result
}

type fakePushProvider struct {
	mu       sync.Mutex
	result   ProviderResult
	received []PushMessage
}

func (f *fakePushProvider) SendPush(_ context.Context, message PushMessage) ProviderResult {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.received = append(f.received, message)
	return f.result
}

func TestEmailDeliveryUsesExplicitTestRecipientAndStructuredProviderOutcome(t *testing.T) {
	provider := &fakeEmailProvider{result: ProviderResult{Outcome: ProviderAccepted, Reference: "smtp-1"}}
	delivery := NewEmailDelivery(provider)
	result := delivery.SendTest(context.Background(), "test@example.test", EmailContent{Subject: "Test", Body: "Hello"})
	if result.Outcome != ProviderAccepted || result.Reference != "smtp-1" {
		t.Fatalf("provider result = %#v", result)
	}
	if len(provider.received) != 1 || provider.received[0].To != "test@example.test" {
		t.Fatalf("received = %#v, want explicit test recipient", provider.received)
	}
	missing := delivery.SendTest(context.Background(), "", EmailContent{Subject: "Test", Body: "Hello"})
	if missing.Outcome != ProviderPermanentFailure || missing.ErrorCode != "test_recipient_required" {
		t.Fatalf("missing recipient result = %#v", missing)
	}
}

func TestProviderOutcomesMapToRetryFailureDisabledAndUnknownResults(t *testing.T) {
	cases := []struct {
		name        string
		provider    ProviderResult
		wantRetry   bool
		wantStatus  string
		wantOutcome jobs.Outcome
	}{
		{name: "accepted", provider: ProviderResult{Outcome: ProviderAccepted}, wantStatus: jobs.StatusCompleted, wantOutcome: jobs.OutcomeProviderAccepted},
		{name: "transient", provider: ProviderResult{Outcome: ProviderTransientFailure, ErrorCode: "timeout"}, wantRetry: true, wantOutcome: jobs.OutcomeUnknownDelivery},
		{name: "permanent", provider: ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "rejected"}, wantStatus: jobs.StatusFailed, wantOutcome: jobs.OutcomeFailed},
		{name: "disabled", provider: ProviderResult{Outcome: ProviderDisabled}, wantStatus: jobs.StatusFailed, wantOutcome: jobs.OutcomeFailed},
		{name: "unknown", provider: ProviderResult{Outcome: ProviderUnknownDelivery}, wantRetry: true, wantOutcome: jobs.OutcomeUnknownDelivery},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := tc.provider.JobResult()
			if got.Retry != tc.wantRetry || got.Status != tc.wantStatus || got.Outcome != tc.wantOutcome {
				t.Fatalf("job result = %#v, want retry=%v status=%q outcome=%q", got, tc.wantRetry, tc.wantStatus, tc.wantOutcome)
			}
		})
	}
}

func TestClassifyFCMUnknownErrorIsRetryableUncertain(t *testing.T) {
	result := classifyFCMError(context.Background(), errors.New("firebase changed its response envelope"))
	if result.Outcome != ProviderUnknownDelivery {
		t.Fatalf("unknown FCM outcome = %q, want unknown delivery", result.Outcome)
	}
	if result.ErrorCode != "provider_unknown" {
		t.Fatalf("unknown FCM error code = %q, want bounded provider_unknown", result.ErrorCode)
	}
	if !result.JobResult().Retry || result.JobResult().Outcome != jobs.OutcomeUnknownDelivery {
		t.Fatalf("unknown FCM job result = %#v, want retryable unknown delivery", result.JobResult())
	}
}

func TestClassifyFCMKnownPermanentRequestErrorRemainsTerminal(t *testing.T) {
	result := classifyFCMError(context.Background(), errors.New("firebase invalid argument: malformed message"))
	if result.Outcome != ProviderPermanentFailure || result.ErrorCode != "provider_rejected" {
		t.Fatalf("known permanent FCM result = %#v, want terminal provider rejection", result)
	}
}

func TestPushEligibilitySeparatesPreferenceFromRegisteredDevices(t *testing.T) {
	userID := uuid.New()
	devices := []db.DeviceRegistration{
		{ID: uuid.New(), UserID: userID, Provider: "firebase", DeviceToken: "one", Enabled: true},
		{ID: uuid.New(), UserID: userID, Provider: "firebase", DeviceToken: "two", Enabled: false},
	}
	prefs := &db.CommunicationPreferences{UserID: userID, PushEnabled: true}
	eligible := EligiblePushDevices(prefs, devices)
	if len(eligible) != 1 || eligible[0].DeviceToken != "one" {
		t.Fatalf("eligible devices = %#v, want enabled device only", eligible)
	}
	prefs.PushEnabled = false
	if got := EligiblePushDevices(prefs, devices); len(got) != 0 {
		t.Fatalf("opted-out devices = %#v, want none", got)
	}
	if !EligibleForEmail(nil, EmailCategoryGeneral) || !EligibleForEmail(nil, EmailCategorySecurity) {
		t.Fatal("missing preferences should use enabled defaults")
	}
	if !EligibleForEmail(&db.CommunicationPreferences{SecurityEmailEnabled: true, GeneralEmailEnabled: false}, EmailCategorySecurity) {
		t.Fatal("general opt-out must not disable security mail")
	}
}

type fakeAttemptStore struct {
	mu       sync.Mutex
	attempts map[uuid.UUID]*db.DeliveryAttempt
	outcomes []attemptOutcome
	clears   []attemptClear
	disabled []struct{ id, userID uuid.UUID }
}

type attemptOutcome struct {
	id                uuid.UUID
	status            string
	providerReference *string
	providerOutcome   *string
	errorCode         *string
	acceptedAt        *time.Time
}

type attemptClear struct {
	id      uuid.UUID
	now     time.Time
	cleared bool
}

func (f *fakeAttemptStore) GetDeliveryAttempt(_ context.Context, id uuid.UUID) (*db.DeliveryAttempt, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	attempt := f.attempts[id]
	if attempt == nil {
		return nil, nil
	}
	copy := *attempt
	copy.EncryptedPayload = append([]byte(nil), attempt.EncryptedPayload...)
	return &copy, nil
}

func (f *fakeAttemptStore) UpdateDeliveryAttemptOutcome(_ context.Context, id uuid.UUID, status string, providerReference, providerOutcome, errorCode *string, acceptedAt *time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.outcomes = append(f.outcomes, attemptOutcome{id: id, status: status, providerReference: providerReference, providerOutcome: providerOutcome, errorCode: errorCode, acceptedAt: acceptedAt})
	if attempt := f.attempts[id]; attempt != nil {
		attempt.Status = status
		attempt.ProviderReference = providerReference
		attempt.ProviderOutcome = providerOutcome
		attempt.ErrorCode = errorCode
		attempt.AcceptedAt = acceptedAt
	}
	return nil
}

func (f *fakeAttemptStore) ClearDeliveryAttemptPayload(_ context.Context, id uuid.UUID, now time.Time) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	attempt := f.attempts[id]
	if attempt == nil {
		f.clears = append(f.clears, attemptClear{id: id, now: now})
		return false, nil
	}
	clear := len(attempt.EncryptedPayload) > 0 || attempt.DeliveryKeyID != nil
	if clear && (attempt.Status == DeliveryStatusAccepted || attempt.Status == DeliveryStatusFailed || (attempt.PayloadExpiresAt != nil && !now.Before(*attempt.PayloadExpiresAt))) {
		attempt.EncryptedPayload = nil
		attempt.DeliveryKeyID = nil
		clear = true
	} else {
		clear = false
	}
	f.clears = append(f.clears, attemptClear{id: id, now: now, cleared: clear})
	return clear, nil
}

func (f *fakeAttemptStore) DisableDeviceRegistration(_ context.Context, id, userID uuid.UUID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.disabled = append(f.disabled, struct{ id, userID uuid.UUID }{id: id, userID: userID})
	return nil
}

func TestDeliveryDispatcherPersistsAcceptedEmailOutcomeWithoutExposingPayload(t *testing.T) {
	ring := testKeyRing(t)
	provider := &fakeEmailProvider{result: ProviderResult{Outcome: ProviderAccepted, Reference: "smtp-accepted"}}
	store := &fakeAttemptStore{attempts: make(map[uuid.UUID]*db.DeliveryAttempt)}
	dispatcher := NewDeliveryDispatcher(store, ring, NewEmailDelivery(provider), nil, func() time.Time { return time.Unix(100, 0) })
	attemptID := uuid.New()
	accountID := uuid.New()
	payload, err := json.Marshal(DeliveryPayload{Email: &EmailContent{To: "person@example.test", Subject: "Notice", Body: "Hello"}})
	if err != nil {
		t.Fatalf("marshal delivery payload: %v", err)
	}
	envelope, err := ring.EncryptPayload(payload, time.Unix(100, 0), time.Minute)
	if err != nil {
		t.Fatalf("encrypt delivery payload: %v", err)
	}
	keyID := envelope.KeyID
	expiresAt := envelope.ExpiresAt
	store.attempts[attemptID] = &db.DeliveryAttempt{ID: attemptID, Channel: "email", AccountID: &accountID, EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &keyID, PayloadExpiresAt: &expiresAt}
	job := deliveryJob(attemptID)
	w := jobs.NewWorker(&fakeJobStore{}, jobs.Config{WorkerID: "worker-a", Clock: time.Now})
	if err := RegisterDeliveryHandlers(w, dispatcher); err != nil {
		t.Fatalf("register delivery handlers: %v", err)
	}
	if err := w.Process(context.Background(), job); err != nil {
		t.Fatalf("process delivery job: %v", err)
	}
	if len(store.outcomes) != 1 || store.outcomes[0].status != DeliveryStatusAccepted || store.outcomes[0].providerOutcome == nil || *store.outcomes[0].providerOutcome != string(ProviderAccepted) {
		t.Fatalf("delivery outcomes = %#v, want accepted", store.outcomes)
	}
	if len(store.clears) != 1 || !store.clears[0].cleared {
		t.Fatalf("delivery clears = %#v, want accepted payload clear", store.clears)
	}
	if store.attempts[attemptID].EncryptedPayload != nil || store.attempts[attemptID].DeliveryKeyID != nil {
		t.Fatal("accepted delivery payload was retained")
	}
	if len(provider.received) != 1 || provider.received[0].To != "person@example.test" {
		t.Fatalf("provider messages = %#v", provider.received)
	}
}

func TestDeliveryDispatcherRetainsUnexpiredRetryPayload(t *testing.T) {
	now := time.Unix(100, 0)
	ring := testKeyRing(t)
	provider := &fakeEmailProvider{result: ProviderResult{Outcome: ProviderUnknownDelivery, ErrorCode: "provider_unknown"}}
	store := &fakeAttemptStore{attempts: make(map[uuid.UUID]*db.DeliveryAttempt)}
	dispatcher := NewDeliveryDispatcher(store, ring, NewEmailDelivery(provider), nil, func() time.Time { return now })
	attemptID := uuid.New()
	payload, err := json.Marshal(DeliveryPayload{Email: &EmailContent{To: "person@example.test", Subject: "Notice", Body: "Hello"}})
	if err != nil {
		t.Fatalf("marshal delivery payload: %v", err)
	}
	envelope, err := ring.EncryptPayload(payload, now, time.Minute)
	if err != nil {
		t.Fatalf("encrypt delivery payload: %v", err)
	}
	keyID := envelope.KeyID
	expiresAt := envelope.ExpiresAt
	store.attempts[attemptID] = &db.DeliveryAttempt{ID: attemptID, Channel: "email", EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &keyID, PayloadExpiresAt: &expiresAt}
	w := jobs.NewWorker(&fakeJobStore{}, jobs.Config{WorkerID: "worker-a", Clock: time.Now})
	if err := RegisterDeliveryHandlers(w, dispatcher); err != nil {
		t.Fatalf("register delivery handlers: %v", err)
	}
	if err := w.Process(context.Background(), deliveryJob(attemptID)); err != nil {
		t.Fatalf("process retryable delivery: %v", err)
	}
	if len(store.outcomes) != 1 || store.outcomes[0].status != DeliveryStatusUnknown {
		t.Fatalf("delivery outcomes = %#v, want unknown delivery", store.outcomes)
	}
	if len(store.clears) != 1 || store.clears[0].cleared {
		t.Fatalf("delivery clears = %#v, want retained retry payload", store.clears)
	}
	if len(store.attempts[attemptID].EncryptedPayload) == 0 || store.attempts[attemptID].DeliveryKeyID == nil {
		t.Fatal("unexpired retry payload was cleared")
	}
}

func TestDeliveryDispatcherClearsExpiredPayloadWithoutProviderCall(t *testing.T) {
	now := time.Unix(100, 0)
	ring := testKeyRing(t)
	provider := &fakeEmailProvider{result: ProviderResult{Outcome: ProviderAccepted}}
	store := &fakeAttemptStore{attempts: make(map[uuid.UUID]*db.DeliveryAttempt)}
	dispatcher := NewDeliveryDispatcher(store, ring, NewEmailDelivery(provider), nil, func() time.Time { return now })
	attemptID := uuid.New()
	payload, err := json.Marshal(DeliveryPayload{Email: &EmailContent{To: "person@example.test", Subject: "Notice", Body: "Hello"}})
	if err != nil {
		t.Fatalf("marshal delivery payload: %v", err)
	}
	envelope, err := ring.EncryptPayload(payload, now.Add(-2*time.Minute), time.Minute)
	if err != nil {
		t.Fatalf("encrypt delivery payload: %v", err)
	}
	keyID := envelope.KeyID
	expiresAt := envelope.ExpiresAt
	store.attempts[attemptID] = &db.DeliveryAttempt{ID: attemptID, Channel: "email", EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &keyID, PayloadExpiresAt: &expiresAt}
	w := jobs.NewWorker(&fakeJobStore{}, jobs.Config{WorkerID: "worker-a", Clock: time.Now})
	if err := RegisterDeliveryHandlers(w, dispatcher); err != nil {
		t.Fatalf("register delivery handlers: %v", err)
	}
	if err := w.Process(context.Background(), deliveryJob(attemptID)); err != nil {
		t.Fatalf("process expired delivery: %v", err)
	}
	if len(provider.received) != 0 {
		t.Fatalf("expired payload reached provider: %#v", provider.received)
	}
	if len(store.outcomes) != 1 || store.outcomes[0].status != DeliveryStatusFailed {
		t.Fatalf("delivery outcomes = %#v, want terminal failure", store.outcomes)
	}
	if len(store.clears) != 1 || !store.clears[0].cleared {
		t.Fatalf("delivery clears = %#v, want expired payload clear", store.clears)
	}
	if store.attempts[attemptID].EncryptedPayload != nil || store.attempts[attemptID].DeliveryKeyID != nil {
		t.Fatal("expired delivery payload was retained")
	}
}

func TestDeliveryDispatcherRemovesOnlyPermanentlyInvalidPushTokens(t *testing.T) {
	ring := testKeyRing(t)
	provider := &fakePushProvider{result: ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "invalid_registration_token"}}
	store := &fakeAttemptStore{attempts: make(map[uuid.UUID]*db.DeliveryAttempt)}
	dispatcher := NewDeliveryDispatcher(store, ring, nil, NewPushDelivery(provider), time.Now)
	attemptID := uuid.New()
	accountID := uuid.New()
	deviceID := uuid.New()
	payload, _ := json.Marshal(DeliveryPayload{Push: &PushMessage{Token: "token", Title: "Title", Body: "Body"}})
	envelope, _ := ring.EncryptPayload(payload, time.Now(), time.Minute)
	keyID := envelope.KeyID
	expiresAt := envelope.ExpiresAt
	store.attempts[attemptID] = &db.DeliveryAttempt{ID: attemptID, Channel: "push", AccountID: &accountID, DeviceID: &deviceID, EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &keyID, PayloadExpiresAt: &expiresAt}
	w := jobs.NewWorker(&fakeJobStore{}, jobs.Config{WorkerID: "worker-a", Clock: time.Now})
	if err := RegisterDeliveryHandlers(w, dispatcher); err != nil {
		t.Fatalf("register delivery handlers: %v", err)
	}
	if err := w.Process(context.Background(), deliveryJobOf(KindPushDelivery, attemptID)); err != nil {
		t.Fatalf("process permanent push: %v", err)
	}
	if len(store.disabled) != 1 || store.disabled[0].id != deviceID || store.disabled[0].userID != accountID {
		t.Fatalf("disabled devices = %#v, want permanent invalid token removal", store.disabled)
	}
	provider.result = ProviderResult{Outcome: ProviderDisabled}
	secondID := uuid.New()
	store.attempts[secondID] = store.attempts[attemptID]
	store.attempts[secondID].ID = secondID
	if err := w.Process(context.Background(), deliveryJobOf(KindPushDelivery, secondID)); err != nil {
		t.Fatalf("process disabled push: %v", err)
	}
	if len(store.disabled) != 1 {
		t.Fatalf("disabled provider removed a token: %#v", store.disabled)
	}
}

func TestDeliveryDispatcherFailsClosedWhenPayloadKeyIsUnavailable(t *testing.T) {
	ring := testKeyRing(t)
	other, err := NewDeliveryKeyRing(map[string][]byte{"other": bytes.Repeat([]byte{0x44}, 32)}, "other", time.Minute)
	if err != nil {
		t.Fatalf("other key ring: %v", err)
	}
	payload, _ := json.Marshal(DeliveryPayload{Email: &EmailContent{To: "person@example.test", Subject: "Notice", Body: "Hello"}})
	envelope, _ := ring.EncryptPayload(payload, time.Unix(100, 0), time.Minute)
	keyID := envelope.KeyID
	expiresAt := envelope.ExpiresAt
	attemptID := uuid.New()
	store := &fakeAttemptStore{attempts: map[uuid.UUID]*db.DeliveryAttempt{attemptID: {ID: attemptID, Channel: "email", EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &keyID, PayloadExpiresAt: &expiresAt}}}
	dispatcher := NewDeliveryDispatcher(store, other, nil, nil, func() time.Time { return time.Unix(100, 0) })
	w := jobs.NewWorker(&fakeJobStore{}, jobs.Config{WorkerID: "worker-a", Clock: time.Now})
	if err := RegisterDeliveryHandlers(w, dispatcher); err != nil {
		t.Fatalf("register delivery handlers: %v", err)
	}
	if err := w.Process(context.Background(), deliveryJob(attemptID)); err != nil {
		t.Fatalf("process missing key: %v", err)
	}
	if len(store.outcomes) != 1 || store.outcomes[0].status != DeliveryStatusFailed || store.outcomes[0].errorCode == nil || *store.outcomes[0].errorCode != "delivery_key_unavailable" {
		t.Fatalf("missing-key outcomes = %#v, want failed and redacted", store.outcomes)
	}
}

func deliveryJob(attemptID uuid.UUID) db.DurableJob {
	return deliveryJobOf(KindEmailDelivery, attemptID)
}

func deliveryJobOf(kind string, attemptID uuid.UUID) db.DurableJob {
	raw, _ := json.Marshal(DeliveryJobPayload{AttemptID: attemptID})
	return db.DurableJob{ID: uuid.New(), Kind: kind, Payload: raw, AttemptCount: 1, MaxAttempts: 2, LeaseOwner: deliveryStringPtr("worker-a"), LeaseToken: uuid.New()}
}
