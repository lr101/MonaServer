package service

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/jobs"
	"github.com/lrprojects/monaserver/internal/token"
)

type recordingLoginLinkEnqueuer struct {
	requests []LoginLinkDeliveryRequest
}

func (e *recordingLoginLinkEnqueuer) EnqueueLoginLink(_ context.Context, _ *db.Queries, request LoginLinkDeliveryRequest) (*uuid.UUID, error) {
	e.requests = append(e.requests, request)
	id := uuid.New()
	return &id, nil
}

type failingLoginLinkEnqueuer struct{}

func (failingLoginLinkEnqueuer) EnqueueLoginLink(context.Context, *db.Queries, LoginLinkDeliveryRequest) (*uuid.UUID, error) {
	return nil, errors.New("delivery unavailable")
}

type recordingFailingLoginLinkEnqueuer struct {
	request LoginLinkDeliveryRequest
}

func (e *recordingFailingLoginLinkEnqueuer) EnqueueLoginLink(_ context.Context, _ *db.Queries, request LoginLinkDeliveryRequest) (*uuid.UUID, error) {
	e.request = request
	return nil, errors.New("delivery unavailable")
}

type partialLoginLinkEnqueuer struct {
	request   LoginLinkDeliveryRequest
	attemptID uuid.UUID
	jobID     uuid.UUID
}

func (e *partialLoginLinkEnqueuer) EnqueueLoginLink(ctx context.Context, tx *db.Queries, request LoginLinkDeliveryRequest) (*uuid.UUID, error) {
	e.request = request
	e.attemptID = uuid.New()
	keyID := "partial-key"
	expiresAt := request.ExpiresAt
	if err := tx.CreateDeliveryAttempt(ctx, db.DeliveryAttemptParams{
		ID: e.attemptID, Channel: "email", AccountID: &request.AccountID, Status: DeliveryStatusPending,
		AttemptNumber: 0, EncryptedPayload: []byte("partial-ciphertext"), DeliveryKeyID: &keyID,
		PayloadExpiresAt: &expiresAt,
	}); err != nil {
		return nil, err
	}
	payload, err := json.Marshal(DeliveryJobPayload{AttemptID: e.attemptID})
	if err != nil {
		return nil, err
	}
	e.jobID = uuid.New()
	if err := tx.CreateDurableJob(ctx, db.DurableJobParams{
		ID: e.jobID, Kind: KindEmailDelivery, IdempotencyKey: "partial-login-link:" + request.ActionTokenID.String(),
		Payload: payload, Priority: 100, AvailableAt: request.ExpiresAt.Add(-15 * time.Minute), MaxAttempts: 5,
	}); err != nil {
		return nil, err
	}
	return nil, errors.New("delivery unavailable after durable writes")
}

func TestEmailLoginRequestUsesCanonicalOwnedEmailAndReturnsGenericAcceptance(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()

	email := " Alice.Example@Example.COM "
	pair, err := auth.Signup(ctx, "email_link_owner", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}

	enqueuer := &recordingLoginLinkEnqueuer{}
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{
		HMACKeyID: "test-v1",
		HMACKey:   uniqueQuotaKey(),
	}, enqueuer)
	result, err := login.RequestEmailLink(ctx, EmailLoginRequest{
		Email:    "  alice.example@example.com ",
		ClientIP: "192.0.2.10",
	})
	if err != nil {
		t.Fatalf("request email link: %v", err)
	}
	if !result.Accepted || !result.Issued {
		t.Fatalf("request result = %#v, want accepted issued result", result)
	}
	if result.CanonicalEmail != "alice.example@example.com" {
		t.Fatalf("canonical email = %q, want alice.example@example.com", result.CanonicalEmail)
	}
	if result.Username != "email_link_owner" {
		t.Fatalf("username = %q, want authoritative username", result.Username)
	}
	if result.Action == nil || result.Action.Token == "" {
		t.Fatal("request did not return an opaque action token to the issuance caller")
	}
	if len(enqueuer.requests) != 1 {
		t.Fatalf("enqueue calls = %d, want one", len(enqueuer.requests))
	}
	if enqueuer.requests[0].To != "alice.example@example.com" {
		t.Fatalf("delivery recipient = %q, want canonical email", enqueuer.requests[0].To)
	}
	if enqueuer.requests[0].Token != result.Action.Token {
		t.Fatal("delivery token differs from issued action token")
	}
}

