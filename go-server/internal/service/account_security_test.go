package service

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

type failingRecoveryEnqueuer struct{}

func (failingRecoveryEnqueuer) EnqueueRecovery(context.Context, *db.Queries, RecoveryEnqueueRequest) (RecoveryEnqueueResult, error) {
	return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, errors.New("queue unavailable")
}

type retryingRecoveryEnqueuer struct {
	mu       sync.Mutex
	attempts int
}

func (e *retryingRecoveryEnqueuer) EnqueueRecovery(context.Context, *db.Queries, RecoveryEnqueueRequest) (RecoveryEnqueueResult, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.attempts++
	if e.attempts == 1 {
		return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, errors.New("queue unavailable")
	}
	return RecoveryEnqueueResult{Status: RecoveryEnqueueQueued}, nil
}

func TestContainAccountCommitsDisabledStateWhenRecoveryQueueFails(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	userID := createTestUser(t, auth, "containment_queue_failure")
	security := NewAccountSecurity(q, failingRecoveryEnqueuer{})

	result, err := security.ContainAccount(ctx, ContainmentRequest{
		AccountID: userID,
		Reason:    "credential theft",
	})
	if err != nil {
		t.Fatalf("contain account: %v", err)
	}
	if result == nil || result.Generation != 1 || result.NewState != db.SecurityStateSecuredManualRecovery {
		t.Fatalf("containment result = %#v, want generation 1/manual recovery", result)
	}
	state, err := q.GetUserSecurityState(ctx, userID)
	if err != nil {
		t.Fatalf("read security state: %v", err)
	}
	if state == nil || state.AuthGeneration != 1 || !state.PasswordDisabled || !state.PasswordResetRequired {
		t.Fatalf("security state = %#v, want disabled generation 1", state)
	}
}

func TestContainAccountIsIdempotentAfterExistingRestriction(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	userID := createTestUser(t, auth, "containment_idempotent")
	security := NewAccountSecurity(q)

	first, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: userID, Reason: "first"})
	if err != nil {
		t.Fatalf("first containment: %v", err)
	}
	second, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: userID, Reason: "retry"})
	if err != nil {
		t.Fatalf("second containment: %v", err)
	}
	if first == nil || second == nil || first.Generation != 1 || second.Generation != 1 {
		t.Fatalf("containment generations = %#v and %#v, want both 1", first, second)
	}
	incidents, err := q.ListSecurityIncidentsForAccount(ctx, userID, 10)
	if err != nil {
		t.Fatalf("list incidents: %v", err)
	}
	if len(incidents) != 1 {
		t.Fatalf("incident count = %d, want one idempotent incident", len(incidents))
	}
}

func TestRevokeOwnSessionCannotRevokeAnotherAccountRefresh(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	owner := createTestUser(t, auth, "revoke_owner")
	other := createTestUser(t, auth, "revoke_other")
	ownerPair, err := auth.Login(ctx, "revoke_owner", "password123")
	if err != nil {
		t.Fatalf("owner login: %v", err)
	}
	security := NewAccountSecurity(q)
	if err := security.RevokeOwnSession(ctx, other, ownerPair.RefreshToken); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("other-account revoke error = %v, want status 400", err)
	}
	if err := security.RevokeOwnSession(ctx, owner, ownerPair.RefreshToken); err != nil {
		t.Fatalf("owner revoke: %v", err)
	}
	if _, err := q.FindRefreshToken(ctx, ownerPair.RefreshToken); err == nil {
		t.Fatal("owner refresh token still exists after revoke")
	}
}

func TestRevokeOwnSessionIsIdempotentAfterTheFirstRevoke(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	owner := createTestUser(t, auth, "revoke_idempotent")
	pair, err := auth.Login(ctx, "revoke_idempotent", "password123")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	security := NewAccountSecurity(q)
	if err := security.RevokeOwnSession(ctx, owner, pair.RefreshToken); err != nil {
		t.Fatalf("first revoke: %v", err)
	}
	if err := security.RevokeOwnSession(ctx, owner, pair.RefreshToken); err != nil {
		t.Fatalf("second revoke: %v, want idempotent success", err)
	}
}

