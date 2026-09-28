package service

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

type recordingRecoveryEnqueuer struct {
	inner RecoveryEnqueuer
	err   error
}

func (e *recordingRecoveryEnqueuer) EnqueueRecovery(ctx context.Context, tx *db.Queries, request RecoveryEnqueueRequest) (RecoveryEnqueueResult, error) {
	result, err := e.inner.EnqueueRecovery(ctx, tx, request)
	e.err = err
	return result, err
}

func TestAccountRecoveryConsumesOnceClearsRestrictionAndRequiresFreshLogin(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recover@example.com"
	pair, err := auth.Signup(ctx, "recover_owner", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	oldPair, err := auth.Login(ctx, "recover_owner", "password123")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "recovery test"}); err != nil {
		t.Fatalf("contain: %v", err)
	}
	action, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, 10*time.Minute)
	if err != nil || action == nil {
		t.Fatalf("issue recovery action = %#v, err=%v", action, err)
	}
	recovery := NewAccountRecovery(q, security)
	if err := recovery.CompleteRecovery(ctx, RecoveryCompletionRequest{Token: action.Token, Password: "new-password"}); err != nil {
		t.Fatalf("complete recovery: %v", err)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil {
		t.Fatalf("security state = %#v, err=%v", state, err)
	}
	if state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired || state.AuthGeneration != 2 {
		t.Fatalf("security state = %#v, want normal generation 2", state)
	}
	if _, err := q.FindRefreshToken(ctx, oldPair.RefreshToken); err == nil {
		t.Fatal("pre-containment refresh token still exists")
	}
	if _, err := auth.Login(ctx, "recover_owner", "password123"); err == nil {
		t.Fatal("old password still works after recovery")
	}
	if _, err := auth.Login(ctx, "recover_owner", "new-password"); err != nil {
		t.Fatalf("new password login: %v", err)
	}
	if err := recovery.CompleteRecovery(ctx, RecoveryCompletionRequest{Token: action.Token, Password: "another-password"}); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("replay error = %v, want generic 400", err)
	}
}

func TestAccountRecoveryRejectsBadPasswordWithoutConsumingToken(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recover-policy@example.com"
	pair, err := auth.Signup(ctx, "recover_policy", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "policy test"}); err != nil {
		t.Fatalf("contain: %v", err)
	}
	action, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, time.Minute)
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	recovery := NewAccountRecovery(q, security)
	if err := recovery.CompleteRecovery(ctx, RecoveryCompletionRequest{Token: action.Token, Password: ""}); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("empty password error = %v, want 400", err)
	}
	hash := sha256.Sum256([]byte(action.Token))
	stored, err := q.GetAccountActionTokenByHash(ctx, hash[:])
	if err != nil || stored == nil || stored.ConsumedAt != nil {
		t.Fatalf("token after invalid password = %#v, err=%v, want unconsumed", stored, err)
	}
}

func TestValidateRecoveryPasswordMatchesFrozenSchemaBoundaries(t *testing.T) {
	if err := ValidateRecoveryPassword(strings.Repeat("a", 7)); err == nil {
		t.Fatal("7-character recovery password was accepted")
	}
	if err := ValidateRecoveryPassword(strings.Repeat("a", 8)); err != nil {
		t.Fatalf("8-character recovery password rejected: %v", err)
	}
	if err := ValidateRecoveryPassword(strings.Repeat("a", 256)); err != nil {
		t.Fatalf("256-character recovery password rejected: %v", err)
	}
	if err := ValidateRecoveryPassword(strings.Repeat("a", 257)); err == nil {
		t.Fatal("257-character recovery password was accepted")
	}
	if err := ValidateRecoveryPassword("пароль-🙂"); err != nil {
		t.Fatalf("valid UTF-8 recovery password rejected: %v", err)
	}
}