func TestAdminIssuedLoginLinkQueuesToVerifiedEmailAndAudits(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recipient@example.com"
	pair, err := auth.Signup(ctx, "admin_link_recipient", "password123", &email)
	if err != nil {
		t.Fatal(err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatal(err)
	}
	enqueuer := &recordingLoginLinkEnqueuer{}
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{HMACKeyID: "test-v1", HMACKey: uniqueQuotaKey()}, enqueuer)
	actorID := pair.UserID
	issued, err := login.IssueLoginLink(ctx, LoginLinkIssueRequest{AccountID: pair.UserID, ActorID: &actorID})
	if err != nil || issued == nil || !issued.Issued || len(enqueuer.requests) != 1 || enqueuer.requests[0].To != email {
		t.Fatalf("admin link issue failed: issued=%t deliveries=%d err=%v", issued != nil && issued.Issued, len(enqueuer.requests), err)
	}
	events, err := q.ListAuditEvents(ctx, nil, 20)
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, event := range events {
		if event.Action == "admin_login_link_queued" && event.ActorID != nil && *event.ActorID == actorID {
			found = true
		}
	}
	if !found {
		t.Fatal("admin login link audit event missing")
	}
}

func newTestEmailLogin(q *db.Queries, auth *Auth, enqueuer LoginLinkDeliveryEnqueuer) *EmailLogin {
	return NewEmailLogin(q, auth.Security(), token.NewHelper("test-secret", time.Minute), EmailLoginConfig{
		HMACKeyID: "test-v1",
		HMACKey:   uniqueQuotaKey(),
	}, enqueuer)
}

func uniqueQuotaKey() []byte {
	return []byte("t06-quota-" + uuid.NewString())
}

func confirmTestEmail(t *testing.T, q *db.Queries, auth *Auth, username, email string) uuid.UUID {
	t.Helper()
	pair, err := auth.Signup(context.Background(), username, "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(context.Background(), pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	return pair.UserID
}

func TestEmailLoginExchangeConsumesOneTokenAndRevokesSiblings(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	enqueuer := &recordingLoginLinkEnqueuer{}
	login := newTestEmailLogin(q, auth, enqueuer)
	ctx := context.Background()
	userID := confirmTestEmail(t, q, auth, "exchange_owner", "exchange@example.com")

	first, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "EXCHANGE@example.com", ClientIP: "192.0.2.20"})
	if err != nil || first.Action == nil {
		t.Fatalf("first request = %#v, err=%v", first, err)
	}
	second, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "exchange@example.com", ClientIP: "192.0.2.21"})
	if err != nil || second.Action == nil {
		t.Fatalf("second request = %#v, err=%v", second, err)
	}

	exchanged, err := login.ExchangeEmailLink(ctx, first.Action.Token)
	if err != nil {
		t.Fatalf("exchange: %v", err)
	}
	if exchanged == nil || exchanged.Pair == nil || exchanged.Pair.UserID != userID || exchanged.Username != "exchange_owner" {
		t.Fatalf("exchange result = %#v, want canonical owner credentials", exchanged)
	}
	if _, err := login.ExchangeEmailLink(ctx, first.Action.Token); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("replay error = %v, want generic 400", err)
	}
	if _, err := login.ExchangeEmailLink(ctx, second.Action.Token); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("sibling error = %v, want revoked sibling generic 400", err)
	}

	firstHash := sha256.Sum256([]byte(first.Action.Token))
	stored, err := q.GetAccountActionTokenByHash(ctx, firstHash[:])
	if err != nil || stored == nil || stored.ConsumedAt == nil {
		t.Fatalf("consumed token = %#v, err=%v", stored, err)
	}
	secondHash := sha256.Sum256([]byte(second.Action.Token))
	stored, err = q.GetAccountActionTokenByHash(ctx, secondHash[:])
	if err != nil || stored == nil || stored.RevokedAt == nil {
		t.Fatalf("sibling token = %#v, err=%v, want revoked", stored, err)
	}
}

func TestEmailLoginExchangeRejectsExpiredAndWrongPurposeTokens(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	enqueuer := &recordingLoginLinkEnqueuer{}
	login := newTestEmailLogin(q, auth, enqueuer)
	ctx := context.Background()
	confirmTestEmail(t, q, auth, "expiry_owner", "expiry@example.com")

	base := time.Date(2026, 9, 16, 12, 0, 0, 0, time.UTC)
	login.SetClock(func() time.Time { return base })
	issued, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "expiry@example.com", ClientIP: "192.0.2.22"})
	if err != nil || issued.Action == nil {
		t.Fatalf("request = %#v, err=%v", issued, err)
	}
	login.SetClock(func() time.Time { return base.Add(16 * time.Minute) })
	if _, err := login.ExchangeEmailLink(ctx, issued.Action.Token); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("expired exchange error = %v, want generic 400", err)
	}

	// A valid hash with a different purpose must be indistinguishable from an
	// unknown token at the public exchange boundary.
	wrongRaw := "wrong-purpose-token"
	wrongHash := sha256.Sum256([]byte(wrongRaw))
	state, err := q.GetUserSecurityState(ctx, issued.AccountID)
	if err != nil || state == nil {
		t.Fatalf("state for wrong-purpose token: %#v, err=%v", state, err)
	}
	if err := q.CreateAccountActionToken(ctx, db.AccountActionTokenParams{
		ID: uuid.New(), AccountID: issued.AccountID, TokenHash: wrongHash[:],
		Purpose: db.ActionTokenPurposeRecovery, EmailBinding: &issued.CanonicalEmail,
		AuthGeneration: state.AuthGeneration, ExpiresAt: base.Add(time.Hour),
	}); err != nil {
		t.Fatalf("create wrong-purpose token: %v", err)
	}
	if _, err := login.ExchangeEmailLink(ctx, wrongRaw); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("wrong-purpose exchange error = %v, want generic 400", err)
	}
	if _, err := login.ExchangeEmailLink(ctx, "random-token"); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("random exchange error = %v, want generic 400", err)
	}
}