func TestContainmentRetriesRecoveryEnqueueAfterAProviderFailure(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "retry-recovery@example.test"
	pair, err := auth.Signup(ctx, "retry_recovery", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	enqueuer := &retryingRecoveryEnqueuer{}
	security := NewAccountSecurity(q, enqueuer)
	first, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "retry test"})
	if err != nil {
		t.Fatalf("first containment: %v", err)
	}
	if first == nil || first.Recovery.Status != RecoveryEnqueueManualRecoveryRequired {
		t.Fatalf("first recovery result = %#v, want manual recovery after enqueue failure", first)
	}
	second, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "retry test"})
	if err != nil {
		t.Fatalf("retry containment: %v", err)
	}
	if second == nil || second.Recovery.Status != RecoveryEnqueueQueued {
		t.Fatalf("retry recovery result = %#v, want queued after retry", second)
	}
	enqueuer.mu.Lock()
	attempts := enqueuer.attempts
	enqueuer.mu.Unlock()
	if attempts != 2 {
		t.Fatalf("recovery enqueue attempts = %d, want 2", attempts)
	}
}

func TestContainmentWithoutARecoveryEnqueuerReportsManualRecovery(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "no-recovery-enqueuer@example.test"
	pair, err := auth.Signup(ctx, "no_recovery_enqueuer", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	result, err := NewAccountSecurity(q).ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "missing queue"})
	if err != nil {
		t.Fatalf("containment: %v", err)
	}
	if result == nil || result.Recovery.Status != RecoveryEnqueueManualRecoveryRequired {
		t.Fatalf("containment recovery result = %#v, want manual recovery without adapter", result)
	}
}

func TestContainmentRequiresAnOwnedEmailClaimForRecovery(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "duplicate-recovery@example.test"
	first, err := auth.Signup(ctx, "duplicate_recovery_one", "password123", &email)
	if err != nil {
		t.Fatalf("first signup: %v", err)
	}
	second, err := auth.Signup(ctx, "duplicate_recovery_two", "password123", &email)
	if err != nil {
		t.Fatalf("second signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, first.UserID); err != nil {
		t.Fatalf("confirm first email: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, `UPDATE users SET email_confirmed = TRUE WHERE id = $1`, second.UserID); err != nil {
		t.Fatalf("mark duplicate verified: %v", err)
	}
	if err := q.BackfillEmailLoginClaims(ctx); err != nil {
		t.Fatalf("backfill duplicate claim: %v", err)
	}
	claim, err := q.GetEmailLoginClaim(ctx, email)
	if err != nil || claim == nil || claim.State != db.EmailClaimBlocked || claim.OwnerUserID != nil {
		t.Fatalf("duplicate claim = %#v, err=%v", claim, err)
	}

	security := NewAccountSecurity(q)
	result, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: first.UserID, Reason: "duplicate test"})
	if err != nil {
		t.Fatalf("contain duplicate account: %v", err)
	}
	if result == nil || result.NewState != db.SecurityStateSecuredManualRecovery || result.Recovery.Status != RecoveryEnqueueManualRecoveryRequired {
		t.Fatalf("duplicate containment result = %#v, want manual recovery", result)
	}
}

func TestRecoveryActionRequiresRestrictedAccountAndOwnedEmailBinding(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "restricted-recovery@example.test"
	pair, err := auth.Signup(ctx, "restricted_recovery", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, nil, time.Minute); err == nil {
		t.Fatal("normal account received an unbound recovery action")
	}
	if _, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, time.Minute); err == nil {
		t.Fatal("normal account received a bound recovery action")
	}
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "restricted action test"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	if _, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, nil, time.Minute); err == nil {
		t.Fatal("restricted recovery accepted a nil email binding")
	}
	if action, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, time.Minute); err != nil || action == nil {
		t.Fatalf("restricted recovery with owned binding: action=%#v err=%v", action, err)
	}
}