func TestAccountRecoveryCompletesContractValidLongPasswordEndToEnd(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recover-long-password@example.com"
	pair, err := auth.Signup(ctx, "recover_long_password", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "long password test"}); err != nil {
		t.Fatalf("contain: %v", err)
	}
	action, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, time.Minute)
	if err != nil || action == nil {
		t.Fatalf("issue recovery action = %#v, err=%v", action, err)
	}
	longPassword := strings.Repeat("L", 256)
	if err := NewAccountRecovery(q, security).CompleteRecovery(ctx, RecoveryCompletionRequest{Token: action.Token, Password: longPassword}); err != nil {
		t.Fatalf("complete long recovery: %v", err)
	}
	if _, err := auth.Login(ctx, "recover_long_password", longPassword); err != nil {
		t.Fatalf("login with contract-valid long password: %v", err)
	}
}

func TestAccountRecoveryRedemptionHasOneWinner(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recover-race@example.com"
	pair, err := auth.Signup(ctx, "recover_race", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "recovery race"}); err != nil {
		t.Fatalf("contain: %v", err)
	}
	action, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, time.Minute)
	if err != nil || action == nil {
		t.Fatalf("issue recovery action = %#v, err=%v", action, err)
	}
	recovery := NewAccountRecovery(q, security)
	var wg sync.WaitGroup
	var mu sync.Mutex
	winners := 0
	for _, password := range []string{"race-password-one", "race-password-two"} {
		wg.Add(1)
		go func(password string) {
			defer wg.Done()
			if err := recovery.CompleteRecovery(ctx, RecoveryCompletionRequest{Token: action.Token, Password: password}); err == nil {
				mu.Lock()
				winners++
				mu.Unlock()
			}
		}(password)
	}
	wg.Wait()
	if winners != 1 {
		t.Fatalf("successful recoveries = %d, want exactly one", winners)
	}
}

func TestAccountRecoveryRejectsChangedOrBlockedEmail(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recover-change@example.com"
	pair, err := auth.Signup(ctx, "recover_change", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "change test"}); err != nil {
		t.Fatalf("contain: %v", err)
	}
	action, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, time.Minute)
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	// ChangeUserEmail intentionally rejects restricted accounts. Simulate the
	// post-issuance mutation used by an integration race and block the claim.
	if _, err := q.Pool().Exec(ctx, `UPDATE email_login_claims SET state = 'blocked', owner_user_id = NULL, is_ambiguous = TRUE WHERE canonical_email = $1`, email); err != nil {
		t.Fatalf("block claim: %v", err)
	}
	recovery := NewAccountRecovery(q, security)
	if err := recovery.CompleteRecovery(ctx, RecoveryCompletionRequest{Token: action.Token, Password: "new-password"}); err == nil || apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("blocked claim recovery error = %v, want generic 400", err)
	}
}

func TestDurableRecoveryEnqueuerQueuesEncryptedAttemptAndJob(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "durable-recovery@example.com"
	pair, err := auth.Signup(ctx, "durable_recovery", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	key := []byte("01234567890123456789012345678901")
	ring, err := NewDeliveryKeyRing(map[string][]byte{"test": key}, "test", 15*time.Minute)
	if err != nil {
		t.Fatalf("key ring: %v", err)
	}
	security := NewAccountSecurity(q)
	enqueuer := NewDurableRecoveryEnqueuer(security, ring, "https://consumer.example/#/email-login/callback?token=", nil)
	recorder := &recordingRecoveryEnqueuer{inner: enqueuer}
	security = NewAccountSecurity(q, recorder)
	result, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "durable recovery"})
	if err != nil {
		t.Fatalf("contain with durable recovery: %v", err)
	}
	if result == nil || result.Recovery.Status != RecoveryEnqueueQueued || result.Recovery.AttemptID == nil {
		t.Fatalf("containment result = %#v, enqueue err=%v, want queued attempt", result, recorder.err)
	}
	attempt, err := q.GetDeliveryAttempt(ctx, *result.Recovery.AttemptID)
	if err != nil || attempt == nil {
		t.Fatalf("delivery attempt = %#v, err=%v", attempt, err)
	}
	if strings.Contains(string(attempt.EncryptedPayload), "token=") || strings.Contains(string(attempt.EncryptedPayload), email) {
		t.Fatal("delivery payload appears to contain plaintext recipient/token")
	}
}