func TestEmailLoginExchangeRejectsEmailChangedAfterIssuance(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	oldEmail := "email-change-login@example.com"
	userID := confirmTestEmail(t, q, auth, "email_change_login", oldEmail)
	login := newTestEmailLogin(q, auth, &recordingLoginLinkEnqueuer{})
	issued, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: oldEmail, ClientIP: "192.0.2.27"})
	if err != nil || issued == nil || issued.Action == nil {
		t.Fatalf("request = %#v, err=%v", issued, err)
	}
	newEmail := "new-email-change-login@example.com"
	if err := q.ChangeUserEmail(ctx, userID, &newEmail, nil); err != nil {
		t.Fatalf("change email: %v", err)
	}
	if _, err := login.ExchangeEmailLink(ctx, issued.Action.Token); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("changed-email exchange error = %v, want generic 400", err)
	}
}

func TestEmailLoginExchangeIsSingleWinnerUnderConcurrentRedemption(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	login := newTestEmailLogin(q, auth, &recordingLoginLinkEnqueuer{})
	ctx := context.Background()
	confirmTestEmail(t, q, auth, "race_owner", "race@example.com")
	issued, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "race@example.com", ClientIP: "192.0.2.23"})
	if err != nil || issued.Action == nil {
		t.Fatalf("request = %#v, err=%v", issued, err)
	}

	var wg sync.WaitGroup
	var mu sync.Mutex
	winners := 0
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			result, err := login.ExchangeEmailLink(ctx, issued.Action.Token)
			if err == nil && result != nil && result.Pair != nil {
				mu.Lock()
				winners++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if winners != 1 {
		t.Fatalf("successful redemptions = %d, want exactly one", winners)
	}
}

func TestDurableLoginLinkEnqueuerStoresEncryptedAttemptAndJob(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "durable-login@example.com"
	userID := confirmTestEmail(t, q, auth, "durable_login", email)
	ring, err := NewDeliveryKeyRing(map[string][]byte{"test": []byte("01234567890123456789012345678901")}, "test", 15*time.Minute)
	if err != nil {
		t.Fatalf("key ring: %v", err)
	}
	login := NewEmailLogin(q, auth.Security(), token.NewHelper("test-secret", time.Minute), EmailLoginConfig{
		HMACKeyID: "durable-login-v1", HMACKey: uniqueQuotaKey(), DeliveryKeyRing: ring, DeliveryPayloadTTL: time.Minute,
		CallbackURL: "https://consumer.example/#/email-login/callback?token=",
	}, nil)
	before := time.Now()
	issued, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.28"})
	if err != nil || issued == nil || issued.Action == nil || issued.DeliveryID == nil {
		t.Fatalf("durable request = %#v, err=%v", issued, err)
	}
	attempt, err := q.GetDeliveryAttempt(ctx, *issued.DeliveryID)
	if err != nil || attempt == nil {
		t.Fatalf("delivery attempt = %#v, err=%v", attempt, err)
	}
	if len(attempt.EncryptedPayload) == 0 || attempt.DeliveryKeyID == nil || *attempt.DeliveryKeyID != "test" {
		t.Fatalf("delivery attempt = %#v, want encrypted payload and key id", attempt)
	}
	if attempt.PayloadExpiresAt == nil {
		t.Fatal("delivery attempt has no payload expiry")
	}
	if attempt.PayloadExpiresAt.Before(before.Add(50*time.Second)) || attempt.PayloadExpiresAt.After(before.Add(70*time.Second)) {
		t.Fatalf("payload expiry = %s, want approximately one configured minute", attempt.PayloadExpiresAt)
	}
	envelope := EncryptedDeliveryPayload{Ciphertext: attempt.EncryptedPayload, KeyID: *attempt.DeliveryKeyID, ExpiresAt: *attempt.PayloadExpiresAt}
	plaintext, err := ring.DecryptPayload(envelope, time.Now())
	if err != nil || string(plaintext) == "" {
		t.Fatalf("decrypt delivery payload: %v", err)
	}
	if string(plaintext) == email || string(plaintext) == issued.Action.Token {
		t.Fatal("delivery payload was stored as plaintext")
	}
	job, err := q.GetDurableJob(ctx, jobs.DeterministicJobID(KindEmailDelivery, "email-login:"+issued.Action.ID.String()))
	if err != nil || job == nil {
		t.Fatalf("durable job = %#v, err=%v", job, err)
	}
	var jobPayload DeliveryJobPayload
	if err := json.Unmarshal(job.Payload, &jobPayload); err != nil {
		t.Fatalf("job payload: %v", err)
	}
	if jobPayload.AttemptID != *issued.DeliveryID || userID == uuid.Nil {
		t.Fatalf("job payload = %#v, attempt=%s", jobPayload, issued.DeliveryID)
	}
}