func TestRecoveryRejectsABlockedEmailBindingAtRedemption(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "blocked-redemption@example.test"
	pair, err := auth.Signup(ctx, "blocked_redemption", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	other, err := auth.Signup(ctx, "blocked_redemption_other", "password123", &email)
	if err != nil {
		t.Fatalf("second signup: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "blocked redemption"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	secret := "blocked-redemption-token"
	hash := sha256.Sum256([]byte(secret))
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil {
		t.Fatalf("security state: %#v err=%v", state, err)
	}
	if err := q.CreateAccountActionToken(ctx, db.AccountActionTokenParams{
		ID: uuid.New(), AccountID: pair.UserID, TokenHash: hash[:], Purpose: db.ActionTokenPurposeRecovery,
		EmailBinding: &email, AuthGeneration: state.AuthGeneration, ExpiresAt: time.Now().Add(time.Minute),
	}); err != nil {
		t.Fatalf("create recovery token: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, `UPDATE users SET email_confirmed = TRUE WHERE id = $1`, other.UserID); err != nil {
		t.Fatalf("create duplicate verified address: %v", err)
	}
	if err := q.BackfillEmailLoginClaims(ctx); err != nil {
		t.Fatalf("backfill blocked address: %v", err)
	}
	if err := security.CompleteRecovery(ctx, secret, "recovery-password"); err == nil {
		t.Fatal("recovery consumed a token whose email claim became blocked")
	}
}

func TestContainmentAndRecoveryInvalidateLegacyActionValues(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "legacy-fence@example.test"
	pair, err := auth.Signup(ctx, "legacy_fence", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	oldReset, oldDelete, oldCode := "old-reset", "old-delete", "123456"
	expires := time.Now().Add(time.Hour)
	if err := q.SetUserResetPasswordUrl(ctx, pair.UserID, oldReset, expires); err != nil {
		t.Fatalf("set old reset URL: %v", err)
	}
	if err := q.SetUserDeletionUrl(ctx, pair.UserID, oldDelete, expires); err != nil {
		t.Fatalf("set old deletion URL: %v", err)
	}
	if err := q.SetUserRecoveryCode(ctx, pair.UserID, oldCode, expires); err != nil {
		t.Fatalf("set old recovery code: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "legacy fence"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	if got, err := q.GetUserByResetPasswordUrl(ctx, oldReset); err != nil || got != nil {
		t.Fatalf("old reset URL after containment = %#v err=%v", got, err)
	}
	if got, err := q.GetUserByDeletionUrl(ctx, oldDelete); err != nil || got != nil {
		t.Fatalf("old deletion URL after containment = %#v err=%v", got, err)
	}
	if ok, err := q.GetUserByIDAndCode(ctx, pair.UserID, oldCode); err != nil || ok {
		t.Fatalf("old recovery code after containment = %v err=%v", ok, err)
	}

	// Exercise the recovery transition independently with values that could have
	// been written by an old client while the account was restricted.
	if err := q.SetUserResetPasswordUrl(ctx, pair.UserID, oldReset, expires); err != nil {
		t.Fatalf("set recovery reset URL: %v", err)
	}
	if err := q.SetUserDeletionUrl(ctx, pair.UserID, oldDelete, expires); err != nil {
		t.Fatalf("set recovery deletion URL: %v", err)
	}
	if err := q.SetUserRecoveryCode(ctx, pair.UserID, oldCode, expires); err != nil {
		t.Fatalf("set recovery code: %v", err)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil {
		t.Fatalf("restricted state: %#v err=%v", state, err)
	}
	secret := "legacy-fence-recovery"
	hash := sha256.Sum256([]byte(secret))
	if err := q.CreateAccountActionToken(ctx, db.AccountActionTokenParams{
		ID: uuid.New(), AccountID: pair.UserID, TokenHash: hash[:], Purpose: db.ActionTokenPurposeRecovery,
		EmailBinding: &email, AuthGeneration: state.AuthGeneration, ExpiresAt: expires,
	}); err != nil {
		t.Fatalf("create recovery token: %v", err)
	}
	if err := security.CompleteRecovery(ctx, secret, "legacy-fence-password"); err != nil {
		t.Fatalf("complete recovery: %v", err)
	}
	if got, err := q.GetUserByResetPasswordUrl(ctx, oldReset); err != nil || got != nil {
		t.Fatalf("old reset URL after recovery = %#v err=%v", got, err)
	}
	if got, err := q.GetUserByDeletionUrl(ctx, oldDelete); err != nil || got != nil {
		t.Fatalf("old deletion URL after recovery = %#v err=%v", got, err)
	}
	if ok, err := q.GetUserByIDAndCode(ctx, pair.UserID, oldCode); err != nil || ok {
		t.Fatalf("old recovery code after recovery = %v err=%v", ok, err)
	}
}

func TestRecoveryFencesAccessTokenIssuedBeforeContainment(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "stale-after-recovery@example.test"
	pair, err := auth.Signup(ctx, "stale_after_recovery", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "stale token"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil {
		t.Fatalf("contained state: %#v err=%v", state, err)
	}
	secret := "stale-after-recovery-token"
	hash := sha256.Sum256([]byte(secret))
	if err := q.CreateAccountActionToken(ctx, db.AccountActionTokenParams{
		ID: uuid.New(), AccountID: pair.UserID, TokenHash: hash[:], Purpose: db.ActionTokenPurposeRecovery,
		EmailBinding: &email, AuthGeneration: state.AuthGeneration, ExpiresAt: time.Now().Add(time.Minute),
	}); err != nil {
		t.Fatalf("create recovery token: %v", err)
	}
	if err := security.CompleteRecovery(ctx, secret, "stale-recovery-password"); err != nil {
		t.Fatalf("complete recovery: %v", err)
	}
	claims, err := auth.tok.ParseAccessTokenClaims(pair.AccessToken)
	if err != nil {
		t.Fatalf("parse stale access token: %v", err)
	}
	if err := security.ValidateGeneration(ctx, pair.UserID, claims.AuthGeneration, claims.GenerationPresent); err != ErrStaleGeneration {
		t.Fatalf("stale access token validation = %v, want ErrStaleGeneration", err)
	}
}

func TestConfiguredAdminUsernameWithoutMembershipIsNotAdmin(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	uid := createTestUser(t, auth, "configured-admin-name")
	auth.cfg.AdminUsername = "configured-admin-name"
	isAdmin, err := auth.IsAdmin(ctx, uid)
	if err != nil {
		t.Fatalf("admin lookup: %v", err)
	}
	if isAdmin {
		t.Fatal("configured username received admin role without membership")
	}
	_ = q
}

func TestRefreshLookupMappingPreservesDatabaseFailures(t *testing.T) {
	databaseErr := errors.New("refresh lookup unavailable")
	if mapped, handled := classifyRefreshLookupError(databaseErr); handled || mapped != databaseErr {
		t.Fatalf("database refresh error mapping = %v, handled=%v; want original error and propagation", mapped, handled)
	}
	if mapped, handled := classifyRefreshLookupError(fmt.Errorf("wrapped: %w", pgx.ErrNoRows)); !handled || apperrors.HTTPStatus(mapped) != 400 {
		t.Fatalf("not-found refresh error mapping = %v, handled=%v; want compatibility bad request", mapped, handled)
	}
}

func TestContainmentRejectsOversizedIncidentInputs(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	uid := createTestUser(t, auth, "containment_input_limits")
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{
		AccountID: uid,
		Reason:    strings.Repeat("r", maxContainmentReasonBytes+1),
	}); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("oversized reason error = %v, want status 400", err)
	}
	if _, err := security.ContainAccount(ctx, ContainmentRequest{
		AccountID: uid,
		Metadata:  []byte(strings.Repeat("m", maxContainmentMetadataBytes+1)),
	}); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("oversized metadata error = %v, want status 400", err)
	}
	state, err := q.GetUserSecurityState(ctx, uid)
	if err != nil {
		t.Fatalf("read state: %v", err)
	}
	if state == nil || state.SecurityState != db.SecurityStateNormal {
		t.Fatalf("oversized input changed security state: %#v", state)
	}
}

func TestEmailChangeInvalidatesLegacyResetAndDeletionValues(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	oldEmail := "email-change-fence@example.test"
	pair, err := auth.Signup(ctx, "email_change_fence", "password123", &oldEmail)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	oldReset, oldDelete := "email-change-old-reset", "email-change-old-delete"
	expires := time.Now().Add(time.Hour)
	if err := q.SetUserResetPasswordUrl(ctx, pair.UserID, oldReset, expires); err != nil {
		t.Fatalf("set reset URL: %v", err)
	}
	if err := q.SetUserDeletionUrl(ctx, pair.UserID, oldDelete, expires); err != nil {
		t.Fatalf("set deletion URL: %v", err)
	}
	newEmail := "email-change-new@example.test"
	if _, err := user.Update(ctx, pair.UserID, UserUpdateInput{Email: &newEmail}); err != nil {
		t.Fatalf("email change: %v", err)
	}
	if got, err := q.GetUserByResetPasswordUrl(ctx, oldReset); err != nil || got != nil {
		t.Fatalf("old reset URL after email change = %#v err=%v", got, err)
	}
	if got, err := q.GetUserByDeletionUrl(ctx, oldDelete); err != nil || got != nil {
		t.Fatalf("old deletion URL after email change = %#v err=%v", got, err)
	}
}

func TestLegacyResetActionBindsCurrentEmailAndGenerationAndIsSingleUse(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "legacy-reset-binding@example.test"
	pair, err := auth.Signup(ctx, "legacy_reset_binding", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "legacy reset binding"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	legacyURL := "legacy-reset-binding-url"
	if err := q.SetUserResetPasswordUrl(ctx, pair.UserID, legacyURL, time.Now().Add(time.Minute)); err != nil {
		t.Fatalf("set legacy reset URL: %v", err)
	}
	action, err := security.IssueLegacyActionToken(ctx, legacyURL, db.ActionTokenPurposeRecovery, time.Minute)
	if err != nil {
		t.Fatalf("issue legacy recovery action: %v", err)
	}
	if action == nil || action.AuthGeneration != 1 {
		t.Fatalf("legacy action = %#v, want generation 1", action)
	}
	hash := sha256.Sum256([]byte(action.Token))
	stored, err := q.GetAccountActionTokenByHash(ctx, hash[:])
	if err != nil || stored == nil || stored.EmailBinding == nil || *stored.EmailBinding != email || stored.AuthGeneration != 1 {
		t.Fatalf("stored legacy action = %#v err=%v, want current bound generation", stored, err)
	}
	if _, err := security.IssueLegacyActionToken(ctx, legacyURL, db.ActionTokenPurposeRecovery, time.Minute); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("reused legacy reset URL error = %v, want status 400", err)
	}
	if got, err := q.GetUserByResetPasswordUrl(ctx, legacyURL); err != nil || got != nil {
		t.Fatalf("legacy reset URL after upgrade = %#v err=%v, want invalidated", got, err)
	}
}

func TestLegacyResetURLIsRejectedAfterEmailChange(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	oldEmail := "legacy-reset-old@example.test"
	pair, err := auth.Signup(ctx, "legacy_reset_old", "password123", &oldEmail)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	legacyURL := "legacy-reset-before-email-change"
	if err := q.SetUserResetPasswordUrl(ctx, pair.UserID, legacyURL, time.Now().Add(time.Minute)); err != nil {
		t.Fatalf("set legacy reset URL: %v", err)
	}
	newEmail := "legacy-reset-new@example.test"
	if _, err := user.Update(ctx, pair.UserID, UserUpdateInput{Email: &newEmail}); err != nil {
		t.Fatalf("email change: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.IssueLegacyActionToken(ctx, legacyURL, db.ActionTokenPurposeRecovery, time.Minute); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("stale legacy reset error = %v, want status 400", err)
	}
}

func TestConcurrentLegacyResetUpgradeConsumesURLOnce(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "legacy-reset-race@example.test"
	pair, err := auth.Signup(ctx, "legacy_reset_race", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "legacy reset race"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	legacyURL := "legacy-reset-race-url"
	if err := q.SetUserResetPasswordUrl(ctx, pair.UserID, legacyURL, time.Now().Add(time.Minute)); err != nil {
		t.Fatalf("set legacy reset URL: %v", err)
	}
	start := make(chan struct{})
	results := make(chan error, 2)
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, err := security.IssueLegacyActionToken(ctx, legacyURL, db.ActionTokenPurposeRecovery, time.Minute)
			results <- err
		}()
	}
	close(start)
	wg.Wait()
	close(results)
	var successes int
	var failures int
	for err := range results {
		if err == nil {
			successes++
		} else if apperrors.HTTPStatus(err) == 400 {
			failures++
		} else {
			t.Fatalf("legacy reset race error = %v, want invalid replay or success", err)
		}
	}
	if successes != 1 || failures != 1 {
		t.Fatalf("legacy reset race outcomes = successes %d failures %d, want one each", successes, failures)
	}
}

func TestLegacyEmailConfirmationChecksPresentedURLInsideAccountLock(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	oldEmail := "confirmation-old@example.test"
	pair, err := auth.Signup(ctx, "confirmation_atomic", "password123", &oldEmail)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	created, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil || created == nil || created.EmailConfirmationUrl == nil {
		t.Fatalf("created confirmation state = %#v err=%v", created, err)
	}
	oldURL := *created.EmailConfirmationUrl
	// Move to a genuinely new address after first confirming the original one;
	// this leaves a fresh confirmation URL while the presented URL is stale.
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm original email: %v", err)
	}
	newEmail := "confirmation-new@example.test"
	if _, err := user.Update(ctx, pair.UserID, UserUpdateInput{Email: &newEmail}); err != nil {
		t.Fatalf("email change: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ConfirmLegacyEmail(ctx, oldURL); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("stale confirmation error = %v, want status 400", err)
	}
	current, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("read changed user: %v", err)
	}
	if current == nil || current.EmailConfirmed {
		t.Fatalf("stale confirmation changed current email state: %#v", current)
	}
}

func TestLegacyEmailConfirmationReturnsUsernameOnlyForCurrentURL(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "confirmation-current@example.test"
	pair, err := auth.Signup(ctx, "confirmation_current", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	u, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil || u == nil || u.EmailConfirmationUrl == nil {
		t.Fatalf("confirmation state = %#v err=%v", u, err)
	}
	security := NewAccountSecurity(q)
	username, err := security.ConfirmLegacyEmail(ctx, *u.EmailConfirmationUrl)
	if err != nil || username != "confirmation_current" {
		t.Fatalf("confirm current URL = %q err=%v, want username", username, err)
	}
	if _, err := security.ConfirmLegacyEmail(ctx, *u.EmailConfirmationUrl); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("replayed confirmation error = %v, want status 400", err)
	}
}

func TestConcurrentLegacyEmailConfirmationsHaveOneClaimOwner(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "confirmation-race@example.test"
	one, err := auth.Signup(ctx, "confirmation_race_one", "password123", &email)
	if err != nil {
		t.Fatalf("first signup: %v", err)
	}
	two, err := auth.Signup(ctx, "confirmation_race_two", "password123", &email)
	if err != nil {
		t.Fatalf("second signup: %v", err)
	}
	firstUser, err := q.GetUserByID(ctx, one.UserID)
	if err != nil || firstUser == nil || firstUser.EmailConfirmationUrl == nil {
		t.Fatalf("first confirmation state = %#v err=%v", firstUser, err)
	}
	secondUser, err := q.GetUserByID(ctx, two.UserID)
	if err != nil || secondUser == nil || secondUser.EmailConfirmationUrl == nil {
		t.Fatalf("second confirmation state = %#v err=%v", secondUser, err)
	}
	security := NewAccountSecurity(q)
	urls := []string{*firstUser.EmailConfirmationUrl, *secondUser.EmailConfirmationUrl}
	results := make(chan error, len(urls))
	start := make(chan struct{})
	var wg sync.WaitGroup
	for _, confirmationURL := range urls {
		confirmationURL := confirmationURL
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, err := security.ConfirmLegacyEmail(ctx, confirmationURL)
			results <- err
		}()
	}
	close(start)
	wg.Wait()
	close(results)
	var successes int
	for err := range results {
		if err == nil {
			successes++
		}
	}
	if successes != 1 {
		t.Fatalf("concurrent confirmation successes = %d, want exactly one", successes)
	}
	claim, err := q.GetEmailLoginClaim(ctx, email)
	if err != nil || claim == nil || claim.State != db.EmailClaimOwned || claim.OwnerUserID == nil {
		t.Fatalf("confirmation race claim = %#v err=%v, want one owner", claim, err)
	}
}

func TestCompleteRecoveryConsumesTokenAndRequiresFreshGeneration(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recovery-completion@example.test"
	pair, err := auth.Signup(ctx, "recovery_completion", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	userID := pair.UserID
	if err := q.ConfirmUserEmail(ctx, userID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: userID, Reason: "recovery test"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	secret := "recovery-secret"
	hash := sha256.Sum256([]byte(secret))
	if err := q.CreateAccountActionToken(ctx, db.AccountActionTokenParams{
		ID: uuid.New(), AccountID: userID, TokenHash: hash[:], Purpose: db.ActionTokenPurposeRecovery,
		EmailBinding: &email, AuthGeneration: 1, ExpiresAt: time.Now().Add(time.Minute),
	}); err != nil {
		t.Fatalf("create recovery token: %v", err)
	}
	if err := security.CompleteRecovery(ctx, secret, "new-password"); err != nil {
		t.Fatalf("complete recovery: %v", err)
	}
	state, err := q.GetUserSecurityState(ctx, userID)
	if err != nil {
		t.Fatalf("read recovered state: %v", err)
	}
	if state == nil || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired || state.AuthGeneration != 2 {
		t.Fatalf("recovered state = %#v, want normal generation 2", state)
	}
	if err := security.CompleteRecovery(ctx, secret, "another-password"); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("replayed recovery error = %v, want status 400", err)
	}
}

func TestAuthIssuesGenerationBoundAccessTokens(t *testing.T) {
	_, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "generation_bound_signup", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	claims, err := auth.tok.ParseAccessTokenClaims(pair.AccessToken)
	if err != nil {
		t.Fatalf("parse signup token: %v", err)
	}
	if !claims.GenerationPresent || claims.AuthGeneration != 0 {
		t.Fatalf("signup claims = %#v, want explicit generation zero", claims)
	}
}

func TestLoginAndRefreshRejectContainedAccount(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "contained_login", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "test"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	if _, err := auth.Login(ctx, "contained_login", "password123"); apperrors.HTTPStatus(err) != 403 {
		t.Fatalf("contained login error = %v, want 403", err)
	}
	if _, err := auth.Refresh(ctx, pair.RefreshToken, pair.UserID); apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("contained refresh error = %v, want 400", err)
	}
}

func TestConcurrentLoginAndContainmentCannotLeaveAnUsableToken(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "login_containment_race", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	security := NewAccountSecurity(q)
	start := make(chan struct{})
	loginResult := make(chan *TokenPair, 1)
	loginError := make(chan error, 1)
	containResult := make(chan error, 1)
	go func() {
		<-start
		result, err := auth.Login(ctx, "login_containment_race", "password123")
		loginResult <- result
		loginError <- err
	}()
	go func() {
		<-start
		_, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "login race"})
		containResult <- err
	}()
	close(start)
	if err := <-containResult; err != nil {
		t.Fatalf("containment race: %v", err)
	}
	loginPair, err := <-loginResult, <-loginError
	if err != nil && apperrors.HTTPStatus(err) != 403 && apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("login race error = %v, want normal rejection", err)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil || (state.SecurityState != db.SecurityStateCompromised && state.SecurityState != db.SecurityStateSecuredManualRecovery) {
		t.Fatalf("post-race security state = %#v err=%v, want contained", state, err)
	}
	if loginPair != nil {
		claims, err := auth.tok.ParseAccessTokenClaims(loginPair.AccessToken)
		if err != nil {
			t.Fatalf("parse raced login token: %v", err)
		}
		if err := security.ValidateGeneration(ctx, pair.UserID, claims.AuthGeneration, claims.GenerationPresent); err != ErrAccountRestricted {
			t.Fatalf("raced login token validation = %v, want ErrAccountRestricted", err)
		}
	}
}

func TestConcurrentRefreshAndOwnRevokeCannotResurrectRefreshCredential(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "refresh_revoke_race", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	security := NewAccountSecurity(q)
	start := make(chan struct{})
	refreshResult := make(chan *TokenPair, 1)
	refreshError := make(chan error, 1)
	revokeError := make(chan error, 1)
	go func() {
		<-start
		result, err := auth.Refresh(ctx, pair.RefreshToken, pair.UserID)
		refreshResult <- result
		refreshError <- err
	}()
	go func() {
		<-start
		revokeError <- security.RevokeOwnSession(ctx, pair.UserID, pair.RefreshToken)
	}()
	close(start)
	if err := <-revokeError; err != nil {
		t.Fatalf("revoke race: %v", err)
	}
	refreshed, err := <-refreshResult, <-refreshError
	if err != nil && apperrors.HTTPStatus(err) != 400 {
		t.Fatalf("refresh race error = %v, want success or compatibility 400", err)
	}
	if refreshed != nil && refreshed.RefreshToken != pair.RefreshToken {
		t.Fatalf("refresh race returned a different refresh token: %#v", refreshed)
	}
	if _, err := q.FindRefreshToken(ctx, pair.RefreshToken); !errors.Is(err, pgx.ErrNoRows) {
		t.Fatalf("refresh credential after revoke race err = %v, want pgx.ErrNoRows", err)
	}
}

func TestConcurrentPasswordUpdateAndContainmentLeaveOnlyContainedState(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "password_containment_race", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	security := NewAccountSecurity(q)
	start := make(chan struct{})
	updateResult := make(chan *UserUpdateResult, 1)
	updateError := make(chan error, 1)
	containError := make(chan error, 1)
	go func() {
		<-start
		password := "race-password"
		result, err := user.Update(ctx, pair.UserID, UserUpdateInput{Password: &password})
		updateResult <- result
		updateError <- err
	}()
	go func() {
		<-start
		_, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "password race"})
		containError <- err
	}()
	close(start)
	if err := <-containError; err != nil {
		t.Fatalf("containment race: %v", err)
	}
	updated, err := <-updateResult, <-updateError
	if err != nil && apperrors.HTTPStatus(err) != 403 && apperrors.HTTPStatus(err) != 401 {
		t.Fatalf("password update race error = %v, want restricted rejection", err)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil || (state.SecurityState != db.SecurityStateCompromised && state.SecurityState != db.SecurityStateSecuredManualRecovery) || !state.PasswordDisabled || !state.PasswordResetRequired {
		t.Fatalf("post-password-race state = %#v err=%v, want contained", state, err)
	}
	if updated != nil && updated.UserTokenDto != nil {
		claims, err := auth.tok.ParseAccessTokenClaims(updated.UserTokenDto.AccessToken)
		if err != nil {
			t.Fatalf("parse raced password token: %v", err)
		}
		if err := security.ValidateGeneration(ctx, pair.UserID, claims.AuthGeneration, claims.GenerationPresent); err != ErrAccountRestricted {
			t.Fatalf("raced password token validation = %v, want ErrAccountRestricted", err)
		}
	}
}

