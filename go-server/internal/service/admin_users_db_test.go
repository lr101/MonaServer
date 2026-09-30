package service

import (
	"context"
	"testing"
	"time"
)

func TestProductionAdminUserUpdateChangesEmailAndSecurityState(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "admin_edit_target", "password123", nil)
	if err != nil {
		t.Fatal(err)
	}
	actorID := createTestUser(t, auth, "admin_edit_actor")
	store := NewProductionAdminStore(q, serviceTestEmail(t))
	users := NewAdminUserService(store)
	users.SetRecentMFATTL(5 * time.Minute)
	actor := AdminActor{
		ID: actorID, Capabilities: []string{"users.write"},
		RecentMFAAt: timePtrForAdminUserTest(time.Now().UTC()), RecentMFAAction: "users.write",
	}
	initial, err := q.GetAdminRuntimeAccount(ctx, pair.UserID)
	if err != nil || initial == nil {
		t.Fatalf("load initial target: %#v, err=%v", initial, err)
	}
	expectedAuthGeneration := initial.AuthGeneration

	newEmail := "admin-edit-target@example.com"
	newUsername := "admin_edit_target_renamed"
	optOut := true
	updated, err := users.Update(ctx, actor, pair.UserID, AdminUserUpdate{
		ExpectedAuthGeneration: &expectedAuthGeneration,
		Username:               &newUsername, Email: &newEmail, CommunicationOptOut: &optOut,
	})
	if err != nil {
		t.Fatalf("update profile: %v", err)
	}
	if updated.Username != newUsername || updated.Email == nil || *updated.Email != newEmail || updated.EmailVerified || !updated.CommunicationOptOut {
		t.Fatalf("updated profile = %#v", updated)
	}
	expectedAuthGeneration = updated.AuthGeneration
	stored, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil || stored == nil || stored.EmailConfirmationUrl == nil || stored.AuthGeneration < 1 {
		t.Fatalf("stored email confirmation/generation = %#v, err=%v", stored, err)
	}

	compromised := "compromised"
	updated, err = users.Update(ctx, actor, pair.UserID, AdminUserUpdate{ExpectedAuthGeneration: &expectedAuthGeneration, SecurityState: &compromised})
	if err != nil {
		t.Fatalf("update security state: %v", err)
	}
	if updated.SecurityState != compromised || !updated.PasswordDisabled || !updated.PasswordResetRequired || updated.CompromisedAt == nil {
		t.Fatalf("updated security state = %#v", updated)
	}
	security, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || security == nil || security.AuthGeneration < 2 {
		t.Fatalf("stored security generation = %#v, err=%v", security, err)
	}
	audit, err := q.ListAuditEvents(ctx, nil, 10)
	if err != nil {
		t.Fatal(err)
	}
	updatedEvents := 0
	for _, event := range audit {
		if event.Action == "admin_user_updated" && event.TargetAccountID != nil && *event.TargetAccountID == pair.UserID {
			updatedEvents++
		}
	}
	if updatedEvents != 2 {
		t.Fatalf("admin user update audit events = %d, want 2", updatedEvents)
	}
}

func timePtrForAdminUserTest(value time.Time) *time.Time { return &value }