func TestValidatedDeliveryAttemptStoreSuppressesEmailChangedLogin(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "stale-login-delivery@example.com"
	userID := confirmTestEmail(t, q, auth, "stale_login_delivery", email)
	ring, err := NewDeliveryKeyRing(map[string][]byte{"test": []byte("01234567890123456789012345678901")}, "test", 15*time.Minute)
	if err != nil {
		t.Fatalf("key ring: %v", err)
	}
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{
		HMACKeyID: "stale-login-v1", HMACKey: uniqueQuotaKey(), DeliveryKeyRing: ring,
	}, nil)
	issued, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.50"})
	if err != nil || issued == nil || issued.DeliveryID == nil {
		t.Fatalf("request = %#v, err=%v", issued, err)
	}
	store := NewValidatedDeliveryAttemptStore(q, q, ring, nil)
	valid, err := store.GetDeliveryAttempt(ctx, *issued.DeliveryID)
	if err != nil || valid == nil || valid.Status != DeliveryStatusPending {
		t.Fatalf("fresh attempt = %#v, err=%v, want pending", valid, err)
	}
	newEmail := "stale-login-delivery-new@example.com"
	if err := q.ChangeUserEmail(ctx, userID, &newEmail, nil); err != nil {
		t.Fatalf("change email: %v", err)
	}
	suppressed, err := store.GetDeliveryAttempt(ctx, *issued.DeliveryID)
	if err != nil || suppressed == nil || suppressed.Status != DeliveryStatusAccepted {
		t.Fatalf("stale attempt = %#v, err=%v, want suppressed accepted status", suppressed, err)
	}
	stored, err := q.GetDeliveryAttempt(ctx, *issued.DeliveryID)
	if err != nil || stored == nil || stored.Status != DeliveryStatusFailed || stored.ErrorCode == nil || *stored.ErrorCode != "stale_action" {
		t.Fatalf("stored stale attempt = %#v, err=%v, want audit failure", stored, err)
	}
}

func TestValidatedDeliveryAttemptStoreSuppressesRevokedSiblingLogin(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "sibling-login-delivery@example.com"
	confirmTestEmail(t, q, auth, "sibling_login_delivery", email)
	ring, err := NewDeliveryKeyRing(map[string][]byte{"test": []byte("01234567890123456789012345678901")}, "test", 15*time.Minute)
	if err != nil {
		t.Fatalf("key ring: %v", err)
	}
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{
		HMACKeyID: "sibling-login-v1", HMACKey: uniqueQuotaKey(), DeliveryKeyRing: ring,
	}, nil)
	first, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.51"})
	if err != nil || first == nil || first.Action == nil || first.DeliveryID == nil {
		t.Fatalf("first request = %#v, err=%v", first, err)
	}
	second, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.52"})
	if err != nil || second == nil || second.Action == nil || second.DeliveryID == nil {
		t.Fatalf("second request = %#v, err=%v", second, err)
	}
	if _, err := login.ExchangeEmailLink(ctx, first.Action.Token); err != nil {
		t.Fatalf("exchange first link: %v", err)
	}
	store := NewValidatedDeliveryAttemptStore(q, q, ring, nil)
	suppressed, err := store.GetDeliveryAttempt(ctx, *second.DeliveryID)
	if err != nil || suppressed == nil || suppressed.Status != DeliveryStatusAccepted {
		t.Fatalf("revoked sibling attempt = %#v, err=%v, want suppressed", suppressed, err)
	}
}