func TestConcurrentEmailChangeAndContainmentLeaveTheAddressFenced(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	oldEmail := "email_containment_race_old@example.test"
	pair, err := auth.Signup(ctx, "email_containment_race", "password123", &oldEmail)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	security := NewAccountSecurity(q)
	start := make(chan struct{})
	updateError := make(chan error, 1)
	containError := make(chan error, 1)
	go func() {
		<-start
		newEmail := "email_containment_race_new@example.test"
		_, err := user.Update(ctx, pair.UserID, UserUpdateInput{Email: &newEmail})
		updateError <- err
	}()
	go func() {
		<-start
		_, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "email race"})
		containError <- err
	}()
	close(start)
	if err := <-containError; err != nil {
		t.Fatalf("containment race: %v", err)
	}
	if err := <-updateError; err != nil && apperrors.HTTPStatus(err) != 403 && apperrors.HTTPStatus(err) != 401 {
		t.Fatalf("email update race error = %v, want restricted rejection", err)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil || (state.SecurityState != db.SecurityStateCompromised && state.SecurityState != db.SecurityStateSecuredManualRecovery) || !state.PasswordDisabled || !state.PasswordResetRequired {
		t.Fatalf("post-email-race state = %#v err=%v, want contained", state, err)
	}
	if state.EmailConfirmed {
		claim, err := q.GetEmailLoginClaim(ctx, oldEmail)
		if err != nil || claim == nil || claim.State != db.EmailClaimOwned || claim.OwnerUserID == nil || *claim.OwnerUserID != pair.UserID {
			t.Fatalf("contained verified email claim = %#v err=%v, want owned account claim", claim, err)
		}
	}
}