func TestDurableRecoveryDeliveryFailureLeavesContainmentCommitted(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "delivery-failure@example.com"
	pair, err := auth.Signup(ctx, "delivery_failure", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	security := NewAccountSecurity(q)
	enqueuer := NewDurableRecoveryEnqueuer(security, nil, "", nil)
	security = NewAccountSecurity(q, enqueuer)
	result, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "delivery failure"})
	if err != nil {
		t.Fatalf("contain with unavailable delivery: %v", err)
	}
	if result == nil || result.Recovery.Status != RecoveryEnqueueManualRecoveryRequired {
		t.Fatalf("result = %#v, want manual recovery", result)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil || !state.PasswordDisabled || !state.PasswordResetRequired {
		t.Fatalf("state = %#v, err=%v, want containment committed", state, err)
	}
}

func TestValidatedDeliveryAttemptStoreSuppressesCompletedRecovery(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "stale-recovery-delivery@example.com"
	pair, err := auth.Signup(ctx, "stale_recovery_delivery", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	ring, err := NewDeliveryKeyRing(map[string][]byte{"test": []byte("01234567890123456789012345678901")}, "test", 15*time.Minute)
	if err != nil {
		t.Fatalf("key ring: %v", err)
	}
	security := NewAccountSecurity(q)
	enqueuer := NewDurableRecoveryEnqueuer(security, ring, "https://consumer.example/#/recovery?token=", nil, time.Minute)
	security = NewAccountSecurity(q, enqueuer)
	contained, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "stale recovery delivery"})
	if err != nil || contained == nil || contained.Recovery.AttemptID == nil {
		t.Fatalf("containment = %#v, err=%v, want queued recovery", contained, err)
	}
	attempt, err := q.GetDeliveryAttempt(ctx, *contained.Recovery.AttemptID)
	if err != nil || attempt == nil || attempt.DeliveryKeyID == nil || attempt.PayloadExpiresAt == nil {
		t.Fatalf("attempt = %#v, err=%v", attempt, err)
	}
	plaintext, err := ring.DecryptPayload(EncryptedDeliveryPayload{Ciphertext: attempt.EncryptedPayload, KeyID: *attempt.DeliveryKeyID, ExpiresAt: *attempt.PayloadExpiresAt}, time.Now())
	if err != nil {
		t.Fatalf("decrypt attempt: %v", err)
	}
	var payload authenticatedDeliveryPayload
	if err := json.Unmarshal(plaintext, &payload); err != nil || payload.Email == nil {
		t.Fatalf("delivery payload = %s, err=%v", plaintext, err)
	}
	tokenStart := strings.LastIndex(payload.Email.Body, "token=")
	if tokenStart < 0 {
		t.Fatalf("recovery body has no token: %q", payload.Email.Body)
	}
	rawToken := strings.TrimSpace(payload.Email.Body[tokenStart+len("token="):])
	if err := NewAccountRecovery(q, security).CompleteRecovery(ctx, RecoveryCompletionRequest{Token: rawToken, Password: "completed-recovery-password"}); err != nil {
		t.Fatalf("complete recovery: %v", err)
	}
	store := NewValidatedDeliveryAttemptStore(q, q, ring, nil)
	suppressed, err := store.GetDeliveryAttempt(ctx, *contained.Recovery.AttemptID)
	if err != nil || suppressed == nil || suppressed.Status != DeliveryStatusAccepted {
		t.Fatalf("completed recovery attempt = %#v, err=%v, want suppressed", suppressed, err)
	}
	stored, err := q.GetDeliveryAttempt(ctx, *contained.Recovery.AttemptID)
	if err != nil || stored == nil || stored.Status != DeliveryStatusFailed || stored.ErrorCode == nil || *stored.ErrorCode != "stale_action" {
		t.Fatalf("stored completed recovery attempt = %#v, err=%v, want stale audit", stored, err)
	}
}