func TestValidatedDeliveryAttemptStoreSuppressesContainedLogin(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "contained-login-delivery@example.com"
	userID := confirmTestEmail(t, q, auth, "contained_login_delivery", email)
	ring, err := NewDeliveryKeyRing(map[string][]byte{"test": []byte("01234567890123456789012345678901")}, "test", 15*time.Minute)
	if err != nil {
		t.Fatalf("key ring: %v", err)
	}
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{
		HMACKeyID: "contained-login-v1", HMACKey: uniqueQuotaKey(), DeliveryKeyRing: ring,
	}, nil)
	issued, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.53"})
	if err != nil || issued == nil || issued.DeliveryID == nil {
		t.Fatalf("request = %#v, err=%v", issued, err)
	}
	if _, err := NewAccountSecurity(q).ContainAccount(ctx, ContainmentRequest{AccountID: userID, Reason: "queued login containment"}); err != nil {
		t.Fatalf("contain account: %v", err)
	}
	store := NewValidatedDeliveryAttemptStore(q, q, ring, nil)
	suppressed, err := store.GetDeliveryAttempt(ctx, *issued.DeliveryID)
	if err != nil || suppressed == nil || suppressed.Status != DeliveryStatusAccepted {
		t.Fatalf("contained login attempt = %#v, err=%v, want suppressed", suppressed, err)
	}
}

func createTestDeliveryAttempt(t *testing.T, q *db.Queries, ring *DeliveryKeyRing, plaintext []byte, createdAt time.Time, ttl time.Duration, corrupt bool) uuid.UUID {
	t.Helper()
	envelope, err := ring.EncryptPayload(plaintext, createdAt, ttl)
	if err != nil {
		t.Fatalf("encrypt test delivery payload: %v", err)
	}
	if corrupt {
		envelope.Ciphertext[len(envelope.Ciphertext)-1] ^= 0x01
	}
	attemptID := uuid.New()
	keyID := envelope.KeyID
	expiresAt := envelope.ExpiresAt
	if err := q.CreateDeliveryAttempt(context.Background(), db.DeliveryAttemptParams{
		ID: attemptID, Channel: "email", Status: DeliveryStatusPending, AttemptNumber: 0,
		EncryptedPayload: envelope.Ciphertext, DeliveryKeyID: &keyID, PayloadExpiresAt: &expiresAt,
	}); err != nil {
		t.Fatalf("create test delivery attempt: %v", err)
	}
	return attemptID
}

func assertClassifiedDeliveryPayloadError(t *testing.T, err error, code string, cause error) {
	t.Helper()
	if err == nil {
		t.Fatalf("delivery payload error = nil, want %s", code)
	}
	var classified *DeliveryAttemptValidationError
	if !errors.As(err, &classified) {
		t.Fatalf("delivery payload error = %T %v, want classified validation error", err, err)
	}
	if classified.Code != code {
		t.Fatalf("classified delivery code = %q, want %q", classified.Code, code)
	}
	if !errors.Is(err, cause) {
		t.Fatalf("classified delivery error = %v, want cause %v", err, cause)
	}
}

func TestValidatedDeliveryAttemptStoreClassifiesExpiredPayloadForDispatcher(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	now := time.Unix(1000, 0)
	ring := testKeyRing(t)
	attemptID := createTestDeliveryAttempt(t, q, ring, []byte(`{"email":{"to":"person@example.test","subject":"Notice","body":"Hello"}}`), now.Add(-2*time.Minute), time.Minute, false)
	store := NewValidatedDeliveryAttemptStore(q, q, ring, func() time.Time { return now })
	_, err := store.GetDeliveryAttempt(ctx, attemptID)
	assertClassifiedDeliveryPayloadError(t, err, "delivery_payload_expired", ErrDeliveryPayloadExpired)

	provider := &fakeEmailProvider{result: ProviderResult{Outcome: ProviderAccepted}}
	dispatcher := NewDeliveryDispatcher(store, ring, NewEmailDelivery(provider), nil, func() time.Time { return now })
	result := dispatcher.handleEmail(ctx, jobs.Job{}, DeliveryJobPayload{AttemptID: attemptID})
	if result.Status != jobs.StatusFailed || result.ErrorCode != "delivery_payload_expired" {
		t.Fatalf("expired dispatcher result = %#v, want terminal classified failure", result)
	}
	stored, err := q.GetDeliveryAttempt(ctx, attemptID)
	if err != nil || stored == nil || stored.Status != DeliveryStatusFailed || stored.ErrorCode == nil || *stored.ErrorCode != "delivery_payload_expired" || stored.EncryptedPayload != nil || stored.DeliveryKeyID != nil {
		t.Fatalf("expired stored attempt = %#v, err=%v, want failed and cleared", stored, err)
	}
	if len(provider.received) != 0 {
		t.Fatalf("expired payload reached provider: %#v", provider.received)
	}
}