func TestConcurrentRecoveryRedemptionConsumesCapabilityOnce(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "recovery-race@example.test"
	pair, err := auth.Signup(ctx, "recovery_race", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm email: %v", err)
	}
	security := NewAccountSecurity(q)
	if _, err := security.ContainAccount(ctx, ContainmentRequest{AccountID: pair.UserID, Reason: "recovery redemption race"}); err != nil {
		t.Fatalf("containment: %v", err)
	}
	action, err := security.IssueActionToken(ctx, nil, pair.UserID, db.ActionTokenPurposeRecovery, &email, time.Minute)
	if err != nil || action == nil {
		t.Fatalf("issue recovery action: %#v err=%v", action, err)
	}
	start := make(chan struct{})
	results := make(chan error, 2)
	var wg sync.WaitGroup
	for _, password := range []string{"recovery-race-one", "recovery-race-two"} {
		password := password
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			results <- security.CompleteRecovery(ctx, action.Token, password)
		}()
	}
	close(start)
	wg.Wait()
	close(results)
	var successes int
	var failures int
	for err := range results {
		if err == nil {
			successes++
		} else if apperrors.HTTPStatus(err) == 400 {
			failures++
		} else {
			t.Fatalf("recovery race error = %v, want invalid replay or success", err)
		}
	}
	if successes != 1 || failures != 1 {
		t.Fatalf("recovery race outcomes = successes %d failures %d, want one each", successes, failures)
	}
	state, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || state == nil || state.SecurityState != db.SecurityStateNormal || state.AuthGeneration != 2 {
		t.Fatalf("recovered race state = %#v err=%v, want normal generation 2", state, err)
	}
}

func TestPasswordUpdateAdvancesGenerationAndReissuesInsideMutation(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	old, err := auth.Signup(ctx, "password_generation", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	newPassword := "new-password"
	result, err := user.Update(ctx, old.UserID, UserUpdateInput{Password: &newPassword})
	if err != nil {
		t.Fatalf("password update: %v", err)
	}
	if result == nil || result.UserTokenDto == nil {
		t.Fatal("password update did not issue a replacement token pair")
	}
	claims, err := auth.tok.ParseAccessTokenClaims(result.UserTokenDto.AccessToken)
	if err != nil {
		t.Fatalf("parse replacement token: %v", err)
	}
	if !claims.GenerationPresent || claims.AuthGeneration != 1 {
		t.Fatalf("replacement claims = %#v, want generation 1", claims)
	}
	if _, err := q.FindRefreshToken(ctx, old.RefreshToken); err == nil {
		t.Fatal("old refresh token survived password change")
	}
}
