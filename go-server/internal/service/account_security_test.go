package service

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

type failingRecoveryEnqueuer struct{}

func (failingRecoveryEnqueuer) EnqueueRecovery(context.Context, *db.Queries, RecoveryEnqueueRequest) (RecoveryEnqueueResult, error) {
	return RecoveryEnqueueResult{Status: RecoveryEnqueueManualRecoveryRequired}, errors.New("queue unavailable")
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
		AuthGeneration: 1, ExpiresAt: time.Now().Add(time.Minute),
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