func TestValidatedDeliveryAttemptStoreClassifiesMissingKeyForDispatcher(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	now := time.Unix(1100, 0)
	ring := testKeyRing(t)
	attemptID := createTestDeliveryAttempt(t, q, ring, []byte(`{"email":{"to":"person@example.test","subject":"Notice","body":"Hello"}}`), now, time.Minute, false)
	missingKeyRing, err := NewDeliveryKeyRing(map[string][]byte{"other": []byte("01234567890123456789012345678901")}, "other", 15*time.Minute)
	if err != nil {
		t.Fatalf("missing-key ring: %v", err)
	}
	store := NewValidatedDeliveryAttemptStore(q, q, missingKeyRing, func() time.Time { return now })
	_, err = store.GetDeliveryAttempt(ctx, attemptID)
	assertClassifiedDeliveryPayloadError(t, err, "delivery_key_unavailable", ErrDeliveryKeyUnavailable)

	provider := &fakeEmailProvider{result: ProviderResult{Outcome: ProviderAccepted}}
	dispatcher := NewDeliveryDispatcher(store, missingKeyRing, NewEmailDelivery(provider), nil, func() time.Time { return now })
	result := dispatcher.handleEmail(ctx, jobs.Job{}, DeliveryJobPayload{AttemptID: attemptID})
	if result.Status != jobs.StatusFailed || result.ErrorCode != "delivery_key_unavailable" {
		t.Fatalf("missing-key dispatcher result = %#v, want terminal classified failure", result)
	}
	stored, err := q.GetDeliveryAttempt(ctx, attemptID)
	if err != nil || stored == nil || stored.Status != DeliveryStatusFailed || stored.ErrorCode == nil || *stored.ErrorCode != "delivery_key_unavailable" || stored.EncryptedPayload != nil || stored.DeliveryKeyID != nil {
		t.Fatalf("missing-key stored attempt = %#v, err=%v, want failed and cleared", stored, err)
	}
	if len(provider.received) != 0 {
		t.Fatalf("missing-key payload reached provider: %#v", provider.received)
	}
}

func TestValidatedDeliveryAttemptStoreClassifiesCorruptPayloadForDispatcher(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	now := time.Unix(1200, 0)
	ring := testKeyRing(t)
	attemptID := createTestDeliveryAttempt(t, q, ring, []byte(`{"email":{"to":"person@example.test","subject":"Notice","body":"Hello"}}`), now, time.Minute, true)
	store := NewValidatedDeliveryAttemptStore(q, q, ring, func() time.Time { return now })
	_, err := store.GetDeliveryAttempt(ctx, attemptID)
	assertClassifiedDeliveryPayloadError(t, err, "delivery_payload_invalid", ErrInvalidDeliveryPayload)

	provider := &fakeEmailProvider{result: ProviderResult{Outcome: ProviderAccepted}}
	dispatcher := NewDeliveryDispatcher(store, ring, NewEmailDelivery(provider), nil, func() time.Time { return now })
	result := dispatcher.handleEmail(ctx, jobs.Job{}, DeliveryJobPayload{AttemptID: attemptID})
	if result.Status != jobs.StatusFailed || result.ErrorCode != "delivery_payload_invalid" {
		t.Fatalf("corrupt dispatcher result = %#v, want terminal classified failure", result)
	}
	stored, err := q.GetDeliveryAttempt(ctx, attemptID)
	if err != nil || stored == nil || stored.Status != DeliveryStatusFailed || stored.ErrorCode == nil || *stored.ErrorCode != "delivery_payload_invalid" || stored.EncryptedPayload != nil || stored.DeliveryKeyID != nil {
		t.Fatalf("corrupt stored attempt = %#v, err=%v, want failed and cleared", stored, err)
	}
	if len(provider.received) != 0 {
		t.Fatalf("corrupt payload reached provider: %#v", provider.received)
	}
}

func TestEmailLoginRequestSuppressesUnknownDuplicateAndRestrictedAccounts(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	enqueuer := &recordingLoginLinkEnqueuer{}
	login := newTestEmailLogin(q, auth, enqueuer)
	ctx := context.Background()

	unknown, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "unknown@example.com", ClientIP: "192.0.2.24"})
	if err != nil || unknown == nil || !unknown.Accepted || unknown.Issued {
		t.Fatalf("unknown result = %#v, err=%v", unknown, err)
	}

	email := "duplicate@example.com"
	first := confirmTestEmail(t, q, auth, "duplicate_one", email)
	secondPair, err := auth.Signup(ctx, "duplicate_two", "password123", &email)
	if err != nil {
		t.Fatalf("duplicate signup: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, `UPDATE users SET email_confirmed = TRUE WHERE id = $1`, secondPair.UserID); err != nil {
		t.Fatalf("mark duplicate verified: %v", err)
	}
	if err := q.BackfillEmailLoginClaims(ctx); err != nil {
		t.Fatalf("backfill duplicate claim: %v", err)
	}
	duplicate, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.25"})
	if err != nil || duplicate == nil || !duplicate.Accepted || duplicate.Issued {
		t.Fatalf("duplicate result = %#v, err=%v", duplicate, err)
	}

	if _, err := NewAccountSecurity(q).ContainAccount(ctx, ContainmentRequest{AccountID: first, Reason: "test restriction"}); err != nil {
		t.Fatalf("contain: %v", err)
	}
	restrictedEmail := "restricted@example.com"
	restrictedID := confirmTestEmail(t, q, auth, "restricted_owner", restrictedEmail)
	if _, err := NewAccountSecurity(q).ContainAccount(ctx, ContainmentRequest{AccountID: restrictedID, Reason: "test restriction"}); err != nil {
		t.Fatalf("contain restricted: %v", err)
	}
	restricted, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: restrictedEmail, ClientIP: "192.0.2.26"})
	if err != nil || restricted == nil || !restricted.Accepted || restricted.Issued {
		t.Fatalf("restricted result = %#v, err=%v", restricted, err)
	}
}

func TestEmailLoginRequestAppliesAddressAndIPQuotasWithoutEnumeration(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	enqueuer := &recordingLoginLinkEnqueuer{}
	login := NewEmailLogin(q, auth.Security(), token.NewHelper("test-secret", time.Minute), EmailLoginConfig{
		HMACKeyID:         "test-v1",
		HMACKey:           uniqueQuotaKey(),
		AddressLimit:      1,
		AddressDailyLimit: 1,
		IPLimit:           2,
		GlobalLimit:       100,
	}, enqueuer)
	ctx := context.Background()
	confirmTestEmail(t, q, auth, "quota_owner", "quota@example.com")

	first, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "quota@example.com", ClientIP: "192.0.2.30"})
	if err != nil || first == nil || !first.Issued {
		t.Fatalf("first quota request = %#v, err=%v", first, err)
	}
	second, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "quota@example.com", ClientIP: "192.0.2.30"})
	if err != nil || second == nil || !second.Accepted || second.Issued {
		t.Fatalf("address-suppressed request = %#v, err=%v", second, err)
	}
	third, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "other@example.com", ClientIP: "192.0.2.30"})
	if err == nil || apperrors.HTTPStatus(err) != 429 || third != nil {
		t.Fatalf("ip-throttled request = %#v, err=%v, want generic 429", third, err)
	}
}

func TestEmailLoginDeliveryFailureKeepsAbuseQuotaCommitted(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "login-delivery-failure@example.com"
	confirmTestEmail(t, q, auth, "login_delivery_failure", email)
	login := NewEmailLogin(q, auth.Security(), token.NewHelper("test-secret", time.Minute), EmailLoginConfig{
		HMACKeyID: "delivery-failure-v1", HMACKey: uniqueQuotaKey(), IPLimit: 1,
	}, failingLoginLinkEnqueuer{})
	accepted, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.41"})
	if err != nil || accepted == nil || !accepted.Accepted || accepted.Issued {
		t.Fatalf("delivery failure = %#v, err=%v, want generic accepted response", accepted, err)
	}
	if _, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "unknown-after-failure@example.com", ClientIP: "192.0.2.41"}); err == nil || apperrors.HTTPStatus(err) != 429 {
		t.Fatalf("retry after delivery failure = %v, want committed IP quota 429", err)
	}
}

func TestEmailLoginDeliveryFailureRollsBackIssuedAction(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "login-action-rollback@example.com"
	confirmTestEmail(t, q, auth, "login_action_rollback", email)
	enqueuer := &recordingFailingLoginLinkEnqueuer{}
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{
		HMACKeyID: "action-rollback-v1", HMACKey: uniqueQuotaKey(),
	}, enqueuer)
	accepted, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.46"})
	if err != nil || accepted == nil || !accepted.Accepted || accepted.Issued {
		t.Fatalf("delivery failure = %#v, err=%v, want generic accepted response", accepted, err)
	}
	if enqueuer.request.Token == "" {
		t.Fatal("failing enqueuer did not observe issued action token")
	}
	actionHash := sha256.Sum256([]byte(enqueuer.request.Token))
	action, err := q.GetAccountActionTokenByHash(ctx, actionHash[:])
	if err != nil {
		t.Fatalf("read rolled-back action token: %v", err)
	}
	if action != nil {
		t.Fatalf("action token survived failed enqueue: %#v", action)
	}
}

func TestEmailLoginDeliveryFailureNormalizesEligibleAndUnknownAcceptance(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "normalized-delivery-failure@example.com"
	confirmTestEmail(t, q, auth, "normalized_delivery_failure", email)
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{
		HMACKeyID: "normalized-failure-v1", HMACKey: uniqueQuotaKey(), IPLimit: 20,
	}, failingLoginLinkEnqueuer{})
	eligible, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.42"})
	if err != nil || eligible == nil || !eligible.Accepted || eligible.Issued {
		t.Fatalf("eligible delivery failure = %#v, err=%v, want generic accepted", eligible, err)
	}
	unknown, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "missing-normalized@example.com", ClientIP: "192.0.2.43"})
	if err != nil || unknown == nil || !unknown.Accepted || unknown.Issued {
		t.Fatalf("unknown delivery failure = %#v, err=%v, want generic accepted", unknown, err)
	}
}

func TestEmailLoginDeliveryEnqueueFailureRollsBackActionAndPartialDurableWrites(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "login-partial-delivery-failure@example.com"
	confirmTestEmail(t, q, auth, "login_partial_delivery_failure", email)
	enqueuer := &partialLoginLinkEnqueuer{}
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{
		HMACKeyID: "partial-delivery-failure-v1", HMACKey: uniqueQuotaKey(), IPLimit: 1,
	}, enqueuer)
	accepted, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: email, ClientIP: "192.0.2.45"})
	if err != nil || accepted == nil || !accepted.Accepted || accepted.Issued {
		t.Fatalf("partial delivery failure = %#v, err=%v, want generic accepted response", accepted, err)
	}
	if enqueuer.request.Token == "" || enqueuer.attemptID == uuid.Nil || enqueuer.jobID == uuid.Nil {
		t.Fatalf("partial enqueuer did not observe durable writes: %#v", enqueuer)
	}
	actionHash := sha256.Sum256([]byte(enqueuer.request.Token))
	action, err := q.GetAccountActionTokenByHash(ctx, actionHash[:])
	if err != nil {
		t.Fatalf("read rolled-back action token: %v", err)
	}
	if action != nil {
		t.Fatalf("action token survived failed enqueue: %#v", action)
	}
	attempt, err := q.GetDeliveryAttempt(ctx, enqueuer.attemptID)
	if err != nil {
		t.Fatalf("read rolled-back delivery attempt: %v", err)
	}
	if attempt != nil {
		t.Fatalf("delivery attempt survived failed enqueue: %#v", attempt)
	}
	job, err := q.GetDurableJob(ctx, enqueuer.jobID)
	if err != nil {
		t.Fatalf("read rolled-back durable job: %v", err)
	}
	if job != nil {
		t.Fatalf("durable job survived failed enqueue: %#v", job)
	}
	if _, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "unknown-after-partial-failure@example.com", ClientIP: "192.0.2.45"}); err == nil || apperrors.HTTPStatus(err) != 429 {
		t.Fatalf("retry after partial delivery failure = %v, want committed IP quota 429", err)
	}
}

func TestEmailLoginRequiresExplicitQuotaSecretAndKeyID(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	login := NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{}, &recordingLoginLinkEnqueuer{})
	result, err := login.RequestEmailLink(context.Background(), EmailLoginRequest{Email: "person@example.com", ClientIP: "192.0.2.43"})
	if result != nil || err == nil || apperrors.HTTPStatus(err) != 503 {
		t.Fatalf("missing quota key result = %#v, err=%v, want fail-closed 503", result, err)
	}
	login = NewEmailLogin(q, auth.Security(), authTokenHelper(auth), EmailLoginConfig{HMACKey: uniqueQuotaKey()}, &recordingLoginLinkEnqueuer{})
	result, err = login.RequestEmailLink(context.Background(), EmailLoginRequest{Email: "person@example.com", ClientIP: "192.0.2.44"})
	if result != nil || err == nil || apperrors.HTTPStatus(err) != 503 {
		t.Fatalf("missing quota key id result = %#v, err=%v, want fail-closed 503", result, err)
	}
}

func TestEmailLoginExchangeRollsBackConsumptionWhenRefreshInsertionFails(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	login := newTestEmailLogin(q, auth, &recordingLoginLinkEnqueuer{})
	ctx := context.Background()
	confirmTestEmail(t, q, auth, "rollback_owner", "rollback@example.com")
	issued, err := login.RequestEmailLink(ctx, EmailLoginRequest{Email: "rollback@example.com", ClientIP: "192.0.2.40"})
	if err != nil || issued.Action == nil {
		t.Fatalf("request = %#v, err=%v", issued, err)
	}
	login.SetTokenIssuer(func(context.Context, *db.Queries, uuid.UUID) (*TokenPair, error) {
		return nil, errors.New("refresh insert failed")
	})
	if _, err := login.ExchangeEmailLink(ctx, issued.Action.Token); err == nil {
		t.Fatal("exchange unexpectedly succeeded with failing refresh issuer")
	}
	login.SetTokenIssuer(func(ctx context.Context, tx *db.Queries, accountID uuid.UUID) (*TokenPair, error) {
		return auth.Security().IssueTokens(ctx, tx, token.NewHelper("test-secret", time.Minute), accountID)
	})
	result, err := login.ExchangeEmailLink(ctx, issued.Action.Token)
	if err != nil || result == nil || result.Pair == nil {
		t.Fatalf("retry after rollback = %#v, err=%v", result, err)
	}
}

// authTokenHelper keeps the test coupled to the same helper used by Auth
// without requiring any production accessor on Auth.
func authTokenHelper(_ *Auth) *token.Helper { return token.NewHelper("test-secret", time.Minute) }
